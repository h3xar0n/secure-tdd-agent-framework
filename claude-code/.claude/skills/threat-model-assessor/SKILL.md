---
name: threat-model-assessor
description: Plans feature architecture, functional requirements, and evaluates STRIDE security boundaries (Phase A: Plan).
---

# Planning, Requirements & Threat Model Assessor Skill (Phase A: Plan Phase)

## Overview
Decompose feature requirements, establish functional acceptance criteria, and map trust boundaries before any production code is authored. This skill pairs functional engineering scoping with STRIDE threat modeling at the planning stage, establishing the functional and security acceptance criteria consumed by downstream test writers.

## System Sequence
1. **Ingest Context**: Read `CONTEXT.md` to identify existing architecture, trust boundaries, approved libraries, and conventions.
2. **Decompose Requirements**: Define user stories, input/output contracts, and functional acceptance criteria. Break complex tasks into testable implementation stages.
3. **Apply STRIDE Threat Modeling**:
   - **Spoofing**: Authentication boundaries, session validation, caller identity checks.
   - **Tampering**: Input payload validation, integrity checks, parameter tampering.
   - **Repudiation**: Audit logging of critical state transitions.
   - **Information Disclosure**: Restrict error responses, prevent stack trace leaks, mask PII/secrets.
   - **Denial of Service**: Resource limits, payload size constraints, timeout limits.
   - **Elevation of Privilege**: Role-Based Access Control (RBAC), caller authorization checks.
4. **Generate/Update `threat_model.md`**:
   - Store or update `threat_model.md` at the workspace root with both Functional & Security Acceptance Criteria.

