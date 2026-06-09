//// Admin feature update handlers.
////
//// ## Mission
////
//// Provides unified access to admin-specific flows: org settings, project
//// members management, and org user search.
////
//// ## Responsibilities
////
//// - Handle members fetch results
////
//// ## Non-responsibilities
////
//// - API calls (see `api/*.gleam`)
//// - User permissions checking (see `permissions.gleam`)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches admin messages to handlers here
//// - **org_settings.gleam**: Org settings handlers
//// - **member_add.gleam**: Member add dialog handlers
//// - **member_remove.gleam**: Member remove handlers
//// - **search.gleam**: Org users search handlers

import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError}
import domain/project.{type Project}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/invites as admin_invites
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/admin/projects as admin_projects
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/assignments/update as assignments_workflow
import scrumbringer_client/features/capabilities/update as capabilities_workflow
import scrumbringer_client/features/invites/update as invite_links_workflow
import scrumbringer_client/features/projects/project_list
import scrumbringer_client/features/projects/update as projects_workflow
import scrumbringer_client/features/task_types/update as task_types_workflow
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/router

import scrumbringer_client/features/admin/member_add
import scrumbringer_client/features/admin/member_list
import scrumbringer_client/features/admin/member_release_all
import scrumbringer_client/features/admin/member_remove
import scrumbringer_client/features/admin/member_role
import scrumbringer_client/features/admin/org_settings
import scrumbringer_client/features/admin/search
import scrumbringer_client/features/auth/helpers as auth_helpers
import scrumbringer_client/i18n/i18n

// =============================================================================
// Dispatch
// =============================================================================

/// Provides admin update context.
pub type Context {
  Context(
    refresh_section_for_test: fn(client_state.Model) ->
      #(client_state.Model, effect.Effect(client_state.Msg)),
  )
}

/// Dispatch admin messages to feature handlers.
///
pub fn update(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    projects_workflow.try_update(
      model.admin.projects,
      inner,
      projects_context(model),
      projects_feedback_context(model),
      projects_error_feedback_context(model),
    )
  {
    opt.Some(update) -> apply_projects_update(model, update)
    opt.None -> update_without_projects(model, inner, ctx)
  }
}

fn update_without_projects(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    invite_links_workflow.try_update(
      model.admin.invites,
      inner,
      invite_links_context(model),
      invite_links_feedback_context(model),
      invite_links_error_feedback_context(model),
    )
  {
    opt.Some(update) -> apply_invites_update(model, update)
    opt.None -> update_without_invites(model, inner, ctx)
  }
}

fn update_without_invites(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    capabilities_workflow.try_update(
      model.admin.capabilities,
      inner,
      capabilities_context(model),
      capabilities_feedback_context(model),
      capabilities_error_feedback_context(model),
    )
  {
    opt.Some(update) -> apply_capabilities_update(model, update)
    opt.None -> update_without_capabilities(model, inner, ctx)
  }
}

fn update_without_capabilities(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    task_types_workflow.try_update(
      model.admin.task_types,
      inner,
      task_types_context(model),
      task_types_feedback_context(model),
      task_types_error_feedback_context(model),
    )
  {
    opt.Some(update) -> apply_task_types_update(model, update, ctx)
    opt.None -> update_without_task_types(model, inner, ctx)
  }
}

fn update_without_task_types(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    member_list.try_update(
      model.admin.members,
      inner,
      member_list_context(model),
    )
  {
    opt.Some(update) -> apply_member_list_update(model, update)
    opt.None -> update_without_member_list(model, inner, ctx)
  }
}

fn update_without_member_list(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    org_settings.try_update(
      model.admin.members,
      inner,
      org_settings_context(),
      org_settings_feedback_context(model),
    )
  {
    opt.Some(update) -> apply_org_settings_update(model, update)
    opt.None -> update_without_org_settings(model, inner, ctx)
  }
}

fn update_without_org_settings(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    member_add.try_update(
      model.admin.members,
      inner,
      member_add_context(model),
      member_add_feedback_context(model),
      member_add_error_feedback_context(model),
    )
  {
    opt.Some(update) -> apply_member_add_update(model, update, ctx)
    opt.None -> update_without_member_add(model, inner, ctx)
  }
}

fn update_without_member_add(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    member_remove.try_update(
      model.admin.members,
      inner,
      member_remove_context(model),
      member_remove_feedback_context(model),
      member_remove_error_feedback_context(model),
    )
  {
    opt.Some(update) -> apply_member_remove_update(model, update, ctx)
    opt.None -> update_without_member_remove(model, inner, ctx)
  }
}

