# Story ref4-0.3: Tests de Authorization

## Status: Done

## Story

**As a** developer,
**I want** comprehensive tests for authorization logic (project member/admin checks),
**so that** I can safely refactor the authorization helpers without breaking access control.

## Acceptance Criteria

1. **Auth session valid test**: Test verifies `require_current_user` returns user for valid session.
2. **Auth session invalid test**: Test verifies `require_current_user` returns error for invalid/expired session.
3. **Project member positive test**: Test verifies `is_project_member` returns true for actual member.
4. **Project member negative test**: Test verifies `is_project_member` returns false for non-member.
5. **Project admin positive test**: Test verifies `is_project_admin` returns true for admin.
6. **Project admin negative test**: Test verifies `is_project_admin` returns false for regular member.
7. **Org admin check test**: Test verifies org admin role is correctly identified.
8. **All tests pass in CI**: Tests run successfully via `make test`.

## Tasks / Subtasks

- [x] Task 1: Create unit tests for auth module (AC: 1, 2)
  - [x] Create `apps/server/test/unit/http/auth_test.gleam`
  - [x] Test: `require_current_user_returns_user_for_valid_session_test`
  - [x] Test: `require_current_user_returns_error_for_invalid_session_test`
  - [x] Test: `require_current_user_returns_error_for_expired_token_test` (bonus)

- [x] Task 2: Create unit tests for is_project_member (AC: 3, 4)
  - [x] Create `apps/server/test/unit/services/projects_db_test.gleam`
  - [x] Test: `is_project_member_returns_true_for_member_test`
  - [x] Test: `is_project_member_returns_false_for_non_member_test`

- [x] Task 3: Create unit tests for is_project_admin (AC: 5, 6)
  - [x] Test: `is_project_admin_returns_true_for_admin_test`
  - [x] Test: `is_project_admin_returns_false_for_member_test`

- [x] Task 4: Create unit tests for org role checks (AC: 7)
  - [x] Test: `org_admin_role_correctly_identified_test`
  - [x] Test: `org_member_role_correctly_identified_test`

- [x] Task 5: Verify CI passes (AC: 8)
  - [x] Run `gleam test` and verify all tests pass (128 passed, 0 failures)
  - [x] Fix any test failures

## Dev Notes

### Source Tree (relevant to this story)

```
apps/server/
├── src/scrumbringer_server/
│   ├── http/
│   │   └── auth.gleam            # READ: require_current_user
│   └── services/
│       └── projects_db.gleam     # READ: is_project_member, is_project_admin
├── test/
│   ├── unit/
│   │   ├── http/
│   │   │   └── auth_test.gleam   # CREATE
│   │   └── services/
│   │       └── projects_db_test.gleam  # CREATE
```

### Key Functions to Test

From `apps/server/src/scrumbringer_server/http/auth.gleam`:

```gleam
pub fn require_current_user(
  req: wisp.Request,
  ctx: Ctx,
) -> Result(StoredUser, Nil)
```

From `apps/server/src/scrumbringer_server/services/projects_db.gleam`:

```gleam
pub fn is_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Bool, pog.QueryError)

pub fn is_project_admin(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Bool, pog.QueryError)
```

### Test Pattern: Auth Module

Testing `require_current_user` requires mocking the request and session store. Consider:

```gleam
// test/unit/http/auth_test.gleam
import gleeunit
import gleeunit/should
import scrumbringer_server/http/auth
import scrumbringer_server/services/store_state.{StoredUser}
import domain/org_role

pub fn main() {
  gleeunit.main()
}

pub fn require_current_user_returns_user_for_valid_session_test() {
  // Given: A request with valid session cookie
  // And: Session store contains user data
  // When: require_current_user is called
  // Then: Returns Ok(StoredUser)

  // Note: Requires mock setup for wisp.Request and ETS store
  True |> should.be_true()
}

pub fn require_current_user_returns_error_for_invalid_session_test() {
  // Given: A request with invalid/missing session cookie
  // When: require_current_user is called
  // Then: Returns Error(Nil)

  True |> should.be_true()
}
```

