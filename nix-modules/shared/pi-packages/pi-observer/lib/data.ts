/**
 * pi-observer shared data layer.
 *
 * Owns the data-dir contract (the stable interface between the registry
 * extension and the piobs CLI):
 *
 *   ~/.local/share/pi-observer/
 *     sessions/<sessionId>.json    registry doc; atomic rewrite by extension
 *     feed/<sessionId>.jsonl       distilled feed; append-only by CLI
 *     feed/<sessionId>.state.json  distiller watermark + rolling state summary
 *
 * Strict ownership: the extension writes sessions/, the CLI writes feed/.
 * Pi's own session JSONL files are the (read-only) content source.
 */

import { execFileSync } from "node:child_process";
import {
	appendFileSync,
	mkdirSync,
	readdirSync,
	readFileSync,
	renameSync,
	rmSync,
	writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { DATA_DIR, SESSIONS_DIR, registryPath, type RegistryDoc, type SessionState } from "./registry.ts";

export {
	briefArgs,
	collapse,
	DATA_DIR,
	registryPath,
	SESSIONS_DIR,
	truncate,
	writeRegistryDoc,
	type RegistryDoc,
	type SessionState,
} from "./registry.ts";

export const FEED_DIR = join(DATA_DIR, "feed");
export const CONFIG_FILE = join(homedir(), ".config", "pi-observer", "config.json");

export type FeedKind =
	| "phase"
	| "insight"
	| "note"
	| "backtrack"
	| "done"
	| "error"
	| "prompt";

export interface FeedEntry {
	t: string;
	kind: FeedKind;
	text: string;
	detail?: string;
	/** Session-file byte offset this line covers. Makes distillation idempotent. */
	upTo: number;
}

export interface DistillerState {
	upTo: number;
	/** Rolling summary maintained by the distiller across calls. */
	state: string;
}

export function ensureDirs(): void {
	mkdirSync(SESSIONS_DIR, { recursive: true });
	mkdirSync(FEED_DIR, { recursive: true });
}

export function feedPath(sessionId: string): string {
	return join(FEED_DIR, `${sessionId}.jsonl`);
}

export function statePath(sessionId: string): string {
	return join(FEED_DIR, `${sessionId}.state.json`);
}

export function readRegistryDoc(sessionId: string): RegistryDoc | null {
	try {
		return JSON.parse(readFileSync(registryPath(sessionId), "utf8")) as RegistryDoc;
	} catch {
		return null;
	}
}

export interface SessionInfo extends RegistryDoc {
	/** Registry state corrected by the pid identity check. */
	effectiveState: SessionState;
}

export function listSessions(): SessionInfo[] {
	ensureDirs();
	const out: SessionInfo[] = [];
	for (const f of readdirSync(SESSIONS_DIR)) {
		if (!f.endsWith(".json")) continue;
		let doc: RegistryDoc;
		try {
			doc = JSON.parse(readFileSync(join(SESSIONS_DIR, f), "utf8")) as RegistryDoc;
		} catch {
			continue;
		}
		const effectiveState: SessionState =
			doc.state !== "exited" && !isProcessAlive(doc) ? "exited" : doc.state;
		out.push({ ...doc, effectiveState });
	}
	out.sort((a, b) => {
		const rank = (s: SessionInfo) =>
			s.effectiveState === "working" ? 0 : s.effectiveState === "idle" ? 1 : 2;
		if (rank(a) !== rank(b)) return rank(a) - rank(b);
		return b.updatedAt.localeCompare(a.updatedAt);
	});
	return out;
}

/**
 * Liveness with pid-reuse guard: kill -0 alone would make crashed sessions
 * immortal once the pid is recycled. Confirm identity by comparing process
 * start time (derived from `ps -o etime=`) against the recorded one.
 */
export function isProcessAlive(doc: RegistryDoc): boolean {
	try {
		process.kill(doc.pid, 0);
	} catch {
		return false;
	}
	try {
		const out = execFileSync("ps", ["-o", "etime=", "-p", String(doc.pid)], {
			encoding: "utf8",
			stdio: ["ignore", "pipe", "ignore"],
		});
		const elapsed = etimeToMs(out);
		if (elapsed === null) return true; // cannot verify; assume alive
		const started = Date.now() - elapsed;
		return Math.abs(started - doc.pidStartedAt) < 30_000;
	} catch {
		return false;
	}
}

/** Parse ps etime format: [[dd-]hh:]mm:ss */
function etimeToMs(etime: string): number | null {
	const m = etime.trim().match(/^(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+)$/);
	if (!m) return null;
	const [, d, h, min, s] = m;
	return (((Number(d ?? 0) * 24 + Number(h ?? 0)) * 60 + Number(min)) * 60 + Number(s)) * 1000;
}

/** Read feed, tolerating a partially-written (non-newline-terminated) tail. */
export function readFeed(sessionId: string): FeedEntry[] {
	let raw: string;
	try {
		raw = readFileSync(feedPath(sessionId), "utf8");
	} catch {
		return [];
	}
	const entries: FeedEntry[] = [];
	for (const line of raw.split("\n")) {
		if (!line.trim()) continue;
		try {
			entries.push(JSON.parse(line) as FeedEntry);
		} catch {
			// partial tail or corruption; skip
		}
	}
	return entries;
}

export function appendFeed(sessionId: string, entries: FeedEntry[]): void {
	if (entries.length === 0) return;
	ensureDirs();
	appendFileSync(feedPath(sessionId), entries.map((e) => JSON.stringify(e) + "\n").join(""));
}

export function readState(sessionId: string): DistillerState | null {
	try {
		return JSON.parse(readFileSync(statePath(sessionId), "utf8")) as DistillerState;
	} catch {
		return null;
	}
}

export function writeState(sessionId: string, state: DistillerState): void {
	ensureDirs();
	const path = statePath(sessionId);
	const tmp = `${path}.tmp`;
	writeFileSync(tmp, JSON.stringify(state));
	renameSync(tmp, path);
}

/**
 * Distiller watermark. state.json is a cache; the feed itself is the source
 * of truth (last entry's upTo), so a crash between feed-append and
 * state-write cannot duplicate lines.
 */
export function watermark(sessionId: string): { upTo: number; state: string } {
	const cached = readState(sessionId);
	const feed = readFeed(sessionId);
	const fromFeed = feed.length > 0 ? feed[feed.length - 1].upTo : 0;
	if (cached && cached.upTo >= fromFeed) return cached;
	return { upTo: fromFeed, state: cached?.state ?? "" };
}

export function clearFeed(sessionId: string): void {
	rmSync(feedPath(sessionId), { force: true });
	rmSync(statePath(sessionId), { force: true });
}

/** Delete observer files (never pi's session files) for long-dead sessions. */
export function gc(maxAgeDays = 14): number {
	const cutoff = Date.now() - maxAgeDays * 24 * 60 * 60 * 1000;
	let removed = 0;
	for (const s of listSessions()) {
		if (s.effectiveState !== "exited") continue;
		if (Date.parse(s.updatedAt) > cutoff) continue;
		rmSync(registryPath(s.sessionId), { force: true });
		clearFeed(s.sessionId);
		removed++;
	}
	return removed;
}

// Text helpers now live in ./registry.ts (re-exported above).
