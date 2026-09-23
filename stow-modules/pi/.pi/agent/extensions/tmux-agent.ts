/**
 * Tmux Agent Protocol Extension
 *
 * Publishes this pane's agent identity to tmux as pane-scoped user options, so
 * tmux-side tools (e.g. the `tmux-agent-panes` picker) can find and label agent panes
 * without knowing which agent runs:
 *
 *   @agent_name     "pi"
 *   @agent_status   "idle" | "working"
 *   @agent_session  session name, else session id
 *
 * The protocol is defined in docs/tmux-agent-protocol.md. This extension only
 * owns the data and installs no global tmux options. All three options are
 * cleared when the session shuts down. No-op outside tmux.
 */

import { execFile } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const AGENT_NAME = "pi";
const OPTIONS = ["@agent_name", "@agent_status", "@agent_session"] as const;

const pane = process.env.TMUX_PANE;
const inTmux = !!process.env.TMUX && !!pane;

function tmuxFire(...args: string[]) {
	if (!inTmux) return;
	execFile("tmux", args, () => {
		/* best-effort */
	});
}

// Every option write must be visible immediately: refresh-client redraws any
// tmux consumer that renders the option (status bars, pickers).
function publish(option: string, value: string) {
	tmuxFire("set-option", "-p", "-t", pane!, option, value);
	tmuxFire("refresh-client", "-S");
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		if (!inTmux) return;
		// Prefer the user-assigned session name, fall back to the session id.
		const session = ctx.sessionManager.getSessionName() ?? ctx.sessionManager.getSessionId();
		publish("@agent_name", AGENT_NAME);
		publish("@agent_session", session);
		publish("@agent_status", "idle");
	});

	pi.on("session_info_changed", (_event, ctx) => {
		const session = ctx.sessionManager.getSessionName() ?? ctx.sessionManager.getSessionId();
		publish("@agent_session", session);
	});

	pi.on("agent_start", () => {
		publish("@agent_status", "working");
	});

	pi.on("agent_end", () => {
		publish("@agent_status", "idle");
	});

	pi.on("session_shutdown", () => {
		if (!inTmux) return;
		for (const option of OPTIONS) {
			tmuxFire("set-option", "-p", "-t", pane!, "-u", option);
		}
		tmuxFire("refresh-client", "-S");
	});
}
