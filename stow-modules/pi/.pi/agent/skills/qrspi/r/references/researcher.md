# Researcher subagent

The `r` skill delegates each question to a researcher subagent defined in `~/.pi/agent/agents/researcher.md`. The researcher:

- Runs on a cheaper, faster model than the orchestrator
- Uses whatever tools the session has available — codebase reading, web search, docs fetchers, project-specific context tools
- Returns a condensed answer with file paths, line numbers, and short code references
- Does not propose changes — only reports facts

The orchestrating session stays lean; the researcher burns context on investigation and returns only the summary.
