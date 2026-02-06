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
import domain/org_role
import scrumbringer_client/client_state.{
  type Model, type Msg, admin_msg, update_admin,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/i18n/text as i18n_text

// API modules
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/helpers/toast as helpers_toast

// =============================================================================
// Confirmation Handlers
// =============================================================================

/// Handle member remove click (show confirmation).
pub fn handle_member_remove_clicked(
  model: Model,
  user_id: Int,
) -> #(Model, Effect(Msg)) {
  let maybe_user =
    helpers_lookup.resolve_org_user(
      model.admin.members.org_users_cache,
      user_id,
    )

  let user = case maybe_user {
    opt.Some(user) -> user
    opt.None -> fallback_org_user(user_id)
  }

  #(
    update_admin(model, fn(admin) {
      update_members(admin, fn(members_state) {
        admin_members.Model(
          ..members_state,
          members_remove_confirm: opt.Some(user),
          members_remove_error: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle member remove cancel.
pub fn handle_member_remove_cancelled(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_members(admin, fn(members_state) {
        admin_members.Model(
          ..members_state,
          members_remove_confirm: opt.None,
          members_remove_error: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle member remove confirmation.
pub fn handle_member_remove_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.members.members_remove_in_flight {
    True -> #(model, effect.none())
    False -> {
      case
        model.core.selected_project_id,
        model.admin.members.members_remove_confirm
      {
        opt.Some(project_id), opt.Some(user) -> {
          let model =
            update_admin(model, fn(admin) {
              update_members(admin, fn(members_state) {
                admin_members.Model(
                  ..members_state,
                  members_remove_in_flight: True,
                  members_remove_error: opt.None,
                )
              })
            })
          #(
            model,
            api_projects.remove_project_member(project_id, user.id, fn(result) {
              admin_msg(admin_messages.MemberRemoved(result))
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
      update_members(admin, fn(members_state) {
        admin_members.Model(
          ..members_state,
          members_remove_in_flight: False,
          members_remove_confirm: opt.None,
        )
      })
    })
  let #(model, refresh_fx) = refresh_fn(model)
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
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
  helpers_auth.handle_401_or(model, err, fn() {
    case err.status {
      403 -> #(
        update_admin(model, fn(admin) {
          update_members(admin, fn(members_state) {
            admin_members.Model(
              ..members_state,
              members_remove_in_flight: False,
              members_remove_error: opt.Some(helpers_i18n.i18n_t(
                model,
                i18n_text.NotPermitted,
              )),
            )
          })
        }),
        helpers_toast.toast_warning(helpers_i18n.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
      )
      _ -> #(
        update_admin(model, fn(admin) {
          update_members(admin, fn(members_state) {
            admin_members.Model(
              ..members_state,
              members_remove_in_flight: False,
              members_remove_error: opt.Some(err.message),
            )
          })
        }),
        effect.none(),
      )
    }
  })
}

// =============================================================================
// Private Helpers
// =============================================================================

fn fallback_org_user(user_id: Int) -> OrgUser {
  // ProjectMember doesn't have email, so we use a placeholder
  OrgUser(
    id: user_id,
    email: "User #" <> int.to_string(user_id),
    org_role: org_role.Member,
    created_at: "",
  )
}

fn update_members(
  admin: admin_state.AdminModel,
  f: fn(admin_members.Model) -> admin_members.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, members: f(admin.members))
}
