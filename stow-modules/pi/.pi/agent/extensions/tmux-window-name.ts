/**
 * Tmux Window Name Extension
 *
 * Self-contained - no tmux config changes required. While pi is running it
 * installs an `automatic-rename-format` that consults a per-pane
 * `@pi_status` user option. Pi publishes `idle` / `busy` on its own pane, so
 * tmux's active-pane-driven `#W` shows `pi` / `pi [idle]` when pi's pane is
 * focused, and falls through to `pane_current_command` (`zsh`, `nvim`, ...)
 * for sibling panes. The previous format is restored on shutdown.
 *
 * Inspired by ranger's gui/ui.py snapshot/restore pattern.
 *
 * Trade-off: if pi is killed without `session_shutdown` firing, the override
 * lingers. The format is transparent (only changes behavior for panes with
 * `@pi_status` set), but to fully reset run:
 *
 *     tmux set-option -gwu automatic-rename-format
 *
 * No-op outside tmux.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const execFileAsync = promisify(execFile);

const SENTINEL = "@pi_status";

// tmux format evaluated against the active pane to produce `#W`. Reads:
//
//   if pane is in copy/scroll mode:        "[tmux]"
//   else if active pane has @pi_status:    "pi" + (" [idle]" if status==idle)
//   else:                                  pane_current_command  (zsh, nvim, ...)
//   then suffix "[dead]" if the pane process has exited
//
// `#{?cond,then,else}` is tmux's ternary; `#{==:a,b}` is string equality;
// `#{@foo}` reads a user option from the format's evaluation context (here,
// the active pane). Pi's extension publishes `@pi_status` on its own pane,
// so focusing a sibling pane naturally falls through to the default branch.
const FORMAT =
	"#{?pane_in_mode,[tmux]," +
	"#{?#{@pi_status},pi#{?#{==:#{@pi_status},idle}, [idle],}," +
	"#{pane_current_command}}}" +
	"#{?pane_dead,[dead],}";

const pane = process.env.TMUX_PANE;
const inTmux = !!process.env.TMUX && !!pane;

let savedFormat: string | null = null;
let savedFormatPresent = false;

async function tmux(...args: string[]): Promise<string> {
	if (!inTmux) return "";
	try {
		const { stdout } = await execFileAsync("tmux", args);
		return stdout;
	} catch {
		return "";
	}
}

function tmuxFire(...args: string[]) {
	if (!inTmux) return;
	execFile("tmux", args, () => {
		/* best-effort */
	});
}

async function installFormat() {
	// Capture the current effective format. If it already contains our
	// sentinel (e.g. a prior pi run crashed), keep whatever we previously
	// saved - don't snapshot ourselves over the user's real value.
	const current = (await tmux("show-options", "-gwv", "automatic-rename-format")).trim();
	if (!current.includes(SENTINEL)) {
		// `-gw` prints `option "value"` when explicit, nothing when default.
		const explicit = (await tmux("show-options", "-gw", "automatic-rename-format")).trim();
		savedFormatPresent = explicit.length > 0;
		savedFormat = current;
	}
	await tmux("set-option", "-gw", "automatic-rename-format", FORMAT);
}

async function restoreFormat() {
	if (savedFormat === null) return;
	if (savedFormatPresent) {
		await tmux("set-option", "-gw", "automatic-rename-format", savedFormat);
	} else {
		await tmux("set-option", "-gwu", "automatic-rename-format");
	}
}

function setStatus(status: "idle" | "busy") {
	tmuxFire("set-option", "-p", "-t", pane!, "@pi_status", status);
	tmuxFire("refresh-client", "-S");
}

function clearStatus() {
	tmuxFire("set-option", "-p", "-t", pane!, "-u", "@pi_status");
	tmuxFire("refresh-client", "-S");
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async () => {
		if (!inTmux) return;
		await installFormat();
		setStatus("idle");
	});

	pi.on("agent_start", async () => {
		setStatus("busy");
	});

	pi.on("agent_end", async () => {
		setStatus("idle");
	});

	pi.on("session_shutdown", async () => {
		if (!inTmux) return;
		clearStatus();
		await restoreFormat();
		tmuxFire("refresh-client", "-S");
	});
}
