---
name: security-test-writer
description: Translates security criteria and threat models into failing (RED) unit and integration tests.
---

# Security Test Writer Skill (Phase B: RED Phase)

## Overview
Translate the security criteria and trust boundaries defined in `threat_model.md` into executable test cases that fail initially (RED) to verify defense boundaries before any functional logic is authored.

## Three Verification Pillars
1. **Behavior-Driven Outcomes**: Assert strictly on API/HTTP outcomes (status codes 400/401/403, error response schemas) and boundary contracts rather than mocking internal private methods.
2. **Strict Test Isolation**: Ensure test setup and teardown cleanly isolate state (e.g., transaction rollbacks, fresh test contexts) so state never bleeds between test runs.
3. **Integration Over Fragile Mocking**: Utilize local test databases or real server contexts rather than fragile fake mocks to verify realistic security behavior.

## Execution Sequence
1. Read `threat_model.md` and extract the Security Acceptance Criteria.
2. Write test cases covering functional requirements, authentication/authorization boundaries, input validation, and exploit payloads.
3. Run the project test suite and verify tests **FAIL** for the expected assertion reason (and not syntax/import errors).
