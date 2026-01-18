# Story ref3-005A: Scaffold + base app structure

## Status: Done

## Story
**As a** maintainer,
**I want** to scaffold the new feature-based structure without moving logic yet,
**so that** subsequent splits can proceed safely with clear directories.

## Acceptance Criteria
1. Feature and app directories exist per refactor architecture.
2. No functional logic is moved in this story.
3. No behavior changes; repo still builds/tests.

## Tasks / Subtasks

- [x] Create client feature/app/ui directory structure
  - [x] `apps/client/src/scrumbringer_client/features/{pool,my_bar,tasks,admin,auth,invites,now_working,projects,capabilities,task_types,i18n}`
  - [x] `apps/client/src/scrumbringer_client/app/`
  - [x] `apps/client/src/scrumbringer_client/ui/` (already exists from ref3-004)

- [x] Create server directories (if missing)
  - [x] `apps/server/src/scrumbringer_server/persistence/tasks/`
  - [x] `apps/server/src/scrumbringer_server/persistence/auth/`
  - [x] `apps/server/src/scrumbringer_server/services/workflows/`

- [x] Add placeholder modules with `////` docs where needed (no logic)
  - [x] `apps/client/src/scrumbringer_client/app/effects.gleam`

- [x] Verification
  - [x] Run `gleam test` (82 passed)
  - [x] Run `make test` (82 passed)

## Dev Notes
- No logic moves in this story. Just scaffold.
- If any new files are created, include `////` module docs.

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Split from ref3-005 | assistant |

## Dev Agent Record

### 2026-01-18 Implementation Session

**Implementation Summary:**

1. **Client Directory Structure Created:**
   - `features/` with 11 subdirectories: pool, my_bar, tasks, admin, auth, invites, now_working, projects, capabilities, task_types, i18n
   - `app/` directory for application-level modules
   - `ui/` already existed from ref3-004

2. **Server Directory Structure Created:**
   - `persistence/tasks/` and `persistence/auth/`
   - `services/workflows/`

3. **Placeholder Module:**
   - Created `app/effects.gleam` with `////` module documentation

**Test Results:**
- Client tests: 82 passed, 0 failures
- Warning about empty module (expected for placeholder)

**Files Changed:**
- Created: `app/effects.gleam`
- Created directories: 11 client feature dirs, 1 app dir, 3 server dirs

## QA Results

### Review Date: 2026-01-18

### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment

**Overall: Excellent** - Clean scaffolding implementation. Placeholder module has proper documentation following project standards.

### Refactoring Performed

None required.

### Compliance Check

- Coding Standards: ✓ Module docs present with Mission/Responsibilities/Non-responsibilities
- Project Structure: ✓ Directories follow planned architecture
- Testing Strategy: ✓ No new tests needed for scaffolding
- All ACs Met: ✓ All 3 acceptance criteria verified

### Acceptance Criteria Verification

| AC | Status | Evidence |
|----|--------|----------|
| AC1 | ✅ PASS | 11 feature dirs + app/ + 3 server dirs created |
| AC2 | ✅ PASS | Only placeholder with docs, no logic |
| AC3 | ✅ PASS | 82/82 tests pass |

### Improvements Checklist

- [x] All directories created per specification
- [x] Placeholder module has proper `////` documentation
- [x] No functional changes introduced

### Security Review

No concerns - scaffolding only.

### Performance Considerations

No concerns - no runtime impact.

### Gate Status

Gate: **PASS** → docs/qa/gates/ref3-005A-scaffold.yml

### Recommended Status

✓ **Ready for Done** - All acceptance criteria met. Clean scaffolding prepares codebase for subsequent feature extraction.

