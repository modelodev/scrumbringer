# Story ref4-0.3: Tests de Authorization

## Status: Ready

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

- [ ] Task 1: Create unit tests for auth module (AC: 1, 2)
  - [ ] Create `apps/server/test/unit/http/auth_test.gleam`
  - [ ] Test: `require_current_user_returns_user_for_valid_session_test`
  - [ ] Test: `require_current_user_returns_error_for_invalid_session_test`

- [ ] Task 2: Create unit tests for is_project_member (AC: 3, 4)
  - [ ] Create `apps/server/test/unit/services/projects_db_test.gleam`
  - [ ] Test: `is_project_member_returns_true_for_member_test`
  - [ ] Test: `is_project_member_returns_false_for_non_member_test`

- [ ] Task 3: Create unit tests for is_project_admin (AC: 5, 6)
  - [ ] Test: `is_project_admin_returns_true_for_admin_test`
  - [ ] Test: `is_project_admin_returns_false_for_member_test`

- [ ] Task 4: Create unit tests for org role checks (AC: 7)
  - [ ] Test: `org_admin_role_correctly_identified_test`
  - [ ] Test: `org_member_role_correctly_identified_test`

- [ ] Task 5: Verify CI passes (AC: 8)
  - [ ] Run `make test` and verify all tests pass
  - [ ] Fix any test failures

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

### Debug Log References

### Completion Notes List

### File List

## QA Results
