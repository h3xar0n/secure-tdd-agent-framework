# Security Test Writer Skill (Phase B: RED Phase)

## Overview
Translate the security criteria and trust boundaries defined in `threat_model.md` into executable test cases that fail initially (RED) to verify defense boundaries before any functional logic is authored.

## Three Verification Pillars
1. **Behavior-Driven Outcomes**:
   - Assert strictly on API/HTTP outcomes (status codes 400/401/403, error response schemas) and boundary contracts rather than mocking internal private methods.
2. **Strict Test Isolation**:
   - Ensure test setup and teardown cleanly isolate state (e.g., transaction rollbacks, fresh test contexts) so state never bleeds between test runs.
3. **Integration Over Fragile Mocking**:
   - Utilize local test databases or real server contexts rather than fragile fake mocks to verify realistic security behavior.

## Execution Sequence
1. **Consume Threat Model**: Read `threat_model.md` and extract the Security Acceptance Criteria.
2. **Author Test Cases**:
   - **Functional Assertion**: Test validating happy-path expected behavior.
   - **Authentication Boundary**: Assert requests without credentials return `401 Unauthorized`.
   - **Authorization Boundary**: Assert requests with insufficient role return `403 Forbidden`.
   - **Input Validation**: Assert malformed, oversized, or un-whitelisted data returns `400 Bad Request` or validation error.
   - **Exploit Payloads**: Assert classic payloads (SQLi, path traversal `../../`, XSS payloads) are rejected safely.
3. **Execute & Verify RED**:
   - Run the project's test command (e.g., `pytest`, `python3 -m unittest discover -s tests`).
   - **Crucial**: Confirm the tests fail due to the expected missing boundary/logic assertion and NOT due to a Python syntax or import error.
