/**
 * Distiller: turns raw session activity into semantic feed lines.
 *
 * Mechanical items (prompts, done, errors, compaction, branch switches)
 * bypass the LLM. Turns are batched in chunks and distilled by a small
 * model that receives its own rolling state summary + the feed tail + the
 * new delta, and returns 0..n lines plus the updated state. Emitting
 * nothing is the common, correct output - feed quality equals suppression
 * quality.
 *
 * Idempotency: every feed line carries `upTo` (session-file byte offset).
 * The watermark derives from the feed itself; state.json is a cache.
 */

import { readFileSync } from "node:fs";
import { complete, getModel } from "@earendil-works/pi-ai";
import {
	appendFeed,
	CONFIG_FILE,
	readFeed,
	truncate,
	watermark,
	writeState,
	type FeedEntry,
	type FeedKind,
	type RegistryDoc,
} from "./data.ts";
import { parseSince, renderItems, type ActivityItem, type TurnItem } from "./session-parser.ts";

const CHUNK_TURNS = 15;
const FEED_TAIL_LINES = 10;
const LLM_KINDS: FeedKind[] = ["phase", "insight", "note", "backtrack"];

export interface DistillerConfig {
	provider: string;
	modelId: string;
	maxTokens: number;
}

export function loadConfig(): DistillerConfig {
	const defaults: DistillerConfig = {
		provider: "anthropic",
		modelId: "claude-haiku-4-5",
		maxTokens: 1024,
	};
	try {
		return { ...defaults, ...JSON.parse(readFileSync(CONFIG_FILE, "utf8")) };
	} catch {
		return defaults;
	}
}

const SYSTEM_PROMPT = `You distill a coding agent's raw activity into a terse, high-signal feed for a human glancing at a monitor. The human wants the big picture: what phase the agent is in, key decisions, surprises, reversals - never mechanics.

You receive:
- STATE: your own rolling summary from previous calls (empty on first call)
- FEED TAIL: recent feed lines already shown to the human
- NEW ACTIVITY: new agent turns (reasoning excerpts, tool calls with results)

Respond with strict JSON only, no markdown fences, no prose:
{"lines":[{"kind":"phase|insight|backtrack|note","text":"...","detail":"..."}],"state":"..."}

Rules for "lines":
- Emit a line ONLY when the big picture changed. An empty array is the common, correct output.
- kind "phase": agent entered a new phase (researching X, designing Y, implementing Z, debugging W, verifying).
- kind "insight": standalone reasoning nugget - a realization, key decision, discovered constraint.
- kind "backtrack": agent reversed course, abandoned an approach, or discovered its assumption was wrong.
- kind "note": anything else worth one glance.
- "text": one short specific sentence. "Exploring binary search over commit range" - never generic filler like "working on the task".
- "detail" (optional): 1-3 sentences of genuinely interesting reasoning - why this approach, the rejected alternative, the surprise. Omit by default. "text" must stand alone without it. Never fabricate reasoning that is not in the activity.
- Never restate what FEED TAIL already says. Never narrate tool mechanics ("ran grep", "read file").

Rules for "state": updated rolling summary, max 400 chars: current goal, chosen approach, position in the plan. Always provide it.`;

export interface DistillOptions {
	onEntry?: (entry: FeedEntry) => void;
	config?: DistillerConfig;
	signal?: AbortSignal;
}