### Test Pattern: Projects DB

Uses `test/support/test_db.gleam` from ref4-0.1:

```gleam
// test/unit/services/projects_db_test.gleam
import gleeunit
import gleeunit/should
import scrumbringer_server/services/projects_db
import support/test_db

pub fn main() {
  gleeunit.main()
}

pub fn is_project_member_returns_true_for_member_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: User 1 is a member of Project 1 (setup test data)
    // When: is_project_member(db, project_id=1, user_id=1)
    let result = projects_db.is_project_member(tx, 1, 1)

    // Then: Returns Ok(True)
    result |> should.equal(Ok(True))
  })
}

pub fn is_project_member_returns_false_for_non_member_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: User 99 is NOT a member of Project 1
    let result = projects_db.is_project_member(tx, 1, 99)

    // Then: Returns Ok(False)
    result |> should.equal(Ok(False))
  })
}

pub fn is_project_admin_returns_true_for_admin_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: User 1 is an admin of Project 1 (role = "admin")
    let result = projects_db.is_project_admin(tx, 1, 1)

    // Then: Returns Ok(True)
    result |> should.equal(Ok(True))
  })
}

pub fn is_project_admin_returns_false_for_member_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: User 2 is a regular member of Project 1 (role = "member")
    let result = projects_db.is_project_admin(tx, 1, 2)

    // Then: Returns Ok(False)
    result |> should.equal(Ok(False))
  })
}
```

### Database Setup for Tests

The `project_memberships` table schema:

```sql
CREATE TABLE project_memberships (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    role TEXT NOT NULL DEFAULT 'member',  -- 'admin' | 'member'
    UNIQUE(project_id, user_id)
);
```

Test data setup:
```sql
-- Test user who is project admin
INSERT INTO users (id, email, org_id, org_role) VALUES (1, 'admin@test.com', 1, 'admin');
-- Test user who is project member
INSERT INTO users (id, email, org_id, org_role) VALUES (2, 'member@test.com', 1, 'member');
-- Test user who is not a member
INSERT INTO users (id, email, org_id, org_role) VALUES (99, 'outsider@test.com', 2, 'member');

-- Project membership
INSERT INTO project_memberships (project_id, user_id, role) VALUES (1, 1, 'admin');
INSERT INTO project_memberships (project_id, user_id, role) VALUES (1, 2, 'member');
```

### Dependencies

This story depends on:
- **ref4-0.1**: Test infrastructure must be in place

### Testing

**Test file location:**
- `apps/server/test/unit/http/auth_test.gleam`
- `apps/server/test/unit/services/projects_db_test.gleam`

**Framework:** gleeunit

**Run command:** `cd apps/server && gleam test`

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-20 | 0.1 | Story created from refactoring roadmap Fase 0.3 | po |

## Dev Agent Record

### Agent Model Used

claude-opus-4-5-20251101

### Debug Log References

N/A

### Completion Notes List

1. **Task 1 (Auth module tests)**: Created `apps/server/test/unit/http/auth_test.gleam` with 3 tests:
   - `require_current_user_returns_user_for_valid_session_test` - Tests /me endpoint with valid session returns 200
   - `require_current_user_returns_error_for_invalid_session_test` - Tests /me endpoint without auth returns 401
   - `require_current_user_returns_error_for_expired_token_test` - Tests /me endpoint with invalid JWT returns 401

2. **Tasks 2-3 (Project membership tests)**: Created `apps/server/test/unit/services/projects_db_test.gleam` with 4 tests:
   - `is_project_member_returns_true_for_member_test` - Verifies project creator is member
   - `is_project_member_returns_false_for_non_member_test` - Verifies user not added to project is not member
   - `is_project_admin_returns_true_for_admin_test` - Verifies project creator is admin
   - `is_project_admin_returns_false_for_member_test` - Verifies regular member is not admin

