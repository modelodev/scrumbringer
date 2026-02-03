import domain/org_role
import gleam/dict
import gleam/option.{None, Some}
import gleeunit/should
import scrumbringer_server/services/auth_logic
import scrumbringer_server/services/store_state as ss

const now_iso = "2026-01-20T00:00:00Z"

const now_unix = 1_737_000_000

fn state_with_org() -> ss.State {
  let state = ss.initial()
  let org = ss.Organization(id: 1, name: "Acme", created_at: now_iso)
  ss.State(
    ..state,
    org: Some(org),
    next_org_id: 2,
    next_project_id: 2,
    next_user_id: 2,
  )
}

fn state_with_invite(invite: ss.OrgInvite) -> ss.State {
  let state = state_with_org()
  ss.State(
    ..state,
    invites_by_code: dict.insert(state.invites_by_code, invite.code, invite),
  )
}

fn invite_base(code: String) -> ss.OrgInvite {
  ss.OrgInvite(
    code: code,
    org_id: 1,
    created_at_unix: now_unix - 10,
    expires_at_unix: None,
    used_at_unix: None,
    used_by: None,
  )
}

pub fn register_requires_org_name_when_bootstrapping_test() {
  let state = ss.initial()

  let result =
    auth_logic.register(
      state,
      "admin@example.com",
      "passwordpassword",
      None,
      None,
      now_iso,
      now_unix,
    )

  result |> should.equal(Error(auth_logic.OrgNameRequired))
}

pub fn register_requires_invite_when_org_exists_test() {
  let state = state_with_org()

  let result =
    auth_logic.register(
      state,
      "member@example.com",
      "passwordpassword",
      None,
      None,
      now_iso,
      now_unix,
    )

  result |> should.equal(Error(auth_logic.InviteRequired))
}

pub fn register_rejects_invalid_invite_code_test() {
  let state = state_with_org()

  let result =
    auth_logic.register(
      state,
      "member@example.com",
      "passwordpassword",
      None,
      Some("badcode"),
      now_iso,
      now_unix,
    )

  result |> should.equal(Error(auth_logic.InviteInvalid))
}

pub fn register_rejects_expired_invite_test() {
  let invite =
    ss.OrgInvite(..invite_base("expired"), expires_at_unix: Some(now_unix - 1))
  let state = state_with_invite(invite)

  let result =
    auth_logic.register(
      state,
      "member@example.com",
      "passwordpassword",
      None,
      Some("expired"),
      now_iso,
      now_unix,
    )

  result |> should.equal(Error(auth_logic.InviteExpired))
}

pub fn register_rejects_used_invite_test() {
  let invite =
    ss.OrgInvite(
      ..invite_base("used"),
      used_at_unix: Some(now_unix - 1),
      used_by: Some(1),
    )
  let state = state_with_invite(invite)

  let result =
    auth_logic.register(
      state,
      "member@example.com",
      "passwordpassword",
      None,
      Some("used"),
      now_iso,
      now_unix,
    )

  result |> should.equal(Error(auth_logic.InviteUsed))
}

pub fn register_rejects_taken_email_test() {
  let state = ss.initial()
  let user =
    ss.StoredUser(
      id: 1,
      email: "admin@example.com",
      password_hash: "hash",
      org_id: 1,
      org_role: org_role.Admin,
      created_at: now_iso,
    )

  let seeded =
    ss.State(
      ..state,
      users_by_id: dict.insert(state.users_by_id, 1, user),
      user_id_by_email: dict.insert(state.user_id_by_email, user.email, 1),
    )

  let result =
    auth_logic.register(
      seeded,
      "admin@example.com",
      "passwordpassword",
      Some("Acme"),
      None,
      now_iso,
      now_unix,
    )

  result |> should.equal(Error(auth_logic.EmailTaken))
}