fn update_without_member_remove(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    member_release_all.try_update(
      model.admin.members,
      inner,
      member_release_all_context(model),
      member_release_all_feedback_context(model),
    )
  {
    opt.Some(update) -> apply_member_release_all_update(model, update)
    opt.None -> update_without_member_release_all(model, inner, ctx)
  }
}

fn update_without_member_release_all(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    member_role.try_update(
      model.admin.members,
      inner,
      member_role_context(model),
      member_role_feedback_context(model),
    )
  {
    opt.Some(update) -> apply_member_role_update(model, update)
    opt.None -> update_without_member_role(model, inner, ctx)
  }
}

fn update_without_member_role(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    search.try_update(model.admin.members, inner, org_users_search_context())
  {
    opt.Some(update) -> apply_org_users_search_update(model, update)
    opt.None -> update_without_org_users_search(model, inner, ctx)
  }
}

fn update_without_org_users_search(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    assignments_workflow.try_update(
      model.admin.assignments,
      inner,
      assignments_context(model),
      assignments_feedback_context(),
    )
  {
    opt.Some(update) -> apply_assignments_update(model, update)
    opt.None -> update_without_assignments(model, inner, ctx)
  }
}

fn update_without_assignments(
  model: client_state.Model,
  inner: admin_messages.Msg,
  _ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case inner {
    // Handled by the root update before this dispatch.
    admin_messages.ProjectsFetched(_) -> #(model, effect.none())

    // Handled by projects_workflow.try_update before this dispatch.
    admin_messages.ProjectCreateDialogOpened
    | admin_messages.ProjectCreateDialogClosed
    | admin_messages.ProjectCreateNameChanged(_)
    | admin_messages.ProjectCreateSubmitted
    | admin_messages.ProjectCreated(_)
    | admin_messages.ProjectEditDialogOpened(_, _)
    | admin_messages.ProjectEditDialogClosed
    | admin_messages.ProjectEditNameChanged(_)
    | admin_messages.ProjectEditSubmitted
    | admin_messages.ProjectUpdated(_)
    | admin_messages.ProjectDeleteConfirmOpened(_, _)
    | admin_messages.ProjectDeleteConfirmClosed
    | admin_messages.ProjectDeleteSubmitted
    | admin_messages.ProjectDeleted(_) -> #(model, effect.none())

    // Handled by invite_links_workflow.try_update before this dispatch.
    admin_messages.InviteCreateDialogOpened
    | admin_messages.InviteCreateDialogClosed
    | admin_messages.InviteLinkEmailChanged(_)
    | admin_messages.InviteLinksFetched(_)
    | admin_messages.InviteLinkCreateSubmitted
    | admin_messages.InviteLinkRegenerateClicked(_)
    | admin_messages.InviteLinkCreated(_)
    | admin_messages.InviteLinkRegenerated(_)
    | admin_messages.InviteLinkCopyClicked(_)
    | admin_messages.InviteLinkCopyFinished(_) -> #(model, effect.none())

    // Handled by capabilities_workflow.try_update before this dispatch.
    admin_messages.CapabilitiesFetched(_)
    | admin_messages.CapabilityCreateDialogOpened
    | admin_messages.CapabilityCreateDialogClosed
    | admin_messages.CapabilityCreateNameChanged(_)
    | admin_messages.CapabilityCreateSubmitted
    | admin_messages.CapabilityCreated(_)
    | admin_messages.CapabilityDeleteDialogOpened(_)
    | admin_messages.CapabilityDeleteDialogClosed
    | admin_messages.CapabilityDeleteSubmitted
    | admin_messages.CapabilityDeleted(_)
    | admin_messages.MemberCapabilitiesDialogOpened(_)
    | admin_messages.MemberCapabilitiesDialogClosed
    | admin_messages.MemberCapabilitiesToggled(_)
    | admin_messages.MemberCapabilitiesSaveClicked
    | admin_messages.MemberCapabilitiesFetched(_)
    | admin_messages.MemberCapabilitiesSaved(_)
    | admin_messages.CapabilityMembersDialogOpened(_)
    | admin_messages.CapabilityMembersDialogClosed
    | admin_messages.CapabilityMembersToggled(_)
    | admin_messages.CapabilityMembersSaveClicked
    | admin_messages.CapabilityMembersFetched(_)
    | admin_messages.CapabilityMembersSaved(_) -> #(model, effect.none())

    // Handled by member_list.try_update before this dispatch.
    admin_messages.MembersFetched(_) -> #(model, effect.none())

    // Handled by org_settings.try_update before this dispatch.
    admin_messages.OrgUsersCacheFetched(_)
    | admin_messages.OrgSettingsUsersFetched(_)
    | admin_messages.OrgSettingsRoleChanged(_, _)
    | admin_messages.OrgSettingsSaved(_, _)
    | admin_messages.OrgSettingsDeleteClicked(_)
    | admin_messages.OrgSettingsDeleteCancelled
    | admin_messages.OrgSettingsDeleteConfirmed
    | admin_messages.OrgSettingsDeleted(_) -> #(model, effect.none())

    // Handled by member_add.try_update before this dispatch.
    admin_messages.MemberAddDialogOpened
    | admin_messages.MemberAddDialogClosed
    | admin_messages.MemberAddRoleChanged(_)
    | admin_messages.MemberAddUserSelected(_)
    | admin_messages.MemberAddSubmitted
    | admin_messages.MemberAdded(_) -> #(model, effect.none())

    // Handled by member_remove.try_update before this dispatch.
    admin_messages.MemberRemoveClicked(_)
    | admin_messages.MemberRemoveCancelled
    | admin_messages.MemberRemoveConfirmed
    | admin_messages.MemberRemoved(_) -> #(model, effect.none())

    // Handled by member_release_all.try_update before this dispatch.
    admin_messages.MemberReleaseAllClicked(_, _)
    | admin_messages.MemberReleaseAllCancelled
    | admin_messages.MemberReleaseAllConfirmed
    | admin_messages.MemberReleaseAllResult(_) -> #(model, effect.none())

    // Handled by member_role.try_update before this dispatch.
    admin_messages.MemberRoleChangeRequested(_, _)
    | admin_messages.MemberRoleChanged(_) -> #(model, effect.none())

    // Handled by search.try_update before this dispatch.
    admin_messages.OrgUsersSearchChanged(_)
    | admin_messages.OrgUsersSearchDebounced(_)
    | admin_messages.OrgUsersSearchResults(_, _) -> #(model, effect.none())

    // Handled by assignments_workflow.try_update before this dispatch.
    admin_messages.AssignmentsViewModeChanged(_)
    | admin_messages.AssignmentsSearchChanged(_)
    | admin_messages.AssignmentsSearchDebounced(_)
    | admin_messages.AssignmentsProjectToggled(_)
    | admin_messages.AssignmentsUserToggled(_)
    | admin_messages.AssignmentsProjectMembersFetched(_, _)
    | admin_messages.AssignmentsUserProjectsFetched(_, _) -> #(
      model,
      effect.none(),
    )

    // Handled by assignments_workflow.try_update before this dispatch.
    admin_messages.AssignmentsInlineAddStarted(_)
    | admin_messages.AssignmentsInlineAddSearchChanged(_)
    | admin_messages.AssignmentsInlineAddSelectionChanged(_)
    | admin_messages.AssignmentsInlineAddRoleChanged(_)
    | admin_messages.AssignmentsInlineAddSubmitted
    | admin_messages.AssignmentsInlineAddCancelled
    | admin_messages.AssignmentsProjectMemberAdded(_, _)
    | admin_messages.AssignmentsUserProjectAdded(_, _) -> #(
      model,
      effect.none(),
    )

    // Handled by assignments_workflow.try_update before this dispatch.
    admin_messages.AssignmentsRemoveClicked(_, _)
    | admin_messages.AssignmentsRemoveCancelled
    | admin_messages.AssignmentsRemoveConfirmed
    | admin_messages.AssignmentsRemoveCompleted(_, _, _) -> #(
      model,
      effect.none(),
    )

    // Handled by assignments_workflow.try_update before this dispatch.
    admin_messages.AssignmentsRoleChanged(_, _, _)
    | admin_messages.AssignmentsRoleChangeCompleted(_, _, _) -> #(
      model,
      effect.none(),
    )

    // Handled by task_types_workflow.try_update before this dispatch.
    admin_messages.TaskTypesFetched(_)
    | admin_messages.TaskTypeCreateDialogOpened
    | admin_messages.TaskTypeCreateDialogClosed
    | admin_messages.TaskTypeCreateNameChanged(_)
    | admin_messages.TaskTypeCreateIconChanged(_)
    | admin_messages.TaskTypeCreateIconSearchChanged(_)
    | admin_messages.TaskTypeCreateIconCategoryChanged(_)
    | admin_messages.TaskTypeIconLoaded
    | admin_messages.TaskTypeIconErrored
    | admin_messages.TaskTypeCreateCapabilityChanged(_)
    | admin_messages.TaskTypeCreateSubmitted
    | admin_messages.TaskTypeCreated(_)
    | admin_messages.OpenTaskTypeDialog(_)
    | admin_messages.CloseTaskTypeDialog
    | admin_messages.TaskTypeCrudCreated(_)
    | admin_messages.TaskTypeCrudUpdated(_)
    | admin_messages.TaskTypeCrudDeleted(_) -> #(model, effect.none())
  }
}

