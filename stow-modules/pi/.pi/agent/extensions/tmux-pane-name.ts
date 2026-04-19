/**
 * Tmux Pane Renaming Extension
 *
 * Renames the current tmux window using Haiku to generate a creative short name
 * based on the project directory. Appends `*` when waiting for user input.
 *
 * Requires: tmux with `allow-rename on`, ANTHROPIC_API_KEY for Haiku calls.
 */

import path from "node:path";
import { complete, getModel } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

let paneName: string | null = null;
let inTmux = false;
let named = false;

function setWindowName(name: string) {
	if (!inTmux) return;
	// ESC k ... ESC \ sets the tmux window name (automatic-rename title)
	process.stdout.write(`\x1bk${name}\x1b\\`);
}

async function generatePaneName(prompt: string, ctx: ExtensionContext): Promise<string> {
	const fallback = path.basename(process.cwd());
	const model = getModel("anthropic", "claude-haiku-4-5");

	if (!model) return fallback;

	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
	if (!auth?.ok || !auth.apiKey) return fallback;

	try {
		const response = await complete(
			model,
			{
				messages: [
					{
						role: "user" as const,
						content: [
							{
								type: "text" as const,
								text: `Give me a very short name (1-3 words, max 20 chars) for a coding session about the following task:\n\n${prompt}\n\nJust respond with the name, nothing else. Be creative but make it relevant to the task.`,
							},
						],
						timestamp: Date.now(),
					},
				],
			},
			{ apiKey: auth.apiKey, headers: auth.headers },
		);

		const name = response.content
			.filter((c): c is { type: "text"; text: string } => c.type === "text")
			.map((c) => c.text.trim())
			.join("")
			.slice(0, 20);

		return name || fallback;
	} catch {
		return fallback;
	}
}

function showIdle() {
	if (paneName) setWindowName(`${paneName} [idle]`);
}

function showBusy() {
	if (paneName) setWindowName(paneName);
}

export default function(pi: ExtensionAPI) {
	inTmux = !!process.env.TMUX;

	pi.on("session_start", async (event, ctx) => {
		named = false;
		paneName = null;

		if (!inTmux) return;

		// On resume/fork, derive name from the first user message in the session
		if (event.reason === "resume" || event.reason === "fork") {
			const entries = ctx.sessionManager.getBranch();
			const firstUserMsg = entries.find(
				(e) => e.type === "message" && e.message?.role === "user",
			);
			if (firstUserMsg?.type === "message") {
				const content = firstUserMsg.message.content;
				const text =
					typeof content === "string"
						? content
						: Array.isArray(content)
							? content
								.filter((c): c is { type: "text"; text: string } => c.type === "text")
								.map((c) => c.text)
								.join("\n")
							: "";
				if (text) {
					named = true;
					generatePaneName(text, ctx).then((name) => {
						paneName = name;
						showIdle();
					});
				}
			}
		}
	});

	pi.on("before_agent_start", async (event, ctx) => {
		if (!inTmux || named) return;
		named = true;
		// Generate name from first prompt in the background
		const prompt = event.prompt ?? "";
		generatePaneName(prompt, ctx).then((name) => {
			paneName = name;
			showBusy();
		});
	});

	pi.on("agent_start", async () => {
		showBusy();
	});

	pi.on("agent_end", async () => {
		showIdle();
	});

	pi.on("session_shutdown", async () => {
		if (inTmux) {
			// Reset - allow automatic-rename to take over again
			setWindowName("");
		}
	});
}
