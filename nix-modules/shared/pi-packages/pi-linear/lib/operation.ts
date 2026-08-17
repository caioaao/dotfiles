/**
 * Minimal lexical inspection of a GraphQL document.
 *
 * Only exists to keep reads and writes in separate tools: the query tool must
 * refuse mutations, the mutate tool must refuse everything else. Deliberately
 * not a parser - it strips comments and string literals, then looks at
 * operation keywords.
 */

/** Remove comments and string literals so keyword matching cannot be fooled. */
export function stripNoise(source: string): string {
	let out = "";
	let i = 0;
	while (i < source.length) {
		const rest = source.slice(i);
		if (rest.startsWith('"""')) {
			const end = source.indexOf('"""', i + 3);
			i = end === -1 ? source.length : end + 3;
			continue;
		}
		if (source[i] === '"') {
			i++;
			while (i < source.length && source[i] !== '"') {
				i += source[i] === "\\" ? 2 : 1;
			}
			i++;
			continue;
		}
		if (source[i] === "#") {
			const end = source.indexOf("\n", i);
			i = end === -1 ? source.length : end;
			continue;
		}
		out += source[i];
		i++;
	}
	return out;
}

// Matched against noise-stripped source, so the keyword can only come from the
// document itself. Deliberately not anchored to what follows it: GraphQL allows
// commas and comments between tokens, and a looser match fails closed (a
// rejected read) instead of open (an unapproved write).
const MUTATION_KEYWORD = /\bmutation\b/;
const SUBSCRIPTION_KEYWORD = /\bsubscription\b/;

export function hasMutation(source: string): boolean {
	return MUTATION_KEYWORD.test(stripNoise(source));
}

export function hasSubscription(source: string): boolean {
	return SUBSCRIPTION_KEYWORD.test(stripNoise(source));
}

/** Operation name for logs and rendering; falls back to the first root field. */
export function operationLabel(source: string): string {
	const clean = stripNoise(source);
	const named = clean.match(/\b(?:query|mutation)\s+(\w+)/);
	if (named) return named[1];
	const field = clean.match(/\{\s*(\w+)/);
	return field ? field[1] : "operation";
}
