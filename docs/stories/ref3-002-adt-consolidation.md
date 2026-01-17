# Story ref3-002: Consolidación ADT en shared/domain — Phase 2

## Status: Draft

## Story
**As a** maintainer,
**I want** a single canonical source for domain ADTs in `shared/src/domain/`,
**so that** client and server share identical types and we eliminate duplication.

## Acceptance Criteria
1. All ADTs listed in `docs/sprint-3-backlog.md` are moved/defined in `shared/src/domain/*.gleam`.
2. Client modules and server domain modules import from `shared/domain` (no duplicate definitions).
3. `api/*` modules use canonical ADTs and stop defining local equivalents.
4. All references compile and tests pass.

## Tasks / Subtasks

### Scaffold shared package
- [ ] Create `shared/` package structure:
  ```
  shared/
  ├── gleam.toml
  └── src/
      └── domain/
  ```
- [ ] Add `shared` as dependency in `apps/client/gleam.toml` and `apps/server/gleam.toml`

### Create canonical domain modules
- [ ] `shared/src/domain/task_status.gleam`
  - TaskStatus, ClaimedState, WorkState, OngoingBy
- [ ] `shared/src/domain/task.gleam`
  - Task, TaskNote, TaskPosition, ActiveTask, ActiveTaskPayload, TaskFilters
- [ ] `shared/src/domain/project.gleam`
  - Project, ProjectMember
- [ ] `shared/src/domain/org.gleam`
  - OrgUser, OrgInvite, InviteLink
- [ ] `shared/src/domain/capability.gleam`
  - Capability
- [ ] `shared/src/domain/metrics.gleam`
  - MyMetrics, OrgMetricsBucket, OrgMetricsProjectOverview, OrgMetricsOverview, MetricsProjectTask, OrgMetricsProjectTasksPayload
- [ ] `shared/src/domain/api_error.gleam`
  - ApiError, ApiResult
- [ ] `shared/src/domain/task_type.gleam`
  - TaskType, TaskTypeInline

### Update client API modules to import canonical types
- [ ] `apps/client/src/scrumbringer_client/api/tasks.gleam`
- [ ] `apps/client/src/scrumbringer_client/api/projects.gleam`
- [ ] `apps/client/src/scrumbringer_client/api/org.gleam`
- [ ] `apps/client/src/scrumbringer_client/api/metrics.gleam`
- [ ] `apps/client/src/scrumbringer_client/api/auth.gleam`
- [ ] `apps/client/src/scrumbringer_client/api/core.gleam`

### Update server domain modules
- [ ] `apps/server/src/scrumbringer_server/domain/task_status.gleam` → import from `shared/domain/task_status`

### Remove duplicate definitions
- [ ] Remove type definitions from `api/*` modules (keep decoders/encoders only)
- [ ] Ensure `client/api.gleam` duplicates are handled in ref3-003

### Verification
- [ ] Run `gleam build` in shared/
- [ ] Run `gleam test` in apps/client/
- [ ] Run `gleam test` in apps/server/
- [ ] Run `make test`

## Dev Notes
- **New package location:** `shared/src/domain/*.gleam` (not `packages/domain/`)
- Use `////` module docs and `///` function/type docs with examples in new shared modules
- Each type must have explicit constructors — no type aliases that diverge
- Decoders/encoders stay in `api/*` modules, only types move to `shared/domain`

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Created ref3-002 story from Sprint 3 backlog | assistant |
| 2026-01-17 | 0.2 | Fixed shared/src/domain path, added scaffolding step | assistant |

## Dev Agent Record

## QA Results
