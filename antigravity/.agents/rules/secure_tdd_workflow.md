---
trigger: always_on
---

# Secure Test-Driven Development (Secure TDD) Workflow Rule

You MUST strictly follow this 4-phase cyclical workflow for all feature implementations, refactors, and bug fixes:

1. **Phase A (Plan & Threat Model)**:
   - Ingest `CONTEXT.md` to review established project conventions, approved helpers, and trust zones.
   - Invoke the **Threat Model Assessor Skill** to perform a STRIDE evaluation and generate/update `threat_model.md`.
   - Decompose the implementation into small, sequential stages.

2. **Phase B (Security Test-First - RED)**:
   - Invoke the **Security Test Writer Skill**.
   - Author unit and integration tests asserting functional behavior AND security boundaries (rejecting invalid inputs, unauthenticated requests, or unauthorized role access).
   - Execute the tests and confirm they FAIL for the expected assertion reason (RED).

3. **Phase C (Defensive Implementation - GREEN)**:
   - Invoke the **Defensive Developer Skill**.
   - Author the minimal production code strictly required to make the failing tests pass.
   - Apply input validation allow-lists, parameterized queries, and least-privilege payload returns.
   - Run the tests to confirm they are GREEN.

4. **Phase D (Refactor & Scan)**:
   - Invoke the **Local Refactor & Scanner Skill**.
   - Run fast deterministic checks (secrets, dependencies, local SAST).
   - Conduct a guided AI review to verify architectural boundaries and eliminate logic bypasses.
   - Ensure diffs remain small, surgical, and preserve baseline stability.

5. **Continuous Evolution**:
   - If a new security pattern, helper function, or architectural convention was introduced, invoke the **Skill Evolution Updater Skill** to document the lesson into `CONTEXT.md` or the appropriate `SKILL.md`.
