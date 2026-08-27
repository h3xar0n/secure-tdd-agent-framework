---
name: skill-evolution-updater
description: Extracts systemic lessons from local remediations and updates CONTEXT.md and SKILL.md specs.
---

# Skill Evolution Updater Skill (Continuous Evolution)

## Overview
Ensure the agent continuously learns from local fixes and refactoring so that systemic mistakes are never repeated in future agent cycles.

## Execution Sequence
1. Analyze the completed remediation diff.
2. Extract the actionable systemic rule (e.g. approved helper or pattern).
3. Append the rule to `CONTEXT.md` under `## 4. Continuous Evolution: Auto-Evolved Conventions`.
4. Update skills or rules if general anti-patterns were caught.
