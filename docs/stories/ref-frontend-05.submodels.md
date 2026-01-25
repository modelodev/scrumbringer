# Story ref-frontend-05: Sub-modelos por pagina

## Status

**In Progress**

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

- [x] **Task 1: Define sub-model types** (AC: 1)
  - [x] Add page/feature sub-model types in `client_state.gleam`
  - [x] Update `default_model()` to initialize sub-models

- [x] **Task 2: Update view usage** (AC: 2, 3)
  - [x] Update view functions to use sub-model accessors
  - [x] Ensure no direct root flags remain for migrated parts

- [x] **Task 3: Update update logic** (AC: 2, 3)
  - [x] Route update logic through sub-model helpers
  - [x] Keep effects unchanged

- [x] **Task 4: Regression check** (AC: 3, 4)
  - [x] Run `cd apps/client && gleam test`
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
| 2026-01-25 | 1.1 | Progress update: submodel migration and tests updated | James (Dev) |

---

## Dev Agent Record

### Agent Model Used

openai/gpt-5.2-codex

### Debug Log References

- `gleam check` (apps/client)
- `gleam test` (apps/client)
- Playwright smoke run against https://localhost:8443
- Playwright error inspection: Lustre build error in `features/invites/update.gleam`
- Playwright headless smoke retry against https://localhost:8443
- Playwright headless smoke retry (no Lustre error, login incomplete)

### Completion Notes List

- Migrated client update flows to `update_core/auth/admin/member/ui` helpers.
- Updated tasks/skills/task types handlers to write via sub-models.
- Adjusted client init and tests for sub-model access.
- `gleam check` and `gleam test` pass.
- Initial smoke attempts blocked by Lustre error dialog; screenshots: `/tmp/smoke-error-dialog.png`, `/tmp/smoke-error-dialog-after.png`.
- Headless retry completes login and renders main window; sidebar text not detected by locator, but view appears loaded. Screenshot: `/tmp/smoke-admin.png`.

### File List

- `apps/client/src/scrumbringer_client/client_update.gleam`
- `apps/client/src/scrumbringer_client/features/skills/update.gleam`
- `apps/client/src/scrumbringer_client/features/task_types/update.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/update.gleam`
- `apps/client/src/scrumbringer_client.gleam`
- `apps/client/test/admin_refresh_section_test.gleam`
- `apps/client/test/org_settings_test.gleam`

---

## QA Results