fn update_members(
  admin: admin_state.AdminModel,
  f: fn(admin_members.Model) -> admin_members.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, members: f(admin.members))
}

fn set_members(
  model: client_state.Model,
  members: admin_members.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    update_members(admin, fn(_) { members })
  })
}

fn apply_members_result(
  model: client_state.Model,
  members: admin_members.Model,
  fx: effect.Effect(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(set_members(model, members), fx)
}

fn apply_auth_check_before(
  model: client_state.Model,
  auth_error: opt.Option(ApiError),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case auth_error {
    opt.None -> apply_update()
    opt.Some(err) -> auth_helpers.handle_401_or(model, err, apply_update)
  }
}

fn apply_auth_check_after(
  auth_error: opt.Option(ApiError),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case auth_error {
    opt.None -> apply_update()
    opt.Some(err) -> {
      let #(next, fx) = apply_update()
      auth_helpers.handle_401_or(next, err, fn() { #(next, fx) })
    }
  }
}

fn apply_member_list_update(
  model: client_state.Model,
  update: member_list.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let member_list.Update(members, local_fx, auth_policy) = update

  apply_auth_check_before(model, member_list_auth_error(auth_policy), fn() {
    apply_members_result(model, members, local_fx)
  })
}

fn member_list_auth_error(
  policy: member_list.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    member_list.NoAuthCheck -> opt.None
    member_list.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_org_settings_update(
  model: client_state.Model,
  update: org_settings.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let org_settings.Update(members, local_fx, auth_policy, root_policy) = update

  apply_auth_check_before(model, org_settings_auth_error(auth_policy), fn() {
    let model = set_members(model, members)

    case root_policy {
      org_settings.NoRootPolicy -> #(model, local_fx)

      org_settings.StartAssignmentsFetch(users) -> {
        let #(model, assignments_fx) =
          apply_assignments_transition(model, fn(assignments) {
            assignments_workflow.start_user_projects_fetch(
              assignments,
              users,
              assignments_context(model),
            )
          })
        #(model, effect.batch([local_fx, assignments_fx]))
      }

      org_settings.UpdateCurrentUser(updated) -> {
        let user =
          org_settings.current_user_after_saved(model.core.user, updated)
        let model =
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(..core, user: user)
          })
        #(model, local_fx)
      }
    }
  })
}

fn org_settings_auth_error(
  policy: org_settings.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    org_settings.NoAuthCheck -> opt.None
    org_settings.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_member_add_update(
  model: client_state.Model,
  update: member_add.Update(client_state.Msg),
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let Context(refresh_section_for_test: refresh_section_for_test) = ctx
  let member_add.Update(members, local_fx, auth_policy, refresh_policy) = update

  apply_auth_check_before(model, member_add_auth_error(auth_policy), fn() {
    let model = set_members(model, members)
    let #(model, refresh_fx) = case refresh_policy {
      member_add.NoRefresh -> #(model, effect.none())
      member_add.RefreshSection -> refresh_section_for_test(model)
    }
    #(model, effect.batch([local_fx, refresh_fx]))
  })
}

fn member_add_auth_error(policy: member_add.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    member_add.NoAuthCheck -> opt.None
    member_add.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_member_remove_update(
  model: client_state.Model,
  update: member_remove.Update(client_state.Msg),
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let Context(refresh_section_for_test: refresh_section_for_test) = ctx
  let member_remove.Update(members, local_fx, auth_policy, refresh_policy) =
    update

  apply_auth_check_before(model, member_remove_auth_error(auth_policy), fn() {
    let model = set_members(model, members)
    let #(model, refresh_fx) = case refresh_policy {
      member_remove.NoRefresh -> #(model, effect.none())
      member_remove.RefreshSection -> refresh_section_for_test(model)
    }
    #(model, effect.batch([local_fx, refresh_fx]))
  })
}

fn member_remove_auth_error(
  policy: member_remove.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    member_remove.NoAuthCheck -> opt.None
    member_remove.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_member_role_update(
  model: client_state.Model,
  update: member_role.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let member_role.Update(members, local_fx, auth_policy) = update

  apply_auth_check_before(model, member_role_auth_error(auth_policy), fn() {
    apply_members_result(model, members, local_fx)
  })
}

fn member_role_auth_error(
  policy: member_role.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    member_role.NoAuthCheck -> opt.None
    member_role.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_member_release_all_update(
  model: client_state.Model,
  update: member_release_all.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let member_release_all.Update(members, local_fx, auth_policy) = update

  apply_auth_check_before(
    model,
    member_release_all_auth_error(auth_policy),
    fn() { apply_members_result(model, members, local_fx) },
  )
}

fn member_release_all_auth_error(
  policy: member_release_all.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    member_release_all.NoAuthCheck -> opt.None
    member_release_all.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_org_users_search_update(
  model: client_state.Model,
  update: search.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let search.Update(members, local_fx, auth_policy) = update

  apply_auth_check_before(model, search_auth_error(auth_policy), fn() {
    apply_members_result(model, members, local_fx)
  })
}

fn search_auth_error(policy: search.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    search.NoAuthCheck -> opt.None
    search.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_assignments(
  admin: admin_state.AdminModel,
  f: fn(state_types.AssignmentsModel) -> state_types.AssignmentsModel,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, assignments: f(admin.assignments))
}

fn apply_assignments_update(
  model: client_state.Model,
  update: assignments_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let assignments_workflow.Update(
    assignments,
    local_fx,
    auth_policy,
    root_policy,
  ) = update
  let apply_update = fn() {
    let model =
      client_state.update_admin(model, fn(admin) {
        update_assignments(admin, fn(_) { assignments })
      })

    let root_fx = case root_policy {
      assignments_workflow.NoRootPolicy -> effect.none()
      assignments_workflow.ReplaceAssignmentsView(view_mode) ->
        router.replace_assignments_view(view_mode)
      assignments_workflow.MemberRoleSuccessFeedback ->
        member_role.success_effect(member_role_feedback_context(model))
      assignments_workflow.MemberRoleErrorFeedback(err) ->
        member_role.error_effect(err, member_role_feedback_context(model))
    }

    #(model, effect.batch([local_fx, root_fx]))
  }

  case assignments_auth_timing(auth_policy) {
    NoAssignmentsAuthCheck -> apply_update()
    CheckAssignmentsAuthBefore(err) ->
      apply_auth_check_before(model, opt.Some(err), apply_update)
    CheckAssignmentsAuthAfter(err) ->
      apply_auth_check_after(opt.Some(err), apply_update)
  }
}

type AssignmentsAuthTiming {
  NoAssignmentsAuthCheck
  CheckAssignmentsAuthBefore(ApiError)
  CheckAssignmentsAuthAfter(ApiError)
}

fn assignments_auth_timing(
  policy: assignments_workflow.AuthPolicy,
) -> AssignmentsAuthTiming {
  case policy {
    assignments_workflow.NoAuthCheck -> NoAssignmentsAuthCheck
    assignments_workflow.CheckAuth(err) -> CheckAssignmentsAuthBefore(err)
    assignments_workflow.CheckAuthAfterUpdate(err) ->
      CheckAssignmentsAuthAfter(err)
  }
}

fn apply_assignments_transition(
  model: client_state.Model,
  transition: fn(state_types.AssignmentsModel) ->
    #(state_types.AssignmentsModel, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let #(assignments, fx) = transition(model.admin.assignments)
  #(
    client_state.update_admin(model, fn(admin) {
      update_assignments(admin, fn(_) { assignments })
    }),
    fx,
  )
}

fn assignments_context(
  model: client_state.Model,
) -> assignments_workflow.Context(client_state.Msg) {
  assignments_workflow.Context(
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
      client_state.admin_msg(admin_messages.AssignmentsRemoveCompleted(
        project_id,
        user_id,
        result,
      ))
    },
    on_role_change_completed: fn(project_id, user_id, result) {
      client_state.admin_msg(admin_messages.AssignmentsRoleChangeCompleted(
        project_id,
        user_id,
        result,
      ))
    },
  )
}

fn assignments_feedback_context() -> assignments_workflow.FeedbackContext(
  client_state.Msg,
) {
  assignments_workflow.FeedbackContext(on_error_toast: app_effects.toast_error)
}

fn org_settings_context() -> org_settings.Context(client_state.Msg) {
  org_settings.Context(
    on_org_settings_saved: fn(user_id, result) {
      client_state.admin_msg(admin_messages.OrgSettingsSaved(user_id, result))
    },
    on_org_settings_deleted: fn(result) {
      client_state.admin_msg(admin_messages.OrgSettingsDeleted(result))
    },
  )
}

fn org_settings_feedback_context(
  model: client_state.Model,
) -> org_settings.FeedbackContext(client_state.Msg) {
  org_settings.FeedbackContext(
    role_updated: i18n.t(model.ui.locale, i18n_text.RoleUpdated),
    user_deleted: i18n.t(model.ui.locale, i18n_text.UserDeleted),
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_success_toast: app_effects.toast_success,
    on_warning_toast: app_effects.toast_warning,
  )
}

fn member_add_context(
  model: client_state.Model,
) -> member_add.Context(client_state.Msg) {
  member_add.Context(
    selected_project_id: model.core.selected_project_id,
    select_user_first: i18n.t(model.ui.locale, i18n_text.SelectUserFirst),
    on_member_added: fn(result) {
      client_state.admin_msg(admin_messages.MemberAdded(result))
    },
  )
}

fn member_add_feedback_context(
  model: client_state.Model,
) -> member_add.FeedbackContext(client_state.Msg) {
  member_add.FeedbackContext(
    member_added: i18n.t(model.ui.locale, i18n_text.MemberAdded),
    on_success_toast: app_effects.toast_success,
  )
}

fn member_add_error_feedback_context(
  model: client_state.Model,
) -> member_add.ErrorFeedbackContext(client_state.Msg) {
  member_add.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}

fn member_release_all_context(
  model: client_state.Model,
) -> member_release_all.Context(client_state.Msg) {
  member_release_all.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_release_all_result: fn(result) {
      client_state.admin_msg(admin_messages.MemberReleaseAllResult(result))
    },
  )
}

fn member_release_all_feedback_context(
  model: client_state.Model,
) -> member_release_all.FeedbackContext(client_state.Msg) {
  member_release_all.FeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    release_all_self_error: i18n.t(
      model.ui.locale,
      i18n_text.ReleaseAllSelfError,
    ),
    release_all_none: fn(user_name) {
      i18n.t(model.ui.locale, i18n_text.ReleaseAllNone(user_name))
    },
    release_all_success: fn(released_count, user_name) {
      i18n.t(
        model.ui.locale,
        i18n_text.ReleaseAllSuccess(released_count, user_name),
      )
    },
    release_all_error: fn(user_name) {
      i18n.t(model.ui.locale, i18n_text.ReleaseAllError(user_name))
    },
    on_success_toast: app_effects.toast_success,
    on_warning_toast: app_effects.toast_warning,
  )
}

fn member_role_context(
  model: client_state.Model,
) -> member_role.Context(client_state.Msg) {
  member_role.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_role_changed: fn(result) {
      client_state.admin_msg(admin_messages.MemberRoleChanged(result))
    },
  )
}

