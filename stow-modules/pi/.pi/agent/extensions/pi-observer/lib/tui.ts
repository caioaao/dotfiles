/**
 * piobs TUI: session list (left) + distilled feed (right).
 *
 * Deliberately dependency-free: raw-mode stdin, alternate screen, 1s poll
 * loop. Only the selected session distills in real time; selecting a
 * session that fell behind triggers catch-up.
 */

import { execFileSync } from "node:child_process";
import { statSync } from "node:fs";
import {
	clearFeed,
	gc,
	listSessions,
	readFeed,
	watermark,
	type FeedEntry,
	type SessionInfo,
} from "./data.ts";
import { distillSession } from "./distiller.ts";
import { parseSince, renderItems } from "./session-parser.ts";

const TICK_MS = 1000;
const DEBOUNCE_MS = 2500;
const SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

// ANSI helpers
const ESC = "\x1b[";
const reset = `${ESC}0m`;
const dim = (s: string) => `${ESC}2m${s}${reset}`;
const bold = (s: string) => `${ESC}1m${s}${reset}`;
const inverse = (s: string) => `${ESC}7m${s}${reset}`;
const fg = (n: number, s: string) => `${ESC}38;5;${n}m${s}${reset}`;

const KIND_STYLE: Record<string, { badge: string; color: number }> = {
	phase: { badge: "▶", color: 51 }, // cyan
	insight: { badge: "✦", color: 213 }, // magenta
	note: { badge: "·", color: 245 }, // grey
	backtrack: { badge: "↩", color: 220 }, // yellow
	done: { badge: "✔", color: 82 }, // green
	error: { badge: "✖", color: 196 }, // red
	prompt: { badge: "❯", color: 255 }, // white
};

interface UiState {
	sessions: SessionInfo[];
	selectedId: string | null;
	follow: boolean;
	showDetails: boolean;
	rawView: boolean;
	status: string;
	statusUntil: number;
	distilling: boolean;
	tick: number;
	// per-session growth tracking for debounce
	sizes: Map<string, { size: number; changedAt: number }>;
}

