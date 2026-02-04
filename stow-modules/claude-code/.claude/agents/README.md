# Claude Code Sub-Agents

Sub-agents are specialized AI assistants that can be invoked during Claude Code sessions to handle specific tasks.

## Available Agents

### code-reviewer
**Purpose**: Review code for quality, security, and best practices
**Usage**: `/agent code-reviewer <file-or-pattern>`
**Tools**: Read, Grep, Glob

Provides structured feedback categorized as Critical/Warning/Suggestion with specific line numbers and actionable fixes.

## Creating Custom Sub-Agents

Sub-agents are defined as markdown files with YAML front matter.

### File Structure

```markdown
---
name: agent-name
description: Brief description of what this agent does
tools: [Read, Write, Bash, Grep, Glob]
model: sonnet  # or opus, haiku
---

# Agent Name

Your agent's prompt goes here. This defines:
- The agent's role and expertise
- What tasks it should perform
- How it should structure output
- Any specific guidelines or constraints

## Section 1
...

## Section 2
...
```

### Front Matter Fields

- **name**: Identifier used to invoke the agent (lowercase, hyphens)
- **description**: Short summary shown in agent list
- **tools**: Array of tools the agent can use (Read, Write, Edit, Bash, Grep, Glob, Task, etc.)
- **model**: Claude model to use (sonnet for most tasks, opus for complex reasoning, haiku for simple/fast tasks)

### Best Practices

1. **Clear role definition**: Start with "You are a [role]..." to establish context
2. **Specific tasks**: List concrete tasks the agent should perform
3. **Output format**: Define expected output structure
4. **Tool usage**: Only grant necessary tools (security principle)
5. **Examples**: Include examples of good output if complex

### Example: Documentation Writer

```markdown
---
name: doc-writer
description: Generate comprehensive documentation from code
tools: [Read, Grep, Glob, Write]
model: sonnet
---

# Documentation Writer

You are a technical documentation specialist. Generate clear, accurate documentation from code.

## Tasks

1. Read the specified code files
2. Extract key functions, classes, and APIs
3. Write documentation in markdown format
4. Include usage examples where appropriate

## Output Format

Use standard markdown with:
- Brief overview paragraph
- API reference (functions/classes)
- Usage examples
- Any important notes or caveats

Save output to `docs/` directory with appropriate filename.
```

## Testing Sub-Agents

1. Save agent to `~/.claude/agents/your-agent.md`
2. Start a new Claude Code session
3. List agents: `/agents`
4. Invoke agent: `/agent your-agent <args>`
5. Review output and iterate on prompt

## Tips

- **Start simple**: Begin with a focused agent, expand later
- **Use existing agents as templates**: Copy structure from code-reviewer
- **Grant minimal tools**: Only provide tools the agent needs
- **Test thoroughly**: Try edge cases and unclear inputs
- **Iterate on prompts**: Refine based on actual output quality
