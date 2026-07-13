/**
 * Context extension - wraps the `context` skill (box-local agent context
 * bundle at $XDG_STATE_HOME/agent-context).
 *
 * Contributions:
 *   - Prompt templates (ctx-bootstrap, ctx-for, ctx-plan) and the
 *     `context` skill (bundled under skills/) via `resources_discover`.
 *   - Short system prompt block pointing at the bundle + skill via
 *     `before_agent_start` (appended, chained per turn - no accumulation).
 *
 * The skill itself stays authoritative for the full read/write protocol;
 * this extension keeps its own text thin to avoid duplication.
 */

import * as path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const EXTENSION_DIR = path.dirname(fileURLToPath(import.meta.url));

const CONTEXT_BUNDLE_BLOCK = `## Cross-session context bundle

Box-local bundle at \`$XDG_STATE_HOME/agent-context\` (git-tracked). Load the
\`context\` skill before reading or writing it. Use it when starting work that
may have prior context, or when recording durable findings, plans, handoffs.
Authority order: repo ADRs/specs > Linear > bundle.`;

export default function (pi: ExtensionAPI) {
	pi.on("resources_discover", () => ({
		promptPaths: [path.join(EXTENSION_DIR, "prompts")],
		skillPaths: [path.join(EXTENSION_DIR, "skills")],
	}));

	pi.on("before_agent_start", (event) => ({
		systemPrompt: `${event.systemPrompt}\n\n${CONTEXT_BUNDLE_BLOCK}`,
	}));
}
