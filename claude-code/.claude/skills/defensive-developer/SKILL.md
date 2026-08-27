---
name: defensive-developer
description: Implements minimal secure code to satisfy failing tests and pass the GREEN phase.
---

# Defensive Developer Skill (Phase C: GREEN Phase)

## Overview
Implement the minimum production code required to satisfy the failing tests from Phase B while strictly adhering to defensive coding principles and project conventions in `CONTEXT.md`.

## Three Defensive Pillars
1. **Simple Input Validation**: Enforce type, size, and strict allow-list validation on all incoming data.
2. **Explicit Authorization**: Validate caller identity and match required permissions before invoking business logic.
3. **Least Privilege & Safe Operations**: Parameterize all queries, use canonical path checks, and return minimal data payloads.

## Execution Sequence
1. Review failing tests and `CONTEXT.md` rules.
2. Implement clean, minimal defensive code addressing the failing assertions.
3. Run tests and confirm all pass (**GREEN**).
