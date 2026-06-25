/**
 * Subagent Tool - Delegate tasks to generic subagents
 *
 * Spawns a separate `pi` process for each invocation, giving it an isolated
 * context window. The subagent runs as a generic coding agent (pi's default
 * system prompt, full toolset). Its behavior is governed entirely by the task
 * prompt the caller writes - there is no agent selection.
 *
 * Supports three modes:
 *   - Single:   { task: "..." }
 *   - Parallel: { tasks: [{ task: "..." }, ...] }
 *   - Chain:    { chain: [{ task: "... {previous} ..." }, ...] }
 *
 * Uses JSON mode to capture structured output from subagents.
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import type { AgentToolResult } from "@mariozechner/pi-agent-core";
import type { Message } from "@mariozechner/pi-ai";
import { type ExtensionAPI, getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const MAX_PARALLEL_TASKS = 8;
const MAX_CONCURRENCY = 4;
const COLLAPSED_ITEM_COUNT = 10;

// Skills bundled with this extension live under <extension dir>/skills and are
// contributed via the `resources_discover` event (see default export). Keeping the
// delegation skill here ships it with the tool instead of as a standalone skill.
const EXTENSION_DIR = path.dirname(fileURLToPath(import.meta.url));

// Recursion / escape safety. Subagents may use ANY tool EXCEPT this denylist, so
// research tasks keep broad capability: bash + CLIs for web search and doc fetching,
// extension/custom tools, and skills. The denylist is the one hard invariant:
//   - subagent:      direct recursion (the original fork-bomb).
//   - council:       fans out more paid LLM expert calls.
//   - questionnaire: needs an interactive UI; would hang a headless (-p) child.
//   - spawn_session: spawns new sessions.
// DENYLIST is a deliberate choice - broad capability is a core use case. The cost
// (vs an allowlist) is that a FUTURE process-spawning / recursive extension tool is
// allowed by default; add it here when one is introduced. bash stays allowed, so
// recursion *prevention* is best-effort - the hard guarantee is *cleanup*
// (process-group kill reaps the whole descendant tree on abort).
const BLOCKED_SUBAGENT_TOOLS = ["subagent", "council", "questionnaire", "spawn_session"];

/**
 * Validate an optional per-task tool list. Returns the explicit allowlist to pass to
 * `--tools` (narrowing that task), or `undefined` to use the permissive default
 * (everything except BLOCKED_SUBAGENT_TOOLS, via `--exclude-tools`). Fails loud on a
 * blocked or malformed entry rather than silently degrading the child.
 */
function resolveTools(requested: string[] | undefined): string[] | undefined {
	if (requested === undefined) return undefined;
	if (!Array.isArray(requested) || requested.length === 0) {
		throw new Error("tools: [] is ambiguous - omit `tools` for the permissive default, or list explicit tool names.");
	}
	const blocked = new Set(BLOCKED_SUBAGENT_TOOLS);
	for (const t of requested) {
		if (typeof t !== "string" || t !== t.toLowerCase()) {
			throw new Error(`Invalid tool name ${JSON.stringify(t)}: tool names are lowercase identifiers.`);
		}
		if (blocked.has(t)) {
			throw new Error(`Tool '${t}' is not allowed in subagents (recursion/escape prevention).`);
		}
	}
	return [...requested];
}

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

function formatUsageStats(
	usage: {
		input: number;
		output: number;
		cacheRead: number;
		cacheWrite: number;
		cost: number;
		contextTokens?: number;
		turns?: number;
	},
	model?: string,
): string {
	const parts: string[] = [];
	if (usage.turns) parts.push(`${usage.turns} turn${usage.turns > 1 ? "s" : ""}`);
	if (usage.input) parts.push(`↑${formatTokens(usage.input)}`);
	if (usage.output) parts.push(`↓${formatTokens(usage.output)}`);
	if (usage.cacheRead) parts.push(`R${formatTokens(usage.cacheRead)}`);
	if (usage.cacheWrite) parts.push(`W${formatTokens(usage.cacheWrite)}`);
	if (usage.cost) parts.push(`$${usage.cost.toFixed(4)}`);
	if (usage.contextTokens && usage.contextTokens > 0) {
		parts.push(`ctx:${formatTokens(usage.contextTokens)}`);
	}
	if (model) parts.push(model);
	return parts.join(" ");
}

