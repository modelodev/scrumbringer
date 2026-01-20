//// Factory functions for creating test data.
////
//// ## Mission
////
//// Provides consistent, typed factory functions for unit tests that need
//// to create domain objects without database access.
////
//// ## Usage
////
//// ```gleam
//// import support/test_helpers
////
//// pub fn my_test() {
////   let user = test_helpers.make_test_user()
////   let admin = test_helpers.make_test_admin()
////   // ... use in tests
//// }
//// ```

import domain/org_role
import scrumbringer_server/services/store_state.{type StoredUser, StoredUser}

/// Creates a test user with member role.
pub fn make_test_user() -> StoredUser {
  StoredUser(
    id: 1,
    email: "test@example.com",
    password_hash: "hashed_password",
    org_id: 1,
    org_role: org_role.Member,
    created_at: "2026-01-20T00:00:00Z",
  )
}

/// Creates a test user with admin role.
pub fn make_test_admin() -> StoredUser {
  StoredUser(
    id: 1,
    email: "admin@example.com",
    password_hash: "hashed_password",
    org_id: 1,
    org_role: org_role.Admin,
    created_at: "2026-01-20T00:00:00Z",
  )
}

/// Creates a test user with custom ID.
pub fn make_test_user_with_id(id: Int) -> StoredUser {
  StoredUser(
    id: id,
    email: "test" <> int_to_string(id) <> "@example.com",
    password_hash: "hashed_password",
    org_id: 1,
    org_role: org_role.Member,
    created_at: "2026-01-20T00:00:00Z",
  )
}

/// Creates a test admin with custom ID.
pub fn make_test_admin_with_id(id: Int) -> StoredUser {
  StoredUser(
    id: id,
    email: "admin" <> int_to_string(id) <> "@example.com",
    password_hash: "hashed_password",
    org_id: 1,
    org_role: org_role.Admin,
    created_at: "2026-01-20T00:00:00Z",
  )
}

fn int_to_string(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    _ -> "N"
  }
}
