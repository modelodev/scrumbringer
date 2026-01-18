# Story ref3-005: Splits críticos (>500 líneas) — Phase 5

## Status: Done (completed via ref3-005A..F)

## Story
**As a** maintainer,
**I want** to split critical large files into feature‑scoped modules,
**so that** code size and complexity are reduced per hygiene rules.

## Acceptance Criteria
1. Each critical file is split into smaller modules following the new architecture.
2. No module exceeds 100 lines unless explicitly justified in `////` docs.
3. Module docs (`////`) and public function docs (`///`) are present in all new modules.
4. All tests pass after refactor.

## Tasks / Subtasks

### 0. Scaffold feature directory structure (prerequisite)
- [ ] Create client feature directories:
  ```
  apps/client/src/scrumbringer_client/
  ├── features/
  │   ├── pool/
  │   ├── my_bar/
  │   ├── tasks/
  │   ├── admin/
  │   ├── auth/
  │   ├── invites/
  │   ├── now_working/
  │   ├── projects/
  │   ├── capabilities/
  │   ├── task_types/
  │   └── i18n/
  ├── app/
  │   └── effects.gleam
  └── ui/
  ```
- [ ] Create server directories (if needed):
  ```
  apps/server/src/scrumbringer_server/
  ├── persistence/
  │   ├── tasks/
  │   └── auth/
  └── services/
      └── workflows/
  ```

### 1. Split client view (3667 lines)
- [ ] `apps/client/src/scrumbringer_client/client_view.gleam` → feature views:
  - [ ] `features/pool/view.gleam`
  - [ ] `features/my_bar/view.gleam`
  - [ ] `features/tasks/view.gleam`
  - [ ] `features/admin/view.gleam`
  - [ ] `features/auth/view.gleam` (login, forgot password)
  - [ ] `features/invites/view.gleam`
  - [ ] `features/now_working/view.gleam`
  - [ ] `features/projects/view.gleam`
  - [ ] `ui/layout.gleam` (shared layout components)
  - [ ] `ui/toast.gleam` (toast notifications)

### 2. Split client state (733 lines)
- [ ] `apps/client/src/scrumbringer_client/client_state.gleam` → feature models:
  - [ ] `features/pool/model.gleam`
  - [ ] `features/my_bar/model.gleam`
  - [ ] `features/tasks/model.gleam`
  - [ ] `features/admin/model.gleam`
  - [ ] `features/auth/model.gleam`
  - [ ] `features/invites/model.gleam`
  - [ ] `features/now_working/model.gleam`
  - [ ] `features/projects/model.gleam`
  - [ ] `app/model.gleam` (root model composing features)

### 3. Split client update (2276 lines)
- [ ] `apps/client/src/scrumbringer_client/client_update.gleam` → feature updates:
  - [ ] Move existing `client_workflows/*` to `features/*/update.gleam`
  - [ ] Create `app/update.gleam` (root dispatcher)
  - [ ] Keep `client_update.gleam` as thin dispatcher or delete

### 4. Split server HTTP tasks (711 lines)
- [ ] `apps/server/src/scrumbringer_server/http/tasks.gleam` → sub-handlers:
  - [ ] Review existing `http/tasks/*.gleam` (validators, filters, presenters, conflict_handlers)
  - [ ] Extract remaining handlers to new modules if needed

### 5. Split tasks DB (513 lines)
- [ ] `apps/server/src/scrumbringer_server/services/tasks_db.gleam` → persistence modules:
  - [ ] `persistence/tasks/queries.gleam`
  - [ ] `persistence/tasks/mappers.gleam`

### 6. Split remaining critical files
- [ ] `apps/server/src/scrumbringer_server/services/task_workflow_actor.gleam` (597 lines)
  - [ ] → `services/workflows/task_workflow.gleam` (phases split if needed)
- [ ] `apps/client/src/scrumbringer_client/client_workflows/admin.gleam` (589 lines)
  - [ ] → `features/admin/update.gleam` + sub-modules
- [ ] `apps/client/src/scrumbringer_client/update_helpers.gleam` (554 lines)
  - [ ] → `app/effects.gleam` + feature-specific helpers
- [ ] `apps/server/src/scrumbringer_server/services/auth_db.gleam` (438 lines)
  - [ ] → `persistence/auth/queries.gleam` + `persistence/auth/mappers.gleam`
- [ ] `apps/client/src/scrumbringer_client/api/tasks.gleam` (725 lines)
  - [ ] → `api/tasks/decoders.gleam` + `api/tasks/requests.gleam`

### Verification
- [ ] Run `gleam test`
- [ ] Run `make test`
- [ ] Verify no file >100 lines without justification

## Dev Notes
- **Exempt:** `apps/server/src/scrumbringer_server/sql.gleam` (Squirrel-generated)
- Source of truth: `docs/sprint-3-backlog.md` → Critical (>500 lines) section
- Scaffolding MUST happen before moving code to avoid import errors
- Use `////` docs in every new module explaining its purpose

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Created ref3-005 story from Sprint 3 backlog | assistant |
| 2026-01-17 | 0.2 | Added scaffolding as first sub-step | assistant |

## Dev Agent Record

## QA Results
