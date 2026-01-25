# Story ref-frontend-03: Consolidar UI reusable

## Status

**Ready**

---

## Story

**As a** maintainer,
**I want** to consolidate repeated view-only UI blocks into `ui/*` modules,
**so that** the codebase maximizes reuse and minimizes per-feature duplication.

---

## Acceptance Criteria

1. Repeated view-only UI blocks are extracted into `apps/client/src/scrumbringer_client/ui/*`.
2. Feature-local duplicates are removed or replaced with the shared UI modules.
3. No new stateful components are introduced; view functions remain stateless.
4. Visual output is unchanged.

---

## Tasks / Subtasks

- [ ] **Task 1: Identify duplicate view-only blocks** (AC: 1, 2)
  - [ ] Scan `features/*/view.gleam` for repeated UI patterns
  - [ ] Confirm existing `ui/*` coverage before creating new helpers

- [ ] **Task 2: Extract or consolidate UI blocks** (AC: 1, 2, 3, 4)
  - [ ] Create or extend modules in `ui/*`
  - [ ] Replace duplicates in features with shared UI functions

- [ ] **Task 3: Regression check** (AC: 4)
  - [ ] Run `cd apps/client && gleam test`
  - [ ] Spot check views that were refactored

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── ui/
└── features/*/view.gleam
```

### Standards and Constraints

- Prefer view functions over components unless internal state is needed.
- Use existing UI modules (section_header, data_table, dialog, toast, icons) instead of ad-hoc UI.
- Keep view functions pure (no effects).

Reference: `docs/architecture/coding-standards.md` (UI components and reuse rules).

---

## Testing

- `cd apps/client && gleam test`

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-25 | 1.0 | Ready story created | Sarah (PO) |

---

## QA Results
