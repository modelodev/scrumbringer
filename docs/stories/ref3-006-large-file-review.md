# Story ref3-006: Revisión y splits de archivos grandes (101–500 líneas) — Phase 6

## Status: Draft

## Story
**As a** maintainer,
**I want** to review and refactor large files (101–500 lines),
**so that** we comply with hygiene rules and reduce complexity.

## Acceptance Criteria
1. Each file in scope is either split or explicitly justified in `////` docs.
2. Missing `////` docs are added where required.
3. No public API is changed inadvertently.
4. Tests pass.

## Tasks / Subtasks

### Server (101–500 lines)
- [ ] `server/http/metrics_service.gleam` — Review size, justify or split
- [ ] `server/http/projects.gleam` — Add docs, review size
- [ ] `server/http/password_resets.gleam` — Add docs, review size
- [ ] `server/http/auth.gleam` — Add docs, review size
- [ ] `server/services/projects_db.gleam` — Add docs
- [ ] `server/services/auth_logic.gleam` — Add docs
- [ ] `server/http/task_positions.gleam` — Add docs
- [ ] `server/services/org_invite_links_db.gleam` — Add docs
- [ ] `server/domain/task_status.gleam` — Re-export from shared domain
- [ ] `server/http/org_users.gleam` — Add docs
- [ ] `server/http/capabilities.gleam` — Add docs
- [ ] `server/services/org_users_db.gleam` — Add docs
- [ ] `server/services/now_working_db.gleam` — Add docs
- [ ] `server/services/password_resets_db.gleam` — Add docs
- [ ] `server/scrumbringer_server.gleam` — Add docs
- [ ] `server/http/org_invite_links.gleam` — Add docs
- [ ] `server/services/store.gleam` — Add docs
- [ ] `server/http/task_notes.gleam` — Add docs
- [ ] `server/services/jwt.gleam` — Add docs
- [ ] `server/services/user_capabilities_db.gleam` — Add docs
- [ ] `server/services/task_types_db.gleam` — Add docs
- [ ] `server/http/me_metrics.gleam` — Add docs

### Client (101–500 lines)
- [ ] `client/client_workflows/tasks.gleam` — Review, split to `features/tasks/update.gleam`
- [ ] `client/api/metrics.gleam` — Review, use shared domain
- [ ] `client/client_workflows/auth.gleam` — Review, split to `features/auth/update.gleam`
- [ ] `client/client_ffi.gleam` — Review, split to `ffi/*.gleam`
- [ ] `client/router.gleam` — Review, move to `app/router.gleam`
- [ ] `client/scrumbringer_client.gleam` — Review, move to `app/main.gleam`
- [ ] `client/i18n/es.gleam` — Add docs
- [ ] `client/i18n/en.gleam` — Add docs
- [ ] `client/client_workflows/invite_links.gleam` — Review, split to `features/invites/update.gleam`
- [ ] `client/client_workflows/now_working.gleam` — Review, split to `features/now_working/update.gleam`
- [ ] `client/api/org.gleam` — Review, use shared domain
- [ ] `client/i18n/text.gleam` — Add docs
- [ ] `client/api/auth.gleam` — Review, use shared domain
- [ ] `client/api/core.gleam` — Review, use shared domain
- [ ] `client/client_workflows/projects.gleam` — Review, split to `features/projects/update.gleam`
- [ ] `client/client_workflows/task_types.gleam` — Review, split to `features/task_types/update.gleam`
- [ ] `client/hydration.gleam` — Review, move to `app/hydration.gleam`
- [ ] `client/accept_invite.gleam` — Add docs
- [ ] `client/reset_password.gleam` — Add docs
- [ ] `client/client_workflows/capabilities.gleam` — OK, confirm no split needed
- [ ] `client/api/projects.gleam` — OK, ensure shared domain
- [ ] `client/styles.gleam` — Add docs
- [ ] `client/theme.gleam` — Add docs

### Verification
- [ ] Run `gleam test`
- [ ] Run `make test`

## Dev Notes
- Source of truth: `docs/sprint-3-backlog.md` → Large (101–500 lines) section.
- If a file is kept >100 lines, justify in `////` docs.

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Created ref3-006 story from Sprint 3 backlog | assistant |

## Dev Agent Record

## QA Results
