//// Admin feature messages.

import domain/api_error.{type ApiResult}
import domain/api_token
import domain/api_token_scope
import domain/capability.{type Capability}
import domain/org.{type InviteLink, type OrgUser}
import domain/org_role
import domain/project.{type Project, type ProjectMember}
import domain/project_role.{type ProjectRole}
import domain/task_type.{type TaskType}

import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/client_state/admin/task_types as admin_task_types

/// Represents AdminMsg.
pub type Msg {
  ProjectsFetched(ApiResult(List(Project)))
  ProjectCreateDialogOpened
  ProjectCreateDialogClosed
  ProjectCreateNameChanged(String)
  ProjectCreateSubmitted
  ProjectCreated(ApiResult(Project))
  ProjectEditDialogOpened(Int, String)
  ProjectEditDialogClosed
  ProjectEditNameChanged(String)
  ProjectEditSubmitted
  ProjectUpdated(ApiResult(Project))
  ProjectDeleteConfirmOpened(Int, String)
  ProjectDeleteConfirmClosed
  ProjectDeleteSubmitted
  ProjectDeleted(ApiResult(Nil))
  InviteCreateDialogOpened
  InviteCreateDialogClosed
  InviteLinkEmailChanged(String)
  InviteLinkCreateSubmitted
  InviteLinkCreated(ApiResult(InviteLink))
  InviteLinksFetched(ApiResult(List(InviteLink)))
  InviteLinkRegenerateClicked(String)
  InviteLinkRegenerated(ApiResult(InviteLink))
  InviteLinkInvalidateClicked(String)
  InviteLinkInvalidateCancelled
  InviteLinkInvalidateConfirmed
  InviteLinkInvalidated(ApiResult(InviteLink))
  InviteLinkCopyClicked(String)
  InviteLinkCopyFinished(Bool)
  CapabilitiesFetched(ApiResult(List(Capability)))
  CapabilityCreateDialogOpened
  CapabilityCreateDialogClosed
  CapabilityCreateNameChanged(String)
  CapabilityCreateSubmitted
  CapabilityCreated(ApiResult(Capability))
  CapabilityEditDialogOpened(Int, String)
  CapabilityEditDialogClosed
  CapabilityEditNameChanged(String)
  CapabilityEditSubmitted
  CapabilityUpdated(ApiResult(Capability))
  CapabilityDeleteDialogOpened(Int)
  CapabilityDeleteDialogClosed
  CapabilityDeleteSubmitted
  CapabilityDeleted(ApiResult(Int))
  MembersFetched(ApiResult(List(ProjectMember)))
  OrgUsersCacheFetched(ApiResult(List(OrgUser)))
  OrgSettingsUsersFetched(ApiResult(List(OrgUser)))
  OrgSettingsRoleChanged(Int, org_role.OrgRole)
  OrgSettingsSaved(Int, ApiResult(OrgUser))
  OrgSettingsDeleteClicked(Int)
  OrgSettingsDeleteCancelled
  OrgSettingsDeleteConfirmed
  OrgSettingsDeleted(ApiResult(Nil))
  MemberAddDialogOpened
  MemberAddDialogClosed
  MemberAddRoleChanged(ProjectRole)
  MemberAddUserSelected(Int)
  MemberAddSubmitted
  MemberAdded(ApiResult(ProjectMember))
  MemberRemoveClicked(Int)
  MemberRemoveCancelled
  MemberRemoveConfirmed
  MemberRemoved(ApiResult(Nil))
  MemberReleaseAllClicked(Int, Int)
  MemberReleaseAllCancelled
  MemberReleaseAllConfirmed
  MemberReleaseAllResult(ApiResult(api_projects.ReleaseAllResult))
  MemberRoleChangeRequested(Int, ProjectRole)
  MemberRoleChanged(ApiResult(api_projects.RoleChangeResult))
  MemberCapabilitiesDialogOpened(Int)
  MemberCapabilitiesDialogClosed
  MemberCapabilitiesToggled(Int)
  MemberCapabilitiesSaveClicked
  MemberCapabilitiesFetched(ApiResult(api_projects.MemberCapabilities))
  MemberCapabilitiesSaved(ApiResult(api_projects.MemberCapabilities))
  CapabilityMembersDialogOpened(Int)
  CapabilityMembersDialogClosed
  CapabilityMembersToggled(Int)
  CapabilityMembersSaveClicked
  CapabilityMembersFetched(ApiResult(api_projects.CapabilityMembers))
  CapabilityMembersSaved(ApiResult(api_projects.CapabilityMembers))
  OrgUsersSearchChanged(String)
  OrgUsersSearchDebounced(String)
  OrgUsersSearchResults(Int, ApiResult(List(OrgUser)))
  AssignmentsViewModeChanged(assignments_view_mode.AssignmentsViewMode)
  AssignmentsSearchChanged(String)
  AssignmentsSearchDebounced(String)
  AssignmentsProjectMembersFetched(Int, ApiResult(List(ProjectMember)))
  AssignmentsUserProjectsFetched(Int, ApiResult(List(Project)))
  AssignmentsInlineAddStarted(assignments_state.AssignmentsAddContext)
  AssignmentsInlineAddSearchChanged(String)
  AssignmentsInlineAddSelectionChanged(String)
  AssignmentsInlineAddRoleChanged(ProjectRole)
  AssignmentsInlineAddSubmitted
  AssignmentsInlineAddCancelled
  AssignmentsProjectMemberAdded(Int, ApiResult(ProjectMember))
  AssignmentsUserProjectAdded(Int, ApiResult(Project))
  AssignmentsRemoveClicked(Int, Int)
  AssignmentsRemoveCancelled
  AssignmentsRemoveConfirmed
  AssignmentsRemoveDone(Int, Int, ApiResult(Nil))
  AssignmentsRoleChanged(Int, Int, ProjectRole)
  AssignmentsRoleChangeDone(Int, Int, ApiResult(api_projects.RoleChangeResult))
  AssignmentsProjectToggled(Int)
  AssignmentsUserToggled(Int)
  IntegrationUsersFetched(ApiResult(List(api_token.IntegrationUser)))
  ApiTokensFetched(ApiResult(List(api_token.ApiToken)))
  ApiTokenCreateDialogOpened
  ApiTokenCreateDialogClosed
  ApiTokenNameChanged(String)
  ApiTokenIntegrationChanged(String)
  ApiTokenProjectChanged(String)
  ApiTokenScopeToggled(api_token_scope.Scope)
  ApiTokenExpiresAtChanged(String)
  ApiTokenCreateSubmitted
  ApiTokenCreated(ApiResult(api_token.CreatedApiToken))
  ApiTokenCreatedSecretDismissed
  ApiTokenCreatedSecretCopyClicked(String)
  ApiTokenCreatedSecretCopyFinished(Bool)
  ApiTokenRenameClicked(Int, String)
  ApiTokenRenameCancelled
  ApiTokenRenameNameChanged(String)
  ApiTokenRenameSubmitted
  ApiTokenRenamed(ApiResult(api_token.ApiToken))
  ApiTokenRevokeClicked(Int)
  ApiTokenRevokeCancelled
  ApiTokenRevokeConfirmed
  ApiTokenRevoked(Int, ApiResult(Nil))
  IntegrationDeactivateClicked(Int)
  IntegrationDeactivateCancelled
  IntegrationDeactivateConfirmed
  IntegrationDeactivated(Int, ApiResult(Nil))
  TaskTypesFetched(ApiResult(List(TaskType)))
  TaskTypeCreateDialogOpened
  TaskTypeCreateDialogClosed
  TaskTypeCreateNameChanged(String)
  TaskTypeCreateIconChanged(String)
  TaskTypeCreateIconSearchChanged(String)
  TaskTypeCreateIconCategoryChanged(String)
  TaskTypeIconLoaded
  TaskTypeIconErrored
  TaskTypeCreateCapabilityChanged(String)
  TaskTypeCreateSubmitted
  TaskTypeCreated(ApiResult(TaskType))
  OpenTaskTypeDialog(admin_task_types.TaskTypeDialogMode)
  CloseTaskTypeDialog
  TaskTypeCrudCreated(TaskType)
  TaskTypeCrudUpdated(TaskType)
  TaskTypeCrudDeleted(Int)
}
