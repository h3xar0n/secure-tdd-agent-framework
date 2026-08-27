---
name: skill-evolution-updater
description: Extracts systemic conventions from resolved bugs, patterns, and refactors to update CONTEXT.md and agent skills (Continuous Evolution).
---

# Skill & Conventions Evolution Updater (Continuous Evolution)

## Overview
Ensure the development team and agent fleet continuously learn from local fixes, architecture decisions, and refactoring patterns so that systemic quality and security standards are retained permanently.

## Execution Sequence
1. Analyze the completed feature implementation or bug fix diff.
2. Extract the actionable systemic rule (e.g. approved helper or pattern).
3. Append the rule to `CONTEXT.md` under `## 4. Continuous Evolution: Auto-Evolved Conventions`.
4. Update skills or rules if general conventions or anti-patterns were refined.

