import gleam/option.{None, Some}

import scrumbringer_server/use_case/org_invite_links_db

const created_at = "2026-06-05T10:00:00Z"

pub fn lifecycle_from_db_accepts_active_test() {
  let assert Ok(lifecycle) =
    org_invite_links_db.lifecycle_from_db("active", created_at, None, None)
  let assert True = lifecycle == org_invite_links_db.Active(created_at)
}

pub fn lifecycle_from_db_accepts_used_with_used_at_test() {
  let used_at = "2026-06-05T11:00:00Z"

  let assert Ok(lifecycle) =
    org_invite_links_db.lifecycle_from_db(
      "used",
      created_at,
      Some(used_at),
      None,
    )
  let assert True = lifecycle == org_invite_links_db.Used(created_at, used_at)
}

pub fn lifecycle_from_db_rejects_used_without_used_at_test() {
  let assert Error(org_invite_links_db.UsedWithoutUsedAt) =
    org_invite_links_db.lifecycle_from_db("used", created_at, None, None)
}

pub fn lifecycle_from_db_rejects_invalidated_without_invalidated_at_test() {
  let assert Error(org_invite_links_db.InvalidatedWithoutInvalidatedAt) =
    org_invite_links_db.lifecycle_from_db("invalidated", created_at, None, None)
}

pub fn lifecycle_from_db_rejects_unknown_state_test() {
  let assert Error(org_invite_links_db.UnknownLifecycleState("archived")) =
    org_invite_links_db.lifecycle_from_db("archived", created_at, None, None)
}
