# Story ref-frontend-08: DOM measurements con after_paint

## Status

**Ready**

---

## Story

**As a** maintainer,
**I want** DOM measurements to run via `effect.after_paint`,
**so that** layout reads happen after render and are more reliable.

---

## Acceptance Criteria

1. DOM measurement effects in pool drag/drop use `effect.after_paint`.
2. Any other measurement-based effects in client features use `after_paint` where applicable.
3. Drag/drop and layout behaviors remain unchanged.

---

## Tasks / Subtasks

- [ ] **Task 1: Identify measurement effects** (AC: 1, 2)
  - [ ] Audit pool drag/drop measurement calls
  - [ ] Audit other features using DOM measurement

- [ ] **Task 2: Apply after_paint** (AC: 1, 2, 3)
  - [ ] Wrap measurement effects with `effect.after_paint`
  - [ ] Keep effects in update/app effects

- [ ] **Task 3: Regression check** (AC: 3)
  - [ ] Run `cd apps/client && gleam test`
  - [ ] Smoke check drag/drop interactions

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── features/pool/
├── client_ffi.gleam
└── fetch.ffi.mjs
```

### Standards and Constraints

- Effects should run from update/app effects only.
- DOM reads should use `effect.after_paint` for reliability.

Reference: `docs/architecture/coding-standards.md` (effects and TEA rules).

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
