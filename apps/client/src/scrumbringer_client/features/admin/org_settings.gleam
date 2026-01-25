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

import gleam/dict
import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser}
import domain/org_role
import domain/user.{User}
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Login, Model, OrgSettingsSaved,
  admin_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// API modules
import scrumbringer_client/api/org as api_org

// =============================================================================
// Org Users Cache Handlers
// =============================================================================

/// Handle org users cache fetch success.
pub fn handle_org_users_cache_fetched_ok(
  model: Model,
  users: List(OrgUser),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, org_users_cache: Loaded(users)), effect.none())
}

/// Handle org users cache fetch error.
pub fn handle_org_users_cache_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> #(Model(..model, page: Login, user: opt.None), effect.none())
    False -> #(Model(..model, org_users_cache: Failed(err)), effect.none())
  }
}

// =============================================================================
// Org Settings Users Handlers
// =============================================================================

/// Handle org settings users fetch success.
pub fn handle_org_settings_users_fetched_ok(
  model: Model,
  users: List(OrgUser),
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      org_settings_users: Loaded(users),
      org_settings_role_drafts: dict.new(),
      org_settings_save_in_flight: False,
      org_settings_error: opt.None,
      org_settings_error_user_id: opt.None,
    ),
    effect.none(),
  )
}

/// Handle org settings users fetch error.
pub fn handle_org_settings_users_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)

    403 -> #(
      Model(
        ..model,
        org_settings_users: Failed(err),
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
      ),
      effect.none(),
    )

    _ -> #(Model(..model, org_settings_users: Failed(err)), effect.none())
  }
}

// =============================================================================
// Role Change Handlers
// =============================================================================

/// Handle org settings role dropdown change.
pub fn handle_org_settings_role_changed(
  model: Model,
  user_id: Int,
  org_role: String,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      org_settings_role_drafts: dict.insert(
        model.org_settings_role_drafts,
        user_id,
        org_role,
      ),
      org_settings_error: opt.None,
      org_settings_error_user_id: opt.None,
    ),
    effect.none(),
  )
}

/// Handle org settings save click.
pub fn handle_org_settings_save_clicked(
  model: Model,
  user_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.org_settings_save_in_flight {
    True -> #(model, effect.none())

    False -> {
      let role = get_user_role_draft(model, user_id)

      case role {
        "admin" | "member" -> {
          let model =
            Model(
              ..model,
              org_settings_save_in_flight: True,
              org_settings_error: opt.None,
              org_settings_error_user_id: opt.None,
            )

          #(
            model,
            api_org.update_org_user_role(user_id, role, fn(result) {
              admin_msg(OrgSettingsSaved(user_id, result))
            }),
          )
        }

        _ -> #(model, effect.none())
      }
    }
  }
}

// =============================================================================
// Save Result Handlers
// =============================================================================

/// Handle org settings save success.
pub fn handle_org_settings_saved_ok(
  model: Model,
  updated: OrgUser,
) -> #(Model, Effect(Msg)) {
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

  // Remove saved user from drafts
  let org_settings_role_drafts =
    dict.delete(model.org_settings_role_drafts, updated.id)

  let org_users_cache = case model.org_users_cache {
    Loaded(users) -> Loaded(update_list(users))
    other -> other
  }

  // If the updated user is the current user, update model.user with new role
  let user = case model.user {
    opt.Some(current_user) if current_user.id == updated.id ->
      case org_role.parse(updated.org_role) {
        Ok(new_role) -> opt.Some(User(..current_user, org_role: new_role))
        Error(_) -> model.user
      }
    _ -> model.user
  }

  // Check if there are more pending changes to save
  let remaining_changes = dict.to_list(org_settings_role_drafts)

  case remaining_changes {
    // No more pending changes, done
    [] -> #(
      Model(
        ..model,
        user: user,
        org_settings_users: org_settings_users,
        org_users_cache: org_users_cache,
        org_settings_role_drafts: org_settings_role_drafts,
        org_settings_save_in_flight: False,
        org_settings_error: opt.None,
        org_settings_error_user_id: opt.None,
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.RoleUpdated)),
      ),
      effect.none(),
    )

    // More pending changes, save next
    [#(next_user_id, next_role), ..] -> #(
      Model(
        ..model,
        user: user,
        org_settings_users: org_settings_users,
        org_users_cache: org_users_cache,
        org_settings_role_drafts: org_settings_role_drafts,
        org_settings_save_in_flight: True,
        org_settings_error: opt.None,
        org_settings_error_user_id: opt.None,
      ),
      api_org.update_org_user_role(next_user_id, next_role, fn(result) {
        admin_msg(OrgSettingsSaved(next_user_id, result))
      }),
    )
  }
}

/// Handle org settings save error.
pub fn handle_org_settings_saved_error(
  model: Model,
  user_id: Int,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)

    403 -> #(
      Model(
        ..model,
        org_settings_save_in_flight: False,
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
      ),
      effect.none(),
    )

    409 -> #(
      Model(
        ..model,
        org_settings_save_in_flight: False,
        org_settings_error_user_id: opt.Some(user_id),
        org_settings_error: opt.Some(err.message),
      ),
      effect.none(),
    )

    _ -> #(
      Model(
        ..model,
        org_settings_save_in_flight: False,
        org_settings_error_user_id: opt.Some(user_id),
        org_settings_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

/// Handle save all pending org role changes.
/// Iterates through org_settings_role_drafts and saves each pending change.
pub fn handle_org_settings_save_all_clicked(
  model: Model,
) -> #(Model, Effect(Msg)) {
  case model.org_settings_save_in_flight {
    True -> #(model, effect.none())

    False -> {
      // Get pending changes (user_id, role) pairs
      let pending_changes = dict.to_list(model.org_settings_role_drafts)

      case pending_changes {
        [] -> #(model, effect.none())

        [#(user_id, role), ..] -> {
          // Save the first pending change, then continue with the rest
          let model =
            Model(
              ..model,
              org_settings_save_in_flight: True,
              org_settings_error: opt.None,
              org_settings_error_user_id: opt.None,
            )

          #(
            model,
            api_org.update_org_user_role(user_id, role, fn(result) {
              admin_msg(OrgSettingsSaved(user_id, result))
            }),
          )
        }
      }
    }
  }
}

// =============================================================================
// Private Helpers
// =============================================================================

/// Get user role from drafts or fallback to current role from org_settings_users.
fn get_user_role_draft(model: Model, user_id: Int) -> String {
  case dict.get(model.org_settings_role_drafts, user_id) {
    Ok(r) -> r
    Error(_) -> get_current_user_role(model, user_id)
  }
}

/// Look up user's current role from org_settings_users.
fn get_current_user_role(model: Model, user_id: Int) -> String {
  case model.org_settings_users {
    Loaded(users) ->
      case list.find(users, fn(u) { u.id == user_id }) {
        Ok(u) -> u.org_role
        Error(_) -> ""
      }
    _ -> ""
  }
}