fn member_role_feedback_context(
  model: client_state.Model,
) -> member_role.FeedbackContext(client_state.Msg) {
  member_role.FeedbackContext(
    role_updated: i18n.t(model.ui.locale, i18n_text.RoleUpdated),
    cannot_demote_last_manager: i18n.t(
      model.ui.locale,
      i18n_text.CannotDemoteLastManager,
    ),
    on_success_toast: app_effects.toast_success,
    on_warning_toast: app_effects.toast_warning,
    on_error_toast: app_effects.toast_error,
  )
}

fn member_remove_context(
  model: client_state.Model,
) -> member_remove.Context(client_state.Msg) {
  member_remove.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_removed: fn(result) {
      client_state.admin_msg(admin_messages.MemberRemoved(result))
    },
  )
}

fn member_remove_feedback_context(
  model: client_state.Model,
) -> member_remove.FeedbackContext(client_state.Msg) {
  member_remove.FeedbackContext(
    member_removed: i18n.t(model.ui.locale, i18n_text.MemberRemoved),
    on_success_toast: app_effects.toast_success,
  )
}

fn member_remove_error_feedback_context(
  model: client_state.Model,
) -> member_remove.ErrorFeedbackContext(client_state.Msg) {
  member_remove.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}

fn member_list_context(
  model: client_state.Model,
) -> member_list.Context(client_state.Msg) {
  member_list.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_capabilities_fetched: fn(result) {
      client_state.admin_msg(admin_messages.MemberCapabilitiesFetched(result))
    },
  )
}

