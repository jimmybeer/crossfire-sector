# Data Dictionary

This document captures gameplay entities and their schemas for synchronization across rules, architecture, and engine assets. Update each entity entry to reflect the latest requirements and technical constraints.

## Linked Table of Contents
- [Template Entity](#template-entity)

## Template Entity [Back to TOC](#linked-table-of-contents)

**Purpose:** One- to two-sentence summary of the entity’s gameplay or system role.

**Schema:**

| Field | Type | Required | Default | Constraints/Notes |
| --- | --- | --- | --- | --- |
| field_name | type | Yes/No | default | Brief constraint, validation, or engine mapping detail. |

**Relationships:**
- Reference or linkage details (cardinality, ownership, identifier expectations).

**Versioning & Migration:**
- Current schema version and change history, plus migration steps for downstream assets.

**Traceability:**
- Requirement and architecture references (IDs or section links) showing alignment.

**Sync Strategy:**
- Steps to keep JSON data and Godot resources in sync, including validation or automation hooks.

**Open Questions / TODOs:**
- Outstanding clarifications or follow-ups.
