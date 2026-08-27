---
name: defensive-developer
description: Implements clean, maintainable production code to deliver features and satisfy functional and security test assertions (Phase C: GREEN).
---

# Feature Implementation & Defensive Developer Skill (Phase C: GREEN Phase)

## Overview
Implement clean, modular production code that delivers the requested feature or bug fix and satisfies all functional, edge-case, and security assertions from Phase B while adhering to defensive design principles and project conventions in `CONTEXT.md`.

## Three Defensive Pillars
1. **Simple Input Validation**: Enforce type, size, and strict allow-list validation on all incoming data (`pydantic`).
2. **Explicit Authorization**: Validate caller identity and match required permissions before invoking business logic.
3. **Least Privilege & Safe Operations**: Parameterize all queries, use canonical path checks, and return minimal data payloads.

## Execution Sequence
1. Review functional requirements, failing tests, and `CONTEXT.md` conventions.
2. Implement clean production code addressing business logic and defensive assertions.
3. Run tests and confirm all pass (**GREEN**).

