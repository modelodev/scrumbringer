import gleam/option.{None, Some}
import pog
import scrumbringer_server/persistence/auth/queries
import scrumbringer_server/services/auth_logic
import scrumbringer_server/services/store_state
import support/assertions as expect

pub fn user_from_row_decodes_human_identity_test() {
  let row =
    queries.UserRow(
      id: 1,
      email: "human@example.com",
      password_hash: Some("hash"),
      org_id: 1,
      org_role: "admin",
      user_kind: "human",
      created_at: "2026-06-08T00:00:00Z",
    )

  let assert Ok(user) = queries.user_from_row(row)
  let assert store_state.HumanIdentity(password_hash: "hash") = user.identity
}

pub fn user_from_row_decodes_integration_identity_test() {
  let row =
    queries.UserRow(
      id: 2,
      email: "integration@example.com",
      password_hash: None,
      org_id: 1,
      org_role: "member",
      user_kind: "integration",
      created_at: "2026-06-08T00:00:00Z",
    )

  let assert Ok(user) = queries.user_from_row(row)
  let assert store_state.IntegrationIdentity = user.identity
}

pub fn user_from_row_rejects_human_without_password_test() {
  let row =
    queries.UserRow(
      id: 1,
      email: "human@example.com",
      password_hash: None,
      org_id: 1,
      org_role: "admin",
      user_kind: "human",
      created_at: "2026-06-08T00:00:00Z",
    )

  let assert Error(auth_logic.InvalidPersistedUserIdentity(
    "human_missing_password",
  )) = queries.user_from_row(row)
}

pub fn user_from_row_rejects_integration_with_password_test() {
  let row =
    queries.UserRow(
      id: 2,
      email: "integration@example.com",
      password_hash: Some("hash"),
      org_id: 1,
      org_role: "member",
      user_kind: "integration",
      created_at: "2026-06-08T00:00:00Z",
    )

  let assert Error(auth_logic.InvalidPersistedUserIdentity(
    "integration_has_password",
  )) = queries.user_from_row(row)
}

pub fn user_from_row_rejects_invalid_persisted_org_role_test() {
  let row =
    queries.UserRow(
      id: 1,
      email: "owner@example.com",
      password_hash: Some("hash"),
      org_id: 1,
      org_role: "owner",
      user_kind: "human",
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
