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

import scrumbringer_client/client_state
import scrumbringer_client/features/admin/assignments_route
import scrumbringer_client/features/admin/capabilities_route
import scrumbringer_client/features/admin/invites_route
import scrumbringer_client/features/admin/members_route
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/org_settings_route
import scrumbringer_client/features/admin/projects_route
import scrumbringer_client/features/admin/task_types_route

import scrumbringer_client/features/admin/api_tokens_route

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
  case projects_route.try_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_projects(model, inner, ctx)
  }
}

fn update_without_projects(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case invites_route.try_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_invites(model, inner, ctx)
  }
}

fn update_without_invites(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case capabilities_route.try_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_capabilities(model, inner, ctx)
  }
}

fn update_without_capabilities(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let Context(refresh_section_for_test: refresh_section_for_test) = ctx
  case task_types_route.try_update(model, inner, refresh_section_for_test) {
    opt.Some(result) -> result
    opt.None -> update_without_task_types(model, inner, ctx)
  }
}

fn update_without_task_types(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let Context(refresh_section_for_test: refresh_section_for_test) = ctx
  case members_route.try_update(model, inner, refresh_section_for_test) {
    opt.Some(result) -> result
    opt.None -> update_without_members(model, inner, ctx)
  }
}

fn update_without_members(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case org_settings_route.try_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_org_settings(model, inner, ctx)
  }
}

fn update_without_org_settings(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case assignments_route.try_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_assignments(model, inner, ctx)
  }
}

fn update_without_assignments(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case api_tokens_route.try_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_api_tokens(model, inner, ctx)
  }
}

