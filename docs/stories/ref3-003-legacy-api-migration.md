# Story ref3-003: Migración legacy api.gleam → api/* — Phase 3

## Status: Draft

## Story
**As a** maintainer,
**I want** to remove the legacy `client/api.gleam` entrypoint,
**so that** API types and calls live only in `client/api/*` modules.

## Acceptance Criteria
1. All importers of `client/api.gleam` are migrated to `client/api/*` modules.
2. `client/api.gleam` is deleted and no longer referenced.
3. Client code compiles and tests pass.

## Tasks / Subtasks

### Migrate all importers (16 verified files)

Files importing `scrumbringer_client/api` directly:

- [ ] `apps/client/src/scrumbringer_client.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_state.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_update.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_view.gleam`
- [ ] `apps/client/src/scrumbringer_client/update_helpers.gleam`
- [ ] `apps/client/src/scrumbringer_client/permissions.gleam` (imports `api.{type Project, Project}`)
- [ ] `apps/client/src/scrumbringer_client/accept_invite.gleam`
- [ ] `apps/client/src/scrumbringer_client/reset_password.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_workflows/admin.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_workflows/auth.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_workflows/capabilities.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_workflows/invite_links.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_workflows/now_working.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_workflows/projects.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_workflows/task_types.gleam`
- [ ] `apps/client/src/scrumbringer_client/client_workflows/tasks.gleam`

### Remove legacy entrypoint
- [ ] Delete `apps/client/src/scrumbringer_client/api.gleam`
- [ ] Verify no imports remain: `grep -r "import scrumbringer_client/api$" apps/`

### Verification
- [ ] Run `gleam test`
- [ ] Run `make test`

## Dev Notes
- **Verified via grep:** `grep -rln "import scrumbringer_client/api$" apps/client/src/`
- `router.gleam` and `hydration.gleam` do NOT import legacy `api.gleam` — excluded
- Do not change runtime behavior; this is a migration-only task
- After ref3-002, types come from `shared/domain`; decoders stay in `api/*`

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Created ref3-003 story from Sprint 3 backlog | assistant |
| 2026-01-17 | 0.2 | Fixed importer count to 16 (verified via grep) | assistant |

## Dev Agent Record

## QA Results
