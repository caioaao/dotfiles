/**
 * Schema exploration over GraphQL introspection.
 *
 * Raw introspection JSON is enormous and unreadable; this module hides that
 * and hands back SDL-shaped text. That is the whole point of a separate tool:
 * the agent asks "what does IssueCreateInput accept?" and gets ~30 lines
 * instead of a megabyte of nested `ofType` wrappers.
 */

import { executeStrict } from "./client.ts";

const TYPE_REF = `
fragment TypeRef on __Type {
  kind name
  ofType { kind name ofType { kind name ofType { kind name ofType { kind name } } } }
}`;

const DESCRIBE_TYPE = `
query DescribeType($name: String!) {
  __type(name: $name) {
    kind
    name
    description
    interfaces { name }
    possibleTypes { name }
    enumValues(includeDeprecated: true) { name description isDeprecated }
    inputFields { name description defaultValue type { ...TypeRef } }
    fields(includeDeprecated: true) {
      name
      description
      isDeprecated
      deprecationReason
      type { ...TypeRef }
      args { name description defaultValue type { ...TypeRef } }
    }
  }
}
${TYPE_REF}`;

const LIST_TYPES = `
query ListTypes {
  __schema { types { kind name description } }
}`;

const MAX_LINES = 400;
const MAX_DESCRIPTION = 160;

interface TypeRef {
	kind: string;
	name: string | null;
	ofType?: TypeRef | null;
}

interface InputValue {
	name: string;
	description: string | null;
	defaultValue: string | null;
	type: TypeRef;
}

interface Field extends InputValue {
	isDeprecated?: boolean;
	deprecationReason?: string | null;
	args?: InputValue[];
}

interface FullType {
	kind: string;
	name: string;
	description: string | null;
	interfaces: { name: string }[] | null;
	possibleTypes: { name: string }[] | null;
	enumValues: { name: string; description: string | null; isDeprecated: boolean }[] | null;
	inputFields: InputValue[] | null;
	fields: Field[] | null;
}

/** `Issue!`, `[String!]!`, `IssueConnection` - the shape people actually read. */
function renderRef(ref: TypeRef | null | undefined): string {
	if (!ref) return "?";
	if (ref.kind === "NON_NULL") return `${renderRef(ref.ofType)}!`;
	if (ref.kind === "LIST") return `[${renderRef(ref.ofType)}]`;
	return ref.name ?? "?";
}

function comment(text: string | null | undefined): string {
	if (!text) return "";
	const oneLine = text.replace(/\s+/g, " ").trim();
	const clipped = oneLine.length > MAX_DESCRIPTION ? `${oneLine.slice(0, MAX_DESCRIPTION)}...` : oneLine;
	return `  # ${clipped}`;
}

function renderArgs(args: InputValue[] | undefined): string {
	if (!args || args.length === 0) return "";
	const rendered = args.map((arg) => {
		const def = arg.defaultValue ? ` = ${arg.defaultValue}` : "";
		return `${arg.name}: ${renderRef(arg.type)}${def}`;
	});
	return `(${rendered.join(", ")})`;
}

function matches(name: string, search: string | undefined): boolean {
	return !search || name.toLowerCase().includes(search.toLowerCase());
}

function clip(lines: string[], hint: string): string {
	if (lines.length <= MAX_LINES) return lines.join("\n");
	return [...lines.slice(0, MAX_LINES), `... ${lines.length - MAX_LINES} more. ${hint}`].join("\n");
}

export async function describeType(
	name: string,
	search: string | undefined,
	signal: AbortSignal | undefined,
): Promise<string> {
	const data = (await executeStrict(DESCRIBE_TYPE, { name }, signal)) as { __type: FullType | null };
	const type = data.__type;
	if (!type) {
		throw new Error(
			`No GraphQL type named "${name}". Type names are case sensitive (Issue, IssueFilter, IssueCreateInput, Query, Mutation). Use the \`search\` parameter alone to look one up.`,
		);
	}

	const lines: string[] = [`${type.kind.toLowerCase()} ${type.name}`];
	if (type.description) lines.push(comment(type.description).trimStart());
	if (type.interfaces?.length) lines.push(`implements ${type.interfaces.map((i) => i.name).join(", ")}`);
	if (type.possibleTypes?.length) {
		lines.push(`possible types: ${type.possibleTypes.map((t) => t.name).join(", ")}`);
	}

	const members: string[] = [];
	for (const field of type.fields ?? []) {
		if (!matches(field.name, search)) continue;
		const deprecated = field.isDeprecated ? " @deprecated" : "";
		members.push(
			`  ${field.name}${renderArgs(field.args)}: ${renderRef(field.type)}${deprecated}${comment(field.description)}`,
		);
	}
	for (const input of type.inputFields ?? []) {
		if (!matches(input.name, search)) continue;
		const def = input.defaultValue ? ` = ${input.defaultValue}` : "";
		members.push(`  ${input.name}: ${renderRef(input.type)}${def}${comment(input.description)}`);
	}
	for (const value of type.enumValues ?? []) {
		if (!matches(value.name, search)) continue;
		members.push(`  ${value.name}${value.isDeprecated ? " @deprecated" : ""}${comment(value.description)}`);
	}

	if (members.length === 0) {
		lines.push(search ? `  (no members matching "${search}")` : "  (no members)");
	} else {
		lines.push("{", clip(members, `Filter with the \`search\` parameter.`), "}");
	}

	return lines.join("\n");
}

export async function searchTypes(
	search: string,
	signal: AbortSignal | undefined,
): Promise<string> {
	const data = (await executeStrict(LIST_TYPES, undefined, signal)) as {
		__schema: { types: { kind: string; name: string; description: string | null }[] };
	};

	const hits = data.__schema.types
		.filter((type) => !type.name.startsWith("__") && matches(type.name, search))
		.sort((a, b) => a.name.length - b.name.length || a.name.localeCompare(b.name))
		.map((type) => `${type.kind.toLowerCase().padEnd(12)} ${type.name}${comment(type.description)}`);

	if (hits.length === 0) {
		return `No type name contains "${search}".`;
	}
	return clip(hits, "Use a more specific search term.");
}
