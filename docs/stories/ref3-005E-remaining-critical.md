# Story ref3-005E: Remaining critical splits

## Status: Done

## Story
**As a** maintainer,
**I want** to split remaining critical files not covered in previous stories,
**so that** all critical modules comply with hygiene rules.

## Acceptance Criteria
1. All remaining critical files are split into smaller modules.
2. Docs present and tests pass.

## Tasks / Subtasks

- [x] `apps/server/src/scrumbringer_server/services/task_workflow_actor.gleam` → `services/workflows/*.gleam`
- [x] `apps/server/src/scrumbringer_server/services/auth_db.gleam` → `persistence/auth/*.gleam`
- [x] `apps/client/src/scrumbringer_client/features/admin/update.gleam` → `features/admin/*.gleam`
- [x] `apps/client/src/scrumbringer_client/api/tasks.gleam` → `api/tasks/*.gleam`

- [x] Verification
  - [x] Run `gleam test`
  - [x] Run `make test`

## Dev Notes
- Keep `server/sql.gleam` exempt.
- Story task 3 referenced `client_workflows/admin.gleam` but actual file was `features/admin/update.gleam` (602 lines)
- Story task 4 referenced `client/api/tasks/*.gleam` but created under `api/tasks/*.gleam` (standard Gleam path)

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Split from ref3-005 | assistant |
| 2026-01-18 | 0.2 | Implementation complete | James (Dev) |

## Dev Agent Record

### Implementation Summary

Completed all 4 split tasks for remaining critical files that exceeded the 500-line hygiene limit.

### Files Created

**Server - services/workflows/ (from task_workflow_actor.gleam 598→4 files)**
- `services/workflows/types.gleam` - Message, Response, Error types
- `services/workflows/handlers.gleam` - Main handle function
- `services/workflows/validation.gleam` - Validation helpers
- `services/workflows/authorization.gleam` - Auth checks (require_project_member, require_project_admin)

**Server - persistence/auth/ (from auth_db.gleam 438→3 files)**
- `persistence/auth/queries.gleam` - DB queries (find_user_by_email, insert_user, etc.)
- `persistence/auth/registration.gleam` - Bootstrap and invite registration flows
- `persistence/auth/login.gleam` - Login and get_user functions

**Client - features/admin/ (from update.gleam 602→5 files)**
- `features/admin/org_settings.gleam` - Org settings handlers
- `features/admin/member_add.gleam` - Member add dialog handlers
- `features/admin/member_remove.gleam` - Member remove handlers
- `features/admin/search.gleam` - Org users search handlers
- `features/admin/update.gleam` - Re-exports + members fetched handlers

**Client - api/tasks/ (from tasks.gleam 610→7 files)**
- `api/tasks/decoders.gleam` - JSON decoders for task types
- `api/tasks/task_types.gleam` - Task type API functions
- `api/tasks/operations.gleam` - Task CRUD operations
- `api/tasks/notes.gleam` - Task notes API functions
- `api/tasks/active.gleam` - Active task API functions
- `api/tasks/positions.gleam` - Task position API functions
- `api/tasks/capabilities.gleam` - User capability API functions

### Files Deleted
- `services/task_workflow_actor.gleam`
- `services/auth_db.gleam`

### Files Modified
- `http/tasks.gleam` - Updated imports to use workflows/* modules
- `http/auth.gleam` - Updated imports to use persistence/auth/* modules

### Verification Results
- **Server tests**: 69 passed, no failures
- **Client tests**: 82 passed, no failures
- **Build**: Clean compilation (warnings are pre-existing)

## QA Results

### Review Date: 2026-01-18

### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment

**Overall: Excellent** - This refactoring story achieves its goal of bringing critical files under the 500-line hygiene limit while maintaining clean separation of concerns. The implementation demonstrates strong architectural thinking with clear module boundaries.

**Key Strengths:**
- All 19 new files are under 400 lines (max: 374 lines in handlers.gleam)
- Consistent module documentation using the Mission/Responsibilities/Relations pattern
- Clean separation: types, handlers, validation, authorization in separate modules
- Re-export pattern in facade modules (tasks.gleam, update.gleam) maintains backward compatibility
- No behavioral changes - pure refactoring

**Architecture Quality:**
- Server workflows split follows command-handler pattern with clear separation
- Auth split follows persistence layer pattern: queries → operations (login/registration)
- Client admin split follows feature-slice pattern by functionality
- Client API tasks split follows operation-type pattern (decoders, operations, etc.)

### Refactoring Performed

None required - implementation quality is high.

### Compliance Check

- Coding Standards: ✓ All naming conventions followed (snake_case modules, PascalCase types)
- Project Structure: ✓ Follows established patterns (persistence/*, services/workflows/*, features/admin/*, api/tasks/*)
- Testing Strategy: ✓ All 69 server + 82 client tests pass
- All ACs Met: ✓
  - AC1: All 4 critical files split into smaller modules (all under 500 lines)
  - AC2: Docs present (all modules have //// documentation), tests pass

### Improvements Checklist

- [x] All files under 500-line hygiene limit
- [x] Module documentation present in all new files
- [x] Imports updated in dependent files
- [x] Old files deleted (task_workflow_actor.gleam, auth_db.gleam)
- [x] Tests verified passing
- [ ] Consider removing pre-existing unused import warnings in future cleanup story

### Security Review

No concerns. Auth files split preserves all security properties:
- Password hashing remains in registration.gleam
- Login flow with first_login_at tracking preserved in login.gleam
- Authorization checks in workflows/authorization.gleam properly gate operations

### Performance Considerations

No concerns. This is a pure refactoring with no runtime behavior changes:
- No additional imports/dependencies beyond what existed
- No new allocations or processing overhead
- Module splitting has no runtime cost in Gleam/BEAM

### Files Modified During Review

None - no refactoring needed.

### Gate Status

Gate: **PASS** → docs/qa/gates/ref3-005E-remaining-critical.yml

### Recommended Status

✓ **Ready for Done** - All acceptance criteria met, tests pass, code quality excellent