fn org_users_search_context() -> search.Context(client_state.Msg) {
  search.Context(on_search_results: fn(token, result) {
    client_state.admin_msg(admin_messages.OrgUsersSearchResults(token, result))
  })
}

fn update_capabilities(
  admin: admin_state.AdminModel,
  f: fn(admin_capabilities.Model) -> admin_capabilities.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, capabilities: f(admin.capabilities))
}

fn update_task_types(
  admin: admin_state.AdminModel,
  f: fn(admin_task_types.Model) -> admin_task_types.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, task_types: f(admin.task_types))
}

fn apply_capabilities_update(
  model: client_state.Model,
  update: capabilities_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let capabilities_workflow.Update(capabilities, fx, auth_policy) = update

  apply_auth_check_before(model, capabilities_auth_error(auth_policy), fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_capabilities(admin, fn(_) { capabilities })
      }),
      fx,
    )
  })
}

fn capabilities_auth_error(
  policy: capabilities_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    capabilities_workflow.NoAuthCheck -> opt.None
    capabilities_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_task_types_update(
  model: client_state.Model,
  update: task_types_workflow.Update(client_state.Msg),
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let Context(refresh_section_for_test: refresh_section_for_test) = ctx
  let task_types_workflow.Update(
    task_types,
    local_fx,
    auth_policy,
    refresh_policy,
  ) = update

  apply_auth_check_before(model, task_types_auth_error(auth_policy), fn() {
    let model =
      client_state.update_admin(model, fn(admin) {
        update_task_types(admin, fn(_) { task_types })
      })
    let #(model, refresh_fx) = case refresh_policy {
      task_types_workflow.NoRefresh -> #(model, effect.none())
      task_types_workflow.RefreshSection -> refresh_section_for_test(model)
    }
    #(model, effect.batch([local_fx, refresh_fx]))
  })
}

