# Secure Test-Driven Development (Secure TDD) Agent Framework

> **A comprehensive Test-Driven Development (TDD) and Quality Assurance (QA) framework with integrated security guardrails for AI coding agents and developers.** Unites functional test-first engineering, living STRIDE threat modeling, local deterministic code quality checks, and continuous skill self-evolution.

---

## 1. Executive Summary & Philosophy: Security as Part of QA

Test-Driven Development (TDD) is the cornerstone of robust **Quality Assurance (QA)**: it guarantees functional correctness, documents expected behavior, handles edge cases, and prevents regressions. 

Historically, software engineering has often treated **functional QA** and **security testing** as completely separate disciplines:
- **QA** runs during development and CI to verify business logic, user journeys, and regressions.
- **Security** is siloed into delayed post-merge scans or third-party audits (leading to 20–70 day remediation cycles and high context-switching costs).

Similarly, AI coding agents without structured QA guardrails frequently write unverified code with fragile edge cases and subtle security holes.

```
       +------------------------------------------------------------------+
       |                  HOLISTIC QUALITY ASSURANCE (QA)                 |
       |                                                                  |
       |   +--------------------------+    +--------------------------+   |
       |   |      FUNCTIONAL QA       |    |       SECURITY QA        |   |
       |   | - Happy paths            |    | - Input allow-lists      |   |
       |   | - Business logic rules   | +  | - Auth & access control  |   |
       |   | - Boundary & edge cases  |    | - Safe sinks & params    |   |
       |   | - Regression protection  |    | - Injection prevention   |   |
       |   +--------------------------+    +--------------------------+   |
       +---------------------------------+--------------------------------+
                                         |
                                         v
                         [ Unified TDD Inner-Loop: RED -> GREEN -> REFACTOR ]
```

**Secure TDD brings security into everyday QA and TDD workflows:**
1. **Holistic Planning & Threat Modeling**: Features are planned with both functional user stories and STRIDE boundary constraints *before* code is authored.
2. **Comprehensive Test-First (RED)**: Unit and integration tests assert both functional outcomes (HTTP 200/302, correct payloads) and defensive boundaries (HTTP 400/401/403, input validation rejections).
3. **Clean, Defensive Implementation (GREEN)**: Minimal, maintainable production code satisfies functional specifications while using safe design patterns (allow-lists, parameterized queries, least privilege).
4. **Local Refactoring & Deterministic Scanning (REFACTOR)**: Fast local checks (linting, test suite regression passes, secret detection, Semgrep SAST) ensure high code quality before commits.
5. **Continuous Quality & Security Evolution**: When edge cases, bugs, or security patterns are resolved, the framework captures the lesson into `CONTEXT.md` and `SKILL.md` so the entire team and agent fleet learn permanently.
6. **No Heavy Database Required**: All state is managed transparently via plain Markdown (`CONTEXT.md`, `threat_model.md`) and append-only logs (`.security-gate/`).

---

## 2. Inspiration & Extensible Design Philosophy

