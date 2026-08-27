---
name: local-refactor-scanner
description: Executes deterministic scans and guided AI audits locally on diffs prior to commit.
---

# Local Refactor & Scanner Skill (Phase D: Refactor & Secure)

## Overview
Validate code quality, eliminate redundancies, and block pattern-based flaws locally prior to code commit. Ensure fixes are isolated into minimal, surgical diffs that preserve baseline stability.

## Verification Guardrails
1. **Deterministic Scans**: Secrets check, dependency CVE audit, local SAST (`semgrep scan --config auto --json`).
2. **Guided AI Review**: Check design issues, centralize helpers, review business logic for bypasses.
3. **Small Diffs & High Stability**: Re-run the complete test suite to confirm zero regressions.
