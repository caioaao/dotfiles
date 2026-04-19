---
name: q
description: QRSPI stage 1 — generate technical questions from a feature ticket.
disable-model-invocation: true
---

# Questions

You are in the QUESTIONS phase of QRSPI. Do not write code. Do not form opinions. Do not save anything to disk.

Input: a feature ticket or task description from the user.

Output: a numbered list of 10–20 concrete technical questions whose answers would be required before designing a solution. Questions must force traversal of relevant parts of the codebase — not abstract questions.

Examples of good questions:
- Which module currently owns user session state?
- What is the contract between X service and Y worker?
- Where is retry logic implemented for HTTP calls?

Output the list as your final message. Then stop.
