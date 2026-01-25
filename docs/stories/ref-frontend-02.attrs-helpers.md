# Story ref-frontend-02: Helpers de attrs y clases

## Status

**Review**

---

## Story

**As a** maintainer,
**I want** to centralize repeated attributes and class patterns into shared helpers,
**so that** UI views are more consistent and reusable across features.

---

## Acceptance Criteria

1. A shared module for attributes/classes exists (e.g. `ui/attrs.gleam`).
2. At least three views use the new helpers instead of local duplicates.
3. No visual changes are introduced.
4. Helpers are pure and reusable (no feature-specific logic).

---

## Tasks / Subtasks

- [x] **Task 1: Create attrs helpers module** (AC: 1, 4)
  - [x] Add `apps/client/src/scrumbringer_client/ui/attrs.gleam`
  - [x] Define helpers for common class lists and attributes

- [x] **Task 2: Migrate existing views** (AC: 2, 3)
  - [x] Replace local class/attr duplication in 3+ views
  - [x] Keep view output identical

- [x] **Task 3: Regression check** (AC: 3)
  - [x] Run `cd apps/client && gleam test`
  - [x] Smoke check key screens (pool/admin)

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── ui/
├── client_view.gleam
└── features/*/view.gleam
```

### Standards and Constraints

- Prefer view functions and shared UI helpers over inline duplication.
- Keep helpers generic and reuse across features.

Reference: `docs/architecture/coding-standards.md` (UI components and DRY rules).

---

## Testing

- `cd apps/client && gleam test`

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-25 | 1.0 | Ready story created | Sarah (PO) |
| 2026-01-25 | 1.1 | Migrated section wrappers to attrs helpers | James (Dev) |

---

## QA Results
