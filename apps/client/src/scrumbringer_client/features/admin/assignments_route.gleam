//// Root adapter for assignments admin messages.

import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/features/admin/member_role_update
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/assignments/update as assignments_update
import scrumbringer_client/features/route_support
import scrumbringer_client/router

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    assignments_update.try_update(
      model.admin.assignments,
      inner,
      context(model),
      feedback_context(),
    )
  {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

pub fn start_user_projects_fetch(
  model: client_state.Model,
  users: List(OrgUser),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let #(assignments, fx) =
    assignments_update.start_user_projects_fetch(
      model.admin.assignments,
      users,
      context(model),
    )

  #(
    client_state.update_admin(model, fn(admin) {
      update_assignments(admin, fn(_) { assignments })
    }),
    fx,
  )
}

fn apply_update(
  model: client_state.Model,
  update: assignments_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let assignments_update.Update(assignments, local_fx, auth_policy, root_policy) =
    update
  let apply_update = fn() {
    let model =
      client_state.update_admin(model, fn(admin) {
        update_assignments(admin, fn(_) { assignments })
      })

    let root_fx = case root_policy {
      assignments_update.NoRootPolicy -> effect.none()
      assignments_update.ReplaceAssignmentsView(view_mode) ->
        router.replace_team_view(view_mode)
      assignments_update.MemberRoleSuccessFeedback ->
        member_role_update.success_effect(model)
      assignments_update.MemberRoleErrorFeedback(err) ->
        member_role_update.error_effect(model, err)
    }

    #(model, effect.batch([local_fx, root_fx]))
  }

  case auth_timing(auth_policy) {
    NoAuthCheck -> apply_update()
    CheckAuthBefore(err) ->
      route_support.apply_auth_check_before(model, opt.Some(err), apply_update)
    CheckAuthAfter(err) ->
      route_support.apply_auth_check_after(opt.Some(err), apply_update)
  }
}

type AuthTiming {
  NoAuthCheck
  CheckAuthBefore(ApiError)
  CheckAuthAfter(ApiError)
}

fn auth_timing(policy: assignments_update.AuthPolicy) -> AuthTiming {
  case policy {
    assignments_update.NoAuthCheck -> NoAuthCheck
    assignments_update.CheckAuth(err) -> CheckAuthBefore(err)
    assignments_update.CheckAuthAfterUpdate(err) -> CheckAuthAfter(err)
  }
}

fn update_assignments(
  admin: admin_state.AdminModel,
  f: fn(assignments_state.AssignmentsModel) ->
    assignments_state.AssignmentsModel,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, assignments: f(admin.assignments))
}

fn context(
  model: client_state.Model,
) -> assignments_update.Context(client_state.Msg) {
  assignments_update.Context(
    active_section: model.core.active_section,
    on_project_members_fetched: fn(project_id, result) {
      client_state.admin_msg(admin_messages.AssignmentsProjectMembersFetched(
        project_id,
        result,
      ))
    },
    on_user_projects_fetched: fn(user_id, result) {
      client_state.admin_msg(admin_messages.AssignmentsUserProjectsFetched(
        user_id,
        result,
      ))
    },
    on_project_member_added: fn(project_id, result) {
      client_state.admin_msg(admin_messages.AssignmentsProjectMemberAdded(
        project_id,
        result,
      ))
    },
    on_user_project_added: fn(user_id, result) {
      client_state.admin_msg(admin_messages.AssignmentsUserProjectAdded(
        user_id,
        result,
      ))
    },
    on_remove_completed: fn(project_id, user_id, result) {
      client_state.admin_msg(admin_messages.AssignmentsRemoveDone(
        project_id,
        user_id,
        result,
      ))
    },
    on_role_change_completed: fn(project_id, user_id, result) {
      client_state.admin_msg(admin_messages.AssignmentsRoleChangeDone(
        project_id,
        user_id,
        result,
      ))
    },
  )
}

fn feedback_context() -> assignments_update.FeedbackContext(client_state.Msg) {
  assignments_update.FeedbackContext(on_error_toast: app_effects.toast_error)
}
