# 5-Minute Demo Script: Monday Morning Secure TDD on `modern-app`

**Presenter**: Aron Eidelman (Sr. DRE, Security)  
**Target Repo**: [`nedtargaryen243870-code/modern-app`](https://github.com/nedtargaryen243870-code/modern-app)  
**Framework Repo**: [`secure-tdd-agent-framework`](../AGENTS.md)  
**Spoken Word Count**: ~610 words (5:00 runtime)

---

## 0:00 – 1:15 | Monday Morning: How Secure TDD Differs from Pure SDD

**[ON SCREEN]**  
Start on [`modern-app/pull/3`](https://github.com/nedtargaryen243870-code/modern-app/pull/3) showing two items from Thursday's PR:
1. The GitHub Actions bot inline suggestion (`Automatic Sensitive Data Redaction Safeguard`) and Ned's reply: *"Ack. But the code suggestion is invalid."*
2. The tech lead's (`anguillanneuf`) two commits (`bf36533`, `96ad25b`) fixing BigQuery `LAX_FLOAT64` and `SAFE_OFFSET` SQL handling.  
Switch to VS Code terminal and run [`skill_evolution_updater`](../.agents/skills/skill_evolution_updater/SKILL.md) + [`scripts/sync_downstream.py`](../scripts/sync_downstream.py).

```bash
# Monday morning: codify last week's Thursday self-review & PR #3 lessons into CONTEXT.md and skills
python3 scripts/sync_downstream.py --commit --push
```

**[SPOKEN SCRIPT]**  
"Thanks, Tianzi. Ned wrapped up Friday with the team's weekly spec review, so it is now **Monday morning** of the next sprint.

Before we build Monday's feature on `modern-app`, I want to point out what we are doing differently here with **Secure TDD** compared to pure **Spec-Driven Development**.

In Tianzi's demo, Spec-Driven Development gave the agent Markdown specs—like `product-guidelines.md`—that describe what the app should do. That is a great starting point, but look at what still happened at the end of last week:
- First, passive Markdown specs sit in the context window. As Ned showed on Wednesday, when the conversation grows, the agent compacts its context window—and passive security guidelines get forgotten.
- Second, because Ned coded all day Wednesday across 21 tasks before checking security, his Thursday morning self-review caught header injection in `src/proxy.ts` and serialization crashes in `publisher.ts` *after* the code was already written.
- Third, when Ned opened PR #3 on Thursday afternoon, the outer-loop review bot—lacking threat-model context—hallucinated an invalid 25-line regex scrubber that Ned and his tech lead had to reject.
- Fourth, the actual Cloud bug—BigQuery SQL failing without `LAX_FLOAT64` and `SAFE_OFFSET`—required his tech lead to manually push two commits directly to the PR.

**Secure TDD changes this in two fundamental ways**:
1. Instead of leaving security rules as passive Markdown prose that drifts when context compacts, **we compile specs into failing, executable security boundary tests before a single line of production code is written.** An agent can forget a prompt instruction, but it cannot bypass a failing test runner.
2. Instead of waiting for Friday's manual spec sync, **we use outer-loop PR findings to upgrade our inner-loop skills.**

Right now on Monday morning, I run [`skill_evolution_updater`](../.agents/skills/skill_evolution_updater/SKILL.md). It extracts the real lessons from Thursday's review—strict trace header allow-lists, safe BigQuery `LAX_FLOAT64` and `SAFE_OFFSET` queries, and schema redaction—and writes them into [`CONTEXT.md`](../CONTEXT.md) and our [`defensive_developer`](../.agents/skills/defensive_developer/SKILL.md) skill. Running `sync_downstream.py` distributes those rules to every developer's agent."

---

## 1:15 – 3:45 | The Inner Loop: Plan, Intentional RED Failure & Automated Repair

**[ON SCREEN]**  
In VS Code, prompt the agent to implement Monday's feature: an admin telemetry search route (`src/app/api/telemetry/search/route.ts`) that queries the BigQuery audit table Ned built. Show [`threat_model.md`](../threat_model.md) updating, then run Vitest on `tests/telemetry/search.security.test.ts`.

```bash
# Phase A (Plan): threat_model_assessor updates threat_model.md
# Phase B (Red): security_test_writer generates functional + adversarial security boundary tests
npx vitest run tests/telemetry/search.security.test.ts
```

**[SPOKEN SCRIPT]**  
"Now let's build Monday's feature: adding `/api/telemetry/search` so admins can query BigQuery audit logs by `traceId` and `userId`.

Enforced by [`.agents/rules/secure_tdd_workflow.md`](../.agents/rules/secure_tdd_workflow.md), our agent cannot write production code until it completes the **Plan** and **Red** phases.

In the **Plan Phase**, it invokes [`threat_model_assessor`](../.agents/skills/threat_model_assessor/SKILL.md) and updates `threat_model.md` with STRIDE boundaries:
- **Elevation of Privilege**: Callers must hold the `admin` role.
- **Tampering**: Incoming `traceId` and `userId` inputs cross a trust boundary into BigQuery.
- **Information Disclosure**: Error responses must strip stack traces and credentials.
- **Denial of Service**: Queries must include a bounded `timestamp` partition filter.

In the **Red Phase**, whereas SDD writes tests mostly for functional happy paths, our [`security_test_writer`](../.agents/skills/security_test_writer/SKILL.md) skill authors **adversarial boundary tests** in `search.security.test.ts`—asserting that unauthenticated callers get `401`, non-admins get `403`, and SQL injection payloads get rejected. Scoping each task to passing a single failing test keeps commits small—which DORA shows increases throughput and avoids the 90% review-time penalty of large AI diffs.

Let's run Vitest—and intentionally trigger a failure."

**[ON SCREEN]**  
Terminal shows **RED** (`FAIL tests/telemetry/search.security.test.ts`: SQL injection payload bypasses `traceId` filter; unredacted token leaks in error fallback). Then show the Automated Repair Loop invoking [`defensive_developer`](../.agents/skills/defensive_developer/SKILL.md), applying the patch, and running [`.agents/security_gate_hook.sh`](../.agents/security_gate_hook.sh) on `git push`.

```bash
# Phase C (Green): Automated Repair Loop applies surgical fix via defensive_developer
npx vitest run tests/telemetry/search.security.test.ts  # -> PASS (49/49 unit, 4/4 parity)

# Phase D (Refactor & Pre-Push Gate):
git push origin feat/telemetry-search
# -> Stage 1 (Wiz CLI): 0 secrets, 0 CVEs, 0 IaC/SAST violations
# -> Stage 2 (CodeMender cm find / cm verify): Confidence Score 0.96 (Verified Clean)
```

**[SPOKEN SCRIPT]**  
"We see the RED failure. Now watch the automated Repair Loop kick in.

The biggest blocker to auto-remediation in traditional pipelines is fear that a security fix will break functionality somewhere else. Here, our 49 unit tests and 4 parity tests remove that risk. The platform diagnoses the root cause, invokes [`defensive_developer`](../.agents/skills/defensive_developer/SKILL.md)—which applies our `LAX_FLOAT64` and schema rules from Monday morning's skill update—and generates a 12-line surgical patch using parameterized BigQuery bindings (`@traceId`, `@userId`).

We re-run Vitest locally. Every test turns **GREEN**.

When I run `git push`, our local pre-push hook—`.agents/security_gate_hook.sh`—intercepts the push and runs two local checks before code leaves my workstation:
- **Stage 1 runs Wiz CLI** locally across the diff for secrets, vulnerable dependencies, and SAST policy checks.
- **Stage 2 runs CodeMender** (`cm find` and `cm verify`), returning a **0.96 confidence score** that the BigQuery sink is non-exploitable.

No waiting until Thursday for a self-review. We caught, tested, and verified the fix inside the inner loop in seconds."

---

## 3:45 – 5:00 | Context-Rich PRs, Trunk-Based Dev & Enterprise Assurance

**[ON SCREEN]**  
Switch to Browser Tab 2: Automated PR #4 on `modern-app`, showing the commit-level Security & Verification Manifest and independent review agent comment. End on Slide 18 (Enterprise Agentic SDLC with Cloud Build & Binary Authorization).

```markdown
### Commit Security & Verification Manifest (`.agents/security_gate_hook.sh`)
- **Local Tests**: `npm run test:unit` (49/49 PASS), `npm run test:parity` (4/4 PASS)
- **Inner-Loop Remediation**: `CM-SQLI-042` fixed via parameterized `@traceId` binding (Wiz CLI: Clean | CodeMender Confidence: 0.96)
- **Threat Model Delta (`threat_model.md`)**:
  - **NEW SINK**: Introduced authenticated admin input (`GET /api/telemetry/search`) querying BigQuery `telemetry_events`.
- **Skill Evolution**: Inherited `LAX_FLOAT64` / `SAFE_OFFSET` and strict schema redaction rules from PR #3.
```

**[SPOKEN SCRIPT]**  
"When the agent opens Pull Request #4, look at why the review experience is completely different from PR #3.

In PR #3, the review bot hallucinated an invalid regex patch because all it saw was a raw code diff. In PR #4, our hook attaches a structured Security & Verification Manifest to every commit:
- Which tests ran locally (`49/49 unit`, `4/4 parity`).
- Which findings were discovered and remediated in the inner loop, with Wiz CLI results and CodeMender's `0.96` confidence score.
- The **Threat Model Delta**: *'Introduced an authenticated admin input querying BigQuery `telemetry_events`.'*
- The upstream skills inherited by the agent.

With that context, an independent review model filters out false positives and focuses on true architectural drift—and if it ever catches a new edge case, that feedback immediately triggers `skill_evolution_updater` to upgrade our skills again.

In fact, because agents with Secure TDD skills and pre-push hooks produce small, test-isolated commits, many synchronous teams are moving away from Pull Request queues altogether—returning to pair and mob programming and trunk-based development.

For async teams and enterprise governance, the CI/CD pipeline serves as an auditable **Assurance Gate**: Cloud Build runs deterministic SAST, SCA, secret scanning, and IaC validation to sign cryptographic attestations, which Cloud Binary Authorization verifies before Cloud Deploy promotes the container to production.

We use outer-loop lessons to continuously sharpen the inner loop—giving developers speed on Monday morning and cryptographic assurance at deployment. Thank you!"
