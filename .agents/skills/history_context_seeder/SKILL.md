# History Context Seeder Skill (Repository Onboarding)

## Overview
Analyzes the repository's Git history and past security commits to extract recurring vulnerability patterns, security fixes, and architectural conventions, seeding `CONTEXT.md` on initial setup.

## Execution Sequence
1. **Analyze Git Log**:
   - Inspect commits touching security fixes, bug patches, and authentication logic:
     `git log --grep="fix\|vuln\|CVE\|security\|patch" -n 50 --oneline`
2. **Extract Historical Lessons**:
   - Identify which files and modules have historically been prone to bugs.
   - Extract past remediation techniques used by maintainers.
3. **Seed `CONTEXT.md`**:
   - Populate `CONTEXT.md` with known architectural risk areas, sensitive directories, and custom project conventions.
