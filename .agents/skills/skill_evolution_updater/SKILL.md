# Skill Evolution Updater Skill (Continuous Evolution)

## Overview
Ensure the agent continuously learns from local fixes, refactoring decisions, and caught flaws so that systemic mistakes are never repeated in future agent cycles.

## Continuous Feedback Mechanism
```
+-----------------------------------------------------------------+
|                    CONTINUOUS FEEDBACK LOOP                     |
|                                                                 |
|   1. Local Fix Applied & Verified (Refactor Phase)              |
|                               v                                 |
|   2. Systemic Lesson Extracted (Block classes of bugs)          |
|                               v                                 |
|   3. Feed Back to Shared Specs (Update SKILL.md/CONTEXT.md)     |
|                               v                                 |
|   4. Context Seeding (All future agents inherit rules upfront)  |
+-----------------------------------------------------------------+
```

## Execution Sequence
1. **Analyze Remediation Diff**: Review the code change or bug fix just completed.
2. **Extract the Systemic Rule**:
   - Formulate an actionable, project-specific rule.
   - Example: *"When implementing redirects, always use `utils.security.safe_redirect()` with allow-listed domains."*
   - Example: *"All JSON endpoints must validate request body using Pydantic schemas."*
3. **Update Shared Specifications**:
   - **Update `CONTEXT.md`**: Append the rule under `## 4. Continuous Evolution: Auto-Evolved Conventions`.
   - **Update Skills (if applicable)**: If a general coding anti-pattern was caught, add a negative check rule to `defensive_developer/SKILL.md`.
4. **Persist Insight**: Append the raw structured event to `.security-gate/findings-log.ndjson` for audit traceability.
