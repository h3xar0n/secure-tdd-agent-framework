# Defensive Developer Skill (Phase C: GREEN Phase)

## Overview
Implement the minimum production code required to satisfy the failing tests from Phase B while strictly adhering to defensive coding principles and project conventions in `CONTEXT.md`.

## Three Defensive Pillars
1. **Simple Input Validation**:
   - Enforce type, size, and strict allow-list validation on all incoming data.
   - Prefer structured parsing libraries (`pydantic`, `urllib.parse`) over complex regex which may be vulnerable to ReDoS.
2. **Explicit Authorization**:
   - Validate caller identity and match required permissions before invoking business logic.
3. **Least Privilege & Safe Operations**:
   - Parameterize all SQL/database queries.
   - Use canonical path checks (`os.path.realpath`) with prefix boundary validation.
   - Return only the minimal data payload required by the client.
   - Mask credentials, PII, and omit internal stack traces in error messages.

## Execution Sequence
1. **Inspect Failing Tests & Rules**: Review the failing tests from Phase B and the rules in `CONTEXT.md`.
2. **Author Minimal Defensive Code**:
   - Implement only the logic necessary to satisfy the assertions.
   - Use approved helpers (e.g. `utils.security.resolve_safe_path`, parameterized SQL statements).
3. **Confirm GREEN State**:
   - Run the test suite.
   - Verify that all tests pass cleanly without errors.
