# Story ref-frontend-07: Helpers de efectos comunes

## Status

**Ready**

---

## Story

**As a** maintainer,
**I want** shared helpers for debounce, timers, and storage effects,
**so that** effect usage is consistent and reusable across features.

---

## Acceptance Criteria

1. Shared helpers exist for debounce, timers, and storage effects in `app/effects.gleam`.
2. At least two features migrate to the new helpers.
3. Behavior of timers and debounce remains unchanged.

---

## Tasks / Subtasks

- [ ] **Task 1: Add shared effect helpers** (AC: 1)
  - [ ] Extend `apps/client/src/scrumbringer_client/app/effects.gleam`
  - [ ] Add helpers for debounce, timers, and storage get/set

- [ ] **Task 2: Migrate feature usage** (AC: 2, 3)
  - [ ] Migrate pool search debounce to helper
  - [ ] Migrate now_working or toast timers to helper

- [ ] **Task 3: Regression check** (AC: 3)
  - [ ] Run `cd apps/client && gleam test`
  - [ ] Smoke check debounce + timer behavior

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── app/effects.gleam
├── features/pool/
└── features/now_working/
```

### Standards and Constraints

- All side effects should remain in update/app effects.
- Keep effects isolated from view code.

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
