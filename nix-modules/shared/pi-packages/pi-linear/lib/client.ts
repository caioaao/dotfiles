/**
 * Transport for the Linear GraphQL API.
 *
 * Single concern: send an operation, come back with either a result or an
 * error the agent can act on. Knows nothing about which operations exist -
 * that knowledge lives in the linear-graphql skill, not in code, so adding a
 * use case never means changing this file.
 *
 * Dependency-free: runs inside pi's process on node >= 22 (global fetch).
 */

const ENDPOINT = "https://api.linear.app/graphql";

/** Hard cap on what a single tool result may push into the context window. */
export const MAX_RESULT_CHARS = 60_000;

export interface GraphQLResponse {
	data?: unknown;
	errors?: GraphQLError[];
}

export interface GraphQLError {
	message: string;
	path?: (string | number)[];
	extensions?: Record<string, unknown>;
}

/**
 * Personal API keys go in `Authorization` verbatim; OAuth access tokens use
 * the `Bearer` scheme (https://linear.app/developers/graphql).
 */
function authorization(): string {
	const key = process.env.LINEAR_API_KEY?.trim();
	if (!key) {
		throw new Error(
			"LINEAR_API_KEY is not set. Export a Linear personal API key (Settings > Security & access) before using the Linear tools.",
		);
	}
	return key.startsWith("lin_api_") ? key : `Bearer ${key}`;
}

export interface ExecuteResult {
	data: unknown;
	errors: GraphQLError[];
	/** Non-null only when the request is close to a rate limit. */
	rateLimitWarning: string | null;
}

/**
 * POST an operation. Throws when nothing usable came back (transport failure,
 * auth failure, non-JSON body, or GraphQL errors with no data); returns
 * partial data plus errors when Linear answered with both.
 */
export async function execute(
	query: string,
	variables: Record<string, unknown> | undefined,
	signal: AbortSignal | undefined,
): Promise<ExecuteResult> {
	// Resolved outside the try so a setup error keeps its own message instead of
	// being reported as a transport failure.
	const auth = authorization();
	const body = JSON.stringify({ query, variables: variables ?? {} });

	let response: Response;
	try {
		response = await fetch(ENDPOINT, {
			method: "POST",
			headers: { "Content-Type": "application/json", Authorization: auth },
			body,
			signal,
		});
	} catch (error) {
		throw new Error(`Linear request failed: ${(error as Error).message}`);
	}

	const responseBody = await response.text();
	let payload: GraphQLResponse;
	try {
		payload = JSON.parse(responseBody) as GraphQLResponse;
	} catch {
		throw new Error(
			`Linear returned a non-JSON body (HTTP ${response.status}): ${truncate(responseBody, 1000)}`,
		);
	}

	const errors = payload.errors ?? [];
	const hasData = payload.data !== undefined && payload.data !== null;

	if (errors.length > 0 && !hasData) {
		throw new Error(`Linear GraphQL error (HTTP ${response.status}):\n${formatErrors(errors, response)}`);
	}
	if (!response.ok && !hasData) {
		throw new Error(`Linear HTTP ${response.status}: ${truncate(responseBody, 1000)}`);
	}

	return {
		data: payload.data,
		errors,
		rateLimitWarning: rateLimitWarning(response),
	};
}

/** Convenience wrapper for internal queries that must not partially fail. */
export async function executeStrict(
	query: string,
	variables: Record<string, unknown> | undefined,
	signal: AbortSignal | undefined,
): Promise<unknown> {
	const result = await execute(query, variables, signal);
	if (result.errors.length > 0) {
		throw new Error(`Linear GraphQL error:\n${result.errors.map((e) => e.message).join("\n")}`);
	}
	return result.data;
}

/** One line per error, keeping `code` and `path` - `path` is what tells the
 * agent which field of a large selection set failed. */
function formatErrorLines(errors: GraphQLError[]): string[] {
	return errors.map((error) => {
		const code = error.extensions?.code;
		const path = error.path?.join(".");
		const suffix = [code ? `code=${String(code)}` : null, path ? `path=${path}` : null]
			.filter(Boolean)
			.join(" ");
		return suffix ? `- ${error.message} (${suffix})` : `- ${error.message}`;
	});
}

function formatErrors(errors: GraphQLError[], response: Response): string {
	const lines = formatErrorLines(errors);

	if (errors.some((e) => e.extensions?.code === "RATELIMITED")) {
		lines.push(rateLimitDetail(response));
	}
	return lines.join("\n");
}

function rateLimitDetail(response: Response): string {
	const parts: string[] = [];
	for (const header of [
		"x-ratelimit-requests-remaining",
		"x-ratelimit-requests-reset",
		"x-ratelimit-complexity-remaining",
		"x-complexity",
	]) {
		const value = response.headers.get(header);
		if (value) parts.push(`${header}=${value}`);
	}
	return parts.length > 0 ? `Rate limit state: ${parts.join(" ")}` : "Rate limited.";
}

/** Warn only when a budget drops below 10% - noise otherwise. */
function rateLimitWarning(response: Response): string | null {
	const checks: [string, string, string][] = [
		["requests", "x-ratelimit-requests-remaining", "x-ratelimit-requests-limit"],
		["complexity", "x-ratelimit-complexity-remaining", "x-ratelimit-complexity-limit"],
	];
	for (const [label, remainingHeader, limitHeader] of checks) {
		const remainingHeaderValue = response.headers.get(remainingHeader);
		const limitHeaderValue = response.headers.get(limitHeader);
		if (remainingHeaderValue === null || limitHeaderValue === null) continue;
		const remaining = Number(remainingHeaderValue);
		const limit = Number(limitHeaderValue);
		if (Number.isFinite(remaining) && Number.isFinite(limit) && limit > 0 && remaining / limit < 0.1) {
			return `Linear ${label} budget low: ${remaining}/${limit} left (resets ${response.headers.get(`x-ratelimit-${label}-reset`) ?? "unknown"}).`;
		}
	}
	return null;
}

export function truncate(text: string, max: number): string {
	return text.length <= max ? text : `${text.slice(0, max)}\n... [truncated ${text.length - max} chars]`;
}

/**
 * Render a tool result, capping size. Oversized results are a query design
 * problem, so the message says how to fix the query rather than silently
 * dropping data.
 */
export function renderPayload(data: unknown, errors: GraphQLError[], warning: string | null): string {
	const json = JSON.stringify(data, null, 2) ?? "null";
	const sections: string[] = [];

	if (errors.length > 0) {
		sections.push(`Partial result. Linear reported errors:\n${formatErrorLines(errors).join("\n")}`);
	}
	if (json.length > MAX_RESULT_CHARS) {
		sections.push(
			`Result truncated at ${MAX_RESULT_CHARS} chars (was ${json.length}). Narrow the selection set, lower \`first:\`, or paginate with \`after:\`.`,
		);
	}
	sections.push(truncate(json, MAX_RESULT_CHARS));
	if (warning) sections.push(warning);

	return sections.join("\n\n");
}
