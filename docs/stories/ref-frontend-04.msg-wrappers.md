# Story ref-frontend-04: Msg wrappers por feature

## Status

**Ready**

---

## Story

**As a** maintainer,
**I want** to group messages by feature using wrapper Msg types,
**so that** the root update is smaller and feature logic is better isolated.

---

## Acceptance Criteria

1. Feature wrapper Msg types exist (e.g. `AdminMsg`, `AuthMsg`, `PoolMsg`).
2. `client_update.gleam` delegates to per-feature update functions.
3. `client_view.gleam` and feature views emit the wrapper Msgs consistently.
4. Navigation and core flows (login, pool, admin) behave the same.

---

## Tasks / Subtasks

- [ ] **Task 1: Define wrapper Msg types** (AC: 1)
  - [ ] Update `client_state.gleam` Msg with feature wrappers
  - [ ] Define mapping helpers for wrapper Msgs

- [ ] **Task 2: Refactor update delegation** (AC: 2)
  - [ ] Split per-feature update functions
  - [ ] Route wrapper Msgs to feature updates

- [ ] **Task 3: Update view dispatch** (AC: 3)
  - [ ] Wrap feature messages in views and event handlers
  - [ ] Ensure no mixed Msg types remain

- [ ] **Task 4: Regression check** (AC: 4)
  - [ ] Run `cd apps/client && gleam test`
  - [ ] Smoke check login, pool, admin routes

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── client_state.gleam
├── client_update.gleam
├── client_view.gleam
└── features/*/update.gleam
```

### Standards and Constraints

- Keep Msgs aligned with user actions and server responses.
- Prefer small `handle_*` functions per feature to reduce branching.
- Maintain explicit TEA separation (model/msg/update/view).

Reference: `docs/architecture/coding-standards.md` (Lustre patterns and small handlers).

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
