/**
 * Wayfinder Loop Extension
 *
 * `/wayfind <map>` works through a wayfinder map one ticket per session
 * without re-typing `/wayfinder <map>` after each ticket:
 *
 *   1. start a fresh session and invoke the wayfinder skill with <map>
 *   2. the agent resolves one ticket (grilling with the user as usual) and,
 *      once the resolution is fully recorded, calls `wayfinder_ticket_done`
 *   3. when that turn ends, go back to 1 - or stop if the agent reported an
 *      empty frontier
 *
 * The explicit tool call is the only advance signal. A turn that ends without
 * it (a grilling question waiting for an answer, Esc, an error) leaves the
 * session alone, so the loop never cuts a ticket short. omp's built-in `/loop`
 * cannot make that distinction: it re-submits after every yield, and every
 * manual answer replaces the loop prompt.
 *
 * `/wayfind stop` ends the loop after the current session; `/wayfind` alone
 * reports its state.
 *
 * Each loop session records the loop in a custom session entry, and marks it
 * done when the tool fires. Resuming a session whose ticket is still open (after
 * a crash, a closed terminal, `/resume`) restores the loop and the tool. Only
 * command handlers get session controls, so a restored loop is detached until
 * `/wayfind` re-attaches it; a ticket finished while detached waits for that
 * `/wayfind` to start the next session.
 *
 * The skill is read from the mattpocock-skills extension package and injected the
 * way omp injects a typed skill command (a `skill-prompt` message), because
 * extension-sent messages bypass slash-command and skill expansion.
 */

import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

const SKILL_NAME = "wayfinder";
const SKILL_DIR = join("/run/current-system/sw/share/omp/mattpocock-skills/skills", SKILL_NAME);
const SKILL_FILE = join(SKILL_DIR, "SKILL.md");
const TOOL_NAME = "wayfinder_ticket_done";
const ENTRY_TYPE = "caioaao.wayfinder-loop";

const LOOP_PROTOCOL = `[Wayfinder loop: this session runs inside an automatic loop. When it ends, the next session starts on its own with the same map.]
- Resolve exactly ONE ticket in this session (research tickets excepted, per the skill).
- Grill the user as usual; stopping to wait for their answer is fine and does not advance the loop.
- Call \`${TOOL_NAME}\` exactly once, only after the ticket is fully recorded: resolution comment posted, ticket closed, Decisions-so-far updated, and newly surfaced tickets and graduated fog created and wired. Then end your turn.
- If the map has no ticket you can take (empty frontier, or every open ticket claimed or blocked), call \`${TOOL_NAME}\` with \`frontier_empty: true\` and explain what is left.
- Never call \`${TOOL_NAME}\` while the ticket is still open or a question to the user is pending.`;

interface LoopState {
	map: string;
	/**
	 * Captured from a `/wayfind` invocation; its session controls stay valid after
	 * the handler returns. Undefined for a loop restored from a resumed session.
	 */
	ctx: ExtensionCommandContext | undefined;
	iteration: number;
	stopRequested: boolean;
	/** Set by the tool during a turn; consumed when the loop advances. */
	pending: { frontierEmpty: boolean; summary: string } | undefined;
}

/** Session entry data; the latest one on the branch wins. */
interface PersistedLoop {
	map: string;
	iteration: number;
	stopRequested: boolean;
	/** The tool fired in this session: resuming it must not re-arm the loop. */
	done: boolean;
}

let loop: LoopState | undefined;

/** The loop this session belongs to, unless its ticket was already reported done. */
function persistedLoop(ctx: ExtensionContext): PersistedLoop | undefined {
	let latest: PersistedLoop | undefined;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type === "custom" && entry.customType === ENTRY_TYPE) latest = entry.data as PersistedLoop;
	}
	return latest && !latest.done ? latest : undefined;
}

/** Strip YAML frontmatter, mirroring what omp sends for a typed skill command. */
function skillBody(content: string): string {
	const match = /^---\r?\n[\s\S]*?\r?\n---\r?\n?/.exec(content);
	return (match ? content.slice(match[0].length) : content).trim();
}

