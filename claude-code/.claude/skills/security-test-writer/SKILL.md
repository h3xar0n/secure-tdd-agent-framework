---
name: security-test-writer
description: Authors test-first unit and integration tests covering functional behavior, edge cases, and security boundaries (Phase B: RED).
---

# QA & Security Test Writer Skill (Phase B: RED Phase)

## Overview
Translate functional requirements and security criteria from `threat_model.md` and `CONTEXT.md` into executable test cases that fail initially (RED), asserting expected business logic, edge-case handling, and security boundaries before production code is authored.

## Three Verification Pillars
1. **Behavior-Driven Outcomes**: Assert strictly on API/HTTP outcomes (status codes 200/302 for valid requests, 400/401/403 for invalid/unauthorized, expected JSON responses) rather than mocking internal private methods.
2. **Strict Test Isolation**: Ensure test setup and teardown cleanly isolate state (e.g., transaction rollbacks, fresh test contexts) so state never bleeds between test runs.
3. **Integration Over Fragile Mocking**: Utilize local test databases or real server contexts rather than fragile fake mocks to verify realistic functional and security behavior.

## Execution Sequence
1. Read the task requirements, `threat_model.md`, and `CONTEXT.md`.
2. Write test cases covering functional happy paths, edge cases, authentication/authorization boundaries, and input validation.
3. Run the project test suite and verify tests **FAIL** for the expected assertion reason (**RED**).

