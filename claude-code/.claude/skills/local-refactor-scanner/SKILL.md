---
name: local-refactor-scanner
description: Refactors code for quality and maintainability, executes full test suite regression passes, and runs local deterministic security/lint scans (Phase D: REFACTOR).
---

# Code Refactoring, Quality & Local Scanner Skill (Phase D: REFACTOR Phase)

## Overview
Refactor implementation for clean code structure, modularity, and maintainability while ensuring 100% passing test regressions and blocking pattern-based security flaws locally prior to commit.

## Verification Guardrails
1. **Code Quality & Refactoring**: Clean up boilerplate, eliminate dead code, improve modularity and naming.
2. **Deterministic Scans**: Check for hardcoded secrets, unpinned dependencies/CVEs, and local SAST rules (`semgrep scan --config auto --json`).
3. **Guided AI Review**: Check design issues, helper reuse, and business logic edge cases.
4. **Small Diffs & High Stability**: Re-run the complete test suite to confirm zero regressions.

