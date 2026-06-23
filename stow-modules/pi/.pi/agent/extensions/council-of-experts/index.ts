/**
 * Council of Experts Tool - Consult multiple expert perspectives in parallel
 *
 * Spawns separate `pi` processes for each selected expert, giving each an
 * isolated context window with a lens-specific system prompt. Collects
 * outputs and returns a structured Council Report.
 *
 * Reuses the subprocess spawn pattern from the subagent extension.
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { AgentToolResult } from "@mariozechner/pi-agent-core";
import type { Message } from "@mariozechner/pi-ai";
import { type ExtensionAPI, getMarkdownTheme, parseFrontmatter, withFileMutationQueue } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const MAX_CONCURRENCY = 4;

interface ExpertFrontmatter {
	lens: string;
	opposes?: string;
	"aligns-with"?: string;
	"model-preference"?: string;
}

interface ExpertConfig {
	name: string;
	lens: string;
	opposes: string[];
	alignsWith: string[];
	modelPreference?: string;
	systemPrompt: string;
	filePath: string;
}

interface ExpertResult {
	expert: string;
	lens: string;
	exitCode: number;
	messages: Message[];
	stderr: string;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
}

interface CouncilDetails {
	experts: string[];
	results: ExpertResult[];
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

function loadExperts(expertsDir: string): ExpertConfig[] {
	const experts: ExpertConfig[] = [];

	if (!fs.existsSync(expertsDir)) return experts;

	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(expertsDir, { withFileTypes: true });
	} catch {
		return experts;
	}

	for (const entry of entries) {
		if (!entry.name.endsWith(".md")) continue;
		if (!entry.isFile() && !entry.isSymbolicLink()) continue;

		const filePath = path.join(expertsDir, entry.name);
		let content: string;
		try {
			content = fs.readFileSync(filePath, "utf-8");
		} catch {
			continue;
		}

		const { frontmatter, body } = parseFrontmatter<ExpertFrontmatter>(content);

		if (!frontmatter.lens) continue;

		const name = entry.name.replace(/\.md$/, "");

		experts.push({
			name,
			lens: frontmatter.lens,
			opposes: frontmatter.opposes
				? frontmatter.opposes.split(",").map((s) => s.trim()).filter(Boolean)
				: [],
			alignsWith: frontmatter["aligns-with"]
				? frontmatter["aligns-with"].split(",").map((s) => s.trim()).filter(Boolean)
				: [],
			modelPreference: frontmatter["model-preference"],
			systemPrompt: body.trim(),
			filePath,
		});
	}

	return experts;
}

async function writePromptToTempFile(name: string, content: string): Promise<{ dir: string; filePath: string }> {
	const tmpDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-council-"));
	const safeName = name.replace(/[^\w.-]+/g, "_");
	const filePath = path.join(tmpDir, `expert-${safeName}.md`);
	await withFileMutationQueue(filePath, async () => {
		await fs.promises.writeFile(filePath, content, { encoding: "utf-8", mode: 0o600 });
	});
	return { dir: tmpDir, filePath };
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

function buildUserMessage(
	expertName: string,
	lens: string,
	task: string,
	context?: string,
	focusedQuestion?: string,
): string {
	const parts: string[] = [];

	parts.push(`You are consulting as the **${expertName}** expert on the council.`);
	parts.push("");
	parts.push(`Your lens: ${lens}`);
	parts.push("");

	if (focusedQuestion) {
		parts.push(`Focused question for you: ${focusedQuestion}`);
		parts.push("");
	}

	parts.push("## Task");
	parts.push("");
	parts.push(task);
	parts.push("");

	if (context) {
		parts.push("## Context");
		parts.push("");
		parts.push(context);
		parts.push("");
	}

	parts.push("---");
	parts.push("");
	parts.push("Analyze the task through your specific lens. Focus on what your expertise reveals that others might miss. Be concise and specific.");
	parts.push("");
	parts.push("Structure your response as:");
	parts.push("");
	parts.push("## Observations");
	parts.push("Key things you notice from your lens.");
	parts.push("");
	parts.push("## Risks / Concerns");
	parts.push("What could go wrong that your lens catches.");
	parts.push("");
	parts.push("## Recommendations");
	parts.push("Specific, actionable suggestions.");

	return parts.join("\n");
}

async function runExpert(
	expert: ExpertConfig,
	task: string,
	context: string | undefined,
	focusedQuestion: string | undefined,
	signal: AbortSignal | undefined,
	model?: string,
): Promise<ExpertResult> {
	const userMessage = buildUserMessage(expert.name, expert.lens, task, context, focusedQuestion);

	const args: string[] = ["--mode", "json", "-p", "--no-session"];
	if (model) args.push("--model", model);

	let tmpSystemDir: string | null = null;
	let tmpSystemPath: string | null = null;

	const result: ExpertResult = {
		expert: expert.name,
		lens: expert.lens,
		exitCode: 0,
		messages: [],
		stderr: "",
	};

	try {
		if (expert.systemPrompt) {
			const tmp = await writePromptToTempFile(expert.name, expert.systemPrompt);
			tmpSystemDir = tmp.dir;
			tmpSystemPath = tmp.filePath;
			args.push("--append-system-prompt", tmpSystemPath);
		}

		args.push(userMessage);

		let wasAborted = false;

		const exitCode = await new Promise<number>((resolve) => {
			const invocation = getPiInvocation(args);
			const proc = spawn(invocation.command, invocation.args, {
				cwd: process.cwd(),
				shell: false,
				stdio: ["ignore", "pipe", "pipe"],
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
					result.messages.push(msg);

					if (msg.role === "assistant") {
						if (!result.model && msg.model) result.model = msg.model;
						if (msg.stopReason) result.stopReason = msg.stopReason;
						if (msg.errorMessage) result.errorMessage = msg.errorMessage;
					}
				}

				if (event.type === "tool_result_end" && event.message) {
					result.messages.push(event.message as Message);
				}
			};

			proc.stdout.on("data", (data) => {
				buffer += data.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) processLine(line);
			});

			proc.stderr.on("data", (data) => {
				result.stderr += data.toString();
			});

			proc.on("close", (code) => {
				if (buffer.trim()) processLine(buffer);
				resolve(code ?? 0);
			});

			proc.on("error", () => {
				resolve(1);
			});

			if (signal) {
				const killProc = () => {
					wasAborted = true;
					proc.kill("SIGTERM");
					setTimeout(() => {
						if (!proc.killed) proc.kill("SIGKILL");
					}, 5000);
				};
				if (signal.aborted) killProc();
				else signal.addEventListener("abort", killProc, { once: true });
			}
		});

		result.exitCode = exitCode;
		if (wasAborted) throw new Error("Council expert was aborted");
		return result;
	} finally {
		if (tmpSystemPath) try { fs.unlinkSync(tmpSystemPath); } catch { /* ignore */ }
		if (tmpSystemDir) try { fs.rmdirSync(tmpSystemDir); } catch { /* ignore */ }
	}
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

