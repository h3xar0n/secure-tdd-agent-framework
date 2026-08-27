# Secure TDD Agent Framework

> **A TDD and QA framework with integrated security for AI coding agents and developers.** Combines functional test-first engineering, living STRIDE threat modeling, local code quality checks, and continuous skill self-evolution to mitigate recurring issues.

---

## 1. Security as Part of Quality

Test-Driven Development (TDD) writes tests first to encode the requirements early on and target development against discrete goals. It documents expected behavior, catches regressions early, and keeps the agent zeroed in on implementing verifiable logic instead of guessing. This reduces some of the common issues with AI generated code, for example hallucinated features, hallucinations on test coverage, and going off on sidequests to recreate entire helper libraries, which is a nightmare to even run agentic reviews against.

Historically, software engineering has often treated **functional QA** and **security testing** as completely separate disciplines:
- **QA** runs during development and CI to verify business logic, user journeys, and regressions.
- **Security** is siloed into delayed post-merge scans or third-party audits (leading to an average 20-day remediation cycle, deliterious impacts to throughput, and high context-switching costs). With AI agents, this old approach may lead to more growth risk than the security risk it mitigates, and it certainly costs more to fix later than the moment the code is written.

### The Flaw with Reviewing ONLY in CI/CD
When security and QA reviews happen **only** downstream in CI/CD or post-merge pipelines:
- **Delayed Discovery**: Developers receive feedback hours, days, or weeks after authoring code, when the architectural context is no longer fresh.
- **Context-Switching Tax**: Fixing a failure detected in CI requires rolling back branches, reopening pull requests, and context switching away from current feature work.
- **Compounding Technical Debt**: AI coding agents without local QA guardrails generate unchecked assumptions and subtle logic bypasses that escape into the codebase.

### Security as Part of Software Quality (and the Stability Risk of Isolation)
**Security is an intrinsic part of software quality.** Treating security separately from functional development introduces direct risks to system stability:

- **Isolated Security Threatens Stability**: When security is treated in isolation from functional development, it actively poses a risk to system stability. Out-of-band security scans, external remediation workflows, or isolated security patches frequently introduce regressions, break existing API contracts, and cause unexpected production outages because they modify code without context of the application's functional requirements.
- **Co-Verification via TDD**: Security patches that break functional behavior introduce regressions into production. Unifying security constraints with TDD codifies defensive boundaries (authentication, input allow-lists, parameterized sinks) into tests alongside functional acceptance criteria (happy paths, business workflows). This supports preserving both security and operational stability.

**The Inner-Loop Advantage**: Moving threat modeling and security test assertions into the developer's local test-first loop (TDD) eliminates issues in seconds while code is actively being written.

