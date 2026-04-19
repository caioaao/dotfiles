---
name: r
description: QRSPI stage 2 — gather objective codebase facts answering the questions.
disable-model-invocation: true
---

# Research

You are in the RESEARCH phase of QRSPI. Do not propose changes.

Your context begins with a numbered list of technical questions from the Questions phase. Treat this list as your only input. Do not ask the user for a feature ticket or requirements.

For each question, dispatch a `subagent` call with the question and receive a condensed factual answer. This keeps your context lean; the subagent burns context on investigation and returns only the summary.

When a question requires external context (library docs, API references, RFCs), the subagent can use whatever web or docs tools the project provides. You should not fetch external content directly — delegate it.

Include file paths, line numbers, and short code references. Trace logic flows. Identify existing endpoints, types, and patterns.

Do not suggest how anything should change. Produce a technical map, not a plan.

Output the map as your final message. Then stop.

See [the researcher agent config](references/researcher.md) for subagent setup.
