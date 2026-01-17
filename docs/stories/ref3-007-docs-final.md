# Story ref3-007: Cierre final de higiene (post-refactor docs)

## Status: Draft

## Story
**As a** maintainer,
**I want** to finalize documentation for all files created/moved during phases 2-6,
**so that** the entire repo meets Sprint 3 documentation standards.

## Scope Clarification
- **ref3-001:** Initial docs for files that WON'T move (done first).
- **This story:** Final docs for files that WERE moved/created during refactor phases.
- **Why separate:** Files created in ref3-005 need docs; files split from large modules need docs in new locations.

## Acceptance Criteria
1. All new modules created in phases 2-6 have `////` module docs.
2. All public functions/types in these modules have `///` docs with examples.
3. No functional changes are introduced.
4. Tests pass.

## Tasks / Subtasks

### New shared/domain modules (from ref3-002)
- [ ] `shared/src/domain/task_status.gleam`
- [ ] `shared/src/domain/task.gleam`
- [ ] `shared/src/domain/project.gleam`
- [ ] `shared/src/domain/org.gleam`
- [ ] `shared/src/domain/capability.gleam`
- [ ] `shared/src/domain/metrics.gleam`
- [ ] `shared/src/domain/api_error.gleam`
- [ ] `shared/src/domain/task_type.gleam`

### New client feature modules (from ref3-005)
- [ ] All `features/*/model.gleam` files
- [ ] All `features/*/view.gleam` files
- [ ] All `features/*/update.gleam` files
- [ ] `app/model.gleam`
- [ ] `app/update.gleam`
- [ ] `app/effects.gleam`
- [ ] `ui/layout.gleam`
- [ ] `ui/toast.gleam`
- [ ] `ui/loading.gleam` (from ref3-004)
- [ ] `ui/error.gleam` (from ref3-004)

### New server modules (from ref3-005)
- [ ] `persistence/tasks/queries.gleam`
- [ ] `persistence/tasks/mappers.gleam`
- [ ] `persistence/auth/queries.gleam`
- [ ] `persistence/auth/mappers.gleam`
- [ ] `services/workflows/task_workflow.gleam`

### Files moved during refactor
- [ ] Verify docs in any files relocated from original paths
- [ ] Update module docs to reflect new location/purpose if needed

### Verification
- [ ] Run `gleam test`
- [ ] Run `make test`
- [ ] Verify all new files have `////` docs

## Dev Notes
- **Run AFTER:** ref3-002, ref3-003, ref3-004, ref3-005, ref3-006
- The exact file list will be finalized based on what was actually created during prior phases
- Only documentation changes; no behavior edits

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Created ref3-007 story from Sprint 3 backlog | assistant |
| 2026-01-17 | 0.2 | Clarified scope as post-refactor docs, updated file list | assistant |

## Dev Agent Record

## QA Results
