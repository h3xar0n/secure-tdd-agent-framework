# Agent Instructions: TDD with Integrated Security (Claude Code)

This repository enforces **Test-Driven Development with Integrated Security (Secure TDD)**. You MUST adhere strictly to the 4-phase inner-loop workflow on all feature development, bug fixes, and refactoring tasks:

## The Secure TDD Workflow (Plan -> Red -> Green -> Refactor -> Evolve)

1. **Phase A (Plan, Scope & Threat Model)**:
   - Ingest `CONTEXT.md` to identify existing trust zones, architectural boundaries, and approved helpers.
   - Decompose feature requirements, user stories, and acceptance criteria.
   - Run a STRIDE threat model on the planned change and update `threat_model.md` at the repository root with Functional & Security Acceptance Criteria.

2. **Phase B (Functional & Security Test-First - RED)**:
   - Author unit/integration tests that assert functional correctness (happy paths, business logic), edge cases, and security boundary enforcement (e.g. rejecting unauthenticated, unauthorized, or malformed inputs).
   - Execute the test suite and confirm that tests **FAIL** for the expected assertion reason (RED).

3. **Phase C (Feature Implementation & Defensive Code - GREEN)**:
   - Write clean, modular production code strictly necessary to satisfy functional requirements and passing tests.
   - Adhere to defensive standards: strict input allow-lists (`pydantic`), parameterized queries, canonical path checking, and least-privilege responses.
   - Re-run tests to confirm **GREEN**.

4. **Phase D (Refactor, Quality & Local Scan)**:
   - Clean up code, eliminate duplication, and verify 100% passing test regressions across the suite.
   - Perform local deterministic scans on changed files (secrets, dependencies, Semgrep).
   - Review code for logic bypasses and keep diffs minimal and surgical.

5. **Continuous Evolution (Learn & Update)**:
   - When a bug, convention, or helper is introduced, extract the systemic rule and append it to `CONTEXT.md` under `## 4. Continuous Evolution: Auto-Evolved Conventions`.

6. **Multi-Finding Remediation Protocol**:
   - When fixing multiple findings from scans or review, process them sequentially one finding at a time:
     1. Author one boundary test for the finding (RED).
     2. Implement the minimal defensive fix (GREEN).
     3. Verify the local test passes before moving to the next finding.
   - Avoid batching multiple unrelated edits in a single unverified change. Verify the full suite once all findings have passed their discrete cycle.

---

## Approved Helpers & Safe Patterns
- **Database**: Parameterized SQL / ORM only (never string formatting or f-strings).
- **Paths**: Use `utils.security.resolve_safe_path(base_dir, user_filename)`.
- **Redirects**: Use `utils.security.safe_redirect(url, allowed_hosts)`.
- **Commands**: List-format `subprocess.run([...], shell=False)` only.