fn update_without_api_tokens(
  model: client_state.Model,
  inner: admin_messages.Msg,
  _ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case inner {
    // Handled by the root update before this dispatch.
    admin_messages.ProjectsFetched(_) -> #(model, effect.none())

    // Handled by projects_route.try_update before this dispatch.
    admin_messages.ProjectCreateDialogOpened
    | admin_messages.ProjectCreateDialogClosed
    | admin_messages.ProjectCreateNameChanged(_)
    | admin_messages.ProjectCreateMaxDepthChanged(_)
    | admin_messages.ProjectCreateHealthyPoolLimitChanged(_)
    | admin_messages.ProjectCreateDepthSingularChanged(_, _)
    | admin_messages.ProjectCreateDepthPluralChanged(_, _)
    | admin_messages.ProjectCreateNextClicked
    | admin_messages.ProjectCreateBackClicked
    | admin_messages.ProjectCreateSubmitted
    | admin_messages.ProjectCreated(_)
    | admin_messages.ProjectEditDialogOpened(_, _, _, _)
    | admin_messages.ProjectEditDialogClosed
    | admin_messages.ProjectEditNameChanged(_)
    | admin_messages.ProjectEditMaxDepthChanged(_)
    | admin_messages.ProjectEditHealthyPoolLimitChanged(_)
    | admin_messages.ProjectEditDepthSingularChanged(_, _)
    | admin_messages.ProjectEditDepthPluralChanged(_, _)
    | admin_messages.ProjectEditDepthReductionReviewClicked
    | admin_messages.ProjectEditDepthReductionPreviewed(_)
    | admin_messages.ProjectEditDepthReductionConfirmed
    | admin_messages.ProjectEditSubmitted
    | admin_messages.ProjectUpdated(_)
    | admin_messages.ProjectDeleteConfirmOpened(_, _)
    | admin_messages.ProjectDeleteConfirmClosed
    | admin_messages.ProjectDeleteSubmitted
    | admin_messages.ProjectDeleted(_) -> #(model, effect.none())

    // Handled by invites_route.try_update before this dispatch.
    admin_messages.InviteCreateDialogOpened
    | admin_messages.InviteCreateDialogClosed
    | admin_messages.InviteLinkEmailChanged(_)
    | admin_messages.InviteLinksFetched(_)
    | admin_messages.InviteLinkCreateSubmitted
    | admin_messages.InviteLinkRegenerateClicked(_)
    | admin_messages.InviteLinkCreated(_)
    | admin_messages.InviteLinkRegenerated(_)
    | admin_messages.InviteLinkInvalidateClicked(_)
    | admin_messages.InviteLinkInvalidateCancelled
    | admin_messages.InviteLinkInvalidateConfirmed
    | admin_messages.InviteLinkInvalidated(_)
    | admin_messages.InviteLinkCopyClicked(_)
    | admin_messages.InviteLinkCopyFinished(_) -> #(model, effect.none())

    // Handled by capabilities_route.try_update before this dispatch.
    admin_messages.CapabilitiesFetched(_)
    | admin_messages.CapabilityCreateDialogOpened
    | admin_messages.CapabilityCreateDialogClosed
    | admin_messages.CapabilityCreateNameChanged(_)
    | admin_messages.CapabilityCreateSubmitted
    | admin_messages.CapabilityCreated(_)
    | admin_messages.CapabilityEditDialogOpened(_, _)
    | admin_messages.CapabilityEditDialogClosed
    | admin_messages.CapabilityEditNameChanged(_)
    | admin_messages.CapabilityEditSubmitted
    | admin_messages.CapabilityUpdated(_)
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

    // Handled by org_settings_route.try_update before this dispatch.
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

    // Handled by assignments_route.try_update before this dispatch.
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

    // Handled by assignments_route.try_update before this dispatch.
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

    // Handled by assignments_route.try_update before this dispatch.
    admin_messages.AssignmentsRemoveClicked(_, _)
    | admin_messages.AssignmentsRemoveCancelled
    | admin_messages.AssignmentsRemoveConfirmed
    | admin_messages.AssignmentsRemoveDone(_, _, _) -> #(model, effect.none())

    // Handled by assignments_route.try_update before this dispatch.
    admin_messages.AssignmentsRoleChanged(_, _, _)
    | admin_messages.AssignmentsRoleChangeDone(_, _, _) -> #(
      model,
      effect.none(),
    )

    // Handled by api_tokens_route.try_update before this dispatch.
    admin_messages.IntegrationUsersFetched(_)
    | admin_messages.ApiTokensFetched(_)
    | admin_messages.ApiTokenCreateDialogOpened
    | admin_messages.ApiTokenCreateDialogClosed
    | admin_messages.ApiTokenNameChanged(_)
    | admin_messages.ApiTokenIntegrationChanged(_)
    | admin_messages.ApiTokenProjectChanged(_)
    | admin_messages.ApiTokenScopeToggled(_)
    | admin_messages.ApiTokenExpiresAtChanged(_)
    | admin_messages.ApiTokenCreateSubmitted
    | admin_messages.ApiTokenCreated(_)
    | admin_messages.ApiTokenCreatedSecretDismissed
    | admin_messages.ApiTokenCreatedSecretCopyClicked(_)
    | admin_messages.ApiTokenCreatedSecretCopyFinished(_)
    | admin_messages.ApiTokenRenameClicked(_, _)
    | admin_messages.ApiTokenRenameCancelled
    | admin_messages.ApiTokenRenameNameChanged(_)
    | admin_messages.ApiTokenRenameSubmitted
    | admin_messages.ApiTokenRenamed(_)
    | admin_messages.ApiTokenRevokeClicked(_)
    | admin_messages.ApiTokenRevokeCancelled
    | admin_messages.ApiTokenRevokeConfirmed
    | admin_messages.ApiTokenRevoked(_, _)
    | admin_messages.IntegrationDeactivateClicked(_)
    | admin_messages.IntegrationDeactivateCancelled
    | admin_messages.IntegrationDeactivateConfirmed
    | admin_messages.IntegrationDeactivated(_, _) -> #(model, effect.none())

    // Handled by task_types_route.try_update before this dispatch.
    admin_messages.TaskTypesFetched(_)
    | admin_messages.TaskTypeCreateDialogOpened
    | admin_messages.TaskTypeCreateDialogClosed
    | admin_messages.TaskTypeCreateNameChanged(_)
    | admin_messages.TaskTypeCreateIconChanged(_)
    | admin_messages.TaskTypeCreateIconSearchChanged(_)
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
