# Story ref-frontend-05: Sub-modelos por pagina

## Status

**Ready**

---

## Story

**As a** maintainer,
**I want** to split the root Model into sub-models by page/feature,
**so that** state is clearer and reduces boolean-driven complexity.

---

## Acceptance Criteria

1. Root Model uses sub-models per page (e.g. AdminModel, PoolModel, AuthModel).
2. Update and view functions read/write sub-models consistently.
3. No behavior changes in routing or page rendering.
4. State initialization remains deterministic and complete.

---

## Tasks / Subtasks

- [ ] **Task 1: Define sub-model types** (AC: 1)
  - [ ] Add page/feature sub-model types in `client_state.gleam`
  - [ ] Update `default_model()` to initialize sub-models

- [ ] **Task 2: Update view usage** (AC: 2, 3)
  - [ ] Update view functions to use sub-model accessors
  - [ ] Ensure no direct root flags remain for migrated parts

- [ ] **Task 3: Update update logic** (AC: 2, 3)
  - [ ] Route update logic through sub-model helpers
  - [ ] Keep effects unchanged

- [ ] **Task 4: Regression check** (AC: 3, 4)
  - [ ] Run `cd apps/client && gleam test`
  - [ ] Smoke check navigation between key pages

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── client_state.gleam
├── client_update.gleam
├── client_view.gleam
└── features/*
```

### Standards and Constraints

- Prefer ADTs over scattered boolean flags.
- Keep state updates in model helpers where possible.
- Avoid routing logic outside `router.gleam`.

Reference: `docs/architecture/coding-standards.md` (TEA split and model helpers).

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
