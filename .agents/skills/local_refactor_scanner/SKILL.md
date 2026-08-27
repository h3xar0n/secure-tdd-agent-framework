# Local Refactor & Scanner Skill (Phase D: Refactor & Secure)

## Overview
Validate code quality, eliminate redundancies, and block pattern-based flaws locally prior to code commit. Ensure fixes are isolated into minimal, surgical diffs that preserve baseline stability.

## Verification Guardrails
1. **Deterministic Scans (Fast & Offline)**:
   - **Secrets**: Check diffs for plaintext credentials, tokens, or private keys.
   - **Dependencies**: Flag unpinned dependencies or known CVEs in new packages.
   - **Rules-Based SAST**: Run local SAST rules on modified files (`semgrep scan --config auto --json` or `cm find`).
2. **Guided AI Review**:
   - Audit architecture and design issues that static AST tools miss.
   - Identify opportunities to refactor repeated logic into centralized security helpers.
   - Review business logic flows for logical bypasses or privilege escalation risks.
   - Disprove false positives using an adversarial stance (evaluating claims based strictly on code evidence).
3. **Small Diffs & High Stability**:
   - Run the complete project test suite to verify zero regressions.
   - Ensure the diff contains only targeted changes directly related to the task scope.

## Execution Sequence
1. Review the git diff of modified files (`git diff`).
2. Run local scanner on changed files.
3. Clean up boilerplate, centralize helpers, and eliminate code duplication.
4. Run the full test suite to guarantee 100% passing tests.
