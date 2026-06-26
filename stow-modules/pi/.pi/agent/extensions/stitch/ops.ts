/**
 * Stitch operation catalog.
 *
 * Maps stable `op` names (the public contract) to MCP tool names (hidden detail).
 * No arg schemas here - they come from the SDK's toolMap at runtime.
 */

export type Risk = "read" | "mutate";

export interface OpDef {
  mcpName: string;
  risk: Risk;
  summary: string;
}

/** Curated allowlist: only these Stitch MCP tools are exposed. */
export const OPS: ReadonlyMap<string, OpDef> = new Map([
  ["list_projects", {
    mcpName: "list_projects",
    risk: "read",
    summary: "List all Stitch projects accessible to you.",
  }],
  ["create_project", {
    mcpName: "create_project",
    risk: "mutate",
    summary: "Create a new Stitch project. Accepts an optional title.",
  }],
  ["get_project", {
    mcpName: "get_project",
    risk: "read",
    summary: "Get details of a specific project by resource name (projects/{id}).",
  }],
  ["list_screens", {
    mcpName: "list_screens",
    risk: "read",
    summary: "List all screens in a project. Needs projectId.",
  }],
  ["get_screen", {
    mcpName: "get_screen",
    risk: "read",
    summary: "Get details of a specific screen. Needs projectId and screenId.",
  }],
  ["generate_screen", {
    mcpName: "generate_screen_from_text",
    risk: "mutate",
    summary: "Generate a new screen from a text prompt. Needs projectId and prompt.",
  }],
  ["edit_screens", {
    mcpName: "edit_screens",
    risk: "mutate",
    summary: "Edit existing screens using a text prompt. Needs projectId, selectedScreenIds, and prompt.",
  }],
  ["generate_variants", {
    mcpName: "generate_variants",
    risk: "mutate",
    summary: "Generate design variants of existing screens. Needs projectId, selectedScreenIds, prompt, and variantOptions.",
  }],
  ["list_design_systems", {
    mcpName: "list_design_systems",
    risk: "read",
    summary: "List design systems in a project.",
  }],
  ["create_design_system", {
    mcpName: "create_design_system",
    risk: "mutate",
    summary: "Create a new design system from an existing screen.",
  }],
  ["update_design_system", {
    mcpName: "update_design_system",
    risk: "mutate",
    summary: "Update an existing design system.",
  }],
  ["apply_design_system", {
    mcpName: "apply_design_system",
    risk: "mutate",
    summary: "Apply a design system to screens in a project.",
  }],
]);

/** Render the catalog index as markdown text for op='help'. */
export function opIndex(): string {
  const lines: string[] = ["# Stitch Operations", ""];
  for (const [op, def] of OPS) {
    const icon = def.risk === "read" ? "📖" : "✏️";
    lines.push(`- **\`${op}\`** ${icon} — ${def.summary}`);
  }
  lines.push("");
  lines.push("Use `stitch(op='help', args={name:'<op>'})` for a specific operation's parameters.");
  lines.push("");
  lines.push("## Setup");
  lines.push("Set `STITCH_API_KEY` env var with your Google Cloud API key.");
  lines.push("Enable the Stitch API: https://stitch.withgoogle.com");
  return lines.join("\n");
}

/** Look up an op and return a user-friendly error if not found. */
export function resolveOp(op: string): { def: OpDef; opName: string } | { error: string } {
  const def = OPS.get(op);
  if (!def) {
    const available = [...OPS.keys()].join(", ");
    return { error: `Unknown operation "${op}". Available: ${available}. Call stitch(op='help').` };
  }
  return { def, opName: op };
}
