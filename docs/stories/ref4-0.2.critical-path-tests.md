# Story ref4-0.2: Tests para Critical Path (Claim/Release/Complete)

## Status: Done

## Story

**As a** developer,
**I want** comprehensive tests for the task claim/release/complete lifecycle,
**so that** I can safely refactor the tasks service without breaking the core business flow.

## Acceptance Criteria

1. **Claim success test**: Test verifies `claim_task` succeeds for an available task.
2. **Claim conflict test**: Test verifies `claim_task` fails for an already claimed task.
3. **Claim version test**: Test verifies `claim_task` fails with version mismatch (optimistic locking).
4. **Release success test**: Test verifies `release_task` succeeds when called by the claimer.
5. **Release auth test**: Test verifies `release_task` fails when called by non-claimer.
6. **Complete success test**: Test verifies `complete_task` succeeds when called by the claimer.
7. **Complete auth test**: Test verifies `complete_task` fails when called by non-claimer.
8. **Integration lifecycle test**: Test verifies full lifecycle: create -> claim -> complete.
9. **Integration release test**: Test verifies lifecycle: create -> claim -> release -> claim (by different user).
10. **All tests pass in CI**: Tests run successfully via `make test`.

## Tasks / Subtasks

- [x] Task 1: Create unit tests for claim_task (AC: 1, 2, 3)
  - [x] Create `apps/server/test/unit/services/tasks_queries_test.gleam`
  - [x] Test: `claim_task_succeeds_for_available_task_test`
  - [x] Test: `claim_task_fails_for_already_claimed_task_test`
  - [x] Test: `claim_task_fails_with_version_mismatch_test`

- [x] Task 2: Create unit tests for release_task (AC: 4, 5)
  - [x] Test: `release_task_succeeds_for_claimer_test`
  - [x] Test: `release_task_fails_for_non_claimer_test`

- [x] Task 3: Create unit tests for complete_task (AC: 6, 7)
  - [x] Test: `complete_task_succeeds_for_claimer_test`
  - [x] Test: `complete_task_fails_for_non_claimer_test`

- [x] Task 4: Create integration tests (AC: 8, 9)
  - [x] Create `apps/server/test/integration/task_lifecycle_test.gleam`
  - [x] Test: `full_lifecycle_create_claim_complete_test`
  - [x] Test: `full_lifecycle_create_claim_release_claim_test`

- [x] Task 5: Verify CI passes (AC: 10)
  - [x] Run `gleam test` and verify all tests pass (119 passed, 0 failures)
  - [x] Fix any test failures

## Dev Notes

### Source Tree (relevant to this story)

```
apps/server/
├── src/scrumbringer_server/
│   └── persistence/tasks/
│       └── queries.gleam         # READ: claim_task, release_task, complete_task
├── test/
│   ├── support/
│   │   └── test_db.gleam         # USE: from ref4-0.1
│   ├── unit/services/
│   │   └── tasks_queries_test.gleam  # CREATE
│   └── integration/
│       └── task_lifecycle_test.gleam  # CREATE
```

### Key Functions to Test

From `apps/server/src/scrumbringer_server/persistence/tasks/queries.gleam`:

```gleam
pub fn claim_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError)

pub fn release_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError)

pub fn complete_task(
  db: pog.Connection,
  org_id: Int,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError)
```

### Error Types to Test

```gleam
pub type NotFoundOrDbError {
  NotFound
  DbError(pog.QueryError)
}
```

Note: The SQL layer handles version mismatch and authorization by returning empty rows (NotFound). Tests should verify behavior through the returned results.

### Test Pattern: Unit Tests

Uses test database with transaction rollback (from ref4-0.1 test_db helper).

```gleam
// test/unit/services/tasks_queries_test.gleam
import gleeunit
import gleeunit/should
import scrumbringer_server/persistence/tasks/queries
import support/test_db
import support/test_helpers

pub fn main() {
  gleeunit.main()
}

pub fn claim_task_succeeds_for_available_task_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: An available task (setup via SQL or factory)
    // When: User 1 claims the task
    let result = queries.claim_task(tx, 1, 1, 1, 1)

    // Then: Task is claimed successfully
    result |> should.be_ok()
  })
}

pub fn claim_task_fails_for_already_claimed_task_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: A task already claimed by User 2
    // When: User 1 tries to claim the task
    let result = queries.claim_task(tx, 1, 1, 1, 1)

    // Then: Returns NotFound (already claimed = no matching row)
    result |> should.be_error()
  })
}

pub fn claim_task_fails_with_version_mismatch_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: A task with version 5
    // When: User tries to claim with version 4
    let result = queries.claim_task(tx, 1, 1, 1, 4)  // wrong version

    // Then: Returns NotFound (version mismatch = no matching row)
    result |> should.be_error()
  })
}
```

### Test Pattern: Integration Tests

```gleam
// test/integration/task_lifecycle_test.gleam
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn full_lifecycle_create_claim_complete_test() {
  // Given: A new task is created
  // When: User claims and then completes the task
  // Then: Task status is "completed", completed_by = user_id

  True |> should.be_true()
}

pub fn full_lifecycle_create_claim_release_claim_test() {
  // Given: A new task is created
  // When: User 1 claims, then releases
  // And: User 2 claims the task
  // Then: Task is claimed by User 2

  True |> should.be_true()
}
```

### Test Database Setup

