# Threat Model Assessor Skill (Phase A: Plan & Threat Model)

## Overview
Decompose feature requirements and map trust boundaries before any production code is authored. This skill enforces STRIDE threat modeling at the planning stage, establishing the security acceptance criteria consumed by downstream test writers.

## System Sequence
1. **Ingest Context**: Read `CONTEXT.md` to identify existing trust boundaries, approved libraries, and architectural conventions.
2. **Apply STRIDE Methodology**:
   - **Spoofing**: Authentication boundaries, session validation, caller identity checks.
   - **Tampering**: Input payload validation, integrity checks, parameter tampering.
   - **Repudiation**: Audit logging of security-critical state transitions.
   - **Information Disclosure**: Restrict error responses, prevent stack trace leaks, mask PII/secrets.
   - **Denial of Service**: Resource limits, payload size constraints, timeout limits.
   - **Elevation of Privilege**: Role-Based Access Control (RBAC), caller authorization checks.
3. **Generate/Update `threat_model.md`**:
   - Store or update `threat_model.md` at the workspace root.
   - Specify:
     - **Entry Points**: Target endpoints, CLI args, files, or environment parameters.
     - **Trust Boundaries**: Transitions between unauthenticated/authenticated or user/admin roles.
     - **Security Acceptance Criteria**: Specific boundary conditions that downstream tests in Phase B must assert.
4. **Decompose Tasks**: Break the feature down into bite-sized, incremental development stages.

## Target Output Artifact (`threat_model.md`)
```markdown
# Threat Model: [Feature Name]
## Entry Points & Data Inputs
- Endpoint / Input: [Path / Name]
- Format & Constraints: [Schema]

## Trust Boundaries & Access Controls
- Authentication: [Required / Public]
- Authorization Role: [User / Admin]

## STRIDE Threat Matrix & Acceptance Criteria
- [STRIDE Category]: [Threat Description] -> [Required Mitigation & Test Assertion]
```
