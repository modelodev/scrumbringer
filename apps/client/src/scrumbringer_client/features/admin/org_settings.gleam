//// Admin org settings update handlers.
////
//// ## Mission
////
//// Handles organization settings flows: org users cache, role changes, and saves.
////
//// ## Responsibilities
////
//// - Org users cache fetch handling
//// - Org settings users fetch handling
//// - Role draft changes
//// - Role save operations
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here

import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/org.{type OrgUser}
import domain/org_role
import domain/remote.{Failed, Loaded}
import domain/user.{type User, User}
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/org_user_fallback

// API modules
import scrumbringer_client/api/org as api_org
import scrumbringer_client/helpers/lookup as helpers_lookup

pub type Context(parent_msg) {
  Context(
    on_org_settings_saved: fn(Int, ApiResult(OrgUser)) -> parent_msg,
    on_org_settings_deleted: fn(ApiResult(Nil)) -> parent_msg,
  )
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    role_updated: String,
    user_deleted: String,
    not_permitted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_warning_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type RootPolicy {
  NoRootPolicy
  StartAssignmentsFetch(List(OrgUser))
  UpdateCurrentUser(OrgUser)
}

pub type Update(parent_msg) {
  Update(admin_members.Model, Effect(parent_msg), AuthPolicy, RootPolicy)
}

pub fn try_update(
  model: admin_members.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.OrgUsersCacheFetched(Ok(users)) ->
      handle_org_users_cache_fetched_ok(model, users)
      |> without_auth_check_with_root(StartAssignmentsFetch(users))

    admin_messages.OrgUsersCacheFetched(Error(err)) ->
      handle_org_users_cache_fetched_error(model, err)
      |> with_auth_check(err)

    admin_messages.OrgSettingsUsersFetched(Ok(users)) ->
      handle_org_settings_users_fetched_ok(model, users)
      |> without_auth_check

    admin_messages.OrgSettingsUsersFetched(Error(err)) ->
      handle_org_settings_users_fetched_error(model, err, feedback)
      |> with_auth_check(err)

    admin_messages.OrgSettingsRoleChanged(user_id, org_role) ->
      handle_org_settings_role_changed_with_context(
        model,
        user_id,
        org_role,
        context,
      )
      |> without_auth_check

    admin_messages.OrgSettingsSaved(_user_id, Ok(updated)) ->
      handle_org_settings_saved_ok(model, updated, feedback)
      |> without_auth_check_with_root(UpdateCurrentUser(updated))

    admin_messages.OrgSettingsSaved(user_id, Error(err)) ->
      handle_org_settings_saved_error(model, user_id, err, feedback)
      |> with_auth_check(err)

    admin_messages.OrgSettingsDeleteClicked(user_id) ->
      handle_org_settings_delete_clicked(model, user_id)
      |> without_auth_check

    admin_messages.OrgSettingsDeleteCancelled ->
      handle_org_settings_delete_cancelled(model)
      |> without_auth_check

    admin_messages.OrgSettingsDeleteConfirmed ->
      handle_org_settings_delete_confirmed(model, context)
      |> without_auth_check

    admin_messages.OrgSettingsDeleted(Ok(_)) ->
      handle_org_settings_deleted_ok(model, feedback)
      |> without_auth_check

    admin_messages.OrgSettingsDeleted(Error(err)) ->
      handle_org_settings_deleted_error(model, err, feedback)
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(admin_members.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  without_auth_check_with_root(result, NoRootPolicy)
}

fn without_auth_check_with_root(
  result: #(admin_members.Model, Effect(parent_msg)),
  root_policy: RootPolicy,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck, root_policy)
}

fn with_auth_check(
  result: #(admin_members.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuth(err), NoRootPolicy)
}

fn with_policy(
  result: #(admin_members.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
  root_policy: RootPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy, root_policy))
}

// =============================================================================
// Org Users Cache Handlers
// =============================================================================

/// Handle org users cache fetch success.
fn handle_org_users_cache_fetched_ok(
  model: admin_members.Model,
  users: List(OrgUser),
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(admin_members.Model(..model, org_users_cache: Loaded(users)), effect.none())
}

/// Handle org users cache fetch error.
fn handle_org_users_cache_fetched_error(
  model: admin_members.Model,
  err: ApiError,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(admin_members.Model(..model, org_users_cache: Failed(err)), effect.none())
}

// =============================================================================
// Org Settings Users Handlers
// =============================================================================

/// Handle org settings users fetch success.
fn handle_org_settings_users_fetched_ok(
  model: admin_members.Model,
  users: List(OrgUser),
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      org_settings_users: Loaded(users),
      org_settings_save_in_flight: False,
      org_settings_error: opt.None,
      org_settings_error_user_id: opt.None,
    ),
    effect.none(),
  )
}

/// Handle org settings users fetch error.
fn handle_org_settings_users_fetched_error(
  model: admin_members.Model,
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(..model, org_settings_users: Failed(err)),
    forbidden_warning_effect(err, feedback),
  )
}

// =============================================================================
// Role Change Handlers
// =============================================================================

fn handle_org_settings_role_changed_with_context(
  model: admin_members.Model,
  user_id: Int,
  org_role: org_role.OrgRole,
  context: Context(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  case model.org_settings_save_in_flight {
    True -> #(model, effect.none())

    False -> {
      let current_role = get_current_user_role(model, user_id)

      case current_role == org_role {
        True -> #(model, effect.none())
        False -> {
          let model =
            admin_members.Model(
              ..model,
              org_settings_save_in_flight: True,
              org_settings_error: opt.None,
              org_settings_error_user_id: opt.None,
            )

          #(
            model,
            api_org.update_org_user_role(user_id, org_role, fn(result) {
              context.on_org_settings_saved(user_id, result)
            }),
          )
        }
      }
    }
  }
}

