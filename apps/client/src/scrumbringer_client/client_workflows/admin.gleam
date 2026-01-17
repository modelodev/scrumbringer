//// Admin workflow handlers.
////
//// ## Mission
////
//// Handles admin-specific flows: org settings, project members management,
//// and org user search.
////
//// ## Responsibilities
////
//// - Org settings role changes and saves
//// - Project member add/remove dialogs
//// - Org users search for member autocomplete
////
//// ## Non-responsibilities
////
//// - API calls (see `api.gleam`)
//// - User permissions checking (see `permissions.gleam`)

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_client/api
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading, Login, MemberAdded,
  MemberRemoved, Model, NotAsked, OrgSettingsSaved, OrgUsersSearchResults,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Org Settings Handlers
// =============================================================================

/// Handle org users cache fetch success.
pub fn handle_org_users_cache_fetched_ok(
  model: Model,
  users: List(api.OrgUser),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, org_users_cache: Loaded(users)), effect.none())
}

/// Handle org users cache fetch error.
pub fn handle_org_users_cache_fetched_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> #(Model(..model, page: Login, user: opt.None), effect.none())
    False -> #(Model(..model, org_users_cache: Failed(err)), effect.none())
  }
}

/// Handle org settings users fetch success.
pub fn handle_org_settings_users_fetched_ok(
  model: Model,
  users: List(api.OrgUser),
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
  err: api.ApiError,
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
            api.update_org_user_role(user_id, role, fn(result) {
              OrgSettingsSaved(user_id, result)
            }),
          )
        }

        _ -> #(model, effect.none())
      }
    }
  }
}

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

/// Handle org settings save success.
pub fn handle_org_settings_saved_ok(
  model: Model,
  updated: api.OrgUser,
) -> #(Model, Effect(Msg)) {
  let update_list = fn(users: List(api.OrgUser)) {
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
    Model(
      ..model,
      org_settings_users: org_settings_users,
      org_users_cache: org_users_cache,
      org_settings_save_in_flight: False,
      org_settings_error: opt.None,
      org_settings_error_user_id: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.RoleUpdated)),
    ),
    effect.none(),
  )
}

/// Handle org settings save error.
pub fn handle_org_settings_saved_error(
  model: Model,
  user_id: Int,
  err: api.ApiError,
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

// =============================================================================
// Member Add Dialog Handlers
// =============================================================================

/// Handle member add dialog open.
pub fn handle_member_add_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      members_add_dialog_open: True,
      members_add_selected_user: opt.None,
      members_add_error: opt.None,
      org_users_search_query: "",
      org_users_search_results: NotAsked,
    ),
    effect.none(),
  )
}

/// Handle member add dialog close.
pub fn handle_member_add_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      members_add_dialog_open: False,
      members_add_selected_user: opt.None,
      members_add_error: opt.None,
      org_users_search_query: "",
      org_users_search_results: NotAsked,
    ),
    effect.none(),
  )
}

/// Handle member add role dropdown change.
pub fn handle_member_add_role_changed(
  model: Model,
  role: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, members_add_role: role), effect.none())
}

/// Handle member add user selection.
pub fn handle_member_add_user_selected(
  model: Model,
  user_id: Int,
) -> #(Model, Effect(Msg)) {
  let selected = case model.org_users_search_results {
    Loaded(users) ->
      case list.find(users, fn(u) { u.id == user_id }) {
        Ok(user) -> opt.Some(user)
        Error(_) -> opt.None
      }

    _ -> opt.None
  }

  #(Model(..model, members_add_selected_user: selected), effect.none())
}

/// Handle member add form submission.
pub fn handle_member_add_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.members_add_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.selected_project_id, model.members_add_selected_user {
        opt.Some(project_id), opt.Some(user) -> {
          let model =
            Model(
              ..model,
              members_add_in_flight: True,
              members_add_error: opt.None,
            )
          #(
            model,
            api.add_project_member(
              project_id,
              user.id,
              model.members_add_role,
              MemberAdded,
            ),
          )
        }

        _, _ -> #(
          Model(
            ..model,
            members_add_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.SelectUserFirst,
            )),
          ),
          effect.none(),
        )
      }
    }
  }
}