```
       +------------------------------------------------------------------+
       |                           HOLISTIC QA                            |
       |                                                                  |
       |   +--------------------------+    +--------------------------+   |
       |   |      FUNCTIONAL QA       |    |       SECURITY QA        |   |
       |   | - Happy paths            |    | - Input allow-lists      |   |
       |   | - Business logic rules   | +  | - Auth & access control  |   |
       |   | - Boundary & edge cases  |    | - Safe sinks & params    |   |
       |   | - Regression protection  |    | - Injection mitigation   |   |
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
4. **Local Refactoring & Deterministic Scanning (REFACTOR)**: Fast local checks (linting, test suite regression passes, secret detection, Semgrep SAST) verify code quality before commits.
5. **Continuous Quality & Security Evolution**: When edge cases, bugs, or security patterns are resolved, the framework captures the lesson into `CONTEXT.md` and `SKILL.md` so the entire team and agent fleet learn permanently.
6. **No Heavy Database Required**: All state is managed transparently via plain Markdown (`CONTEXT.md`, `threat_model.md`) and append-only logs (`.security-gate/`).

> [!TIP]
> **Living Exemplar (Dogfooded in this Repository)**: We use this exact Secure TDD workflow to update and maintain this framework itself! Readers can inspect the live [`threat_model.md`](threat_model.md) generated during Phase A (which models the framework's own pre-push hook gates and trust boundaries) and the comprehensive test coverage across [`tests/`](tests/) and [`.agents/tests/`](.agents/tests/) written test-first during Phase B as real, working examples.

---

## 2. Inspiration, CI/CD Balance & Scaling Philosophy

This framework brings together two inspirations:
1. **TDD & Continuous Verification**: Drawing on the engineering discipline of TDD and Paul Hammond's pioneering work where rapid feedback loops, high verification confidence, and test-first design enable developers to ship reliably and move fast.
2. **Modular Agent Skill Architectures**: Inspired by research into agentic reasoning and specialized skill structures, including [Google's Mantis project](https://github.com/google/mantis).

### Standalone Security Agents vs. Inner-Loop Development
Dedicated security review engines like **[Google Mantis](https://github.com/google/mantis)** serve as powerful standalone security reviewers—performing deep offline batch sweeps, multi-repository research, and exploit reproduction in isolated environments.

- **Deeper Security Belongs in CI/CD**: Exhaustive testing (fuzzing, dynamic analysis, complex multi-repo exploit research, and whole-dependency graphing) **should still take place in CI/CD**.
- **CI/CD as a Secondary Safety Backstop**: CI/CD functions as a safety backstop for long-running checks, while the inner-loop framework eliminates functional flaws and security findings locally during active development.

### Solo Developers vs. Scaling to Teams & Centralized Architectures
- **Out of the Box for Solo Developers**:
  - Designed to work seamlessly with zero infrastructure: all context lives in human-readable Markdown (`CONTEXT.md`, `threat_model.md`), and local deterministic pre-push hooks run offline.
  - The developer maintains full visibility into all changes. In this local setup, the coding agent can "self-heal" by updating local `SKILL.md` files directly when new conventions or edge cases are resolved.
- **Scaling to Larger Teams & Enterprise**:
  - For larger engineering teams, threat models and skills can scale across services via a **centralized knowledge base** and **shared skill registry**.
  - **Governance on Skill Evolution**: In a team or enterprise environment, individual coding agents should not have permission to directly mutate skills in a shared registry. Instead, the agent's continuous evolution phase can be configured to submit *suggested skill improvements, PR proposals, or ticket drafts* for review by QA and security leads.
- **Extensible by Design**: The framework is intentionally unopinionated and modular—it works effortlessly out of the box for an individual developer, while providing clear extension points to integrate with centralized registries, team knowledge bases, and enterprise CI/CD systems.

### Design Principles:
1. **Developer Inner-Loop Integration**: Plugs directly into everyday development tools (`git`, `pytest`, `unittest`, local linters) without requiring heavyweight infrastructure or out-of-band audit cycles.
2. **Modular & Extensible Skills**: Skills are loosely coupled and self-contained in standard `SKILL.md` packages. Developers can freely adopt, customize, or extend whichever skills suit their project (e.g. adding custom domain linters, specialized QA runbooks, or tailored threat models).
3. **Multi-Agent Portability**: Built on open agent skill standards (standard YAML frontmatter and Markdown), allowing identical skills to run seamlessly across **Antigravity**, **Claude Code**, and other coding assistants.
4. **Zero-Database Transparency**: All architectural state and security context live directly alongside the code in human-readable Markdown (`CONTEXT.md`, `threat_model.md`) and append-only logs (`.security-gate/`).

 


---

## 3. The Secure TDD Inner-Loop

```
                 +-----------------------------------------+
                 |                 1. PLAN                 |
                 |  - Ingest CONTEXT.md                    |
                 |  - Functional Specs & Scoping           |
                 |  - STRIDE Threat Model (threat_model.md)|
                 +--------------------+--------------------+
                                      |
                                      v
                 +-----------------------------------------+
                 |                 2. RED                  |
                 |  - Functional QA Tests (Happy Paths)    |
                 |  - Edge Cases & Boundary Handling       |
                 |  - Security Boundary Tests (Assert RED) |
                 +--------------------+--------------------+
                                      |
                                      v
                 +-----------------------------------------+
                 |                3. GREEN                 |
                 |  - Clean, Defensive Code (MVP)          |
                 |  - Satisfy All Functional & Red Tests   |
                 +--------------------+--------------------+
                                      |
                                      v
                 +-----------------------------------------+
                 |          4. REFACTOR & EVOLVE           |
                 |  - Code Quality & 100% Regression Pass  |
                 |  - Local Deterministic Scans & Review   |
                 |  - Update CONTEXT.md & Evolve Skills    |
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

