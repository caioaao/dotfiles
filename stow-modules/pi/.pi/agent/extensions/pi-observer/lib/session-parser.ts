/**
 * Parser for pi's session JSONL files (documented, versioned format - see
 * pi's docs/session-format.md). The only module that touches pi's format;
 * everything downstream works with ActivityItems.
 *
 * Reads incrementally from a byte offset. Only newline-terminated lines are
 * consumed; the returned `upTo` never points past an incomplete tail, which
 * is what makes the distiller watermark safe against partial writes.
 */

import { readFileSync } from "node:fs";
import { briefArgs, collapse, truncate } from "./data.ts";

export interface ToolUse {
	name: string;
	brief: string;
	isError?: boolean;
	resultBrief?: string;
}

export interface TurnItem {
	type: "turn";
	t: string;
	thinking: string;
	text: string;
	tools: ToolUse[];
	stopReason?: string;
	upTo: number;
}

export interface PromptItem {
	type: "prompt";
	t: string;
	text: string;
	upTo: number;
}

export interface MarkerItem {
	type: "marker";
	t: string;
	kind: "done" | "error" | "compaction" | "branch";
	text: string;
	upTo: number;
}

export type ActivityItem = TurnItem | PromptItem | MarkerItem;

export interface ParseResult {
	items: ActivityItem[];
	/** Byte offset after the last complete line consumed. */
	upTo: number;
}

const THINKING_BUDGET = 1400;
const TEXT_BUDGET = 1400;
const RESULT_BUDGET = 160;

export function parseSince(sessionFile: string, offset: number): ParseResult {
	let buf: Buffer;
	try {
		buf = readFileSync(sessionFile);
	} catch {
		return { items: [], upTo: offset };
	}
	if (offset >= buf.length) return { items: [], upTo: offset };

	const items: ActivityItem[] = [];
	// toolCallId -> its ToolUse + owning turn, so results can attach and
	// extend the turn's byte coverage (keeps a turn and its results in the
	// same distillation chunk).
	const openTools = new Map<string, { tool: ToolUse; turn: TurnItem }>();

	let pos = offset;
	while (true) {
		const nl = buf.indexOf(0x0a, pos);
		if (nl === -1) break;
		const lineEnd = nl + 1;
		const line = buf.subarray(pos, nl).toString("utf8").trim();
		pos = lineEnd;
		if (!line) continue;

		let entry: any;
		try {
			entry = JSON.parse(line);
		} catch {
			continue;
		}

		const t = typeof entry.timestamp === "string" ? entry.timestamp : new Date().toISOString();

		switch (entry.type) {
			case "message":
				handleMessage(entry.message, t, lineEnd, items, openTools);
				break;
			case "compaction":
				items.push({ type: "marker", t, kind: "compaction", text: "Compacted context", upTo: lineEnd });
				break;
			case "branch_summary":
				items.push({
					type: "marker",
					t,
					kind: "branch",
					text: `Switched branch. Abandoned path: ${truncate(collapse(String(entry.summary ?? "")), 300)}`,
					upTo: lineEnd,
				});
				break;
			default:
				// session header, labels, model changes, custom entries: not feed material
				break;
		}
	}

	return { items, upTo: pos };
}

function handleMessage(
	msg: any,
	t: string,
	lineEnd: number,
	items: ActivityItem[],
	openTools: Map<string, { tool: ToolUse; turn: TurnItem }>,
): void {
	if (!msg || typeof msg !== "object") return;

	switch (msg.role) {
		case "user": {
			const text = collapse(extractText(msg.content));
			if (text) items.push({ type: "prompt", t, text: truncate(text, 300), upTo: lineEnd });
			break;
		}
		case "bashExecution": {
			items.push({
				type: "prompt",
				t,
				text: truncate(`(user ran) $ ${collapse(String(msg.command ?? ""))}`, 200),
				upTo: lineEnd,
			});
			break;
		}
		case "assistant": {
			const blocks = Array.isArray(msg.content) ? msg.content : [];
			const thinking = collapse(
				blocks
					.filter((b: any) => b?.type === "thinking")
					.map((b: any) => b.thinking)
					.join(" "),
			);
			const text = collapse(
				blocks
					.filter((b: any) => b?.type === "text")
					.map((b: any) => b.text)
					.join(" "),
			);
			const turn: TurnItem = {
				type: "turn",
				t,
				thinking: truncate(thinking, THINKING_BUDGET),
				text: truncate(text, TEXT_BUDGET),
				tools: [],
				stopReason: msg.stopReason,
				upTo: lineEnd,
			};
			for (const b of blocks) {
				if (b?.type !== "toolCall") continue;
				const tool: ToolUse = { name: b.name, brief: briefArgs(b.name, b.arguments) };
				turn.tools.push(tool);
				if (b.id) openTools.set(b.id, { tool, turn });
			}
			if (turn.thinking || turn.text || turn.tools.length > 0) items.push(turn);

			if (msg.stopReason === "error" || msg.stopReason === "aborted") {
				items.push({
					type: "marker",
					t,
					kind: "error",
					text:
						msg.stopReason === "aborted"
							? "Run aborted"
							: `Run failed: ${truncate(collapse(String(msg.errorMessage ?? "unknown error")), 200)}`,
					upTo: lineEnd,
				});
			} else if (msg.stopReason === "stop" && text) {
				// End of an agent run: the final answer, mechanically extracted.
				items.push({ type: "marker", t, kind: "done", text: truncate(text, 500), upTo: lineEnd });
			}
			break;
		}
		case "toolResult": {
			const open = msg.toolCallId ? openTools.get(msg.toolCallId) : undefined;
			if (open) {
				open.tool.isError = Boolean(msg.isError);
				const brief = collapse(extractText(msg.content));
				if (brief) open.tool.resultBrief = truncate(brief, RESULT_BUDGET);
				open.turn.upTo = Math.max(open.turn.upTo, lineEnd);
				if (msg.toolCallId) openTools.delete(msg.toolCallId);
			}
			break;
		}
		default:
			break;
	}
}

function extractText(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content
		.filter((b: any) => b?.type === "text" && typeof b.text === "string")
		.map((b: any) => b.text)
		.join(" ");
}

/** Compact plain-text rendering of activity items (distiller prompt + raw view). */
export function renderItems(items: ActivityItem[]): string {
	const lines: string[] = [];
	for (const item of items) {
		const hm = item.t.slice(11, 16);
		if (item.type === "prompt") {
			lines.push(`[${hm}] USER: ${item.text}`);
		} else if (item.type === "marker") {
			lines.push(`[${hm}] ${item.kind.toUpperCase()}: ${item.text}`);
		} else {
			lines.push(`[${hm}] TURN:`);
			if (item.thinking) lines.push(`  reasoning: ${item.thinking}`);
			if (item.text) lines.push(`  said: ${item.text}`);
			for (const tool of item.tools) {
				const res = tool.isError
					? ` -> ERROR: ${tool.resultBrief ?? ""}`
					: tool.resultBrief
						? ` -> ${tool.resultBrief}`
						: "";
				lines.push(`  tool: ${tool.name}(${tool.brief})${res}`);
			}
		}
	}
	return lines.join("\n");
}