fn task_types_auth_error(
  policy: task_types_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    task_types_workflow.NoAuthCheck -> opt.None
    task_types_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn capabilities_context(
  model: client_state.Model,
) -> capabilities_workflow.Context(client_state.Msg) {
  capabilities_workflow.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_capabilities_fetched: fn(result) {
      client_state.admin_msg(admin_messages.MemberCapabilitiesFetched(result))
    },
    on_member_capabilities_saved: fn(result) {
      client_state.admin_msg(admin_messages.MemberCapabilitiesSaved(result))
    },
    on_capability_members_fetched: fn(result) {
      client_state.admin_msg(admin_messages.CapabilityMembersFetched(result))
    },
    on_capability_members_saved: fn(result) {
      client_state.admin_msg(admin_messages.CapabilityMembersSaved(result))
    },
    on_capability_created: fn(result) {
      client_state.admin_msg(admin_messages.CapabilityCreated(result))
    },
    on_capability_deleted: fn(result) {
      client_state.admin_msg(admin_messages.CapabilityDeleted(result))
    },
    name_required: i18n.t(model.ui.locale, i18n_text.NameRequired),
  )
}

fn capabilities_feedback_context(
  model: client_state.Model,
) -> capabilities_workflow.FeedbackContext(client_state.Msg) {
  capabilities_workflow.FeedbackContext(
    capability_created: i18n.t(model.ui.locale, i18n_text.CapabilityCreated),
    capability_deleted: i18n.t(model.ui.locale, i18n_text.CapabilityDeleted),
    member_capabilities_saved: i18n.t(model.ui.locale, i18n_text.SkillsSaved),
    capability_members_saved: i18n.t(model.ui.locale, i18n_text.MembersSaved),
    on_success_toast: app_effects.toast_success,
  )
}

