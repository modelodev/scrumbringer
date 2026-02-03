//// Authentication business logic for user registration and login.
////
//// ## Mission
////
//// Provides core authentication workflows independent of storage backend.
////
//// ## Responsibilities
////
//// - User registration with invite validation
//// - Login credential verification
//// - Organization creation for new users
//// - Password hashing and validation
////
//// ## Non-responsibilities
////
//// - HTTP request handling (see `http/auth.gleam`)
//// - Database persistence (see `persistence/auth/`)
////
//// ## Relationships
////
//// - Depends on `services/password.gleam` for hashing
//// - Uses `services/store_state.gleam` for in-memory state models

import domain/org_role.{Admin, Member}
import domain/project_role.{Manager}
import gleam/dict
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/services/password
import scrumbringer_server/services/store_state as ss

/// Errors returned by authentication workflows.
pub type AuthError {
  InviteRequired
  InviteInvalid
  InviteExpired
  InviteUsed
  InvalidCredentials
  EmailTaken
  OrgNameRequired
  PasswordError(password.PasswordError)
  DbError(pog.QueryError)
}

/// Registers a user in the in-memory auth state.
///
/// Example:
///   register(state, email, password, org_name, invite_code, now_iso, now_unix)
pub fn register(
  state: ss.State,
  email: String,
  password_raw: String,
  org_name: Option(String),
  invite_code: Option(String),
  now_iso: String,
  now_unix: Int,
) -> Result(#(ss.State, ss.StoredUser), AuthError) {
  case state.org {
    None ->
      bootstrap_register(
        state,
        email,
        password_raw,
        org_name,
        now_iso,
        now_unix,
      )
    Some(org) ->
      invite_register(
        state,
        org,
        email,
        password_raw,
        invite_code,
        now_iso,
        now_unix,
      )
  }
}

fn bootstrap_register(
  state: ss.State,
  email: String,
  password_raw: String,
  org_name: Option(String),
  now_iso: String,
  _now_unix: Int,
) -> Result(#(ss.State, ss.StoredUser), AuthError) {
  let org_name = case org_name {
    Some(name) if name != "" -> Ok(name)
    _ -> Error(OrgNameRequired)
  }

  use org_name <- result.try(org_name)

  use state <- result.try(ensure_email_available(state, email))

  use password_hash <- result.try(
    password.hash(password_raw)
    |> result.map_error(PasswordError),
  )

  let org_id = state.next_org_id
  let project_id = state.next_project_id
  let user_id = state.next_user_id

  let org = ss.Organization(id: org_id, name: org_name, created_at: now_iso)
  let project =
    ss.Project(
      id: project_id,
      org_id: org_id,
      name: "Default",
      created_at: now_iso,
    )
  let user =
    ss.StoredUser(
      id: user_id,
      email: email,
      password_hash: password_hash,
      org_id: org_id,
      org_role: Admin,
      created_at: now_iso,
    )
  let member =
    ss.ProjectMember(
      project_id: project_id,
      user_id: user_id,
      role: Manager,
      created_at: now_iso,
      claimed_count: 0,
    )

  let state =
    ss.State(
      ..state,
      org: Some(org),
      next_org_id: org_id + 1,
      next_project_id: project_id + 1,
      next_user_id: user_id + 1,
      users_by_id: dict.insert(state.users_by_id, user_id, user),
      user_id_by_email: dict.insert(state.user_id_by_email, email, user_id),
      projects_by_id: dict.insert(state.projects_by_id, project_id, project),
      project_members: dict.insert(
        state.project_members,
        #(project_id, user_id),
        member,
      ),
    )

  Ok(#(state, user))
}

fn invite_register(
  state: ss.State,
  org: ss.Organization,
  email: String,
  password_raw: String,
  invite_code: Option(String),
  now_iso: String,
  now_unix: Int,
) -> Result(#(ss.State, ss.StoredUser), AuthError) {
  let invite_code = case invite_code {
    Some(code) if code != "" -> Ok(code)
    _ -> Error(InviteRequired)
  }
  use invite_code <- result.try(invite_code)

  use state <- result.try(ensure_email_available(state, email))

  use invite <- result.try(validate_invite(state, invite_code, now_unix))

  use password_hash <- result.try(
    password.hash(password_raw)
    |> result.map_error(PasswordError),
  )

  let user_id = state.next_user_id

  let user =
    ss.StoredUser(
      id: user_id,
      email: email,
      password_hash: password_hash,
      org_id: org.id,
      org_role: Member,
      created_at: now_iso,
    )

  let invite =
    ss.OrgInvite(..invite, used_at_unix: Some(now_unix), used_by: Some(user_id))

  let state =
    ss.State(
      ..state,
      next_user_id: user_id + 1,
      users_by_id: dict.insert(state.users_by_id, user_id, user),
      user_id_by_email: dict.insert(state.user_id_by_email, email, user_id),
      invites_by_code: dict.insert(state.invites_by_code, invite_code, invite),
    )

  Ok(#(state, user))
}

fn ensure_email_available(
  state: ss.State,
  email: String,
) -> Result(ss.State, AuthError) {
  case dict.get(state.user_id_by_email, email) {
    Ok(_) -> Error(EmailTaken)
    Error(_) -> Ok(state)
  }
}

fn validate_invite(
  state: ss.State,
  code: String,
  now_unix: Int,
) -> Result(ss.OrgInvite, AuthError) {
  use invite <- result.try(
    dict.get(state.invites_by_code, code)
    |> result.replace_error(InviteInvalid),
  )
  use _ <- result.try(check_invite_used(invite))
  use _ <- result.try(check_invite_expired(invite, now_unix))
  Ok(invite)
}

fn check_invite_used(invite: ss.OrgInvite) -> Result(Nil, AuthError) {
  case invite.used_at_unix {
    Some(_) -> Error(InviteUsed)
    None -> Ok(Nil)
  }
}

fn check_invite_expired(
  invite: ss.OrgInvite,
  now_unix: Int,
) -> Result(Nil, AuthError) {
  case invite.expires_at_unix {
    Some(expires) if now_unix > expires -> Error(InviteExpired)
    _ -> Ok(Nil)
  }
}

/// Authenticates a user against the in-memory auth state.
///
/// Example:
///   login(state, email, password)
pub fn login(
  state: ss.State,
  email: String,
  password_raw: String,
) -> Result(ss.StoredUser, AuthError) {
  use user_id <- result.try(
    dict.get(state.user_id_by_email, email)
    |> result.replace_error(InvalidCredentials),
  )

  use user <- result.try(
    dict.get(state.users_by_id, user_id)
    |> result.replace_error(InvalidCredentials),
  )

  use matched <- result.try(
    password.verify(password_raw, user.password_hash)
    |> result.map_error(PasswordError),
  )

  case matched {
    True -> Ok(user)
    False -> Error(InvalidCredentials)
  }
}

/// Returns a user by id from the in-memory auth state.
///
/// Example:
///   get_user(state, user_id)
pub fn get_user(state: ss.State, user_id: Int) -> Result(ss.StoredUser, Nil) {
  dict.get(state.users_by_id, user_id)
}

/// Inserts an invite into the in-memory state.
///
/// Example:
///   insert_invite(state, invite)
pub fn insert_invite(state: ss.State, invite: ss.OrgInvite) -> ss.State {
  ss.State(
    ..state,
    invites_by_code: dict.insert(state.invites_by_code, invite.code, invite),
  )
}
