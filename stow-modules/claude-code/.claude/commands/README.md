# Claude Code Custom Commands

This directory is for defining custom slash commands that can be invoked in Claude Code sessions.

## What Are Custom Commands?

Custom commands (also called "skills" or "slash commands") are reusable prompts that can be invoked with a `/` prefix in Claude Code sessions.

**Example:** `/review-pr` might expand to a detailed prompt for reviewing a pull request.

## Directory Purpose

While Claude Code has built-in commands like `/commit`, `/help`, `/clear`, you can extend functionality by adding your own commands here.

## Creating Custom Commands

Custom commands are typically defined as markdown files similar to agents and skills. Check Claude Code documentation for the specific format:

```bash
claude --help
```

## Common Use Cases

- **Domain-specific workflows**: `/deploy`, `/migration`, `/rollback`
- **Code generation**: `/component`, `/api-endpoint`, `/test`
- **Analysis tasks**: `/perf-audit`, `/security-scan`, `/dep-check`
- **Project-specific**: `/nix-rebuild`, `/stow-sync`, `/bootstrap-check`

## Example Structure

```markdown
---
name: my-command
description: Brief description of what this command does
---

# Command Prompt

When this command is invoked, execute the following steps:

1. Step one
2. Step two
3. Step three

## Expected Output

Describe the format of the output...
```

## Notes

- Commands are invoked with `/` prefix: `/my-command`
- They can accept arguments: `/my-command arg1 arg2`
- They expand to full prompts before being sent to Claude
- Keep commands focused on a single, well-defined task

---

*This is a placeholder directory. Add custom commands as needed for your workflows.*
