//// Admin member remove update handlers.
////
//// ## Mission
////
//// Handles project member removal flows: confirmation dialog and removal.
////
//// ## Responsibilities
////
//// - Show member remove confirmation
//// - Cancel/confirm removal
//// - Result handling for member removal
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **helpers.gleam**: Provides fallback_org_user helper

import gleam/int
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser, OrgUser}
import scrumbringer_client/client_state.{
  type Model, type Msg, AdminModel, MemberRemoved, admin_msg, update_admin,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// API modules
import scrumbringer_client/api/projects as api_projects

// =============================================================================
// Confirmation Handlers
// =============================================================================

/// Handle member remove click (show confirmation).
pub fn handle_member_remove_clicked(
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
        members_remove_confirm: opt.Some(user),
        members_remove_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle member remove cancel.
pub fn handle_member_remove_cancelled(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        members_remove_confirm: opt.None,
        members_remove_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle member remove confirmation.
pub fn handle_member_remove_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.members_remove_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.core.selected_project_id, model.admin.members_remove_confirm {
        opt.Some(project_id), opt.Some(user) -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                members_remove_in_flight: True,
                members_remove_error: opt.None,
              )
            })
          #(
            model,
            api_projects.remove_project_member(project_id, user.id, fn(result) {
              admin_msg(MemberRemoved(result))
            }),
          )
        }
        _, _ -> #(model, effect.none())
      }
    }
  }
}

// =============================================================================
// Result Handlers
// =============================================================================

/// Handle member removed success.
pub fn handle_member_removed_ok(
  model: Model,
  refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        members_remove_in_flight: False,
        members_remove_confirm: opt.None,
      )
    })
  let #(model, refresh_fx) = refresh_fn(model)
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.MemberRemoved,
    ))
  #(model, effect.batch([refresh_fx, toast_fx]))
}

/// Handle member removed error.
pub fn handle_member_removed_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          members_remove_in_flight: False,
          members_remove_error: opt.Some(update_helpers.i18n_t(
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
        AdminModel(
          ..admin,
          members_remove_in_flight: False,
          members_remove_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Private Helpers
// =============================================================================

fn fallback_org_user(user_id: Int) -> OrgUser {
  // ProjectMember doesn't have email, so we use a placeholder
  OrgUser(
    id: user_id,
    email: "User #" <> int.to_string(user_id),
    org_role: "",
    created_at: "",
  )
}
