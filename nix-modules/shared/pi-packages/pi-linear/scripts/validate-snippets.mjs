#!/usr/bin/env node
/**
 * Validate every ```graphql snippet in the skill against Linear's live schema.
 *
 * Linear validates a document before authenticating, so this needs no API key.
 * Run after editing the skill: node scripts/validate-snippets.mjs
 *
 * Blocks that are filter fragments (`filter: { ... }`) are wrapped in a minimal
 * query so their shape is checked too. Anything that cannot be turned into a
 * document is a failure, never a skip.
 */

import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ENDPOINT = "https://api.linear.app/graphql";
const SKILL_DIR = join(dirname(fileURLToPath(import.meta.url)), "..", "skills", "linear-graphql");

/** Errors that mean "no values supplied", not "document is wrong". */
const IGNORE = [/was not provided/i, /Authentication required/i, /not authenticated/i];

function documentsFor(block) {
	const body = block.trim();
	if (/^(query|mutation|fragment|\{)/.test(body)) return [body];
	// Filter fragments: each `filter: { ... }` (possibly multi-line) is wrapped
	// in a minimal query and checked on its own.
	if (/^filter\s*:/.test(body)) {
		const fragments = [];
		let current = "";
		let depth = 0;
		for (const raw of body.split("\n")) {
			const line = raw.replace(/#.*$/, "").trimEnd();
			if (!line.trim()) continue;
			current += `${line}\n`;
			depth += (line.match(/\{/g)?.length ?? 0) - (line.match(/\}/g)?.length ?? 0);
			if (depth === 0) {
				fragments.push(current.trim().replace(/,$/, ""));
				current = "";
			}
		}
		if (current.trim()) throw new Error(`Unbalanced filter fragment:\n${current}`);
		return fragments.map((fragment) => `query FilterShape { issues(first: 1, ${fragment}) { nodes { id } } }`);
	}
	return [`query Wrapped {\n${body}\n}`];
}

async function validate(document) {
	const response = await fetch(ENDPOINT, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify({ query: document }),
	});
	const payload = await response.json().catch(() => ({ errors: [{ message: "non-JSON response" }] }));
	return (payload.errors ?? []).filter((error) => !IGNORE.some((re) => re.test(error.message)));
}

const files = ["SKILL.md", ...readdirSync(join(SKILL_DIR, "reference")).map((f) => `reference/${f}`)];
let checked = 0;
let failed = 0;

for (const file of files) {
	const text = readFileSync(join(SKILL_DIR, file), "utf8");
	for (const [index, match] of [...text.matchAll(/```graphql\n([\s\S]*?)```/g)].entries()) {
		for (const document of documentsFor(match[1])) {
			const errors = await validate(document);
			checked++;
			if (errors.length > 0) {
				failed++;
				console.error(`FAIL ${file} block ${index}: ${errors.map((e) => e.message).join(" | ")}`);
				console.error(document.split("\n").slice(0, 4).join("\n"));
			}
		}
	}
}

console.log(`${checked} snippets validated, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