// =============================================================================
// Delete Handlers
// =============================================================================

/// Handle org settings delete click (show confirmation).
fn handle_org_settings_delete_clicked(
  model: admin_members.Model,
  user_id: Int,
) -> #(admin_members.Model, Effect(parent_msg)) {
  let maybe_user =
    helpers_lookup.resolve_org_user(model.org_users_cache, user_id)

  let user = case maybe_user {
    opt.Some(user) -> user
    opt.None -> org_user_fallback.from_id(user_id)
  }

  #(
    admin_members.Model(
      ..model,
      org_settings_delete_confirm: opt.Some(user),
      org_settings_delete_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle org settings delete cancel.
fn handle_org_settings_delete_cancelled(
  model: admin_members.Model,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      org_settings_delete_confirm: opt.None,
      org_settings_delete_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle org settings delete confirmation.
fn handle_org_settings_delete_confirmed(
  model: admin_members.Model,
  context: Context(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  case model.org_settings_delete_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.org_settings_delete_confirm {
        opt.Some(user) -> {
          let model =
            admin_members.Model(
              ..model,
              org_settings_delete_in_flight: True,
              org_settings_delete_error: opt.None,
            )
          #(
            model,
            api_org.delete_org_user(user.id, fn(result) {
              context.on_org_settings_deleted(result)
            }),
          )
        }
        opt.None -> #(model, effect.none())
      }
  }
}

// =============================================================================
// Save Result Handlers
// =============================================================================

/// Handle org settings save success.
fn handle_org_settings_saved_ok(
  model: admin_members.Model,
  updated: OrgUser,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  let update_list = fn(users: List(OrgUser)) {
    list.map(users, fn(u) {
      case u.id == updated.id {
        True -> updated
        False -> u
      }
    })
  }

  let org_settings_users = case model.org_settings_users {
    Loaded(users) -> Loaded(update_list(users))
    other -> other
  }

  let org_users_cache = case model.org_users_cache {
    Loaded(users) -> Loaded(update_list(users))
    other -> other
  }

  #(
    admin_members.Model(
      ..model,
      org_settings_users: org_settings_users,
      org_users_cache: org_users_cache,
      org_settings_save_in_flight: False,
      org_settings_error: opt.None,
      org_settings_error_user_id: opt.None,
    ),
    feedback.on_success_toast(feedback.role_updated),
  )
}

/// Handle org settings delete success.
fn handle_org_settings_deleted_ok(
  model: admin_members.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  let removed_id = case model.org_settings_delete_confirm {
    opt.Some(user) -> user.id
    opt.None -> -1
  }

  let filter_users = fn(users: List(OrgUser)) {
    list.filter(users, fn(u) { u.id != removed_id })
  }

  let org_settings_users = case model.org_settings_users {
    Loaded(users) -> Loaded(filter_users(users))
    other -> other
  }

  let org_users_cache = case model.org_users_cache {
    Loaded(users) -> Loaded(filter_users(users))
    other -> other
  }

  #(
    admin_members.Model(
      ..model,
      org_settings_users: org_settings_users,
      org_users_cache: org_users_cache,
      org_settings_delete_in_flight: False,
      org_settings_delete_confirm: opt.None,
      org_settings_delete_error: opt.None,
    ),
    feedback.on_success_toast(feedback.user_deleted),
  )
}

/// Handle org settings delete error.
fn handle_org_settings_deleted_error(
  model: admin_members.Model,
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  let message = delete_error_message(err, feedback)

  #(
    admin_members.Model(
      ..model,
      org_settings_delete_in_flight: False,
      org_settings_delete_error: opt.Some(message),
    ),
    delete_error_effect(err, message, feedback),
  )
}

/// Handle org settings save error.
fn handle_org_settings_saved_error(
  model: admin_members.Model,
  user_id: Int,
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  case err.status {
    403 -> #(
      admin_members.Model(..model, org_settings_save_in_flight: False),
      feedback.on_warning_toast(feedback.not_permitted),
    )
    _ -> #(
      admin_members.Model(
        ..model,
        org_settings_save_in_flight: False,
        org_settings_error_user_id: opt.Some(user_id),
        org_settings_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

pub fn current_user_after_saved(
  current_user: opt.Option(User),
  updated: OrgUser,
) -> opt.Option(User) {
  case current_user {
    opt.Some(user) if user.id == updated.id ->
      opt.Some(User(..user, org_role: updated.org_role))
    _ -> current_user
  }
}

// =============================================================================
// Private Helpers
// =============================================================================

/// Look up user's current role from org_settings_users.
fn get_current_user_role(
  model: admin_members.Model,
  user_id: Int,
) -> org_role.OrgRole {
  case model.org_settings_users {
    Loaded(users) ->
      case list.find(users, fn(u) { u.id == user_id }) {
        Ok(u) -> u.org_role
        Error(_) -> org_role.Member
      }
    _ -> org_role.Member
  }
}

fn forbidden_warning_effect(
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(feedback.not_permitted)
    _ -> effect.none()
  }
}

fn delete_error_message(
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> String {
  case err.status {
    403 -> feedback.not_permitted
    _ -> err.message
  }
}

fn delete_error_effect(
  err: ApiError,
  message: String,
  feedback: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 | 409 -> feedback.on_warning_toast(message)
    _ -> effect.none()
  }
}