#### Phase D: Refactoring, Quality, Context & Continuous Evolution (Refactor Phase)
- **Core Skills**: `local_refactor_scanner`, `skill_evolution_updater`
- **Refactor & Context Evolution**: Along with code cleanup, the Refactor phase updates local project context and evolves skills to mitigate recurring bugs and security findings:
  1. *Code Cleanliness & Maintainability*: Eliminate duplication, improve modularity, and verify 100% passing test regressions.
  2. *Local Scans & Guided Review*: Fast deterministic checks on changed files (secrets, dependency CVEs, local Semgrep SAST) + guided AI review to verify architectural boundaries.
  3. *Update Local Context (`CONTEXT.md`)*: Extract systemic lessons, approved helpers, and newly established conventions, appending them directly to `CONTEXT.md` under `## 4. Continuous Evolution: Auto-Evolved Conventions`.
  4. *Evolve & Suggest Skill Updates (`SKILL.md`)*: If a recurring anti-pattern, tricky edge case, or specialized QA/security workflow was identified, suggest or apply updates to `SKILL.md` instructions so future AI agent sessions inherit the rule upfront and avoid repeating the mistake.

##### Security Gate Hook Flow (Sequential Pipeline & Verification Loop)

```
                    [ git push intercepted by Hook ]
                                   │
                                   ▼
                    [ Inspect Modified Files in Push ]
                                   │
                                   ▼
                     [ Stage 1: Deterministic Scan ]
                       (AST Checks & Autofixes)
                                   │
            ┌──────────────────────┼──────────────────────┐
      (Scan Error)           (No Findings)          (Threat-Model Findings)
            │                      │                      │
            ▼                      │                      ▼
    [ Check Fail-Open ]            │            [ 3-Attempt TDD Loop ]
    SECURITY_GATE_ALLOW_ON_ERROR   │        (Add Test -> Fix -> Run Suite)
            │                      │                      │
     ┌──────┴──────┐               │               ┌──────┴──────┐
  (false)        (true)            │         (Fixed in <= 3)  (Fails Past 3)
     │             │               │               │             │
     ▼             ▼               │               ▼             ▼
[ Deny Push  ] [ Log Error ]       │       [ Import Fix & ] [ Import Unresolved ]
[& Escalate  ] [ Proceed   ]       │       [ Context to   ] [ Finding to        ]
                   │               │       [ Stage 2      ] [ Stage 2           ]
                   │               │               │             │
                   └───────────────┼───────────────┴─────────────┘
                                   │
                                   ▼
                       [ Stage 2: Semantic Scan ]
                      (Contextual AI / CodeMender)
                       - Verify Imported Fixes
                       - Ingest Remaining Findings
                                   │
            ┌──────────────────────┼──────────────────────┐
      (Scan Error)           (No Findings /         (Threat-Model Findings)
            │                Verified Clean)              │
            ▼                      │                      ▼
    [ Check Fail-Open ]      [ Allow Push ]     [ 3-Attempt TDD Loop ]
    SECURITY_GATE_ALLOW_ON_ERROR               (Add Test -> Fix -> Run Suite)
            │                                             │
     ┌──────┴──────┐                       ┌──────────────┴──────────────┐
  (false)        (true)               (Fails Tests                  (Passes in
     │             │                Past 3rd Attempt)             <= 3 Attempts)
     ▼             ▼                       │                             │
[ Deny Push  ] [ Tag Commit with           ▼                             ▼
[& Escalate  ]   'unverified-scan' ] [ Revert Changes ]            [ Auto-Commit ]
               [ Allow Push        ] [ git checkout . ]            [ Allow Push  ]
                                           │
                                           ▼
                                  [ Run 'cm verify' ]
                                           │
                      ┌────────────────────┴────────────────────┐
             (Conclusively Not                     (Confirms Issue OR
                Exploitable)                         Verify Crashes)
                      │                                     │
                      ▼                                     ▼
            [ Append Advisory to ]                 [ Escalate to HITL ]
            [ Commit / Audit Log ]                 - Non-TTY: Deny Push
            [    Allow Push      ]
```

> **TDD Principles & Continuous Evolution in Hook Remediation**:
> Every automated fix follows the TDD cycle rather than applying isolated code patches:
> 1. **Add Boundary Test First (RED)**: A test case reproducing the finding or boundary constraint is added to the test suite and confirmed failing.
> 2. **Apply Minimal Fix (GREEN)**: The defensive code change is applied to satisfy the failing test.
> 3. **Full Suite Regression Verification**: The complete test suite is executed across all existing unit and integration tests to confirm that existing functionality is preserved and regressions are caught early.
> 4. **Cross-Stage Context Import**: Fixes applied during the Stage 1 deterministic scan are imported into Stage 2 so the contextual AI engine verifies them against semantic constraints. If a Stage 1 fix cannot pass tests within 3 attempts, the unresolved finding is imported directly into Stage 2 for multi-file contextual remediation.
> 5. **Detailed Commit Documentation**: Auto-commits include structured commit bodies detailing why the security test was added, the threat model boundary addressed, the fix implemented, and test passing confirmation.
> 6. **Local Context & Skill Evolution**: When enabled, the hook appends newly verified conventions directly to the directory-level `CONTEXT.md` and outputs actionable suggestions for updating relevant `SKILL.md` files so future agent sessions avoid repeating the issue.


