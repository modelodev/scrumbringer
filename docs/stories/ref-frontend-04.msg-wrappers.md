# Story ref-frontend-04: Msg wrappers por feature

## Status

**Review**

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

- [x] **Task 1: Define wrapper Msg types** (AC: 1)
  - [x] Update `client_state.gleam` Msg with feature wrappers
  - [x] Define mapping helpers for wrapper Msgs

- [x] **Task 2: Refactor update delegation** (AC: 2)
  - [x] Split per-feature update functions
  - [x] Route wrapper Msgs to feature updates

- [x] **Task 3: Update view dispatch** (AC: 3)
  - [x] Wrap feature messages in views and event handlers
  - [x] Ensure no mixed Msg types remain

- [x] **Task 4: Regression check** (AC: 4)
  - [x] Run `cd apps/client && gleam test`
  - [x] Smoke check login, pool, admin routes

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
| 2026-01-25 | 1.1 | Wrapped client view and update flows by feature | James (Dev) |

---

## QA Results
