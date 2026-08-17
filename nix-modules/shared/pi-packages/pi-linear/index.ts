/**
 * pi-linear: raw Linear GraphQL access.
 *
 * Three tools, one job each:
 *   linear_query  - read operations
 *   linear_mutate - write operations
 *   linear_schema - introspection, rendered as SDL
 *
 * Reads and writes are split so a write is always a deliberate call, and so a
 * guard (ctx.ui.confirm in a `tool_call` handler, or an allowlist) has one
 * obvious place to attach.
 *
 * No operation catalog lives in this extension. What to send is documented in
 * skills/linear-graphql, which the agent loads on demand - a new Linear
 * workflow costs a paragraph of markdown, never a code change.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { execute, MAX_RESULT_CHARS, renderPayload, truncate } from "./lib/client.ts";
import { hasMutation, hasSubscription, operationLabel } from "./lib/operation.ts";
import { describeType, searchTypes } from "./lib/schema.ts";

const SKILL_HINT = "Load the linear-graphql skill for query shapes, filters, and mutation inputs.";

const operationParameters = Type.Object({
	query: Type.String({
		description: "GraphQL document to send to https://api.linear.app/graphql.",
	}),
	variables: Type.Optional(
		Type.Object(
			{},
			{
				additionalProperties: true,
				description: "GraphQL variables object. Prefer variables over string interpolation.",
			},
		),
	),
});

/** Models sometimes send `variables` as a JSON string; accept that shape too. */
function prepareArguments(args: unknown): unknown {
	if (!args || typeof args !== "object") return args;
	const input = args as { variables?: unknown };
	if (typeof input.variables !== "string") return args;
	try {
		return { ...input, variables: JSON.parse(input.variables) };
	} catch {
		return args;
	}
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "linear_query",
		label: "Linear Query",
		description:
			"Run a read-only GraphQL query against the Linear API. Use for issues, projects, documents, comments, cycles, labels, users, and workflow states. Rejects mutations - use linear_mutate for writes. " +
			SKILL_HINT,
		promptSnippet: "Read Linear data with a GraphQL query (issues, projects, documents, comments)",
		promptGuidelines: [
			"Load the linear-graphql skill before writing a linear_query or linear_mutate operation.",
			"Always pass an explicit `first:` on Linear connections and select only the fields you need; Linear rejects queries over 10,000 complexity points.",
		],
		parameters: operationParameters,
		prepareArguments,
		async execute(_toolCallId, params, signal) {
			if (hasMutation(params.query)) {
				throw new Error("linear_query is read-only. Send mutations through linear_mutate.");
			}
			if (hasSubscription(params.query)) {
				throw new Error("Subscriptions are not supported over this transport.");
			}
			const result = await execute(params.query, params.variables, signal);
			return {
				content: [{ type: "text", text: renderPayload(result.data, result.errors, result.rateLimitWarning) }],
				details: { operation: operationLabel(params.query), kind: "query" },
			};
		},
	});

	pi.registerTool({
		name: "linear_mutate",
		label: "Linear Mutate",
		description:
			"Run a GraphQL mutation against the Linear API: create/update/archive issues, comments, projects, documents, attachments. This writes to the user's Linear workspace. Requires a `mutation` operation. " +
			SKILL_HINT,
		promptSnippet: "Write to Linear with a GraphQL mutation (create/update/archive issues, comments, projects)",
		promptGuidelines: [
			"linear_mutate changes the user's Linear workspace - state what will change before calling it, and never batch unrelated writes into one document.",
			"Resolve ids (teamId, stateId, labelIds, assigneeId) with linear_query before calling linear_mutate; Linear mutations take ids, not names.",
		],
		parameters: operationParameters,
		prepareArguments,
		async execute(_toolCallId, params, signal) {
			if (!hasMutation(params.query)) {
				throw new Error("linear_mutate expects a `mutation` operation. Use linear_query for reads.");
			}
			const result = await execute(params.query, params.variables, signal);
			return {
				content: [{ type: "text", text: renderPayload(result.data, result.errors, result.rateLimitWarning) }],
				details: { operation: operationLabel(params.query), kind: "mutation" },
			};
		},
	});

	pi.registerTool({
		name: "linear_schema",
		label: "Linear Schema",
		description:
			"Explore the Linear GraphQL schema as SDL: fields, argument signatures, input object fields, and enum values. " +
			"Pass `type` to describe a type (Query, Mutation, Issue, IssueFilter, IssueCreateInput). " +
			"Pass `search` alone to find type names, or with `type` to filter that type's members. " +
			"With no arguments it lists the root Query fields.",
		promptSnippet: "Explore the Linear GraphQL schema (types, fields, arguments, input objects)",
		promptGuidelines: [
			"When a Linear operation fails validation or you are unsure a field exists, check it with linear_schema instead of guessing.",
		],
		parameters: Type.Object({
			type: Type.Optional(
				Type.String({
					description: "Exact, case-sensitive type name, e.g. Query, Mutation, Issue, IssueFilter, IssueCreateInput.",
				}),
			),
			search: Type.Optional(
				Type.String({
					description: "Substring filter. Alone: search type names. With `type`: filter that type's fields/inputs/enum values.",
				}),
			),
		}),
		async execute(_toolCallId, params, signal) {
			const text = params.type
				? await describeType(params.type, params.search, signal)
				: params.search
					? await searchTypes(params.search, signal)
					: await describeType("Query", undefined, signal);

			return {
				content: [{ type: "text", text: truncate(text, MAX_RESULT_CHARS) }],
				details: { type: params.type ?? (params.search ? "search" : "Query"), search: params.search ?? null },
			};
		},
	});
}
