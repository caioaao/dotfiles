/**
 * The write gate is the only thing keeping a mutation out of the read tool,
 * so its edge cases are pinned here. Run with: npm test (node --test).
 */

import assert from "node:assert/strict";
import { test } from "node:test";
import { hasMutation, operationLabel, stripNoise } from "./operation.ts";

test("reads are not flagged as mutations", () => {
	for (const source of [
		'query Q { issue(id: "ENG-1") { id } }',
		"{ issues(first: 1) { nodes { id } } }",
		'query Q { issue(id: "ENG-1") { description } } # write it with a mutation later',
		'query Q { issue(id: "mutation Foo {") { id } }',
		'query Q { comment(id: "c") { body } } # body may quote """mutation X"""',
	]) {
		assert.equal(hasMutation(source), false, source);
	}
});

test("mutations are flagged whatever the whitespace", () => {
	for (const source of [
		'mutation M($i: IssueCreateInput!) { issueCreate(input: $i) { success } }',
		'mutation { issueArchive(id: "ENG-1") { success } }',
		'mutation,{ issueDelete(id: "ENG-1") { success } }',
		'mutation # comment\n { issueDelete(id: "ENG-1") { success } }',
		'fragment F on Issue { id }\nmutation M { issueCreate(input: {}) { success } }',
	]) {
		assert.equal(hasMutation(source), true, source);
	}
});

test("stripNoise removes comments and string bodies", () => {
	assert.equal(stripNoise('a # mutation\nb').includes("mutation"), false);
	assert.equal(stripNoise('a "mutation" b').includes("mutation"), false);
	assert.equal(stripNoise('a """mutation""" b').includes("mutation"), false);
	assert.equal(stripNoise('a "\\"mutation" b').includes("mutation"), false);
});

test("operationLabel names the operation or its first field", () => {
	assert.equal(operationLabel("query TeamIssues { issues { nodes { id } } }"), "TeamIssues");
	assert.equal(operationLabel("{ viewer { id } }"), "viewer");
	assert.equal(operationLabel('mutation { issueCreate(input: {}) { success } }'), "issueCreate");
});