function buildCouncilReport(results: ExpertResult[], task: string): string {
	const lines: string[] = [];

	lines.push("# Council Report");
	lines.push("");
	lines.push(`**Task:** ${task.split("\n")[0]}`);
	lines.push("");
	lines.push(`**Experts consulted:** ${results.map((r) => r.expert).join(", ")}`);
	lines.push("");

	const succeeded = results.filter((r) => r.exitCode === 0);
	const failed = results.filter((r) => r.exitCode !== 0);

	if (failed.length > 0) {
		lines.push("## Failures");
		lines.push("");
		for (const r of failed) {
			const errorMsg = r.errorMessage || r.stderr || "(no output)";
			lines.push(`- **${r.expert}**: ${errorMsg}`);
		}
		lines.push("");
	}

	for (const r of succeeded) {
		const output = getFinalOutput(r.messages);
		lines.push(`## ${r.expert.charAt(0).toUpperCase() + r.expert.slice(1)}`);
		lines.push(`*Lens: ${r.lens}*`);
		lines.push("");
		lines.push(output || "(no output)");
		lines.push("");
	}

	if (succeeded.length === 0) {
		lines.push("## No successful consultations");
		lines.push("");
		lines.push("All experts failed to respond. Check failures above.");
	}

	return lines.join("\n");
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "council",
		label: "Council",
		description: [
			"Consult a council of experts in parallel. Each expert analyzes the task through their specific lens.",
			"Experts: architect, qa, pedantic, product-engineer, hacker, team-player.",
			"Use with /skill:council-of-experts for the full catalog and selection algorithm.",
		].join(" "),
		parameters: Type.Object({
			experts: Type.Array(Type.String(), {
				description: "Expert names to consult (2-4 recommended)",
			}),
			task: Type.String({
				description: "Task description for the experts to analyze",
			}),
			context: Type.Optional(Type.String({
				description: "Code snippets, diff, constraints, or other relevant context",
			})),
			specific_questions: Type.Optional(Type.Record(Type.String(), Type.String(), {
				description: "Per-expert focused questions. Keys match expert names. Use to steer each expert toward specific concerns.",
			})),
		}),

		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const expertsDir = path.join(__dirname, "experts");
			const allExperts = loadExperts(expertsDir);

			if (allExperts.length === 0) {
				return {
					content: [{ type: "text" as const, text: "No experts found. Check that expert .md files exist in the experts/ directory." }],
					details: { experts: [], results: [] } as CouncilDetails,
					isError: true,
				};
			}

			const expertMap = new Map(allExperts.map((e) => [e.name, e]));

			const selectedExperts: ExpertConfig[] = [];
			const missingExperts: string[] = [];

			for (const name of params.experts) {
				const expert = expertMap.get(name);
				if (expert) {
					selectedExperts.push(expert);
				} else {
					missingExperts.push(name);
				}
			}

			if (missingExperts.length > 0) {
				const available = allExperts.map((e) => e.name).join(", ");
				return {
					content: [{ type: "text" as const, text: `Unknown expert(s): ${missingExperts.join(", ")}. Available: ${available}` }],
					details: { experts: params.experts, results: [] } as CouncilDetails,
					isError: true,
				};
			}

			if (selectedExperts.length === 0) {
				const available = allExperts.map((e) => e.name).join(", ");
				return {
					content: [{ type: "text" as const, text: `No experts selected. Available: ${available}` }],
					details: { experts: params.experts, results: [] } as CouncilDetails,
					isError: true,
				};
			}

			const questionsMap = params.specific_questions ?? {};

			const results = await mapWithConcurrencyLimit(
				selectedExperts,
				MAX_CONCURRENCY,
				async (expert) => {
					return runExpert(
						expert,
						params.task,
						params.context,
						questionsMap[expert.name],
						signal,
					);
				},
			);

			const report = buildCouncilReport(results, params.task);

			return {
				content: [{ type: "text" as const, text: report }],
				details: {
					experts: params.experts,
					results,
				} as CouncilDetails,
			};
		},

		renderCall(args, theme, _context) {
			const expertNames = (args.experts as string[]) || [];
			const preview = args.task
				? (args.task as string).length > 60
					? `${(args.task as string).slice(0, 60)}...`
					: (args.task as string)
				: "...";

			let text =
				theme.fg("toolTitle", theme.bold("council ")) +
				theme.fg("accent", `(${expertNames.length} experts)`) +
				theme.fg("muted", ` ${expertNames.join(", ")}`);
			text += `\n  ${theme.fg("dim", preview)}`;
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded }, theme, _context) {
			const details = result.details as CouncilDetails | undefined;
			const mdTheme = getMarkdownTheme();

			if (!details || details.results.length === 0) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}

			const successCount = details.results.filter((r) => r.exitCode === 0).length;
			const failCount = details.results.filter((r) => r.exitCode !== 0).length;
			const icon = failCount > 0 ? theme.fg("warning", "◐") : theme.fg("success", "✓");
			const status = `${successCount}/${details.results.length} experts`;

			if (expanded) {
				const container = new Container();
				container.addChild(
					new Text(
						`${icon} ${theme.fg("toolTitle", theme.bold("council "))}${theme.fg("accent", status)}`,
						0,
						0,
					),
				);

				for (const r of details.results) {
					const rIcon = r.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
					const output = getFinalOutput(r.messages);

					container.addChild(new Spacer(1));
					container.addChild(
						new Text(
							`${theme.fg("muted", "─── ")}${theme.fg("accent", r.expert)} ${rIcon} ${theme.fg("dim", `(${r.lens})`)}`,
							0,
							0,
						),
					);

					if (r.exitCode !== 0) {
						const errorMsg = r.errorMessage || r.stderr || "(no output)";
						container.addChild(new Text(theme.fg("error", `Error: ${errorMsg}`), 0, 0));
					} else if (output) {
						container.addChild(new Spacer(1));
						container.addChild(new Markdown(output.trim(), 0, 0, mdTheme));
					} else {
						container.addChild(new Text(theme.fg("muted", "(no output)"), 0, 0));
					}
				}

				return container;
			}

			// Collapsed view
			let text = `${icon} ${theme.fg("toolTitle", theme.bold("council "))}${theme.fg("accent", status)}`;

			for (const r of details.results) {
				const rIcon = r.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
				const output = getFinalOutput(r.messages);
				const preview = output
					? output.split("\n").slice(0, 2).join("\n")
					: r.exitCode !== 0
						? r.errorMessage || r.stderr || "(error)"
						: "(no output)";
				text += `\n\n${theme.fg("muted", "─── ")}${theme.fg("accent", r.expert)} ${rIcon}`;
				text += `\n${theme.fg("dim", preview)}`;
			}
			text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
			return new Text(text, 0, 0);
		},
	});
}
