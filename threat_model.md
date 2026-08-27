# Living Threat Model (STRIDE Methodology)

This document is the living STRIDE threat model artifact for the Secure TDD framework. It serves as both the active threat model for the framework's components (such as the security gate hooks and runtime execution) and an exemplar reference for how Phase A outputs guide downstream Phase B tests.

---

## 1. System Overview & Deployment Intent
- **System**: Secure TDD Agent Framework & Security Gate
- **Deployment Intent**: `Intent: PRODUCTION`
- **Scope**: Local pre-commit/pre-push hooks, agent skill execution boundaries, and developer workspace security.

---

## 2. Entry Points & Asset Inventory

| Entry Point | Data Source | Trust Level | Description |
| :--- | :--- | :--- | :--- |
| **`tool_input.command`** | AI Agent / CLI harness | Semi-trusted | Terminal command string invoked by the agent. |
| **`git diff` output** | Local repository state | Trusted format | List of changed files staged for commit or push. |
| **Scanner CLI Output** | `semgrep` / `cm` CLI | Semi-trusted | JSON output from local SAST tools. Must verify scanner health (T1). |
| **Environment Config** | Shell environment / settings | Trusted local | `SECURITY_GATE_*` variables governing severity thresholds. |
| **Audit Log File** | Local file system (`.security-gate/`) | Non-tamper-evident | Append-only JSONL log of gate outcomes. |

---

## 3. Trust Boundaries

- **B1: Local Agent Execution vs Remote VCS**: The local hook is frontline feedback. Server-side CI remains the authoritative gate.
- **B2: Scanner Execution vs Scanner Failure**: A scanner crash, missing binary, or syntax error must NEVER be treated as "0 findings" (silent pass). It must trigger an explicit `ERROR` outcome.
- **B3: Blocking vs Advisory Severity**: Findings at/above `SECURITY_GATE_BLOCK_SEVERITY` (default: `HIGH`/`ERROR`) block push until remediated; findings below threshold are advisory.
- **B4: Automated Fix vs Verified Fix**: A fix is only valid when regression tests pass and a fresh local scan verifies the finding is closed.

---

## 4. STRIDE Threat Matrix

| STRIDE Category | Threat ID | Scenario | Mitigation in this Framework |
| :--- | :--- | :--- | :--- |
| **Spoofing** | T1 | Scanner binary spoofing or unauthenticated CLI failures silently bypassing gate. | Explicit check for scanner binary existence; failures route to `ERROR` and deny by default (`SECURITY_GATE_ALLOW_ON_ERROR=false`). |
| **Tampering** | T2 | Filenames containing spaces, quotes, or glob characters breaking shell iteration. | Strict newline-delimited safe array processing (`read_lines_into_array`). |
| **Repudiation** | T3 | Suppressions or gate bypasses executed without audit records. | Append-only telemetry log (`.security-gate/findings-log.ndjson`) recording timestamp, commit hash, actor, and outcome. |
| **Information Disclosure** | T4 | Plaintext secrets or credentials committed in code or leaked in error traces. | Deterministic local secret scanning in Phase D; gate blocks credentials in diffs. |
| **Denial of Service** | T5 | Scanner hanging or infinite auto-fix retry loops stalling the developer. | Strict timeouts (120s max) and capped retry counters (`SECURITY_GATE_MAX_RETRIES=1`). |
| **Elevation of Privilege** | T6 | Agent executing unapproved system commands via shell expansion. | Sandboxed execution permissions and strict `shell=False` subprocess invocations. |

---

## 5. Security Acceptance Criteria (Downstream Test Drivers)

The following criteria MUST be asserted in Phase B test suites:
1. Scanner absence or exit failure produces `deny` and exits with an error status.
2. High-severity findings block the push unless remediated.
3. Successful fixes must pass both unit tests and a secondary scan before approval.
4. Spaces or unusual characters in file paths must not cause command execution errors.