Uses `test/support/test_db.gleam` from ref4-0.1:

```bash
# Set environment variable before running tests
export TEST_DATABASE_URL=postgres://user:pass@localhost/scrumbringer_test

# Run tests
cd apps/server && gleam test
```

The `with_test_transaction` helper ensures all test data is rolled back after each test, providing isolation without polluting the test database.

### Dependencies

This story depends on:
- **ref4-0.1**: Test infrastructure must be in place

### Testing

**Test file location:**
- `apps/server/test/unit/services/tasks_db_test.gleam`
- `apps/server/test/integration/task_lifecycle_test.gleam`

**Framework:** gleeunit

**Run command:** `cd apps/server && gleam test`

**Database requirement:** Tests may require a test PostgreSQL database. Configure via `TEST_DATABASE_URL` environment variable.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-20 | 0.1 | Story created from refactoring roadmap Fase 0.2 | po |

## Dev Agent Record

### Agent Model Used

claude-opus-4-5-20251101

### Debug Log References

N/A

### Completion Notes List

1. **Task 1-3 (Unit tests)**: Created `apps/server/test/unit/services/tasks_queries_test.gleam` with 7 tests covering all claim/release/complete scenarios via HTTP API with fixtures.

2. **Task 4 (Integration tests)**: Created `apps/server/test/integration/task_lifecycle_test.gleam` with 2 full lifecycle tests that verify:
   - Complete lifecycle: create -> claim -> complete with status and claimed_by verification
   - Release lifecycle: create -> claim -> release -> claim (by different user) with multi-user handoff

3. **Task 5 (CI verification)**: All 119 tests pass with `DATABASE_URL="postgres://scrumbringer:scrumbringer@localhost:5432/scrumbringer_dev" gleam test`.

4. **Schema discovery**: The `tasks` table does not have a `completed_by` column. When a task is completed, the `claimed_by` field stays set (as the claimer is the one who completes). Tests verify `completed_at` timestamp is set instead.

5. **Test approach**: Tests use fixtures.gleam HTTP helpers rather than direct query calls because the queries require proper FK relationships (org_id, project_id, type_id, etc.) that are complex to set up without the full bootstrap.

### File List

- `apps/server/test/unit/services/tasks_queries_test.gleam` (created) - 7 unit tests for claim/release/complete
- `apps/server/test/integration/task_lifecycle_test.gleam` (created) - 2 integration lifecycle tests

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-20 | 0.1 | Story created from refactoring roadmap Fase 0.2 | po |
| 2026-01-20 | 0.2 | Implementation complete, moved to Review | dev |
| 2026-01-20 | 0.3 | QA review passed, moved to Done | qa |

## QA Results

### Review Date: 2026-01-20

### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment

Overall implementation quality is **excellent**. The tests are well-structured, follow clear Given-When-Then patterns, and provide comprehensive coverage of the critical path business logic.

**Strengths:**
- Clear test organization with section headers for each AC
- Good use of fixtures.gleam for test setup - reuses existing infrastructure
- Proper multi-user test scenarios for auth failure cases
- Integration tests verify full state machine transitions with DB queries
- Version tracking correctly tests optimistic locking behavior

**Test Architecture:**
- Unit tests (7) cover individual operations: claim success/conflict/version, release success/auth, complete success/auth
- Integration tests (2) cover full workflows: create->claim->complete and create->claim->release->claim
- Tests verify both HTTP status codes AND database state

### Refactoring Performed

None required - code quality is high.

### Compliance Check

- Coding Standards: ✓ Follows Gleam conventions, proper naming, clear documentation
- Project Structure: ✓ Files in correct locations (unit/services/, integration/)
- Testing Strategy: ✓ Uses fixtures.gleam patterns, proper test isolation
- All ACs Met: ✓ All 10 acceptance criteria verified

### AC Traceability

| AC | Test | Verification |
|----|------|--------------|
| AC1 | `claim_task_succeeds_for_available_task_test` | ✓ HTTP 200 + DB status="claimed" |
| AC2 | `claim_task_fails_for_already_claimed_task_test` | ✓ HTTP 409 conflict |
| AC3 | `claim_task_fails_with_version_mismatch_test` | ✓ HTTP 409 conflict |
| AC4 | `release_task_succeeds_for_claimer_test` | ✓ HTTP 200 |
| AC5 | `release_task_fails_for_non_claimer_test` | ✓ HTTP 403 forbidden |
| AC6 | `complete_task_succeeds_for_claimer_test` | ✓ HTTP 200 |
| AC7 | `complete_task_fails_for_non_claimer_test` | ✓ HTTP 403 forbidden |
| AC8 | `full_lifecycle_create_claim_complete_test` | ✓ Status transitions verified |
| AC9 | `full_lifecycle_create_claim_release_claim_test` | ✓ Multi-user handoff verified |
| AC10 | Test run | ✓ 119 tests pass |

### Improvements Checklist

- [N/A] All tests are well-implemented, no changes needed

### Security Review

No security concerns - tests verify authorization correctly:
- Non-claimer cannot release (403)
- Non-claimer cannot complete (403)

### Performance Considerations

No performance concerns - test infrastructure, not production code.

### Files Modified During Review

None.

### Gate Status

Gate: **PASS** → docs/qa/gates/ref4-0.2-critical-path-tests.yml

### Recommended Status

✓ **Ready for Done** - All 10 acceptance criteria verified with comprehensive tests.