---

## 4. Single Source of Truth & Downstream Distributions

This repository (`secure-tdd-agent-framework`) serves as the **canonical upstream single source of truth** for all skills, rules, threat models, and hook scripts.

Instead of maintaining redundant duplicate folders, the framework automatically builds and synchronizes dedicated downstream distributions:

```none
secure-tdd-agent-framework/ (Canonical Upstream Source of Truth)
├── CONTEXT.md                         # Living project context, boundaries & evolved conventions
├── threat_model.md                    # Living STRIDE threat model & acceptance criteria
├── AGENTS.md                          # Universal agent guidelines & inner-loop spec
├── CLAUDE.md                          # Claude Code always-on workflow instructions
├── requirements.txt                   # Framework dependencies (Flask, pytest, semgrep, pydantic)
├── .agents/                           # Canonical Skills & Hooks Source
│   ├── rules/
│   │   └── secure_tdd_workflow.md    # Always-on workflow rule (Plan -> Red -> Green -> Refactor)
│   ├── skills/
│   │   ├── threat_model_assessor/
│   │   ├── security_test_writer/
│   │   ├── defensive_developer/
│   │   ├── local_refactor_scanner/
│   │   ├── skill_evolution_updater/
│   │   └── history_context_seeder/
│   ├── hooks.json                     # Universal pre-push hook configuration
│   ├── security_gate_hook.sh          # Universal modular security gate hook entrypoint
│   ├── lib/
│   │   ├── gate_common.sh             # Common severity ranking, audit logger & notify
│   │   ├── engine_codemender.sh       # CodeMender scanner engine module
│   │   └── engine_semgrep.sh          # Semgrep scanner engine module
│   └── tests/                         # Offline hook test suite (26/26 mock tests)
├── scripts/
│   └── sync_downstream.py             # Automated downstream repository sync engine
├── sample_app/                        # Sample application demonstrating Secure TDD
│   ├── app.py                         # Flask service with functional & defensive endpoints
│   └── utils/security.py              # Approved security helpers (paths, redirects, SQL)
└── tests/
    └── test_sample_app.py             # Test suite combining functional QA & security assertions
```

### Downstream Distribution Repositories:
- **`secure-tdd-antigravity`**: Dedicated Antigravity workspace package containing `.agents/`, `AGENTS.md`, and `CONTEXT.md`.
- **`secure-tdd-claude-code`**: Dedicated Claude Code CLI package containing `.claude/` (with kebab-case skills and bash hooks), `CLAUDE.md`, and `CONTEXT.md`.

### Platform Rule & Workflow Mapping
Different AI coding platforms discover always-on instructions through different file locations. The canonical upstream repository maintains each format, and `sync_downstream.py` distributes them cleanly to their native locations:

| Platform | Rule / Workflow Location | Purpose & Discovery Mechanism |
| :--- | :--- | :--- |
| **Antigravity** | `.agents/rules/secure_tdd_workflow.md` | Auto-discovered from `.agents/rules/` with `trigger: always_on`. |
| **Claude Code** | `CLAUDE.md` (Project Root) | Auto-loaded by Claude Code on session start as the project system prompt. |
| **Universal Agents** | `AGENTS.md` (Project Root) | Universal reference document for any AI coding assistant or developer. |
| **Shared Context** | `CONTEXT.md` & `threat_model.md` | Living architectural boundaries, helpers, and STRIDE acceptance criteria. |

---

## 5. Primary Use Cases & Operational Scenarios

### 1. Solo Original Feature Development
When building new software or greenfield features as a solo developer, you retain direct control over every layer of the development cycle:
- **Direct Skill & Rule Customization**: You can edit `SKILL.md` instructions, add custom domain helpers to `CONTEXT.md`, and configure your own test commands without needing approval from a centralized committee.
- **Platform Choice**: You can operate natively in Antigravity or in Claude Code CLI depending on your preferred development workflow.
- **Observable Iteration**: You see every test failure (RED), implementation change (GREEN), and refactoring step in your local environment before code is pushed to remotes.