This framework brings together two foundational inspirations:
1. **Test-Driven Development & Continuous Verification**: Drawing on the engineering discipline of TDD and **Paul Hammond's** pioneering work on automated testing and continuous deployment (where rapid feedback loops, high verification confidence, and test-first design enable developers to ship reliably and move fast).
2. **Modular Agent Skill Architectures**: Inspired by research into agentic reasoning and specialized skill structures, including [Google's Mantis project](https://github.com/google/mantis).

While dedicated security review tools often focus on deep offline batch audits and exploit reproduction across legacy repositories, **developers need a lightweight, modular system that integrates directly into everyday feature development and QA workflows**.

### Key Design Principles:
1. **Developer Inner-Loop Integration**: Plugs directly into everyday development tools (`git`, `pytest`, `unittest`, local linters) without requiring heavyweight infrastructure or out-of-band audit cycles.
2. **Modular & Extensible Skills**: Skills are loosely coupled and self-contained in standard `SKILL.md` packages. Developers can freely adopt, customize, or extend whichever skills suit their project (e.g. adding custom domain linters, specialized QA runbooks, or tailored threat models).
3. **Multi-Agent Portability**: Built on open agent skill standards (standard YAML frontmatter and Markdown), allowing identical skills to run seamlessly across **Antigravity (Jetski)**, **Claude Code**, and other coding assistants.
4. **Zero-Database Transparency**: All architectural state and security context live directly alongside the code in human-readable Markdown (`CONTEXT.md`, `threat_model.md`) and append-only logs (`.security-gate/`).
 


---

## 3. The Secure TDD Inner-Loop

```
                 +-----------------------------------------+
                 |               PLAN & RED                |
                 |  - Ingest CONTEXT.md                    |
                 |  - Functional Specs & STRIDE Model      |
                 |  - Functional + Security Tests (RED)    |
                 +--------------------+--------------------+
                                      |
                                      v
                 +-----------------------------------------+
                 |                 GREEN                   |
                 |  - Clean, Defensive Code (MVP)          |
                 |  - Satisfy All Functional & Red Tests   |
                 +--------------------+--------------------+
                                      |
                                      v
                 +-----------------------------------------+
                 |            REFACTOR & SECURE            |
                 |  - Code Quality & Regression Tests      |
                 |  - Local Scans & Guided Review          |
                 |  - Evolve Skills & Architectural Specs  |
                 +--------------------+--------------------+
                                      |
                                      +--- Continuous Evolution ---+
```

### Phase-by-Phase Breakdown

#### Phase A: Planning, Functional Scoping & Threat Modeling (Plan Phase)
- **Core Skill**: `threat_model_assessor`
- Ingests `CONTEXT.md` to identify existing trust boundaries, data flows, and approved helpers.
- Decomposes the feature into clear functional deliverables and evaluates STRIDE risks (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege).
- Generates or updates `threat_model.md` at the workspace root, establishing both Functional and Security Acceptance Criteria.

#### Phase B: Functional & Security Test-First Case Creation (Red Phase)
- **Core Skill**: `security_test_writer`
- Authors comprehensive test cases covering:
  1. *Functional Acceptance*: Happy paths, business logic workflows, valid outputs (e.g. HTTP 200/302).
  2. *Edge Cases & Error Handling*: Malformed inputs, missing parameters, out-of-range values.
  3. *Security Boundary Enforcement*: Rejecting unauthenticated requests, unauthorized access, path traversal, injection payloads (e.g. HTTP 400/401/403).
- Adheres to the Three Verification Pillars:
  1. *Behavior-driven HTTP/API outcomes*: Assert strictly on observable contracts and status codes.
  2. *Strict test isolation*: Fresh contexts and transaction rollbacks.
  3. *Integration over fragile mocking*: Local test instances instead of superficial fakes.
- Runs the test suite and confirms tests fail for the expected reason (**RED**).

#### Phase C: Clean Defensive Implementation (Green Phase)
- **Core Skill**: `defensive_developer`
- Authors the minimal, high-quality production code required to satisfy all failing tests.
- Adheres to the Three Defensive Pillars:
  1. *Strict input validation*: Type safety, structured schemas (`pydantic`), and allow-lists over fragile regex.
  2. *Explicit authorization*: Caller identity and permission verification before executing logic.
  3. *Least privilege & safe sinks*: Parameterized queries, canonical path checking, and minimal returned data payloads.
- Re-runs the test suite to confirm everything is passing (**GREEN**).

#### Phase D: Local Refactoring, Quality & Scanning (Refactor Phase)
- **Core Skill**: `local_refactor_scanner`
- Runs code cleanup for readability, maintainability, and efficiency while ensuring zero test regressions.
- Executes fast deterministic checks on changed files (secrets, dependency vulnerabilities, local Semgrep SAST).
- Conducts a guided AI review to verify architectural boundaries and eliminate logic flaws.
- Keeps diffs small, surgical, and baseline-stable.

#### Continuous Evolution: Updating Skills & Context
- **Core Skill**: `skill_evolution_updater`
- Extracts systemic rules from resolved bugs and newly introduced helpers (e.g., *"Always use `utils.security.safe_redirect()` for URL redirects"*).
- Appends rules to `CONTEXT.md` under `## 4. Continuous Evolution: Auto-Evolved Conventions` and updates `SKILL.md` prompts so all future agent sessions inherit the knowledge.

---

## 4. Repository Structure & Multi-Agent Compatibility

The repository is organized to support **Antigravity**, **Claude Code**, and **Universal AI Agents** simultaneously:

```none
secure-tdd-agent-framework/
├── CONTEXT.md                         # Living project context, boundaries & evolved conventions
├── threat_model.md                    # Living STRIDE threat model & acceptance criteria
├── AGENTS.md                          # Universal agent guidelines & inner-loop spec
├── CLAUDE.md                          # Claude Code always-on workflow instructions
├── requirements.txt                   # Framework dependencies (Flask, pytest, semgrep, pydantic)
├── .agents/                           # Antigravity Workspace Config (Auto-discovered)
│   ├── rules/
│   │   └── secure_tdd_workflow.md    # Always-on workflow rule (Plan -> Red -> Green -> Refactor)
│   ├── skills/
│   │   ├── threat_model_assessor/
│   │   ├── security_test_writer/
│   │   ├── defensive_developer/
│   │   ├── local_refactor_scanner/
│   │   ├── skill_evolution_updater/
│   │   └── history_context_seeder/
│   ├── hooks.json                     # Pre-push hook (CodeMender / Semgrep)
│   ├── security_gate_hook.sh          # CodeMender security hook script
│   ├── security_gate_hook_semgrep.sh  # Semgrep security hook script
│   ├── lib/gate_common.sh             # Common severity ranking & audit logger
│   └── tests/                         # Offline hook test suite (26/26 mock tests)
├── claude-code/                       # Claude Code Portable Port
│   ├── CLAUDE.md
│   └── .claude/
│       ├── settings.json              # Claude Code hooks & permissions
│       ├── hooks/                     # PreToolUse bash push interceptors
│       └── skills/                    # Kebab-case Claude Code skills
├── sample_app/                        # Sample application demonstrating Secure TDD
│   ├── app.py                         # Flask service with functional & defensive endpoints
│   └── utils/security.py              # Approved security helpers (paths, redirects, SQL)
└── tests/
    └── test_sample_app.py             # Test suite combining functional QA & security assertions
```

---

## 5. Quickstart & Installation

### Option 1: Using with Antigravity
The `.agents/` folder at the root of this repository is auto-discovered.
1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
2. Activate the Semgrep hook (or keep default CodeMender):
   ```bash
   cp .agents/hooks_semgrep.json .agents/hooks.json
   ```
3. Start coding! Antigravity will automatically follow the `secure_tdd_workflow.md` rule across all QA and development tasks.

### Option 2: Using with Claude Code
1. Copy `claude-code/CLAUDE.md` and `claude-code/.claude/` to your workspace root:
   ```bash
   cp claude-code/CLAUDE.md ./
   cp -r claude-code/.claude ./
   ```
2. If using Semgrep, activate the Semgrep settings:
   ```bash
   cp .claude/settings.semgrep.json .claude/settings.json
   ```

---

## 6. Running Tests & Verifying Hooks

### 1. Run Application QA & Security Test Suite
```bash
python3 -m unittest discover -s tests
# or with pytest:
pytest tests/
```
*Output: 10 tests passed (verifying both functional happy paths and security boundary rejection).*

### 2. Run Offline Hook Test Suites (Dependency-Free Mocks)
```bash
# Test Antigravity Hook
bash .agents/tests/run_tests.sh

# Test Claude Code Hook
bash claude-code/.claude/hooks/tests/run_tests.sh
```
*Output: 52/52 mock tests passing across PASS, ADVISORY, ERROR, BLOCKED, and FIXED outcomes.*

---

## 7. License

Licensed under the [Apache License, Version 2.0](LICENSE).
