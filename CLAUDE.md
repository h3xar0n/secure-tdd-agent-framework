# Secure TDD Agent Instructions (Claude Code)

This repository enforces **Secure Test-Driven Development (Secure TDD)**. You MUST adhere strictly to the 4-phase inner-loop workflow on all tasks:

## The Secure TDD Workflow (Plan -> Red -> Green -> Refactor -> Evolve)

1. **Phase A (Plan & Threat Model)**:
   - Ingest `CONTEXT.md` to identify existing trust zones, architectural boundaries, and approved helpers.
   - Run a STRIDE threat model on the planned feature or bug fix.
   - Update `threat_model.md` at the repository root with Security Acceptance Criteria.

2. **Phase B (Security Test-First - RED)**:
   - Author unit/integration tests that assert functional correctness and security boundary enforcement (e.g. rejecting unauthenticated, unauthorized, or malformed inputs).
   - Execute the test suite and confirm that tests **FAIL** for the expected assertion reason.

3. **Phase C (Defensive Implementation - GREEN)**:
   - Write the minimal production code strictly necessary to make the failing tests pass.
   - Adhere to secure coding standards: strict input allow-lists, parameterized queries, canonical path checking, and least privilege responses.
   - Re-run tests to confirm **GREEN**.

4. **Phase D (Refactor & Local Scan)**:
   - Perform local deterministic scans on changed files (secrets, dependencies, Semgrep).
   - Review code for logic bypasses and ensure diffs are minimal and surgical.
   - Run the full test suite to guarantee zero regressions.

5. **Continuous Evolution (Learn & Update)**:
   - When a security fix or helper is introduced, extract the systemic rule and append it to `CONTEXT.md` under `## 4. Continuous Evolution: Auto-Evolved Conventions`.

---

## Approved Helpers & Safe Patterns
- **Database**: Parameterized SQL / ORM only (never string formatting or f-strings).
- **Paths**: Use `utils.security.resolve_safe_path(base_dir, user_filename)`.
- **Redirects**: Use `utils.security.safe_redirect(url, allowed_hosts)`.
- **Commands**: List-format `subprocess.run([...], shell=False)` only.