### 2. Autonomous Remediation & Automated Patching Agents
Automated security agents that ingest findings from external scanners (e.g. PR checks or pipeline notifications) benefit from specific skills in this framework:
- **Applicable Skills**:
  - `security_test_writer`: Translates a finding into an explicit, reproducing test asserting the boundary constraint before touching code.
  - `defensive_developer`: Applies minimal code modifications using established helpers and parameterization to satisfy the test.
  - `local_refactor_scanner`: Executes the full local regression test suite to confirm existing functional behavior is preserved.
- **Operating Without Upfront Threat Models**: An automated patching agent often receives an isolated finding report without a complete architectural threat model. To avoid applying blind patches that break production behavior, the agent uses the repository's `CONTEXT.md` as its primary reference:
  1. *Context Reference*: The agent reads approved helpers, trust boundaries, and coding conventions from `CONTEXT.md`.
  2. *Synthesizing Scanner Output with Application Logic*: The agent matches the finding against existing route handlers and data schemas.
  3. *TDD Guardrail*: By requiring a failing test first and a 100% passing regression run after, the agent verifies that the patch resolves the finding without breaking existing API contracts.

### 3. Analyzing & Remediating Legacy Codebases
Applying automated security patches directly to legacy repositories with sparse or missing tests is risky. Modifying legacy code without functional test coverage often causes unexpected runtime regressions and breaks downstream consumers.

**Recommended Remediation Sequence for Legacy Applications**:
1. **Initial Hotspot Triage**: Run dedicated scanning and review tools like Mantis or CodeMender to identify high-risk components and compile an inventory of findings.
2. **Establish Baseline Functional Test Coverage**: Before modifying application logic, generate functional characterization tests for the target component until all existing paths pass green.
   - *Example Prompt for Coding Agent*:
     > "Analyze `[target_module.py]` and its callers. Write characterization unit and integration tests covering the existing happy paths, parameter handling, and return contracts. Confirm all tests pass green against current behavior before applying any security modifications."
3. **Incremental Secure TDD Fixes**: Once baseline functional tests are passing green, address security findings one by one: write a reproducing boundary test (RED), apply the defensive fix using approved helpers (GREEN), and confirm all existing legacy tests continue to pass.

---

## 6. Roadmap & Future Capabilities

- **Expanded LLM Engines**: Multi-model routing supporting OpenAI Codex and diverse inference backends for skill execution.
- **Wiz Code Integration**: Adding Wiz Code as an alternative Stage 1 deterministic scanning engine alongside open-source Semgrep.
- **Language-Specific Skill Packs**: Dedicated defensive skills and test writers for Go, Python, TypeScript/Node.js, Rust, and Java/Spring.
- **Infrastructure as Code (IaC) Verification**: Extending test-first security to Terraform and OpenTofu modules, asserting IAM least privilege, network egress boundaries, and resource policies through local policy-as-code tests.
- **Google Cloud Skill Modules**: Using Google's pre-packaged skills for Cloud Run, Cloud KMS, Workload Identity Federation, and Secret Manager safe integration patterns.

---

## 7. Automated Downstream Synchronization

Whenever updates are made to skills, rules, or hook scripts in this repository, the downstream repositories are updated automatically:

### 1. Manual / Scripted Sync
```bash
# Sync and automatically create git commits in downstream repos
python3 scripts/sync_downstream.py --commit

# Sync, commit, and push to downstream remotes
python3 scripts/sync_downstream.py --commit --push
```

### 2. Local Git `post-commit` Hook
A local git hook is configured in `.git/hooks/post-commit` to automatically run `sync_downstream.py --commit` on every commit in this repository.

### 3. GitHub Actions CI/CD Sync
The [.github/workflows/sync-downstream.yml](file:///.github/workflows/sync-downstream.yml) workflow automatically propagates changes to the downstream GitHub repositories whenever commits are pushed to `main`.

---

## 8. Running Tests & Verifying Hooks

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

# Test Claude Code Hook (in downstream repo)
bash ../secure-tdd-claude-code/.claude/hooks/tests/run_tests.sh
```
*Output: 74/74 mock tests passing (37 per test harness) across PASS, ADVISORY, ERROR, BLOCKED, FIXED, and PIPELINE outcomes.*


---

## 9. License

Licensed under the [Apache License, Version 2.0](LICENSE).
