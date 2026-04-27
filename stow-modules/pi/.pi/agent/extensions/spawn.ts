/**
 * Spawn extension — create a child session seeded with the parent's last output.
 *
 * The new session's first message is: "<user prompt> <last assistant text>".
 * This is useful for branching off a result (e.g. "Sort these." + the list the
 * agent just produced) without carrying the full conversation history.
 *
 * Usage:
 *   /spawn                        — prompts for a starting instruction
 *   /spawn Summarize the results  — uses the argument directly
 *
 * Also registered as a tool so the agent can call it on behalf of the user.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

function getLastAssistantText(
  ctx: { sessionManager: { getBranch: () => any[] } },
): string | undefined {
  const branch = ctx.sessionManager.getBranch();

  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i];
    if (entry.type !== "message") continue;
    const msg = entry.message;
    if (msg.role !== "assistant") continue;

    const texts = (msg.content as any[])
      .filter((c: any) => c.type === "text")
      .map((c: any) => c.text);

    if (texts.length > 0) return texts.join("\n");
  }

  return undefined;
}

async function spawnFromCommand(
  prompt: string,
  ctx: any,
): Promise<{ ok: boolean; reason?: string }> {
  const lastText = getLastAssistantText(ctx);
  if (!lastText) {
    return { ok: false, reason: "No assistant message found in the current session." };
  }

  const combined = `${prompt} ${lastText}`;
  const parentSession = ctx.sessionManager.getSessionFile();

  try {
    const result = await ctx.newSession({
      parentSession,
      withSession: async (replacementCtx: any) => {
        // Pre-fill the editor in the new session so the user can review and submit.
        // Must use the replacement ctx — the outer ctx is stale after newSession.
        replacementCtx.ui.setEditorText(combined);
        replacementCtx.ui.notify(
          "Session spawned. Press Enter to submit the pre-filled prompt.",
          "success",
        );
      },
    });

    if (result.cancelled) {
      return { ok: false, reason: "Session creation was cancelled by another extension." };
    }

    return { ok: true };
  } catch (err: any) {
    return { ok: false, reason: `newSession failed: ${err?.message ?? err}` };
  }
}

export default function (pi: ExtensionAPI) {
  // ── Command ──────────────────────────────────────────────────────────
  pi.registerCommand("spawn", {
    description: "Create a child session seeded with your prompt + the last assistant output",
    handler: async (args, ctx) => {
      let prompt = args?.trim();

      if (!prompt) {
        if (!ctx.hasUI) {
          ctx.ui.notify("Usage: /spawn <prompt>", "error");
          return;
        }
        const input = await ctx.ui.input("Spawn", "Starting prompt for the new session:");
        if (!input) {
          ctx.ui.notify("Cancelled.", "info");
          return;
        }
        prompt = input;
      }

      const result = await spawnFromCommand(prompt, ctx);

      if (!result.ok) {
        // Safe to use ctx here only because newSession failed/was cancelled,
        // i.e. no session replacement occurred. On success, the success notify
        // is emitted from inside withSession using the replacement ctx.
        ctx.ui.notify(result.reason!, "error");
      }
    },
  });

  // ── Tool (for agent use) ─────────────────────────────────────────────
  pi.registerTool({
    name: "spawn_session",
    label: "Spawn Session",
    description:
      "Create a new child session whose first message combines the given prompt with the last assistant output from the current session. " +
      "Use this when the user wants to branch off the current results into a focused follow-up session.",
    promptSnippet: "Spawn a child session seeded with a prompt + the last assistant output",
    promptGuidelines: [
      "Use spawn_session when the user asks to continue a specific result in a new/separate session.",
    ],
    parameters: Type.Object({
      prompt: Type.String({
        description: "The instruction to prepend to the last assistant output in the new session",
      }),
    }),

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const lastText = getLastAssistantText(ctx);
      if (!lastText) {
        return {
          content: [{ type: "text" as const, text: "No assistant message found in the current session." }],
          details: {},
          isError: true,
        };
      }

      // Tools get ExtensionContext (no newSession). Queue the command as a follow-up.
      const escapedPrompt = params.prompt.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
      pi.sendUserMessage(`/spawn ${escapedPrompt}`, { deliverAs: "followUp" });

      return {
        content: [
          {
            type: "text" as const,
            text: "Queued /spawn as a follow-up. A new child session will be created after this turn.",
          },
        ],
        details: {},
      };
    },
  });
}