function formatToolCall(
	toolName: string,
	args: Record<string, unknown>,
	themeFg: (color: any, text: string) => string,
): string {
	const shortenPath = (p: string) => {
		const home = os.homedir();
		return p.startsWith(home) ? `~${p.slice(home.length)}` : p;
	};

	switch (toolName) {
		case "bash": {
			const command = (args.command as string) || "...";
			const preview = command.length > 60 ? `${command.slice(0, 60)}...` : command;
			return themeFg("muted", "$ ") + themeFg("toolOutput", preview);
		}
		case "read": {
			const rawPath = (args.file_path || args.path || "...") as string;
			const filePath = shortenPath(rawPath);
			const offset = args.offset as number | undefined;
			const limit = args.limit as number | undefined;
			let text = themeFg("accent", filePath);
			if (offset !== undefined || limit !== undefined) {
				const startLine = offset ?? 1;
				const endLine = limit !== undefined ? startLine + limit - 1 : "";
				text += themeFg("warning", `:${startLine}${endLine ? `-${endLine}` : ""}`);
			}
			return themeFg("muted", "read ") + text;
		}
		case "write": {
			const rawPath = (args.file_path || args.path || "...") as string;
			const filePath = shortenPath(rawPath);
			const content = (args.content || "") as string;
			const lines = content.split("\n").length;
			let text = themeFg("muted", "write ") + themeFg("accent", filePath);
			if (lines > 1) text += themeFg("dim", ` (${lines} lines)`);
			return text;
		}
		case "edit": {
			const rawPath = (args.file_path || args.path || "...") as string;
			return themeFg("muted", "edit ") + themeFg("accent", shortenPath(rawPath));
		}
		case "ls": {
			const rawPath = (args.path || ".") as string;
			return themeFg("muted", "ls ") + themeFg("accent", shortenPath(rawPath));
		}
		case "find": {
			const pattern = (args.pattern || "*") as string;
			const rawPath = (args.path || ".") as string;
			return themeFg("muted", "find ") + themeFg("accent", pattern) + themeFg("dim", ` in ${shortenPath(rawPath)}`);
		}
		case "grep": {
			const pattern = (args.pattern || "") as string;
			const rawPath = (args.path || ".") as string;
			return (
				themeFg("muted", "grep ") +
				themeFg("accent", `/${pattern}/`) +
				themeFg("dim", ` in ${shortenPath(rawPath)}`)
			);
		}
		default: {
			const argsStr = JSON.stringify(args);
			const preview = argsStr.length > 50 ? `${argsStr.slice(0, 50)}...` : argsStr;
			return themeFg("accent", toolName) + themeFg("dim", ` ${preview}`);
		}
	}
}

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

interface SingleResult {
	task: string;
	label?: string;
	exitCode: number;
	messages: Message[];
	stderr: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
	step?: number;
}

interface SubagentDetails {
	mode: "single" | "parallel" | "chain";
	results: SingleResult[];
}

function previewText(s: string, n: number): string {
	const clean = s.replace(/\s+/g, " ").trim();
	return clean.length > n ? `${clean.slice(0, n)}...` : clean;
}

function displayLabel(r: { label?: string; task: string }): string {
	return r.label?.trim() ? r.label : previewText(r.task, 50) || "(empty task)";
}

function getFinalOutput(messages: Message[]): string {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") return part.text;
			}
		}
	}
	return "";
}

type DisplayItem = { type: "text"; text: string } | { type: "toolCall"; name: string; args: Record<string, any> };

function getDisplayItems(messages: Message[]): DisplayItem[] {
	const items: DisplayItem[] = [];
	for (const msg of messages) {
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") items.push({ type: "text", text: part.text });
				else if (part.type === "toolCall") items.push({ type: "toolCall", name: part.name, args: part.arguments });
			}
		}
	}
	return items;
}

async function mapWithConcurrencyLimit<TIn, TOut>(
	items: TIn[],
	concurrency: number,
	fn: (item: TIn, index: number) => Promise<TOut>,
): Promise<TOut[]> {
	if (items.length === 0) return [];
	const limit = Math.max(1, Math.min(concurrency, items.length));
	const results: TOut[] = new Array(items.length);
	let nextIndex = 0;
	const workers = new Array(limit).fill(null).map(async () => {
		while (true) {
			const current = nextIndex++;
			if (current >= items.length) return;
			results[current] = await fn(items[current], current);
		}
	});
	await Promise.all(workers);
	return results;
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}

	const execName = path.basename(process.execPath).toLowerCase();
	const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
	if (!isGenericRuntime) {
		return { command: process.execPath, args };
	}

	return { command: "pi", args };
}