3. **Task 4 (Org role tests)**: Added 2 more tests to projects_db_test.gleam:
   - `org_admin_role_correctly_identified_test` - Verifies bootstrap user has org_role='admin'
   - `org_member_role_correctly_identified_test` - Verifies invited user has org_role='member'

4. **Discovery**: The `is_project_member` and `is_project_admin` functions are in `auth.gleam`, not `projects_db.gleam` as the story suggested. Tests import from the correct location.

5. **Test approach**: Tests use fixtures.gleam HTTP helpers consistent with existing patterns. The auth functions are tested directly via DB queries after setting up proper state through the API.

### File List

- `apps/server/test/unit/http/auth_test.gleam` (created) - 3 auth session tests
- `apps/server/test/unit/services/projects_db_test.gleam` (created) - 6 project membership/org role tests

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-20 | 0.1 | Story created from refactoring roadmap Fase 0.3 | po |
| 2026-01-20 | 0.2 | Implementation complete, moved to Review | dev |
| 2026-01-20 | 0.3 | QA review passed, moved to Done | qa |

## QA Results

### Review Date: 2026-01-20

### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment

Overall implementation quality is **excellent**. The tests are well-structured with clear Given-When-Then patterns, comprehensive AC coverage, and good use of existing fixtures infrastructure.

**Strengths:**
- Clear section headers mapping tests to acceptance criteria
- Good use of fixtures.gleam for HTTP-level testing - consistent with project patterns
- Tests cover both positive and negative cases for each authorization function
- Bonus test added for expired token scenario
- Clean imports (no unused imports after cleanup)
- Correct discovery of actual function location (auth.gleam vs projects_db.gleam)

**Test Architecture:**
- Auth tests (3): Valid session, invalid session (no auth), invalid token
- Project membership tests (4): Member positive/negative, admin positive/negative
- Org role tests (2): Admin role verified, member role verified

### Refactoring Performed

None required - code quality is high and follows established patterns.

### Compliance Check

- Coding Standards: ✓ Follows Gleam conventions, proper naming, clear documentation
- Project Structure: ✓ Files in correct locations (test/unit/http/, test/unit/services/)
- Testing Strategy: ✓ Uses fixtures.gleam patterns, proper test isolation
- All ACs Met: ✓ All 8 acceptance criteria verified with 9 tests (1 bonus)

### AC Traceability

| AC | Test | Verification |
|----|------|--------------|
| AC1 | `require_current_user_returns_user_for_valid_session_test` | ✓ HTTP 200 with user data |
| AC2 | `require_current_user_returns_error_for_invalid_session_test` | ✓ HTTP 401 (no auth) |
| AC2 | `require_current_user_returns_error_for_expired_token_test` | ✓ HTTP 401 (invalid JWT) |
| AC3 | `is_project_member_returns_true_for_member_test` | ✓ Returns True for project creator |
| AC4 | `is_project_member_returns_false_for_non_member_test` | ✓ Returns False for outsider |
| AC5 | `is_project_admin_returns_true_for_admin_test` | ✓ Returns True for project creator |
| AC6 | `is_project_admin_returns_false_for_member_test` | ✓ Returns False for member role |
| AC7 | `org_admin_role_correctly_identified_test` | ✓ Bootstrap user has org_role='admin' |
| AC7 | `org_member_role_correctly_identified_test` | ✓ Invited user has org_role='member' |
| AC8 | Test run | ✓ 128 tests pass |

### Improvements Checklist

- [N/A] All tests are well-implemented, no changes needed

### Security Review

No security concerns - tests verify authorization correctly:
- Invalid/missing session returns 401
- Project membership checks work correctly
- Admin/member role distinctions verified

### Performance Considerations

No performance concerns - test infrastructure, not production code.

### Files Modified During Review

None.

### Gate Status

Gate: **PASS** → docs/qa/gates/ref4-0.3-authorization-tests.yml

### Recommended Status

✓ **Ready for Done** - All 8 acceptance criteria verified with comprehensive tests.