async function buildSkillPrompt(map: string): Promise<{ message: string; lineCount: number }> {
	const body = skillBody(await readFile(SKILL_FILE, "utf8"));
	const message = [
		`[IMPORTANT: User invoked the "${SKILL_NAME}" skill; follow its instructions. Full skill below.]`,
		"",
		body,
		"",
		"---",
		"",
		`[Skill directory: ${SKILL_DIR}]`,
		"Resolve relative paths in this skill (e.g. `scripts/foo.js`, `templates/config.yaml`) against this absolute directory; read referenced assets and templates; run scripts with the terminal tool when skill instructions call for it.",
		"",
		LOOP_PROTOCOL,
		"",
		`User: ${map}`,
	].join("\n");
	return { message, lineCount: body.split("\n").length };
}

export default function (pi: ExtensionAPI) {
	const z = pi.zod;

	async function setToolActive(active: boolean) {
		const tools = new Set(pi.getActiveTools());
		if (active) tools.add(TOOL_NAME);
		else tools.delete(TOOL_NAME);
		await pi.setActiveTools([...tools]);
	}

	function persist(state: LoopState, done: boolean) {
		const data: PersistedLoop = {
			map: state.map,
			iteration: state.iteration,
			stopRequested: state.stopRequested,
			done,
		};
		pi.appendEntry(ENTRY_TYPE, data);
	}

	async function stop(ctx: ExtensionContext, message: string) {
		loop = undefined;
		await setToolActive(false);
		ctx.ui.notify(message, "info");
	}

	async function startIteration(state: LoopState, ctx: ExtensionCommandContext) {
		await ctx.waitForIdle();
		if (loop !== state) return;
		// Read the skill before leaving the current session so a missing file
		// fails here instead of opening an empty session.
		const prompt = await buildSkillPrompt(state.map);
		const { cancelled } = await ctx.newSession();
		if (cancelled) {
			await stop(ctx, "Wayfinder loop stopped: new session was cancelled.");
			return;
		}
		state.iteration++;
		state.pending = undefined;
		persist(state, false);
		await setToolActive(true);
		pi.sendMessage(
			{
				customType: "skill-prompt",
				content: prompt.message,
				display: true,
				attribution: "user",
				details: {
					name: SKILL_NAME,
					path: SKILL_FILE,
					args: state.map,
					prompt: `/skill:${SKILL_NAME} ${state.map}`,
					lineCount: prompt.lineCount,
				},
			},
			{ triggerTurn: true },
		);
		ctx.ui.notify(`Wayfinder loop: session ${state.iteration} on ${state.map}.`, "info");
	}

	function runIteration(state: LoopState, ctx: ExtensionCommandContext) {
		startIteration(state, ctx).catch(async (error: unknown) => {
			if (loop === state) loop = undefined;
			await setToolActive(false).catch(() => {});
			ctx.ui.notify(`Wayfinder loop stopped: ${error instanceof Error ? error.message : String(error)}`, "error");
		});
	}

	/** Act on a ticket reported done: stop, start the next session, or wait for `/wayfind` when detached. */
	function advance(state: LoopState, ctx: ExtensionContext) {
		const { pending } = state;
		if (!pending) return;
		if (pending.frontierEmpty || state.stopRequested) {
			state.pending = undefined;
			const message = pending.frontierEmpty
				? `Wayfinder loop finished on ${state.map}: ${pending.summary}`
				: `Wayfinder loop stopped after ${state.iteration} session(s).`;
			void stop(ctx, message).catch(() => {});
			return;
		}
		const commandCtx = state.ctx;
		if (!commandCtx) {
			ctx.ui.notify(`Wayfinder ticket done. Run /wayfind to start the next session on ${state.map}.`, "info");
			return;
		}
		state.pending = undefined;
		// Leave the current dispatch before switching sessions; newSession waits
		// for idle, which an agent_end handler is part of. A raw timer, because
		// managed timers are cleared when the session shuts down.
		setTimeout(() => runIteration(state, commandCtx), 0);
	}

	/**
	 * Restore a loop from the session just opened, or drop a detached loop that
	 * does not belong to it. An attached loop owns its session switches.
	 */
	async function reconcile(ctx: ExtensionContext) {
		if (!ctx.hasUI || loop?.ctx) return;
		const saved = persistedLoop(ctx);
		if (!saved) {
			if (loop) {
				loop = undefined;
				await setToolActive(false);
			}
			return;
		}
		loop = {
			map: saved.map,
			ctx: undefined,
			iteration: saved.iteration,
			stopRequested: saved.stopRequested,
			pending: undefined,
		};
		await setToolActive(true);
		ctx.ui.notify(
			`Wayfinder loop on ${saved.map} restored at session ${saved.iteration}. Run /wayfind to re-attach it so the next session starts on its own.`,
			"info",
		);
	}

	pi.on("session_start", (_event, ctx) => reconcile(ctx));
	pi.on("session_switch", (event, ctx) => (event.reason === "new" ? undefined : reconcile(ctx)));

	pi.registerTool({
		name: TOOL_NAME,
		label: "Wayfinder ticket done",
		description:
			"Signal the wayfinder loop that this session's ticket is fully resolved and recorded (resolution comment, ticket closed, map updated, new tickets wired), or that the map has no ticket left to take. The loop starts the next session after this turn ends. Call at most once per session, never while a question to the user is pending.",
		parameters: z.object({
			summary: z.string().describe("One line: the ticket resolved and its decision, or why nothing is left."),
			frontier_empty: z
				.boolean()
				.optional()
				.describe("True when no ticket can be taken: frontier empty, or every open ticket claimed or blocked."),
		}),
		defaultInactive: true,
		loadMode: "essential",
		approval: "read",
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			if (!loop || !ctx.hasUI) {
				return { content: [{ type: "text", text: "No wayfinder loop is running; nothing recorded." }] };
			}
			loop.pending = { frontierEmpty: params.frontier_empty ?? false, summary: params.summary };
			persist(loop, true);
			const next =
				loop.pending.frontierEmpty || loop.stopRequested
					? "The loop will stop when this turn ends"
					: loop.ctx
						? "The next session starts when this turn ends"
						: "This loop was restored from a resumed session, so the user must run /wayfind to start the next session; tell them";
			return {
				content: [{ type: "text", text: `Recorded. ${next}; end your turn now.` }],
			};
		},
	});

	// agent_end fires for every finished turn, including subagents (headless,
	// rebound to this extension). Only the UI session drives the loop, and only
	// a turn in which the tool fired advances it.
	pi.on("agent_end", (_event, ctx) => {
		if (loop && ctx.hasUI) advance(loop, ctx);
	});

	pi.registerCommand("wayfind", {
		description: "Loop the wayfinder skill over a map, one ticket per fresh session: /wayfind <map> | stop",
		handler: async (args, ctx) => {
			const arg = args.trim();
			if (!arg) {
				if (loop && !loop.ctx) {
					loop.ctx = ctx;
					if (loop.pending) advance(loop, ctx);
					else ctx.ui.notify(`Wayfinder loop re-attached on ${loop.map}: session ${loop.iteration}.`, "info");
					return;
				}
				ctx.ui.notify(
					loop
						? `Wayfinder loop on ${loop.map}: session ${loop.iteration}${loop.stopRequested ? ", stopping after this one" : ""}.`
						: "No wayfinder loop running. Usage: /wayfind <map> | stop",
					"info",
				);
				return;
			}
			if (arg === "stop") {
				if (!loop) {
					ctx.ui.notify("No wayfinder loop running.", "info");
					return;
				}
				loop.stopRequested = true;
				// A pending ticket means a detached loop already finished its session.
				if (loop.pending) {
					advance(loop, ctx);
					return;
				}
				persist(loop, false);
				ctx.ui.notify(`Wayfinder loop will stop after session ${loop.iteration}.`, "info");
				return;
			}
			if (loop) {
				ctx.ui.notify(`A wayfinder loop is already running on ${loop.map}. /wayfind stop first.`, "warning");
				return;
			}
			const state: LoopState = { map: arg, ctx, iteration: 0, stopRequested: false, pending: undefined };
			loop = state;
			runIteration(state, ctx);
		},
	});
}
