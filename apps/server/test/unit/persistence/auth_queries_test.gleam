import pog
import scrumbringer_server/persistence/auth/queries
import scrumbringer_server/services/auth_logic
import support/assertions as expect

pub fn user_from_row_rejects_invalid_persisted_org_role_test() {
  let row =
    queries.UserRow(
      id: 1,
      email: "owner@example.com",
      password_hash: "hash",
      org_id: 1,
      org_role: "owner",
      created_at: "2026-06-08T00:00:00Z",
    )

  case queries.user_from_row(row) {
    Ok(_) -> expect.fail()
    Error(auth_logic.DbError(pog.PostgresqlError(
      code: "INVALID_ROLE",
      name: "invalid_role",
      message: "Invalid org role: owner",
    ))) -> Nil
    Error(_) -> expect.fail()
  }
}
