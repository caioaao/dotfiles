---
name: s
description: QRSPI stage 4 — signatures, types, and vertical slices with checkpoints.
disable-model-invocation: true
---

# Structure

You are in the STRUCTURE phase of QRSPI.

Your context begins with the Design output — the agreed end-state and rationale.

Produce a C-header-file-style outline: function signatures, new types, module boundaries. No implementation bodies.

Then decompose the work into VERTICAL slices — each slice must produce a testable end-to-end path. Example ordering: mock API → frontend wired to mock → real DB-backed API.

For each slice, define its checkpoint: what can be run and verified?

Output the structure as your final message. Then stop.