type OnUpdateCallback = (partial: AgentToolResult<SubagentDetails>) => void;

async function runSingleAgent(
	defaultCwd: string,
	task: string,
	label: string | undefined,
	cwd: string | undefined,
	model: string | undefined,
	tools: string[] | undefined,
	step: number | undefined,
	signal: AbortSignal | undefined,
	onUpdate: OnUpdateCallback | undefined,
	makeDetails: (results: SingleResult[]) => SubagentDetails,
): Promise<SingleResult> {
	// --no-context-files: stop the global AGENTS.md "leverage sub-agents" nudge from
	//   propagating into children (the accidental-recursion trigger).
	// Tool scoping: permissive by default (deny only the recursion/escape set) so
	//   research subagents keep bash + CLIs + extension tools + skills; a per-task
	//   `tools` list narrows to an explicit allowlist instead.
	const args: string[] = ["--mode", "json", "-p", "--no-session", "--no-context-files"];
	if (tools && tools.length > 0) args.push("--tools", tools.join(","));
	else args.push("--exclude-tools", BLOCKED_SUBAGENT_TOOLS.join(","));
	if (model) args.push("--model", model);
	args.push(`Task: ${task}`);

	const currentResult: SingleResult = {
		task,
		label,
		exitCode: 0,
		messages: [],
		stderr: "",
		usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
		model,
		step,
	};

	const emitUpdate = () => {
		if (onUpdate) {
			onUpdate({
				content: [{ type: "text", text: getFinalOutput(currentResult.messages) || "(running...)" }],
				details: makeDetails([currentResult]),
			});
		}
	};

	let wasAborted = false;

	const exitCode = await new Promise<number>((resolve) => {
		const invocation = getPiInvocation(args);
		const proc = spawn(invocation.command, invocation.args, {
			cwd: cwd ?? defaultCwd,
			shell: false,
			stdio: ["ignore", "pipe", "pipe"],
			// Own process group so abort can reap the ENTIRE descendant tree
			// (including bash-spawned grandchildren), not just the direct child.
			detached: true,
		});
		let buffer = "";

		const processLine = (line: string) => {
			if (!line.trim()) return;
			let event: any;
			try {
				event = JSON.parse(line);
			} catch {
				return;
			}

			if (event.type === "message_end" && event.message) {
				const msg = event.message as Message;
				currentResult.messages.push(msg);

				if (msg.role === "assistant") {
					currentResult.usage.turns++;
					const usage = msg.usage;
					if (usage) {
						currentResult.usage.input += usage.input || 0;
						currentResult.usage.output += usage.output || 0;
						currentResult.usage.cacheRead += usage.cacheRead || 0;
						currentResult.usage.cacheWrite += usage.cacheWrite || 0;
						currentResult.usage.cost += usage.cost?.total || 0;
						currentResult.usage.contextTokens = usage.totalTokens || 0;
					}
					if (!currentResult.model && msg.model) currentResult.model = msg.model;
					if (msg.stopReason) currentResult.stopReason = msg.stopReason;
					if (msg.errorMessage) currentResult.errorMessage = msg.errorMessage;
				}
				emitUpdate();
			}

			if (event.type === "tool_result_end" && event.message) {
				currentResult.messages.push(event.message as Message);
				emitUpdate();
			}
		};

		proc.stdout.on("data", (data) => {
			buffer += data.toString();
			const lines = buffer.split("\n");
			buffer = lines.pop() || "";
			for (const line of lines) processLine(line);
		});

		proc.stderr.on("data", (data) => {
			currentResult.stderr += data.toString();
		});

		proc.on("close", (code) => {
			if (buffer.trim()) processLine(buffer);
			resolve(code ?? 0);
		});

		proc.on("error", () => {
			resolve(1);
		});

		if (signal) {
			// Signal the whole process group (negative pid) so bash-spawned
			// grandchildren die too; fall back to the direct child if the group
			// signal fails (e.g. pid already gone).
			const killTree = (sig: NodeJS.Signals) => {
				try {
					if (proc.pid !== undefined) process.kill(-proc.pid, sig);
					else proc.kill(sig);
				} catch {
					try {
						proc.kill(sig);
					} catch {}
				}
			};
			const killProc = () => {
				wasAborted = true;
				killTree("SIGTERM");
				setTimeout(() => {
					if (!proc.killed) killTree("SIGKILL");
				}, 5000);
			};
			if (signal.aborted) killProc();
			else signal.addEventListener("abort", killProc, { once: true });
		}
	});

	currentResult.exitCode = exitCode;
	if (wasAborted) throw new Error("Subagent was aborted");
	return currentResult;
}

