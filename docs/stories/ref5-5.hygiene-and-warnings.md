# Story ref5-5: Hygiene and Warnings Cleanup

## Status

**Done**

---

## Story

**As a** maintainer of the Scrumbringer codebase,
**I want** to clean up build warnings introduced during ref5 componentization and update the sprint documentation,
**so that** the codebase maintains a clean build with zero warnings and accurate documentation.

---

## Acceptance Criteria

1. **Zero Build Warnings**: The client app builds with `gleam build` producing zero warnings.

2. **Test File Cleanup**: All unused imports in test files are removed:
   - `card_crud_dialog_test.gleam`: Remove unused `DialogMode`, `Model`, `Msg` type imports
   - `workflow_crud_dialog_test.gleam`: Remove unreachable pattern warnings
   - Other component test files: Clean any similar issues

3. **Index Updated**: The `ref5-index.md` milestone checkboxes reflect actual completion status.

4. **Story Statuses Synced**: All ref5 story status sections match their QA gate decisions.

5. **Technical Debt Documented**: Legacy dialog fields not in ref5 scope are documented as future componentization candidates in a dedicated section of the architecture docs or index.

---

## Tasks / Subtasks

- [x] **Task 1: Fix test file warnings** (AC: 1, 2)
  - [x] Open `card_crud_dialog_test.gleam` and remove unused imports
  - [x] Open `workflow_crud_dialog_test.gleam` and fix unreachable patterns
  - [x] N/A - `task_template_crud_dialog_test.gleam` does not exist
  - [x] Open `rule_crud_dialog_test.gleam` and clean imports if needed
  - [x] Run `gleam build` and verify zero warnings

- [x] **Task 2: Update ref5-index.md** (AC: 3)
  - [x] Mark all milestone checkboxes as `[x]`
  - [x] Update story status table to show "Done" for all 4 stories
  - [x] Add ref5-5 to the status table

- [x] **Task 3: Document technical debt** (AC: 5)
  - [x] Add "Future Work" section to ref5-index.md documenting legacy dialog fields:
    - `projects_create_*` (3 fields) - Projects dialog
    - `capabilities_create_*` (4 fields) - Capabilities dialog
    - `task_types_create_*` (6 fields) - Task Types dialog
    - `member_create_*` (7 fields) - Member task creation dialog
    - `member_position_edit_*` (5 fields) - Member position edit
  - [x] Note these as candidates for a future ref6 sprint

- [x] **Task 4: Final verification** (AC: 1, 4)
  - [x] Run `gleam build` - 0 warnings
  - [x] Run `gleam test` - 261 tests pass
  - [x] Verify all ref5 stories show "Done" status

---

## Dev Notes

### Current Warning Count

As of 2026-01-21, `gleam build` produces **79 warnings**, primarily:

1. **Unused imported types** in test files (e.g., `type DialogMode`, `type Model`, `type Msg`)
2. **Unused imported constructors** (e.g., `CreateResult`, `DeleteResult`, `EditColorChanged`)
3. **Unreachable patterns** in exhaustive test cases

### Files to Clean

| File | Issue | Action |
|------|-------|--------|
| `card_crud_dialog_test.gleam` | Unused type imports | Remove `type DialogMode`, `type Model`, `type Msg` |
| `card_crud_dialog_test.gleam` | Unused constructors | Remove `CreateResult`, `DeleteResult`, etc. |
| `workflow_crud_dialog_test.gleam` | Unreachable patterns | Remove `_ -> should.fail()` after exhaustive match |
| Other test files | Similar issues | Audit and clean |

### Legacy Fields (Out of Scope - Document Only)

These fields follow the old pattern and are **actively used**:

```gleam
// Projects (3 fields)
projects_create_name: String
projects_create_in_flight: Bool
projects_create_error: Option(String)

// Capabilities (4 fields)
capabilities_create_dialog_open: Bool
capabilities_create_name: String
capabilities_create_in_flight: Bool
capabilities_create_error: Option(String)

// Task Types (6 fields)
task_types_create_dialog_open: Bool
task_types_create_name: String
task_types_create_icon: String
task_types_create_capability_id: Option(String)
task_types_create_in_flight: Bool
task_types_create_error: Option(String)

// Member Task Creation (7 fields)
member_create_dialog_open: Bool
member_create_title: String
member_create_description: String
member_create_priority: String
member_create_type_id: String
member_create_in_flight: Bool
member_create_error: Option(String)

// Member Position Edit (5 fields)
member_position_edit_task: Option(Int)
member_position_edit_x: String
member_position_edit_y: String
member_position_edit_in_flight: Bool
member_position_edit_error: Option(String)
```

**Total: 25 fields** - candidates for future componentization following the ref5 pattern.

---

## Testing

### Build Verification

```bash
cd apps/client && gleam build 2>&1 | grep -c "^warning:"
# Expected: 0
```

### Test Verification

```bash
cd apps/client && gleam test
# Expected: All tests pass, no regressions
```

---

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### File List

| File | Action | Description |
|------|--------|-------------|
| `apps/client/src/scrumbringer_client/features/projects/view.gleam` | Modified | Fixed syntax error (extra comma in case expression) |
| `apps/client/test/card_crud_dialog_test.gleam` | Modified | Removed unused imports, replaced unreachable patterns with should.equal |
| `apps/client/test/workflow_crud_dialog_test.gleam` | Modified | Removed unused imports, replaced unreachable patterns with should.equal |
| `apps/client/test/rule_crud_dialog_test.gleam` | Modified | Removed unused imports, replaced unreachable patterns with should.equal |
| `docs/stories/ref5-index.md` | Modified | Updated checkboxes, status table, added Future Work section |

### Debug Log References

None - implementation proceeded without blockers.

### Completion Notes

1. **Build Warnings**: Reduced from 79 to 0 warnings
2. **Test Cleanup**:
   - Removed unused type imports (`type DialogMode`, `type Model`, `type Msg`)
   - Removed unused constructors (`CreateResult`, `DeleteResult`, `EditColorChanged`, etc.)
   - Replaced `_ -> should.fail()` patterns with `should.equal` for cleaner assertions
   - Used `let Pattern(x) = Pattern(val)` for pattern extraction without redundant asserts
3. **Bonus Fix**: Fixed pre-existing syntax error in `projects/view.gleam` (trailing comma)
4. **Tests**: All 261 tests pass

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-21 | 0.1 | Initial draft based on Architect analysis | Winston (Architect) |
| 2026-01-21 | 1.0 | Implementation complete, 0 warnings, 261 tests pass | Dev Agent |
