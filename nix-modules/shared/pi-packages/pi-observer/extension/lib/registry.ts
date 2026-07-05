/**
 * Write side of the pi-observer data-dir contract (see ../CONTRACT.md).
 *
 * This is everything the registry extension needs: the RegistryDoc type,
 * an atomic writer for sessions/<id>.json, and the small text helpers used
 * to build doc fields. Dependency-free by design - it runs inside pi's
 * process and must never drag anything in.
 */

import { mkdirSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const DATA_DIR = join(homedir(), ".local", "share", "pi-observer");
export const SESSIONS_DIR = join(DATA_DIR, "sessions");

export type SessionState = "working" | "idle" | "exited";

export interface RegistryDoc {
	schemaVersion: number;
	sessionId: string;
	pid: number;
	/** Process start time, epoch ms. Guards against pid reuse. */
	pidStartedAt: number;
	cwd: string;
	sessionFile: string | null;
	sessionName: string | null;
	model: string | null;
	tmux: { pane: string } | null;
	state: SessionState;
	/** Live "doing X now" one-liner while a tool runs; null when idle. */
	currentActivity: string | null;
	startedAt: string;
	updatedAt: string;
	lastPrompt: string | null;
}

export function registryPath(sessionId: string): string {
	return join(SESSIONS_DIR, `${sessionId}.json`);
}

/** Atomic write (tmp + rename), per CONTRACT.md. */
export function writeRegistryDoc(doc: RegistryDoc): void {
	mkdirSync(SESSIONS_DIR, { recursive: true });
	const path = registryPath(doc.sessionId);
	const tmp = `${path}.tmp`;
	writeFileSync(tmp, JSON.stringify(doc));
	renameSync(tmp, path);
}

// ---------------------------------------------------------------------------
// Text helpers for building doc fields

export function truncate(s: string, n: number): string {
	return s.length <= n ? s : s.slice(0, n - 1) + "…";
}

export function collapse(s: string): string {
	return s.replace(/\s+/g, " ").trim();
}

/** One-line summary of a tool call's arguments. */
export function briefArgs(toolName: string, args: Record<string, unknown> | undefined): string {
	if (!args) return "";
	const first = (...keys: string[]): string | undefined => {
		for (const k of keys) {
			const v = args[k];
			if (typeof v === "string" && v) return v;
		}
		return undefined;
	};
	let s: string | undefined;
	switch (toolName) {
		case "bash":
			s = first("command", "cmd");
			break;
		case "read":
		case "write":
		case "edit":
			s = first("path", "file_path", "filePath");
			break;
		case "grep":
		case "ffgrep":
		case "glob":
		case "fffind":
		case "find":
			s = first("pattern", "path");
			break;
		default:
			s = first("path", "pattern", "command", "query", "url", "task", "prompt", "label");
	}
	if (s === undefined) {
		try {
			s = JSON.stringify(args);
		} catch {
			s = "";
		}
	}
	return truncate(collapse(s), 100);
}
