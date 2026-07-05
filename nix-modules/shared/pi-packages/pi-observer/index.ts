/**
 * pi-observer registry extension.
 *
 * Publishes a small liveness doc per pi session to
 * ~/.local/share/pi-observer/sessions/<sessionId>.json so the piobs CLI can
 * list active sessions, show live state, and hop to the tmux pane.
 *
 * Registry-only by design: content (thinking, tool calls, results) is read by
 * the CLI straight from pi's own session JSONL - full fidelity, no
 * duplication, truncation stays a distiller-side (reversible) decision.
 *
 * Hard rule: a broken observer must never break the host session. Every
 * handler is wrapped; after repeated write failures the extension
 * self-disables for the rest of the session.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { briefArgs, truncate, writeRegistryDoc, type RegistryDoc } from "./lib/registry.ts";

const MAX_WRITE_FAILURES = 5;
const ACTIVITY_THROTTLE_MS = 1000;

export default function (pi: ExtensionAPI) {
	let doc: RegistryDoc | null = null;
	let failures = 0;
	let disabled = false;
	let lastActivityWrite = 0;

	const write = () => {
		if (!doc || disabled) return;
		try {
			writeRegistryDoc(doc);
			failures = 0;
		} catch {
			failures++;
			if (failures >= MAX_WRITE_FAILURES) disabled = true;
		}
	};

	const update = (patch: Partial<RegistryDoc>) => {
		if (!doc) return;
		doc = { ...doc, ...patch, updatedAt: new Date().toISOString() };
		write();
	};

	/** Wrap handlers so observer bugs can never propagate into the session. */
	const safe = <E>(fn: (event: E, ctx: any) => void) => {
		return async (event: E, ctx: any) => {
			if (disabled) return;
			try {
				fn(event, ctx);
			} catch {
				failures++;
				if (failures >= MAX_WRITE_FAILURES) disabled = true;
			}
		};
	};

	pi.on(
		"session_start",
		safe((_event, ctx) => {
			const now = new Date().toISOString();
			doc = {
				schemaVersion: 1,
				sessionId: ctx.sessionManager.getSessionId(),
				pid: process.pid,
				pidStartedAt: Date.now() - process.uptime() * 1000,
				cwd: ctx.cwd,
				sessionFile: ctx.sessionManager.getSessionFile() ?? null,
				sessionName: ctx.sessionManager.getSessionName?.() ?? null,
				model: ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : null,
				tmux: process.env.TMUX_PANE ? { pane: process.env.TMUX_PANE } : null,
				state: "idle",
				currentActivity: null,
				startedAt: now,
				updatedAt: now,
				lastPrompt: null,
			};
			write();
		}),
	);

	pi.on(
		"before_agent_start",
		safe((event: any) => {
			update({ lastPrompt: truncate(String(event.prompt ?? ""), 200) });
		}),
	);

	// Mid-run redirections (steering / follow-up) stay visible.
	pi.on(
		"input",
		safe((event: any) => {
			if (event.source === "extension") return;
			if (!event.streamingBehavior) return; // idle input reaches before_agent_start
			update({ lastPrompt: truncate(String(event.text ?? ""), 200) });
		}),
	);

	pi.on(
		"agent_start",
		safe(() => {
			update({ state: "working" });
		}),
	);

	pi.on(
		"agent_end",
		safe((_event, ctx) => {
			update({
				state: "idle",
				currentActivity: null,
				sessionName: ctx.sessionManager.getSessionName?.() ?? doc?.sessionName ?? null,
				sessionFile: ctx.sessionManager.getSessionFile() ?? doc?.sessionFile ?? null,
			});
		}),
	);

	pi.on(
		"tool_execution_start",
		safe((event: any) => {
			if (!doc) return;
			doc.currentActivity = `${event.toolName}: ${briefArgs(event.toolName, event.args)}`;
			const now = Date.now();
			if (now - lastActivityWrite >= ACTIVITY_THROTTLE_MS) {
				lastActivityWrite = now;
				update({}); // flush currentActivity + updatedAt
			}
		}),
	);

	// Keeps last-activity age live during long runs; also picks up any
	// throttled currentActivity and late session-file creation.
	pi.on(
		"turn_end",
		safe((_event, ctx) => {
			update({ sessionFile: ctx.sessionManager.getSessionFile() ?? doc?.sessionFile ?? null });
		}),
	);

	pi.on(
		"model_select",
		safe((event: any) => {
			update({ model: `${event.model.provider}/${event.model.id}` });
		}),
	);

	pi.on(
		"session_shutdown",
		safe(() => {
			update({ state: "exited", currentActivity: null });
		}),
	);
}
