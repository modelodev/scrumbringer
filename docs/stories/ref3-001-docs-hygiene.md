# Story ref3-001: Higiene de documentación (//// y ///) — Phase 1 (Quick Wins)

## Status: Draft

## Story
**As a** maintainer,
**I want** to add missing module/function documentation across small and medium modules,
**so that** the codebase meets Sprint 3 hygiene rules before refactoring begins.

## Scope Clarification
- **This story:** Initial documentation pass on files that WON'T move during later phases.
- **ref3-007:** Final cleanup for files that were moved/created during phases 2-6.
- **Why separate:** Avoids documenting files that will be deleted or split later.

## Acceptance Criteria
1. **Module docs:** Every file listed has `////` module docs at the top.
2. **Function docs:** All public functions/types include `///` with a usage example.
3. **Scope discipline:** Only documentation changes (no functional changes).
4. **Consistency:** Docs are in English and follow existing style conventions.
5. **Verification:** `gleam test` and `make test` pass after changes.

## Tasks / Subtasks

### Server ≤100 lines (14 files)
- [ ] `apps/server/src/scrumbringer_server/http/org_invites.gleam` (89)
- [ ] `apps/server/src/scrumbringer_server/http/api.gleam` (88)
- [ ] `apps/server/src/main.gleam` (76)
- [ ] `apps/server/src/scrumbringer_server/services/store_state.gleam` (75)
- [ ] `apps/server/src/scrumbringer_server/services/org_invites_db.gleam` (74)
- [ ] `apps/server/src/scrumbringer_server/services/task_positions_db.gleam` (63)
- [ ] `apps/server/src/scrumbringer_server/services/task_notes_db.gleam` (63)
- [ ] `apps/server/src/scrumbringer_server/services/capabilities_db.gleam` (62)
- [ ] `apps/server/src/scrumbringer_server/services/password.gleam` (34)
- [ ] `apps/server/src/scrumbringer_server/http/csrf.gleam` (26)
- [ ] `apps/server/src/scrumbringer_server/services/task_events_db.gleam` (22)
- [ ] `apps/server/src/scrumbringer_server/services/rate_limit.gleam` (22)
- [ ] `apps/server/src/scrumbringer_server/services/time.gleam` (14)
- [ ] `apps/server/src/scrumbringer_server/http/tasks/conflict_handlers.gleam` (89) — verify docs

### Client ≤100 lines (7 files)
- [ ] `apps/client/src/scrumbringer_client/pool_prefs.gleam` (84)
- [ ] `apps/client/src/scrumbringer_client/permissions.gleam` (75)
- [ ] `apps/client/src/scrumbringer_client/i18n/locale.gleam` (62)
- [ ] `apps/client/src/scrumbringer_client/member_section.gleam` (22)
- [ ] `apps/client/src/scrumbringer_client/member_visuals.gleam` (17)
- [ ] `apps/client/src/scrumbringer_client/i18n/i18n.gleam` (11)
- [ ] `apps/client/src/scrumbringer_client/client_workflows/i18n.gleam` (53) — verify docs

### Domain ≤100 lines (2 files)
- [ ] `packages/domain/src/scrumbringer_domain/org_role.gleam` (19)
- [ ] `packages/domain/src/scrumbringer_domain/user.gleam` (11)

### Server 101–200 lines (8 files)
- [ ] `apps/server/src/scrumbringer_server.gleam` (182)
- [ ] `apps/server/src/scrumbringer_server/http/org_invite_links.gleam` (177)
- [ ] `apps/server/src/scrumbringer_server/services/store.gleam` (151)
- [ ] `apps/server/src/scrumbringer_server/http/task_notes.gleam` (146)
- [ ] `apps/server/src/scrumbringer_server/services/jwt.gleam` (145)
- [ ] `apps/server/src/scrumbringer_server/services/user_capabilities_db.gleam` (121)
- [ ] `apps/server/src/scrumbringer_server/services/task_types_db.gleam` (107)
- [ ] `apps/server/src/scrumbringer_server/http/me_metrics.gleam` (101)

### Client 101–200 lines (4 files) — SKIP if moving in later phases
- [ ] `apps/client/src/scrumbringer_client/accept_invite.gleam` (155) — may move to features/invites/
- [ ] `apps/client/src/scrumbringer_client/reset_password.gleam` (150) — may move to features/auth/
- [ ] `apps/client/src/scrumbringer_client/styles.gleam` (124) — may move to ui/
- [ ] `apps/client/src/scrumbringer_client/theme.gleam` (105) — may move to ui/

### Public function docs
- [ ] Ensure each `pub fn` and `pub type` has a `///` doc with example

### Verification
- [ ] Run `gleam test`
- [ ] Run `make test`

## Dev Notes
- Source of truth: `docs/sprint-3-backlog.md` (Phase 1: Documentation)
- Do not change behavior; docs-only change set
- **Skip files that will move:** If a file will be split/moved in ref3-005/006, defer docs to ref3-007
- If a file already has `////`, verify completeness and add missing `///` docs only

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Created ref3-001 story from Sprint 3 backlog | assistant |
| 2026-01-17 | 0.2 | Clarified scope vs ref3-007, added real paths | assistant |

## Dev Agent Record

## QA Results