export async function runTui(): Promise<void> {
	gc();
	const out = process.stdout;
	const state: UiState = {
		sessions: [],
		selectedId: null,
		follow: true,
		showDetails: true,
		rawView: false,
		status: "",
		statusUntil: 0,
		distilling: false,
		tick: 0,
		sizes: new Map(),
	};

	const setStatus = (msg: string, ms = 4000) => {
		state.status = msg;
		state.statusUntil = Date.now() + ms;
	};

	const selected = (): SessionInfo | undefined =>
		state.sessions.find((s) => s.sessionId === state.selectedId);

	// --- distillation loop -------------------------------------------------

	const maybeDistill = async (force = false) => {
		const doc = selected();
		if (!doc || !doc.sessionFile || state.distilling) return;
		let size: number;
		try {
			size = statSync(doc.sessionFile).size;
		} catch {
			return;
		}
		const tracked = state.sizes.get(doc.sessionId);
		if (!tracked || tracked.size !== size) {
			state.sizes.set(doc.sessionId, { size, changedAt: Date.now() });
		}
		const wm = watermark(doc.sessionId);
		if (size <= wm.upTo) return;
		const changedAt = state.sizes.get(doc.sessionId)?.changedAt ?? 0;
		const settled = doc.effectiveState !== "working" || Date.now() - changedAt > DEBOUNCE_MS;
		if (!force && !settled) return;

		state.distilling = true;
		try {
			await distillSession(doc);
		} catch (err) {
			setStatus(`distill failed: ${err instanceof Error ? err.message : String(err)}`, 8000);
		} finally {
			state.distilling = false;
		}
	};

	const redistill = async () => {
		const doc = selected();
		if (!doc) return;
		clearFeed(doc.sessionId);
		setStatus("redistilling from scratch...");
		await maybeDistill(true);
		setStatus("redistill complete");
	};

	// --- tmux hop ----------------------------------------------------------

	const hop = () => {
		const doc = selected();
		if (!doc) return;
		if (!doc.tmux?.pane) {
			setStatus(`no tmux pane; session file: ${doc.sessionFile ?? "none"}`, 8000);
			return;
		}
		try {
			const pane = doc.tmux.pane;
			const session = execFileSync(
				"tmux",
				["display-message", "-p", "-t", pane, "#{session_name}"],
				{ encoding: "utf8" },
			).trim();
			execFileSync("tmux", ["switch-client", "-t", session]);
			execFileSync("tmux", ["select-window", "-t", pane]);
			execFileSync("tmux", ["select-pane", "-t", pane]);
		} catch (err) {
			setStatus(`tmux hop failed: ${err instanceof Error ? err.message : String(err)}`, 8000);
		}
	};

	// --- rendering ---------------------------------------------------------

	const render = () => {
		const w = out.columns || 80;
		const h = out.rows || 24;
		const leftW = Math.min(46, Math.max(30, Math.floor(w * 0.36)));
		const rightW = w - leftW - 1;
		const bodyH = h - 1;

		const left = renderSessionList(state, leftW, bodyH);
		const right = renderFeedPane(state, selected(), rightW, bodyH);

		const lines: string[] = [];
		for (let i = 0; i < bodyH; i++) {
			lines.push(`${padAnsi(left[i] ?? "", leftW)}${dim("│")}${right[i] ?? ""}`);
		}
		lines.push(renderStatusBar(state, w));

		out.write(`${ESC}H${ESC}2J` + lines.join("\n"));
	};

	// --- input -------------------------------------------------------------

	const onKey = (data: Buffer) => {
		const key = data.toString("utf8");
		const move = (delta: number) => {
			if (state.sessions.length === 0) return;
			const idx = state.sessions.findIndex((s) => s.sessionId === state.selectedId);
			const next = Math.min(Math.max(idx + delta, 0), state.sessions.length - 1);
			state.selectedId = state.sessions[next].sessionId;
		};
		switch (key) {
			case "q":
			case "\x03": // Ctrl+C
				cleanup();
				process.exit(0);
				break;
			case "j":
			case `${ESC}B`:
				move(1);
				break;
			case "k":
			case `${ESC}A`:
				move(-1);
				break;
			case "\r":
				hop();
				break;
			case "f":
				state.follow = !state.follow;
				setStatus(`follow ${state.follow ? "on" : "off"}`);
				break;
			case "i":
				state.showDetails = !state.showDetails;
				break;
			case "d":
				state.rawView = !state.rawView;
				break;
			case "g":
				void maybeDistill(true);
				break;
			case "r":
				void redistill();
				break;
			default:
				break;
		}
		render();
	};

	const cleanup = () => {
		out.write(`${ESC}?25h${ESC}?1049l`); // show cursor, leave alt screen
		if (process.stdin.isTTY) process.stdin.setRawMode(false);
		process.stdin.pause();
	};

	// --- main loop ---------------------------------------------------------

	out.write(`${ESC}?1049h${ESC}?25l`); // alt screen, hide cursor
	if (process.stdin.isTTY) process.stdin.setRawMode(true);
	process.stdin.resume();
	process.stdin.on("data", onKey);
	process.on("SIGINT", () => {
		cleanup();
		process.exit(0);
	});
	out.on("resize", render);

	const tick = async () => {
		state.tick++;
		state.sessions = listSessions();
		if (!state.selectedId && state.sessions.length > 0) {
			state.selectedId = state.sessions[0].sessionId;
		}
		void maybeDistill();
		render();
	};

	await tick();
	setInterval(() => void tick(), TICK_MS);
	// keep process alive; setInterval does that
}

// ---------------------------------------------------------------------------

function renderSessionList(state: UiState, width: number, height: number): string[] {
	const lines: string[] = [];
	lines.push(bold(" pi-observer"));
	lines.push("");
	if (state.sessions.length === 0) {
		lines.push(dim(" no sessions yet"));
	}
	for (const s of state.sessions) {
		if (lines.length >= height) break;
		const isSel = s.sessionId === state.selectedId;
		const marker =
			s.effectiveState === "working"
				? fg(82, SPINNER[state.tick % SPINNER.length])
				: s.effectiveState === "idle"
					? fg(75, "●")
					: dim("○");
		const title = s.sessionName ?? s.lastPrompt ?? "(no prompt yet)";
		const row1 = ` ${marker} ${clip(title, width - 5)}`;
		const cwdShort = s.cwd.replace(/^\/Users\/[^/]+/, "~");
		const modelShort = s.model?.split("/")[1] ?? "?";
		const row2 = `   ${clip(`${cwdShort} · ${modelShort} · ${age(s.updatedAt)}`, width - 4)}`;
		lines.push(isSel ? inverse(padAnsi(row1, width)) : row1);
		lines.push(isSel ? inverse(padAnsi(dim(row2), width)) : dim(row2));
		if (s.effectiveState === "working" && s.currentActivity) {
			lines.push(fg(245, `   ${clip(s.currentActivity, width - 4)}`));
		}
		lines.push("");
	}
	return lines.slice(0, height);
}

