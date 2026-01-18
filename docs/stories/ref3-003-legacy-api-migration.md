# Story ref3-003: Migración legacy api.gleam → api/* — Phase 3

## Status: Done

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

- [x] `apps/client/src/scrumbringer_client.gleam`
- [x] `apps/client/src/scrumbringer_client/client_state.gleam`
- [x] `apps/client/src/scrumbringer_client/client_update.gleam`
- [x] `apps/client/src/scrumbringer_client/client_view.gleam`
- [x] `apps/client/src/scrumbringer_client/update_helpers.gleam`
- [x] `apps/client/src/scrumbringer_client/permissions.gleam` (imports `api.{type Project, Project}`)
- [x] `apps/client/src/scrumbringer_client/accept_invite.gleam`
- [x] `apps/client/src/scrumbringer_client/reset_password.gleam`
- [x] `apps/client/src/scrumbringer_client/client_workflows/admin.gleam`
- [x] `apps/client/src/scrumbringer_client/client_workflows/auth.gleam`
- [x] `apps/client/src/scrumbringer_client/client_workflows/capabilities.gleam`
- [x] `apps/client/src/scrumbringer_client/client_workflows/invite_links.gleam`
- [x] `apps/client/src/scrumbringer_client/client_workflows/now_working.gleam`
- [x] `apps/client/src/scrumbringer_client/client_workflows/projects.gleam`
- [x] `apps/client/src/scrumbringer_client/client_workflows/task_types.gleam`
- [x] `apps/client/src/scrumbringer_client/client_workflows/tasks.gleam`

### Migrate test files (10 files discovered during implementation)

- [x] `apps/client/test/client_state_test.gleam`
- [x] `apps/client/test/api_decode_active_task_test.gleam`
- [x] `apps/client/test/reset_password_test.gleam`
- [x] `apps/client/test/accept_invite_test.gleam`
- [x] `apps/client/test/api_csrf_test.gleam`
- [x] `apps/client/test/permissions_test.gleam`
- [x] `apps/client/test/api_decode_task_enriched_test.gleam`
- [x] `apps/client/test/api_decode_user_test.gleam`
- [x] `apps/client/test/api_decode_invite_links_test.gleam`
- [x] `apps/client/test/api_tasks_url_test.gleam`

### Remove legacy entrypoint
- [x] Delete `apps/client/src/scrumbringer_client/api.gleam`
- [x] Verify no imports remain: `grep -r "import scrumbringer_client/api$" apps/`

### Verification
- [x] Run `gleam test` (82 tests pass)
- [ ] Run `make test` (server tests are independent integration tests requiring DB)

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

### 2026-01-17 Implementation Session

**Migration Summary:**
- Migrated 16 source files + 10 test files from legacy `api.gleam` imports
- Discovered `Capability` type lives in `domain/capability`, not `domain/org`
- Fixed missing constructor imports (Task, TaskNote, TaskFilters, TaskPosition)
- Fixed `create_task_type` function location (in `api/tasks`, not `api/projects`)
- Deleted legacy `apps/client/src/scrumbringer_client/api.gleam`

**Import Pattern Changes:**
- Types: `api.TypeName` → direct import from `domain/*` (e.g., `import domain/task.{Task}`)
- Functions: `api.function_name()` → `api_module.function_name()` (e.g., `api_tasks.claim_task()`)
- Doc comments updated to reference new module paths

**Test Results:**
- Client tests: 82 passed, 0 failures
- Server tests: Independent integration tests (require DB setup)

**Files Changed:** 26 files (16 src + 10 test)

## QA Results

### Gate Decision: PASS

**Reviewed by:** Quinn (QA Agent)
**Date:** 2026-01-17
**Gate file:** `docs/qa/gates/ref3-003-legacy-api-migration.yml`

### Acceptance Criteria Verification

| # | Criterion | Status |
|---|-----------|--------|
| 1 | All importers migrated to client/api/* modules | ✅ PASS |
| 2 | client/api.gleam deleted and no longer referenced | ✅ PASS |
| 3 | Client code compiles and tests pass | ✅ PASS |

### Evidence

- **No legacy imports remain:** `grep -r "import scrumbringer_client/api$" apps/` returns zero matches
- **Legacy file deleted:** `apps/client/src/scrumbringer_client/api.gleam` no longer exists
- **Tests pass:** 82/82 client tests pass
- **Files migrated:** 26 total (16 source + 10 test)

### Code Quality Notes

- Import patterns correctly follow convention: types from `domain/*`, functions from `api/*`
- Two minor unused import warnings in `client_update.gleam` (cosmetic, non-blocking)
- No runtime behavior changes — migration only

### Recommendation

Story is ready to merge. Migration complete with all acceptance criteria verified.
