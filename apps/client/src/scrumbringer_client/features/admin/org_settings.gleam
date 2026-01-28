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

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/user.{User}
import scrumbringer_client/client_state.{
  type Model, type Msg, AdminModel, CoreModel, Failed, Loaded,
  OrgSettingsDeleted, OrgSettingsSaved, admin_msg, update_admin, update_core,
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
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, org_users_cache: Loaded(users))
    }),
    effect.none(),
  )
}

/// Handle org users cache fetch error.
pub fn handle_org_users_cache_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        AdminModel(..admin, org_users_cache: Failed(err))
      }),
      effect.none(),
    )
  })
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
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        org_settings_users: Loaded(users),
        org_settings_save_in_flight: False,
        org_settings_error: opt.None,
        org_settings_error_user_id: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle org settings users fetch error.
pub fn handle_org_settings_users_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    case err.status {
      403 -> {
        let model =
          update_admin(model, fn(admin) {
            AdminModel(..admin, org_settings_users: Failed(err))
          })
        let toast_fx =
          update_helpers.toast_warning(update_helpers.i18n_t(
            model,
            i18n_text.NotPermitted,
          ))
        #(model, toast_fx)
      }

      _ -> #(
        update_admin(model, fn(admin) {
          AdminModel(..admin, org_settings_users: Failed(err))
        }),
        effect.none(),
      )
    }
  })
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
  case model.admin.org_settings_save_in_flight {
    True -> #(model, effect.none())

    False -> {
      let current_role = get_current_user_role(model, user_id)

      case org_role {
        "admin" | "member" ->
          case current_role == org_role {
            True -> #(model, effect.none())
            False -> {
              let model =
                update_admin(model, fn(admin) {
                  AdminModel(
                    ..admin,
                    org_settings_save_in_flight: True,
                    org_settings_error: opt.None,
                    org_settings_error_user_id: opt.None,
                  )
                })

              #(
                model,
                api_org.update_org_user_role(user_id, org_role, fn(result) {
                  admin_msg(OrgSettingsSaved(user_id, result))
                }),
              )
            }
          }

        _ -> #(model, effect.none())
      }
    }
  }
}

// =============================================================================
// Delete Handlers
// =============================================================================

/// Handle org settings delete click (show confirmation).
pub fn handle_org_settings_delete_clicked(
  model: Model,
  user_id: Int,
) -> #(Model, Effect(Msg)) {
  let maybe_user =
    update_helpers.resolve_org_user(model.admin.org_users_cache, user_id)

  let user = case maybe_user {
    opt.Some(user) -> user
    opt.None -> fallback_org_user(user_id)
  }

  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        org_settings_delete_confirm: opt.Some(user),
        org_settings_delete_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle org settings delete cancel.
pub fn handle_org_settings_delete_cancelled(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        org_settings_delete_confirm: opt.None,
        org_settings_delete_error: opt.None,
      )
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle org settings delete confirmation.
pub fn handle_org_settings_delete_confirmed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  case model.admin.org_settings_delete_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.admin.org_settings_delete_confirm {
        opt.Some(user) -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                org_settings_delete_in_flight: True,
                org_settings_delete_error: opt.None,
              )
            })
          #(
            model,
            api_org.delete_org_user(user.id, fn(result) {
              admin_msg(OrgSettingsDeleted(result))
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

  let org_settings_users = case model.admin.org_settings_users {
    Loaded(users) -> Loaded(update_list(users))
    other -> other
  }

  let org_users_cache = case model.admin.org_users_cache {
    Loaded(users) -> Loaded(update_list(users))
    other -> other
  }

  // If the updated user is the current user, update model.core.user with new role
  let user = case model.core.user {
    opt.Some(current_user) if current_user.id == updated.id ->
      case org_role.parse(updated.org_role) {
        Ok(new_role) -> opt.Some(User(..current_user, org_role: new_role))
        Error(_) -> model.core.user
      }
    _ -> model.core.user
  }

  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        org_settings_users: org_settings_users,
        org_users_cache: org_users_cache,
        org_settings_save_in_flight: False,
        org_settings_error: opt.None,
        org_settings_error_user_id: opt.None,
      )
    })
  let model = update_core(model, fn(core) { CoreModel(..core, user: user) })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.RoleUpdated,
    ))
  #(model, toast_fx)
}

/// Handle org settings delete success.
pub fn handle_org_settings_deleted_ok(model: Model) -> #(Model, Effect(Msg)) {
  let removed_id = case model.admin.org_settings_delete_confirm {
    opt.Some(user) -> user.id
    opt.None -> -1
  }

  let filter_users = fn(users: List(OrgUser)) {
    list.filter(users, fn(u) { u.id != removed_id })
  }

  let org_settings_users = case model.admin.org_settings_users {
    Loaded(users) -> Loaded(filter_users(users))
    other -> other
  }

  let org_users_cache = case model.admin.org_users_cache {
    Loaded(users) -> Loaded(filter_users(users))
    other -> other
  }

  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        org_settings_users: org_settings_users,
        org_users_cache: org_users_cache,
        org_settings_delete_in_flight: False,
        org_settings_delete_confirm: opt.None,
        org_settings_delete_error: opt.None,
      )
    })

  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.UserDeleted,
    ))
  #(model, toast_fx)
}

/// Handle org settings delete error.
pub fn handle_org_settings_deleted_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    case err.status {
      403 -> #(
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            org_settings_delete_in_flight: False,
            org_settings_delete_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.NotPermitted,
            )),
          )
        }),
        update_helpers.toast_warning(update_helpers.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
      )
      409 -> #(
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            org_settings_delete_in_flight: False,
            org_settings_delete_error: opt.Some(err.message),
          )
        }),
        update_helpers.toast_warning(err.message),
      )
      _ -> #(
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            org_settings_delete_in_flight: False,
            org_settings_delete_error: opt.Some(err.message),
          )
        }),
        effect.none(),
      )
    }
  })
}

/// Handle org settings save error.
pub fn handle_org_settings_saved_error(
  model: Model,
  user_id: Int,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    case err.status {
      403 -> {
        let model =
          update_admin(model, fn(admin) {
            AdminModel(..admin, org_settings_save_in_flight: False)
          })
        let toast_fx =
          update_helpers.toast_warning(update_helpers.i18n_t(
            model,
            i18n_text.NotPermitted,
          ))
        #(model, toast_fx)
      }

      409 -> #(
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            org_settings_save_in_flight: False,
            org_settings_error_user_id: opt.Some(user_id),
            org_settings_error: opt.Some(err.message),
          )
        }),
        effect.none(),
      )

      _ -> #(
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            org_settings_save_in_flight: False,
            org_settings_error_user_id: opt.Some(user_id),
            org_settings_error: opt.Some(err.message),
          )
        }),
        effect.none(),
      )
    }
  })
}

// =============================================================================
// Private Helpers
// =============================================================================

// Justification: nested case improves clarity for branching logic.
/// Look up user's current role from org_settings_users.
fn get_current_user_role(model: Model, user_id: Int) -> String {
  case model.admin.org_settings_users {
    Loaded(users) ->
      case list.find(users, fn(u) { u.id == user_id }) {
        Ok(u) -> u.org_role
        Error(_) -> ""
      }
    _ -> ""
  }
}

fn fallback_org_user(user_id: Int) -> OrgUser {
  OrgUser(
    id: user_id,
    email: "User #" <> int.to_string(user_id),
    org_role: "",
    created_at: "",
  )
}
