---
name: history-context-seeder
description: Analyzes repository Git history for past bug fixes, architectural conventions, and security patterns to seed CONTEXT.md on onboarding. Use when first adopting the framework in an existing repository, mining historical commits and bug fixes for recurring risk areas, or populating the initial CONTEXT.md baseline with established conventions and helpers. Do not use for routine feature development, authoring test suites, or running the inner TDD loop on active tasks.
---

# History & Architectural Context Seeder Skill (Repository Onboarding)

## Overview
Analyzes the repository's Git history and past fix commits to extract recurring bug patterns, architectural conventions, and security patterns, seeding `CONTEXT.md` during initial repository onboarding.

## Execution Sequence
1. **Analyze Git Log**:
   - Inspect commits touching bug fixes, refactors, and sensitive modules:
     `git log --grep="fix\|bug\|refactor\|vuln\|security\|patch" -n 50 --oneline`
2. **Extract Historical Lessons**:
   - Identify which files and modules have historically been prone to bugs or regressions.
   - Extract past patterns and architectural conventions established by maintainers.
3. **Seed `CONTEXT.md`**:
   - Populate `CONTEXT.md` with known architectural risk areas, sensitive directories, approved helpers, and custom project conventions.

