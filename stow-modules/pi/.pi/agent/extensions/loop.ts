/**
 * Loop extension - run a prompt on a recurring interval, Claude Code /loop style.
 *
 * A loop re-fires its prompt as a user message in the current session, so each
 * iteration sees the conversation's latest state. Fires only while the agent is
 * idle; if the timer expires mid-run, the fire is deferred until the run settles.
 *
 * Usage:
 *   /loop 5m check the deploy     - every 5 minutes, send "check the deploy"
 *   /loop check the deploy        - same, with the default 5m interval
 *   /loop stop                    - cancel the active loop
 *   /loop                         - show loop status
 *
 * Intervals: <n>s | <n>m | <n>h | <n>d (minimum 10s).
 *
 * The model can end the loop itself via the `loop_stop` tool - each fired
 * prompt carries a note saying so. The loop is session-scoped: it is cancelled
 * on session switch and on shutdown.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "@earendil-works/pi-ai";

const DEFAULT_INTERVAL_MS = 5 * 60 * 1000;
const MIN_INTERVAL_MS = 10 * 1000;
const WIDGET_KEY = "loop";

interface LoopState {
  prompt: string;
  intervalMs: number;
  timer: ReturnType<typeof setInterval>;
  iterations: number;
  pendingFire: boolean;
}

function parseInterval(token: string): number | undefined {
  const m = /^(\d+)(s|m|h|d)$/.exec(token);
  if (!m) return undefined;
  const n = Number(m[1]);
  const unit = { s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 }[m[2] as "s" | "m" | "h" | "d"];
  return n * unit;
}

function formatInterval(ms: number): string {
  if (ms % 86_400_000 === 0) return `${ms / 86_400_000}d`;
  if (ms % 3_600_000 === 0) return `${ms / 3_600_000}h`;
  if (ms % 60_000 === 0) return `${ms / 60_000}m`;
  return `${Math.round(ms / 1000)}s`;
}

export default function (pi: ExtensionAPI) {
  let loop: LoopState | undefined;
  let agentBusy = false;

  function updateWidget(ctx: ExtensionContext) {
    if (!ctx.hasUI) return;
    if (!loop) {
      ctx.ui.setWidget(WIDGET_KEY, undefined);
      return;
    }
    const runs = loop.iterations === 1 ? "1 run" : `${loop.iterations} runs`;
    ctx.ui.setWidget(WIDGET_KEY, [
      `⟳ loop every ${formatInterval(loop.intervalMs)} (${runs}): ${loop.prompt} - /loop stop to end`,
    ]);
  }

  function stopLoop(ctx: ExtensionContext, reason: string) {
    if (!loop) return;
    clearInterval(loop.timer);
    loop = undefined;
    updateWidget(ctx);
    if (ctx.hasUI) ctx.ui.notify(reason, "info");
  }

  function fire(ctx: ExtensionContext) {
    if (!loop) return;
    loop.pendingFire = false;
    loop.iterations += 1;
    updateWidget(ctx);
    pi.sendUserMessage(
      `${loop.prompt}\n\n` +
        `[Recurring /loop task, iteration ${loop.iterations}, fires every ` +
        `${formatInterval(loop.intervalMs)}. If the task is complete or no longer ` +
        `useful, call the loop_stop tool to end the loop.]`,
    );
  }

  function startLoop(ctx: ExtensionContext, prompt: string, intervalMs: number) {
    if (loop) clearInterval(loop.timer);
    const state: LoopState = {
      prompt,
      intervalMs,
      iterations: 0,
      pendingFire: false,
      timer: setInterval(() => {
        if (!loop) return;
        if (agentBusy) {
          // Defer to agent_settled; collapse missed fires into one.
          loop.pendingFire = true;
          return;
        }
        fire(ctx);
      }, intervalMs),
    };
    loop = state;
    updateWidget(ctx);
    if (ctx.hasUI) {
      ctx.ui.notify(
        `Loop started: every ${formatInterval(intervalMs)} - "${prompt}". /loop stop to end.`,
        "success",
      );
    }
  }

  // ── Command ──────────────────────────────────────────────────────────
  pi.registerCommand("loop", {
    description: "Run a prompt on a recurring interval (e.g. /loop 5m check the deploy)",
    handler: async (args, ctx) => {
      const trimmed = args?.trim() ?? "";

      if (trimmed === "" || trimmed === "status") {
        if (!loop) {
          ctx.ui.notify("No active loop. Usage: /loop [interval] <prompt>", "info");
        } else {
          ctx.ui.notify(
            `Loop active: every ${formatInterval(loop.intervalMs)}, ` +
              `${loop.iterations} run(s) so far - "${loop.prompt}"`,
            "info",
          );
        }
        return;
      }

      if (trimmed === "stop" || trimmed === "off" || trimmed === "cancel") {
        if (!loop) {
          ctx.ui.notify("No active loop.", "info");
        } else {
          stopLoop(ctx, "Loop stopped.");
        }
        return;
      }

      const [first, ...rest] = trimmed.split(/\s+/);
      let intervalMs = parseInterval(first);
      let prompt: string;
      if (intervalMs === undefined) {
        intervalMs = DEFAULT_INTERVAL_MS;
        prompt = trimmed;
      } else {
        prompt = rest.join(" ");
      }

      if (!prompt) {
        ctx.ui.notify("Usage: /loop [interval] <prompt>", "error");
        return;
      }
      if (intervalMs < MIN_INTERVAL_MS) {
        ctx.ui.notify(`Minimum interval is ${formatInterval(MIN_INTERVAL_MS)}.`, "error");
        return;
      }

      startLoop(ctx, prompt, intervalMs);
    },
  });

  // ── Tool: let the model end the loop ─────────────────────────────────
  pi.registerTool({
    name: "loop_stop",
    label: "Stop Loop",
    description:
      "Stop the active recurring /loop task in this session. Call this when a " +
      "looped task is complete or no longer useful.",
    parameters: Type.Object({
      reason: Type.String({ description: "Short reason why the loop is being stopped" }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      if (!loop) {
        return {
          content: [{ type: "text" as const, text: "No active loop." }],
          details: {},
        };
      }
      stopLoop(ctx, `Loop stopped by agent: ${params.reason}`);
      return {
        content: [{ type: "text" as const, text: `Loop stopped: ${params.reason}` }],
        details: {},
      };
    },
  });

  // ── Lifecycle ────────────────────────────────────────────────────────
  pi.on("agent_start", async () => {
    agentBusy = true;
  });

  pi.on("agent_settled", async (_event, ctx) => {
    agentBusy = false;
    if (loop?.pendingFire && ctx.isIdle()) fire(ctx);
  });

  pi.on("session_before_switch", async (_event, ctx) => {
    if (loop) stopLoop(ctx, "Loop cancelled (session switch).");
  });

  pi.on("session_shutdown", async () => {
    if (loop) clearInterval(loop.timer);
    loop = undefined;
  });
}