/// Handle member added success.
pub fn handle_member_added_ok(
  model: Model,
  refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      members_add_in_flight: False,
      members_add_dialog_open: False,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.MemberAdded)),
    )
  refresh_fn(model)
}

/// Handle member added error.
pub fn handle_member_added_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      Model(
        ..model,
        members_add_in_flight: False,
        members_add_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
      ),
      effect.none(),
    )
    _ -> #(
      Model(
        ..model,
        members_add_in_flight: False,
        members_add_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Member Remove Handlers
// =============================================================================

/// Handle member remove click (show confirmation).
pub fn handle_member_remove_clicked(
  model: Model,
  user_id: Int,
) -> #(Model, Effect(Msg)) {
  let maybe_user =
    update_helpers.resolve_org_user(model.org_users_cache, user_id)

  let user = case maybe_user {
    opt.Some(user) -> user
    opt.None -> fallback_org_user(model, user_id)
  }

  #(
    Model(
      ..model,
      members_remove_confirm: opt.Some(user),
      members_remove_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle member remove cancel.
pub fn handle_member_remove_cancelled(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      members_remove_confirm: opt.None,
      members_remove_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle member remove confirmation.
pub fn handle_member_remove_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.members_remove_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.selected_project_id, model.members_remove_confirm {
        opt.Some(project_id), opt.Some(user) -> {
          let model =
            Model(
              ..model,
              members_remove_in_flight: True,
              members_remove_error: opt.None,
            )
          #(
            model,
            api.remove_project_member(project_id, user.id, MemberRemoved),
          )
        }
        _, _ -> #(model, effect.none())
      }
    }
  }
}

/// Handle member removed success.
pub fn handle_member_removed_ok(
  model: Model,
  refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      members_remove_in_flight: False,
      members_remove_confirm: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.MemberRemoved)),
    )
  refresh_fn(model)
}

/// Handle member removed error.
pub fn handle_member_removed_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      Model(
        ..model,
        members_remove_in_flight: False,
        members_remove_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
      ),
      effect.none(),
    )
    _ -> #(
      Model(
        ..model,
        members_remove_in_flight: False,
        members_remove_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Org Users Search Handlers
// =============================================================================

/// Handle org users search input change.
pub fn handle_org_users_search_changed(
  model: Model,
  query: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, org_users_search_query: query), effect.none())
}

/// Handle org users search debounced.
pub fn handle_org_users_search_debounced(
  model: Model,
  query: String,
) -> #(Model, Effect(Msg)) {
  case string.trim(query) == "" {
    True -> #(
      Model(..model, org_users_search_results: NotAsked),
      effect.none(),
    )
    False -> {
      let model = Model(..model, org_users_search_results: Loading)
      #(model, api.list_org_users(query, OrgUsersSearchResults))
    }
  }
}

/// Handle org users search results success.
pub fn handle_org_users_search_results_ok(
  model: Model,
  users: List(api.OrgUser),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, org_users_search_results: Loaded(users)), effect.none())
}

/// Handle org users search results error.
pub fn handle_org_users_search_results_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> #(Model(..model, page: Login, user: opt.None), effect.none())
    False -> #(
      Model(..model, org_users_search_results: Failed(err)),
      effect.none(),
    )
  }
}

// =============================================================================
// Members Fetched Handlers
// =============================================================================

/// Handle members fetch success.
pub fn handle_members_fetched_ok(
  model: Model,
  members: List(api.ProjectMember),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, members: Loaded(members)), effect.none())
}

/// Handle members fetch error.
pub fn handle_members_fetched_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> #(Model(..model, page: Login, user: opt.None), effect.none())
    False -> #(Model(..model, members: Failed(err)), effect.none())
  }
}

// =============================================================================
// Helpers
// =============================================================================

fn fallback_org_user(_model: Model, user_id: Int) -> api.OrgUser {
  // ProjectMember doesn't have email, so we use a placeholder
  api.OrgUser(
    id: user_id,
    email: "User #" <> int.to_string(user_id),
    org_role: "",
    created_at: "",
  )
}
