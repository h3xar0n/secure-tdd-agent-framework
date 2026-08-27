# Agent Reference Guide: Secure Test-Driven Development (Secure TDD)

This document is the canonical reference guide for AI coding agents operating in this repository. It defines the core philosophy, the 4-phase Secure TDD inner-loop workflow, data contracts, and tool conventions.

---

## 1. Paradigm: Frontline Agentic Security

Traditional security models rely on post-merge CI/CD scans, leading to long remediation cycles (20–70 days) and high context switching costs. Similarly, low-context AI agents often generate large, unreviewable diffs with subtle security flaws.

This framework enforces **Frontline Agentic Security**:
- Security is shifted left directly into the coding agent's inner loop.
- Features and bug fixes are developed using test-first, incremental commits.
- Architectural context (`CONTEXT.md`) and threat models (`threat_model.md`) are ingested *before* authoring production code.

---

## 2. The Secure TDD Inner-Loop

```
                 +---------------------------+
                 |       PLAN & RED          |
                 |  - Ingest CONTEXT.md      |
                 |  - STRIDE Threat Model    |
                 |  - Security Tests (Red)   |
                 +-------------+-------------+
                               |
                               v
                 +---------------------------+
                 |         GREEN             |
                 |  - Defensive Code (MVP)   |
                 |  - Satisfy Red Tests      |
                 +-------------+-------------+
                               |
                               v
                 +---------------------------+
                 |     REFACTOR & SECURE     |
                 |  - Local Scans & Audits   |
                 |  - Surgical Small Diffs   |
                 |  - Evolve Skills/Specs    |
                 +-------------+-------------+
                               |
                               +--- Continuous Evolution ---+
```

### Phase A: Proactive Planning & Threat Modeling (Plan Phase)
- **Skill**: `threat_model_assessor`
- Ingest `CONTEXT.md` to identify existing trust boundaries and approved helpers.
- Perform STRIDE assessment on the proposed change.
- Generate or update `threat_model.md` at the workspace root, establishing Security Acceptance Criteria.

### Phase B: Security Test-First Case Creation (Red Phase)
- **Skill**: `security_test_writer`
- Author unit and integration tests asserting functional behavior AND boundary limits (400/401/403 responses, validation errors).
- Adhere to the Three Verification Pillars:
  1. *Behavior-driven HTTP/API outcomes*.
  2. *Strict test isolation* (transaction rollbacks).
  3. *Integration over fragile mocking*.
- Run the test suite and verify tests fail for the expected reason (RED).

### Phase C: Secure Defensive Code Implementation (Green Phase)
- **Skill**: `defensive_developer`
- Author the minimal defensive logic to make failing tests pass.
- Adhere to the Three Defensive Pillars:
  1. *Strict input validation* (allow-lists, typed schemas).
  2. *Explicit authorization & caller identity verification*.
  3. *Least privilege data payloads & parameterized sinks*.
- Run the test suite and confirm it is GREEN.

### Phase D: Local Refactoring & Scanning (Refactor Phase)
- **Skill**: `local_refactor_scanner`
- Execute fast deterministic scans locally (secrets, dependencies, Semgrep / CodeMender).
- Conduct a guided AI review to verify business logic and eliminate false positives.
- Ensure diffs remain small, surgical, and preserve baseline stability.

### Continuous Evolution: Updating Skills & Context
- **Skill**: `skill_evolution_updater`
- On resolving a security pattern or introducing a new helper, extract the systemic rule.
- Append the rule to `CONTEXT.md` under `## 4. Continuous Evolution: Auto-Evolved Conventions` or update `SKILL.md` instructions.
- All future agent sessions inherit these rules upfront.

---

## 3. Tool Conventions & State Management
- **No Database Required**: All state is managed via plain Markdown (`CONTEXT.md`, `threat_model.md`) and append-only logs (`.security-gate/findings-log.ndjson`).
- **Deterministic Pre-Push Gate**: On `git push`, the local hook intercepts the push to scan modified files, ensuring clean code reaches remote repositories.