fn capabilities_error_feedback_context(
  model: client_state.Model,
) -> capabilities_workflow.ErrorFeedbackContext(client_state.Msg) {
  capabilities_workflow.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}

fn task_types_context(
  model: client_state.Model,
) -> task_types_workflow.Context(client_state.Msg) {
  task_types_workflow.Context(
    selected_project_id: model.core.selected_project_id,
    on_task_type_created: fn(result) {
      client_state.admin_msg(admin_messages.TaskTypeCreated(result))
    },
    select_project_first: i18n.t(model.ui.locale, i18n_text.SelectProjectFirst),
    name_and_icon_required: i18n.t(
      model.ui.locale,
      i18n_text.NameAndIconRequired,
    ),
  )
}

fn task_types_feedback_context(
  model: client_state.Model,
) -> task_types_workflow.FeedbackContext(client_state.Msg) {
  task_types_workflow.FeedbackContext(
    task_type_created: i18n.t(model.ui.locale, i18n_text.TaskTypeCreated),
    task_type_updated: i18n.t(model.ui.locale, i18n_text.TaskTypeUpdated),
    task_type_deleted: i18n.t(model.ui.locale, i18n_text.TaskTypeDeleted),
    on_success_toast: app_effects.toast_success,
  )
}

fn task_types_error_feedback_context(
  model: client_state.Model,
) -> task_types_workflow.ErrorFeedbackContext(client_state.Msg) {
  task_types_workflow.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}

fn update_invites(
  admin: admin_state.AdminModel,
  f: fn(admin_invites.Model) -> admin_invites.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, invites: f(admin.invites))
}

fn update_projects(
  admin: admin_state.AdminModel,
  f: fn(admin_projects.Model) -> admin_projects.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, projects: f(admin.projects))
}

fn apply_projects_update(
  model: client_state.Model,
  update: projects_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let projects_workflow.Update(projects, fx, auth_policy, core_policy) = update

  apply_auth_check_before(model, projects_auth_error(auth_policy), fn() {
    let model = apply_projects_core_policy(model, core_policy)
    #(
      client_state.update_admin(model, fn(admin) {
        update_projects(admin, fn(_) { projects })
      }),
      fx,
    )
  })
}

