# Global Claude Code Configuration

This file provides baseline instructions for Claude Code sessions across all projects.

## Personal Coding Preferences

### Code Style
- **Functional patterns preferred**: Favor pure functions, immutability, and composition over imperative code
- **Descriptive naming**: Use clear, self-documenting names over comments
- **Explicit over implicit**: Make dependencies and side effects visible
- **Avoid premature abstraction**: Don't create helpers/utilities until you have 3+ use cases

### Commit Standards
- **Concise descriptions**: Focus on "why" rather than "what"

## Project Structure Assumptions

When working in a new project, assume:
- There may be a project-specific `CLAUDE.md` that overrides these globals
- Local `.gitignore` should exclude generated files and secrets

## Security Considerations

- **Never commit secrets**: Check for API keys, tokens, passwords before commits
- **Validate inputs**: Always sanitize user input at system boundaries
- **No hardcoded credentials**: Use environment variables or secure storage

## Response Style

- **Concise output**: CLI-focused, brief responses
- **No emojis**: Unless explicitly requested
- **Direct communication**: Use text output, not bash echo or comments
- **Accurate over agreeable**: Prioritize technical correctness

---

*Note: Project-specific CLAUDE.md files in repository roots take precedence over this global configuration.*
