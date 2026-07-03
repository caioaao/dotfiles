#!/usr/bin/env node
/**
 * piobs - observe active pi sessions.
 *
 *   piobs              TUI: session list + distilled feed
 *   piobs list         print sessions to stdout
 *   piobs redistill <id-prefix>   rebuild a session's feed from scratch
 *   piobs distill <id-prefix>     one-shot catch-up distill (prints new lines)
 */

import { clearFeed, gc, listSessions, type FeedEntry, type SessionInfo } from "./lib/data.ts";
import { distillSession } from "./lib/distiller.ts";
import { runTui } from "./lib/tui.ts";

const [cmd, ...args] = process.argv.slice(2);

function findSession(prefix: string | undefined): SessionInfo {
	if (!prefix) {
		console.error("usage: piobs <command> <session-id-prefix>");
		process.exit(1);
	}
	const matches = listSessions().filter((s) => s.sessionId.startsWith(prefix));
	if (matches.length === 0) {
		console.error(`no session matches '${prefix}'`);
		process.exit(1);
	}
	if (matches.length > 1) {
		console.error(`ambiguous: ${matches.map((s) => s.sessionId).join(", ")}`);
		process.exit(1);
	}
	return matches[0];
}

const printEntry = (e: FeedEntry) => {
	const detail = e.detail ? `\n           ${e.detail}` : "";
	console.log(`[${e.t.slice(11, 19)}] ${e.kind.padEnd(9)} ${e.text}${detail}`);
};

switch (cmd) {
	case undefined:
	case "tui":
		await runTui();
		break;

	case "list": {
		gc();
		for (const s of listSessions()) {
			const title = s.sessionName ?? s.lastPrompt ?? "";
			console.log(
				[
					s.effectiveState.padEnd(7),
					s.sessionId.slice(0, 8),
					s.cwd.replace(/^\/Users\/[^/]+/, "~").padEnd(40),
					(s.model ?? "").padEnd(30),
					title.slice(0, 60),
				].join("  "),
			);
		}
		break;
	}

	case "redistill": {
		const s = findSession(args[0]);
		clearFeed(s.sessionId);
		const n = await distillSession(s, { onEntry: printEntry });
		console.log(`\n${n} feed entries`);
		break;
	}

	case "distill": {
		const s = findSession(args[0]);
		const n = await distillSession(s, { onEntry: printEntry });
		console.log(`\n${n} new feed entries`);
		break;
	}

	default:
		console.error(`unknown command: ${cmd}`);
		console.error("usage: piobs [tui|list|distill <id>|redistill <id>]");
		process.exit(1);
}