const ModelSchema = Type.Optional(
	Type.String({
		description:
			'Model for the agent process (e.g. "provider/model-id"). Overrides the top-level model. Defaults to the caller\'s current model.',
	}),
);

const LabelSchema = Type.Optional(
	Type.String({
		description: "Optional short label shown in parallel/chain output. Defaults to a preview of the task.",
	}),
);

const ToolsSchema = Type.Optional(
	Type.Array(Type.String(), {
		description:
			"Tools the subagent may use - a capability GRANT, not the in-prose 'which tools/sources' guidance. OMIT for the permissive default: every tool EXCEPT subagent/council/questionnaire/spawn_session (so bash, CLIs, web-search skills, edit/write are all available - what most research/doc tasks want). Provide an explicit list only to NARROW a task, e.g. [\"read\",\"grep\",\"find\",\"ls\"] for read-only recon. subagent/council/questionnaire/spawn_session are always rejected (recursion/escape prevention).",
	}),
);

const TaskItem = Type.Object({
	task: Type.String({ description: "Task/prompt that governs the generic subagent" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
	model: ModelSchema,
	label: LabelSchema,
	tools: ToolsSchema,
});

const ChainItem = Type.Object({
	task: Type.String({ description: "Task with optional {previous} placeholder for prior step output" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
	model: ModelSchema,
	label: LabelSchema,
	tools: ToolsSchema,
});

const SubagentParams = Type.Object({
	task: Type.Optional(Type.String({ description: "Task/prompt for single mode" })),
	tasks: Type.Optional(
		Type.Array(TaskItem, {
			description: `Array of {task} for parallel execution. Maximum ${MAX_PARALLEL_TASKS} tasks - if you have more, split into sequential batches of ${MAX_PARALLEL_TASKS}.`,
		}),
	),
	chain: Type.Optional(
		Type.Array(ChainItem, { description: "Array of {task} run sequentially; use {previous} to inject prior output" }),
	),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process (single mode)" })),
	model: Type.Optional(
		Type.String({
			description:
				'Model for spawned agents (e.g. "provider/model-id"). Per-task model overrides this. Defaults to the caller\'s current model.',
		}),
	),
	label: LabelSchema,
	tools: ToolsSchema,
});

export default function (pi: ExtensionAPI) {
	// Ship the delegation-contract skill alongside the tool. pi loads any SKILL.md
	// found under this directory at startup and on /reload.
	pi.on("resources_discover", () => ({
		skillPaths: [path.join(EXTENSION_DIR, "skills")],
	}));

	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: [
			"Delegate a task to a generic subagent that runs in an isolated context, like a regular coding agent.",
			"The task prompt fully governs its behavior - write it with all the context the subagent needs; subagents load no context files (AGENTS.md), so make the task self-contained. There is no agent selection.",
			"By default subagents may use ANY tool except subagent/council/questionnaire/spawn_session - so bash, CLIs, web-search skills, and edit/write are all available for research and doc-gathering. They CANNOT spawn their own subagents (no nesting). Pass `tools` only to NARROW a task (e.g. read-only recon).",
			`Modes: single (task), parallel (tasks array, max ${MAX_PARALLEL_TASKS}), chain (sequential; use {previous} to inject prior step output).`,
			"Examples:",
			'- read-only recon: { task: "Investigate how X works. Do NOT modify files. Report file paths + line numbers." }',
			'- parallel fan-out: { tasks: [{ task: "Summarize module A" }, { task: "Summarize module B" }] }',
			'- chain: { chain: [{ task: "Find the bug in auth" }, { task: "Fix it: {previous}" }] }',
			'For structured output, ask for it in the task (e.g. "return JSON {...}").',
		].join("\n"),
		parameters: SubagentParams,

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const defaultModel = params.model ?? (ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined);

			const makeDetails =
				(mode: "single" | "parallel" | "chain") =>
				(results: SingleResult[]): SubagentDetails => ({ mode, results });

			// Named agents were removed. Fail loudly rather than silently ignore a stale `agent` field.
			const raw = params as Record<string, unknown> & { tasks?: unknown[]; chain?: unknown[] };
			const hasAgentField =
				raw.agent !== undefined ||
				(Array.isArray(raw.tasks) && raw.tasks.some((t) => (t as { agent?: unknown })?.agent !== undefined)) ||
				(Array.isArray(raw.chain) && raw.chain.some((c) => (c as { agent?: unknown })?.agent !== undefined));
			if (hasAgentField) {
				return {
					content: [
						{
							type: "text",
							text: "Named agents were removed. Pass `task` directly - the task prompt governs the generic subagent.",
						},
					],
					details: makeDetails("single")([]),
					isError: true,
				};
			}

			const hasChain = (params.chain?.length ?? 0) > 0;
			const hasTasks = (params.tasks?.length ?? 0) > 0;
			const hasSingle = Boolean(params.task);
			const modeCount = Number(hasChain) + Number(hasTasks) + Number(hasSingle);

			if (modeCount !== 1) {
				return {
					content: [
						{
							type: "text",
							text: "Invalid parameters. Provide exactly one mode: task (single), tasks (parallel), or chain.",
						},
					],
					details: makeDetails("single")([]),
					isError: true,
				};
			}

			// Validate every task's tool allowlist up front so a bad `tools` value fails
			// before any process is spawned (indices line up with the dispatch below).
			let resolvedTools: (string[] | undefined)[];
			try {
				if (params.chain && params.chain.length > 0) resolvedTools = params.chain.map((s) => resolveTools(s.tools));
				else if (params.tasks && params.tasks.length > 0) resolvedTools = params.tasks.map((t) => resolveTools(t.tools));
				else resolvedTools = [resolveTools(params.tools)];
			} catch (err) {
				return {
					content: [{ type: "text", text: err instanceof Error ? err.message : String(err) }],
					details: makeDetails("single")([]),
					isError: true,
				};
			}

			if (params.chain && params.chain.length > 0) {
				const results: SingleResult[] = [];
				let previousOutput = "";

				for (let i = 0; i < params.chain.length; i++) {
					const step = params.chain[i];
					const taskWithContext = step.task.replace(/\{previous\}/g, previousOutput);

					// Create update callback that includes all previous results
					const chainUpdate: OnUpdateCallback | undefined = onUpdate
						? (partial) => {
								// Combine completed results with current streaming result
								const currentResult = partial.details?.results[0];
								if (currentResult) {
									const allResults = [...results, currentResult];
									onUpdate({
										content: partial.content,
										details: makeDetails("chain")(allResults),
									});
								}
							}
						: undefined;

					const result = await runSingleAgent(
						ctx.cwd,
						taskWithContext,
						step.label,
						step.cwd,
						step.model ?? defaultModel,
						resolvedTools[i],
						i + 1,
						signal,
						chainUpdate,
						makeDetails("chain"),
					);
					results.push(result);

					const isError =
						result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
					if (isError) {
						const errorMsg =
							result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
						return {
							content: [
								{ type: "text", text: `Chain stopped at step ${i + 1} (${displayLabel(result)}): ${errorMsg}` },
							],
							details: makeDetails("chain")(results),
							isError: true,
						};
					}
					previousOutput = getFinalOutput(result.messages);
				}
				return {
					content: [{ type: "text", text: getFinalOutput(results[results.length - 1].messages) || "(no output)" }],
					details: makeDetails("chain")(results),
				};
			}

			if (params.tasks && params.tasks.length > 0) {
				if (params.tasks.length > MAX_PARALLEL_TASKS)
					return {
						content: [
							{
								type: "text",
								text: `Too many parallel tasks (${params.tasks.length}). Max is ${MAX_PARALLEL_TASKS}.`,
							},
						],
						details: makeDetails("parallel")([]),
						isError: true,
					};

				// Track all results for streaming updates
				const allResults: SingleResult[] = new Array(params.tasks.length);

				// Initialize placeholder results
				for (let i = 0; i < params.tasks.length; i++) {
					allResults[i] = {
						task: params.tasks[i].task,
						label: params.tasks[i].label,
						exitCode: -1, // -1 = still running
						messages: [],
						stderr: "",
						usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
					};
				}

				const emitParallelUpdate = () => {
					if (onUpdate) {
						const running = allResults.filter((r) => r.exitCode === -1).length;
						const done = allResults.filter((r) => r.exitCode !== -1).length;
						onUpdate({
							content: [
								{ type: "text", text: `Parallel: ${done}/${allResults.length} done, ${running} running...` },
							],
							details: makeDetails("parallel")([...allResults]),
						});
					}
				};

				const results = await mapWithConcurrencyLimit(params.tasks, MAX_CONCURRENCY, async (t, index) => {
					const result = await runSingleAgent(
						ctx.cwd,
						t.task,
						t.label,
						t.cwd,
						t.model ?? defaultModel,
						resolvedTools[index],
						undefined,
						signal,
						// Per-task update callback
						(partial) => {
							if (partial.details?.results[0]) {
								allResults[index] = partial.details.results[0];
								emitParallelUpdate();
							}
						},
						makeDetails("parallel"),
					);
					allResults[index] = result;
					emitParallelUpdate();
					return result;
				});

				const successCount = results.filter((r) => r.exitCode === 0).length;
				const summaries = results.map((r) => {
					const output = getFinalOutput(r.messages);
					return `[${displayLabel(r)}] ${r.exitCode === 0 ? "completed" : "failed"}:\n${output || "(no output)"}`;
				});
				return {
					content: [
						{
							type: "text",
							text: `Parallel: ${successCount}/${results.length} succeeded\n\n${summaries.join("\n\n")}`,
						},
					],
					details: makeDetails("parallel")(results),
				};
			}

			if (params.task) {
				const result = await runSingleAgent(
					ctx.cwd,
					params.task,
					params.label,
					params.cwd,
					defaultModel,
					resolvedTools[0],
					undefined,
					signal,
					onUpdate,
					makeDetails("single"),
				);
				const isError = result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
				if (isError) {
					const errorMsg =
						result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
					return {
						content: [{ type: "text", text: `Subagent ${result.stopReason || "failed"}: ${errorMsg}` }],
						details: makeDetails("single")([result]),
						isError: true,
					};
				}
				return {
					content: [{ type: "text", text: getFinalOutput(result.messages) || "(no output)" }],
					details: makeDetails("single")([result]),
				};
			}

			return {
				content: [{ type: "text", text: "Invalid parameters. Provide task, tasks, or chain." }],
				details: makeDetails("single")([]),
				isError: true,
			};
		},

		renderCall(args, theme, _context) {
			if (args.chain && args.chain.length > 0) {
				let text =
					theme.fg("toolTitle", theme.bold("subagent ")) + theme.fg("accent", `chain (${args.chain.length} steps)`);
				for (let i = 0; i < Math.min(args.chain.length, 3); i++) {
					const step = args.chain[i];
					const label = step.label?.trim()
						? step.label
						: previewText((step.task ?? "").replace(/\{previous\}/g, ""), 40);
					text += `\n  ${theme.fg("muted", `${i + 1}.`)} ${theme.fg("dim", label)}`;
				}
				if (args.chain.length > 3) text += `\n  ${theme.fg("muted", `... +${args.chain.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}
			if (args.tasks && args.tasks.length > 0) {
				let text =
					theme.fg("toolTitle", theme.bold("subagent ")) +
					theme.fg("accent", `parallel (${args.tasks.length} tasks)`);
				for (const t of args.tasks.slice(0, 3)) {
					const label = t.label?.trim() ? t.label : previewText(t.task ?? "", 40);
					text += `\n  ${theme.fg("dim", label)}`;
				}
				if (args.tasks.length > 3) text += `\n  ${theme.fg("muted", `... +${args.tasks.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}
			const hasLabel = Boolean(args.label?.trim());
			const heading = hasLabel ? (args.label as string) : previewText(args.task ?? "...", 60);
			let text = theme.fg("toolTitle", theme.bold("subagent ")) + theme.fg("accent", heading);
			if (hasLabel) text += `\n  ${theme.fg("dim", previewText(args.task ?? "", 60))}`;
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded }, theme, _context) {
			const details = result.details as SubagentDetails | undefined;
			if (!details || details.results.length === 0) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}

			const mdTheme = getMarkdownTheme();

			const renderDisplayItems = (items: DisplayItem[], limit?: number) => {
				const toShow = limit ? items.slice(-limit) : items;
				const skipped = limit && items.length > limit ? items.length - limit : 0;
				let text = "";
				if (skipped > 0) text += theme.fg("muted", `... ${skipped} earlier items\n`);
				for (const item of toShow) {
					if (item.type === "text") {
						const preview = expanded ? item.text : item.text.split("\n").slice(0, 3).join("\n");
						text += `${theme.fg("toolOutput", preview)}\n`;
					} else {
						text += `${theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme))}\n`;
					}
				}
				return text.trimEnd();
			};

			if (details.mode === "single" && details.results.length === 1) {
				const r = details.results[0];
				const isError = r.exitCode !== 0 || r.stopReason === "error" || r.stopReason === "aborted";
				const icon = isError ? theme.fg("error", "✗") : theme.fg("success", "✓");
				const displayItems = getDisplayItems(r.messages);
				const finalOutput = getFinalOutput(r.messages);

				if (expanded) {
					const container = new Container();
					let header = `${icon} ${theme.fg("toolTitle", theme.bold(displayLabel(r)))}`;
					if (isError && r.stopReason) header += ` ${theme.fg("error", `[${r.stopReason}]`)}`;
					container.addChild(new Text(header, 0, 0));
					if (isError && r.errorMessage)
						container.addChild(new Text(theme.fg("error", `Error: ${r.errorMessage}`), 0, 0));
					container.addChild(new Spacer(1));
					container.addChild(new Text(theme.fg("muted", "─── Task ───"), 0, 0));
					container.addChild(new Text(theme.fg("dim", r.task), 0, 0));
					container.addChild(new Spacer(1));
					container.addChild(new Text(theme.fg("muted", "─── Output ───"), 0, 0));
					if (displayItems.length === 0 && !finalOutput) {
						container.addChild(new Text(theme.fg("muted", "(no output)"), 0, 0));
					} else {
						for (const item of displayItems) {
							if (item.type === "toolCall")
								container.addChild(
									new Text(
										theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)),
										0,
										0,
									),
								);
						}
						if (finalOutput) {
							container.addChild(new Spacer(1));
							container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
						}
					}
					const usageStr = formatUsageStats(r.usage, r.model);
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", usageStr), 0, 0));
					}
					return container;
				}

				let text = `${icon} ${theme.fg("toolTitle", theme.bold(displayLabel(r)))}`;
				if (isError && r.stopReason) text += ` ${theme.fg("error", `[${r.stopReason}]`)}`;
				if (isError && r.errorMessage) text += `\n${theme.fg("error", `Error: ${r.errorMessage}`)}`;
				else if (displayItems.length === 0) text += `\n${theme.fg("muted", "(no output)")}`;
				else {
					text += `\n${renderDisplayItems(displayItems, COLLAPSED_ITEM_COUNT)}`;
					if (displayItems.length > COLLAPSED_ITEM_COUNT) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				}
				const usageStr = formatUsageStats(r.usage, r.model);
				if (usageStr) text += `\n${theme.fg("dim", usageStr)}`;
				return new Text(text, 0, 0);
			}

			const aggregateUsage = (results: SingleResult[]) => {
				const total = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, turns: 0 };
				for (const r of results) {
					total.input += r.usage.input;
					total.output += r.usage.output;
					total.cacheRead += r.usage.cacheRead;
					total.cacheWrite += r.usage.cacheWrite;
					total.cost += r.usage.cost;
					total.turns += r.usage.turns;
				}
				return total;
			};

			if (details.mode === "chain") {
				const successCount = details.results.filter((r) => r.exitCode === 0).length;
				const icon = successCount === details.results.length ? theme.fg("success", "✓") : theme.fg("error", "✗");

				if (expanded) {
					const container = new Container();
					container.addChild(
						new Text(
							icon +
								" " +
								theme.fg("toolTitle", theme.bold("chain ")) +
								theme.fg("accent", `${successCount}/${details.results.length} steps`),
							0,
							0,
						),
					);

					for (const r of details.results) {
						const rIcon = r.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
						const displayItems = getDisplayItems(r.messages);
						const finalOutput = getFinalOutput(r.messages);

						container.addChild(new Spacer(1));
						container.addChild(
							new Text(
								`${theme.fg("muted", `─── Step ${r.step}: `) + theme.fg("accent", displayLabel(r))} ${rIcon}`,
								0,
								0,
							),
						);
						container.addChild(new Text(theme.fg("muted", "Task: ") + theme.fg("dim", r.task), 0, 0));

						// Show tool calls
						for (const item of displayItems) {
							if (item.type === "toolCall") {
								container.addChild(
									new Text(
										theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)),
										0,
										0,
									),
								);
							}
						}

						// Show final output as markdown
						if (finalOutput) {
							container.addChild(new Spacer(1));
							container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
						}

						const stepUsage = formatUsageStats(r.usage, r.model);
						if (stepUsage) container.addChild(new Text(theme.fg("dim", stepUsage), 0, 0));
					}

					const usageStr = formatUsageStats(aggregateUsage(details.results));
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", `Total: ${usageStr}`), 0, 0));
					}
					return container;
				}

				// Collapsed view
				let text =
					icon +
					" " +
					theme.fg("toolTitle", theme.bold("chain ")) +
					theme.fg("accent", `${successCount}/${details.results.length} steps`);
				for (const r of details.results) {
					const rIcon = r.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
					const displayItems = getDisplayItems(r.messages);
					text += `\n\n${theme.fg("muted", `─── Step ${r.step}: `)}${theme.fg("accent", displayLabel(r))} ${rIcon}`;
					if (displayItems.length === 0) text += `\n${theme.fg("muted", "(no output)")}`;
					else text += `\n${renderDisplayItems(displayItems, 5)}`;
				}
				const usageStr = formatUsageStats(aggregateUsage(details.results));
				if (usageStr) text += `\n\n${theme.fg("dim", `Total: ${usageStr}`)}`;
				text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				return new Text(text, 0, 0);
			}

			if (details.mode === "parallel") {
				const running = details.results.filter((r) => r.exitCode === -1).length;
				const successCount = details.results.filter((r) => r.exitCode === 0).length;
				const failCount = details.results.filter((r) => r.exitCode > 0).length;
				const isRunning = running > 0;
				const icon = isRunning
					? theme.fg("warning", "⏳")
					: failCount > 0
						? theme.fg("warning", "◐")
						: theme.fg("success", "✓");
				const status = isRunning
					? `${successCount + failCount}/${details.results.length} done, ${running} running`
					: `${successCount}/${details.results.length} tasks`;

				if (expanded && !isRunning) {
					const container = new Container();
					container.addChild(
						new Text(
							`${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`,
							0,
							0,
						),
					);

					for (const r of details.results) {
						const rIcon = r.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
						const displayItems = getDisplayItems(r.messages);
						const finalOutput = getFinalOutput(r.messages);

						container.addChild(new Spacer(1));
						container.addChild(
							new Text(`${theme.fg("muted", "─── ") + theme.fg("accent", displayLabel(r))} ${rIcon}`, 0, 0),
						);
						container.addChild(new Text(theme.fg("muted", "Task: ") + theme.fg("dim", r.task), 0, 0));

						// Show tool calls
						for (const item of displayItems) {
							if (item.type === "toolCall") {
								container.addChild(
									new Text(
										theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)),
										0,
										0,
									),
								);
							}
						}

						// Show final output as markdown
						if (finalOutput) {
							container.addChild(new Spacer(1));
							container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
						}

						const taskUsage = formatUsageStats(r.usage, r.model);
						if (taskUsage) container.addChild(new Text(theme.fg("dim", taskUsage), 0, 0));
					}

					const usageStr = formatUsageStats(aggregateUsage(details.results));
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", `Total: ${usageStr}`), 0, 0));
					}
					return container;
				}

				// Collapsed view (or still running)
				let text = `${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`;
				for (const r of details.results) {
					const rIcon =
						r.exitCode === -1
							? theme.fg("warning", "⏳")
							: r.exitCode === 0
								? theme.fg("success", "✓")
								: theme.fg("error", "✗");
					const displayItems = getDisplayItems(r.messages);
					text += `\n\n${theme.fg("muted", "─── ")}${theme.fg("accent", displayLabel(r))} ${rIcon}`;
					if (displayItems.length === 0)
						text += `\n${theme.fg("muted", r.exitCode === -1 ? "(running...)" : "(no output)")}`;
					else text += `\n${renderDisplayItems(displayItems, 5)}`;
				}
				if (!isRunning) {
					const usageStr = formatUsageStats(aggregateUsage(details.results));
					if (usageStr) text += `\n\n${theme.fg("dim", `Total: ${usageStr}`)}`;
				}
				if (!expanded) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				return new Text(text, 0, 0);
			}

			const text = result.content[0];
			return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
		},
	});
}