fn projects_auth_error(
  policy: projects_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    projects_workflow.NoAuthCheck -> opt.None
    projects_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_projects_core_policy(
  model: client_state.Model,
  policy: projects_workflow.CorePolicy,
) -> client_state.Model {
  case policy {
    projects_workflow.NoCoreChange -> model
    projects_workflow.CoreProjectCreated(project) ->
      projects_after_created(model, project)
    projects_workflow.CoreProjectUpdated(project) ->
      projects_after_updated(model, project)
    projects_workflow.CoreProjectDeleted(deleted_id) ->
      projects_after_deleted(model, deleted_id)
  }
}

fn projects_context(
  model: client_state.Model,
) -> projects_workflow.Context(client_state.Msg) {
  projects_workflow.Context(
    on_project_created: fn(result) {
      client_state.admin_msg(admin_messages.ProjectCreated(result))
    },
    on_project_updated: fn(result) {
      client_state.admin_msg(admin_messages.ProjectUpdated(result))
    },
    on_project_deleted: fn(result) {
      client_state.admin_msg(admin_messages.ProjectDeleted(result))
    },
    name_required: i18n.t(model.ui.locale, i18n_text.NameRequired),
  )
}

fn projects_feedback_context(
  model: client_state.Model,
) -> projects_workflow.FeedbackContext(client_state.Msg) {
  projects_workflow.FeedbackContext(
    project_created: i18n.t(model.ui.locale, i18n_text.ProjectCreated),
    project_updated: i18n.t(model.ui.locale, i18n_text.Saved),
    project_deleted: i18n.t(model.ui.locale, i18n_text.Deleted),
    on_success_toast: app_effects.toast_success,
  )
}

fn projects_error_feedback_context(
  model: client_state.Model,
) -> projects_workflow.ErrorFeedbackContext(client_state.Msg) {
  projects_workflow.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
    on_error_toast: app_effects.toast_error,
  )
}

fn projects_after_created(
  model: client_state.Model,
  project: Project,
) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(
      ..core,
      projects: project_list.prepend_or_single(core.projects, project),
      selected_project_id: opt.Some(project.id),
    )
  })
}

fn projects_after_updated(
  model: client_state.Model,
  project: Project,
) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(
      ..core,
      projects: project_list.update_name(core.projects, project),
    )
  })
}

fn projects_after_deleted(
  model: client_state.Model,
  deleted_id: opt.Option(Int),
) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(
      ..core,
      projects: project_list.remove(core.projects, deleted_id),
      selected_project_id: project_list.selected_after_delete(
        core.selected_project_id,
        deleted_id,
      ),
    )
  })
}

fn apply_invites_update(
  model: client_state.Model,
  update: invite_links_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let invite_links_workflow.Update(invites, fx, auth_policy) = update

  apply_auth_check_before(model, invite_links_auth_error(auth_policy), fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_invites(admin, fn(_) { invites })
      }),
      fx,
    )
  })
}

fn invite_links_auth_error(
  policy: invite_links_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    invite_links_workflow.NoAuthCheck -> opt.None
    invite_links_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn invite_links_context(
  model: client_state.Model,
) -> invite_links_workflow.Context(client_state.Msg) {
  invite_links_workflow.Context(
    on_links_fetched: fn(result) {
      client_state.admin_msg(admin_messages.InviteLinksFetched(result))
    },
    on_link_created: fn(result) {
      client_state.admin_msg(admin_messages.InviteLinkCreated(result))
    },
    on_link_regenerated: fn(result) {
      client_state.admin_msg(admin_messages.InviteLinkRegenerated(result))
    },
    on_copy_finished: fn(ok) {
      client_state.admin_msg(admin_messages.InviteLinkCopyFinished(ok))
    },
    email_required: i18n.t(model.ui.locale, i18n_text.EmailRequired),
    copying: i18n.t(model.ui.locale, i18n_text.Copying),
    copied: i18n.t(model.ui.locale, i18n_text.Copied),
    copy_failed: i18n.t(model.ui.locale, i18n_text.CopyFailed),
  )
}

fn invite_links_feedback_context(
  model: client_state.Model,
) -> invite_links_workflow.FeedbackContext(client_state.Msg) {
  invite_links_workflow.FeedbackContext(
    invite_link_created: i18n.t(model.ui.locale, i18n_text.InviteLinkCreated),
    invite_link_regenerated: i18n.t(
      model.ui.locale,
      i18n_text.InviteLinkRegenerated,
    ),
    on_success_toast: app_effects.toast_success,
  )
}

fn invite_links_error_feedback_context(
  model: client_state.Model,
) -> invite_links_workflow.ErrorFeedbackContext(client_state.Msg) {
  invite_links_workflow.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}