function renderFeedPane(
	state: UiState,
	doc: SessionInfo | undefined,
	width: number,
	height: number,
): string[] {
	if (!doc) return [dim(" select a session")];

	const header = ` ${bold(clip(doc.sessionName ?? doc.lastPrompt ?? doc.sessionId, width - 30))} ${dim(`[${doc.effectiveState}]`)} ${dim(doc.model ?? "")}`;
	const lines: string[] = [header, dim("─".repeat(Math.max(0, width)))];

	const body: string[] = [];
	if (state.rawView) {
		if (doc.sessionFile) {
			const { items } = parseSince(doc.sessionFile, 0);
			for (const line of renderItems(items.slice(-80)).split("\n")) {
				body.push(...wrap(line, width - 2).map((l) => ` ${l}`));
			}
		} else {
			body.push(dim(" ephemeral session (--no-session): no content source"));
		}
	} else {
		const feed = readFeed(doc.sessionId);
		if (feed.length === 0) {
			body.push(dim(" feed empty - waiting for activity (g to force distill)"));
		}
		for (const entry of feed) {
			body.push(...renderFeedEntry(entry, width, state.showDetails));
		}
	}

	const room = height - lines.length;
	const visible = state.follow ? body.slice(-room) : body.slice(0, room);
	return [...lines, ...visible];
}

function renderFeedEntry(entry: FeedEntry, width: number, showDetails: boolean): string[] {
	const style = KIND_STYLE[entry.kind] ?? KIND_STYLE.note;
	const time = dim(entry.t.slice(11, 16));
	const badge = fg(style.color, style.badge);
	const textLines = wrap(entry.text, width - 10);
	const out: string[] = [];
	const first = entry.kind === "prompt" ? bold(textLines[0] ?? "") : textLines[0] ?? "";
	out.push(` ${time} ${badge} ${first}`);
	for (const cont of textLines.slice(1)) out.push(`         ${cont}`);
	if (showDetails && entry.detail) {
		for (const d of wrap(entry.detail, width - 12)) out.push(dim(`           ${d}`));
	}
	return out;
}

function renderStatusBar(state: UiState, width: number): string {
	const spin = state.distilling ? ` ${SPINNER[state.tick % SPINNER.length]} distilling ` : "";
	const msg = Date.now() < state.statusUntil ? ` ${state.status} ` : "";
	const keys = " ↵ hop  f follow  i details  d raw  g distill  r redistill  q quit ";
	const leftPart = `${spin}${msg}`;
	return inverse(padAnsi(clip(`${leftPart}${leftPart ? "· " : ""}${keys}`, width), width));
}

// --- text utils ------------------------------------------------------------

function stripAnsi(s: string): string {
	return s.replace(/\x1b\[[0-9;]*m/g, "");
}

function visibleLength(s: string): number {
	return stripAnsi(s).length;
}

function padAnsi(s: string, width: number): string {
	const len = visibleLength(s);
	return len >= width ? s : s + " ".repeat(width - len);
}

function clip(s: string, max: number): string {
	if (max <= 0) return "";
	return s.length <= max ? s : s.slice(0, Math.max(0, max - 1)) + "…";
}

function wrap(s: string, width: number): string[] {
	if (width <= 4) return [clip(s, Math.max(1, width))];
	const words = s.split(" ");
	const lines: string[] = [];
	let cur = "";
	for (const word of words) {
		if (cur && cur.length + 1 + word.length > width) {
			lines.push(cur);
			cur = word;
		} else {
			cur = cur ? `${cur} ${word}` : word;
		}
	}
	if (cur) lines.push(cur);
	return lines;
}

function age(iso: string): string {
	const s = Math.max(0, Math.floor((Date.now() - Date.parse(iso)) / 1000));
	if (s < 60) return `${s}s`;
	if (s < 3600) return `${Math.floor(s / 60)}m`;
	if (s < 86400) return `${Math.floor(s / 3600)}h`;
	return `${Math.floor(s / 86400)}d`;
}
