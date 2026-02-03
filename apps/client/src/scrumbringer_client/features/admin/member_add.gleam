//// Admin member add dialog update handlers.
////
//// ## Mission
////
//// Handles project member add dialog flows: open/close, user selection,
//// and submission.
////
//// ## Responsibilities
////
//// - Member add dialog open/close
//// - Role dropdown changes
//// - User selection from search results
//// - Form submission and result handling
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **search.gleam**: Provides org users search for autocomplete

import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/project_role.{type ProjectRole}
import scrumbringer_client/client_state.{
  type Model, type Msg, MemberAdded, admin_msg, update_admin,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// API modules
import scrumbringer_client/api/projects as api_projects

// =============================================================================
// Dialog Open/Close Handlers
// =============================================================================

/// Handle member add dialog open.
pub fn handle_member_add_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members_add_dialog_open: True,
        members_add_selected_user: opt.None,
        members_add_error: opt.None,
        org_users_search: state_types.OrgUsersSearchIdle("", 0),
      )
    }),
    effect.none(),
  )
}

/// Handle member add dialog close.
pub fn handle_member_add_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members_add_dialog_open: False,
        members_add_selected_user: opt.None,
        members_add_error: opt.None,
        org_users_search: state_types.OrgUsersSearchIdle("", 0),
      )
    }),
    effect.none(),
  )
}

// =============================================================================
// Selection Handlers
// =============================================================================

/// Handle member add role dropdown change.
pub fn handle_member_add_role_changed(
  model: Model,
  role: ProjectRole,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(..admin, members_add_role: role)
    }),
    effect.none(),
  )
}

/// Handle member add user selection.
pub fn handle_member_add_user_selected(
  model: Model,
  user_id: Int,
) -> #(Model, Effect(Msg)) {
  let selected = case model.admin.org_users_search {
    state_types.OrgUsersSearchLoaded(_, _, users) ->
      case list.find(users, fn(u) { u.id == user_id }) {
        Ok(user) -> opt.Some(user)
        Error(_) -> opt.None
      }

    _ -> opt.None
  }

  #(
    update_admin(model, fn(admin) {
      admin_state.AdminModel(..admin, members_add_selected_user: selected)
    }),
    effect.none(),
  )
}

// =============================================================================
// Submission Handlers
// =============================================================================

// Justification: nested case improves clarity for branching logic.
/// Handle member add form submission.
pub fn handle_member_add_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.members_add_in_flight {
    True -> #(model, effect.none())
    False -> {
      case
        model.core.selected_project_id,
        model.admin.members_add_selected_user
      {
        opt.Some(project_id), opt.Some(user) -> {
          let model =
            update_admin(model, fn(admin) {
              admin_state.AdminModel(
                ..admin,
                members_add_in_flight: True,
                members_add_error: opt.None,
              )
            })
          #(
            model,
            api_projects.add_project_member(
              project_id,
              user.id,
              model.admin.members_add_role,
              fn(result) { admin_msg(MemberAdded(result)) },
            ),
          )
        }

        _, _ -> #(
          update_admin(model, fn(admin) {
            admin_state.AdminModel(
              ..admin,
              members_add_error: opt.Some(update_helpers.i18n_t(
                model,
                i18n_text.SelectUserFirst,
              )),
            )
          }),
          effect.none(),
        )
      }
    }
  }
}

// =============================================================================
// Result Handlers
// =============================================================================

/// Handle member added success.
pub fn handle_member_added_ok(
  model: Model,
  refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        members_add_in_flight: False,
        members_add_dialog_open: False,
      )
    })
  let #(model, refresh_fx) = refresh_fn(model)
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.MemberAdded,
    ))
  #(model, effect.batch([refresh_fx, toast_fx]))
}

/// Handle member added error.
pub fn handle_member_added_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    case err.status {
      403 -> #(
        update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            members_add_in_flight: False,
            members_add_error: opt.Some(update_helpers.i18n_t(
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
      _ -> #(
        update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            members_add_in_flight: False,
            members_add_error: opt.Some(err.message),
          )
        }),
        effect.none(),
      )
    }
  })
}