/** Distill everything pending for a session. Returns number of new feed entries. */
export async function distillSession(doc: RegistryDoc, opts: DistillOptions = {}): Promise<number> {
	if (!doc.sessionFile) return 0;
	const config = opts.config ?? loadConfig();
	const wm = watermark(doc.sessionId);
	const { items, upTo } = parseSince(doc.sessionFile, wm.upTo);
	if (items.length === 0) {
		if (upTo > wm.upTo) writeState(doc.sessionId, { upTo, state: wm.state });
		return 0;
	}

	let rollingState = wm.state;
	let feedTail = readFeed(doc.sessionId).slice(-FEED_TAIL_LINES);
	let count = 0;

	const emit = (entries: FeedEntry[]) => {
		appendFeed(doc.sessionId, entries);
		for (const e of entries) opts.onEntry?.(e);
		feedTail = [...feedTail, ...entries].slice(-FEED_TAIL_LINES);
		count += entries.length;
	};

	// Process in order; batch consecutive turns, flush the batch through the
	// LLM before any mechanical entry so feed order matches reality.
	let turnBuffer: TurnItem[] = [];
	const flushTurns = async () => {
		while (turnBuffer.length > 0) {
			const chunk = turnBuffer.slice(0, CHUNK_TURNS);
			turnBuffer = turnBuffer.slice(CHUNK_TURNS);
			const result = await distillChunk(chunk, rollingState, feedTail, config, opts.signal);
			rollingState = result.state;
			const chunkUpTo = chunk[chunk.length - 1].upTo;
			emit(result.entries.map((e) => ({ ...e, upTo: chunkUpTo })));
			writeState(doc.sessionId, { upTo: chunkUpTo, state: rollingState });
		}
	};

	for (const item of items) {
		if (item.type === "turn") {
			turnBuffer.push(item);
			continue;
		}
		await flushTurns();
		emit([mechanicalEntry(item)]);
		writeState(doc.sessionId, { upTo: item.upTo, state: rollingState });
	}
	await flushTurns();
	writeState(doc.sessionId, { upTo, state: rollingState });
	return count;
}

function mechanicalEntry(item: ActivityItem): FeedEntry {
	if (item.type === "prompt") {
		return { t: item.t, kind: "prompt", text: item.text, upTo: item.upTo };
	}
	const marker = item as Extract<ActivityItem, { type: "marker" }>;
	const kind: FeedKind =
		marker.kind === "done"
			? "done"
			: marker.kind === "error"
				? "error"
				: marker.kind === "branch"
					? "backtrack"
					: "note";
	return { t: marker.t, kind, text: marker.text, upTo: marker.upTo };
}

async function distillChunk(
	turns: TurnItem[],
	rollingState: string,
	feedTail: FeedEntry[],
	config: DistillerConfig,
	signal?: AbortSignal,
): Promise<{ entries: FeedEntry[]; state: string }> {
	const tail = feedTail.map((e) => `[${e.t.slice(11, 16)}] ${e.kind}: ${e.text}`).join("\n");
	const prompt = [
		`STATE: ${rollingState || "(none - first call)"}`,
		``,
		`FEED TAIL:`,
		tail || "(empty)",
		``,
		`NEW ACTIVITY:`,
		renderItems(turns),
	].join("\n");

	const model = getModel(config.provider as any, config.modelId as any);
	const msg = await complete(
		model,
		{
			systemPrompt: SYSTEM_PROMPT,
			messages: [{ role: "user", content: prompt, timestamp: Date.now() }],
		},
		{ maxTokens: config.maxTokens, signal },
	);
	if (msg.stopReason === "error" || msg.stopReason === "aborted") {
		throw new Error(msg.errorMessage ?? "distiller LLM call failed");
	}
	const text = msg.content
		.filter((c): c is Extract<typeof c, { type: "text" }> => c.type === "text")
		.map((c) => c.text)
		.join("");
	return parseResponse(text, rollingState, turns[turns.length - 1].t);
}

function parseResponse(
	raw: string,
	previousState: string,
	t: string,
): { entries: FeedEntry[]; state: string } {
	let parsed: any;
	try {
		parsed = JSON.parse(stripFences(raw));
	} catch {
		// Unparseable output: keep state, emit nothing. Source is preserved;
		// a redistill can always retry.
		return { entries: [], state: previousState };
	}
	const entries: FeedEntry[] = [];
	if (Array.isArray(parsed?.lines)) {
		for (const line of parsed.lines) {
			const text = typeof line?.text === "string" ? line.text.trim() : "";
			if (!text) continue;
			const kind: FeedKind = LLM_KINDS.includes(line.kind) ? line.kind : "note";
			const entry: FeedEntry = { t, kind, text: truncate(text, 300), upTo: 0 };
			if (typeof line.detail === "string" && line.detail.trim()) {
				entry.detail = truncate(line.detail.trim(), 600);
			}
			entries.push(entry);
		}
	}
	const state = typeof parsed?.state === "string" ? truncate(parsed.state, 500) : previousState;
	return { entries, state };
}

function stripFences(s: string): string {
	const trimmed = s.trim();
	const m = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/);
	return m ? m[1] : trimmed;
}
