//// Admin feature messages.

import domain/api_error.{type ApiResult}
import domain/capability.{type Capability}
import domain/org.{type InviteLink, type OrgUser}
import domain/org_role
import domain/project.{type Project, type ProjectMember}
import domain/project_role.{type ProjectRole}
import domain/task_type.{type TaskType}

import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state/types as state_types

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
  InviteLinkCopyClicked(String)
  InviteLinkCopyFinished(Bool)
  CapabilitiesFetched(ApiResult(List(Capability)))
  CapabilityCreateDialogOpened
  CapabilityCreateDialogClosed
  CapabilityCreateNameChanged(String)
  CapabilityCreateSubmitted
  CapabilityCreated(ApiResult(Capability))
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
  MemberAddRoleChanged(String)
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
  AssignmentsInlineAddStarted(state_types.AssignmentsAddContext)
  AssignmentsInlineAddSearchChanged(String)
  AssignmentsInlineAddSelectionChanged(String)
  AssignmentsInlineAddRoleChanged(String)
  AssignmentsInlineAddSubmitted
  AssignmentsInlineAddCancelled
  AssignmentsProjectMemberAdded(Int, ApiResult(ProjectMember))
  AssignmentsUserProjectAdded(Int, ApiResult(Project))
  AssignmentsRemoveClicked(Int, Int)
  AssignmentsRemoveCancelled
  AssignmentsRemoveConfirmed
  AssignmentsRemoveCompleted(Int, Int, ApiResult(Nil))
  AssignmentsRoleChanged(Int, Int, ProjectRole)
  AssignmentsRoleChangeCompleted(
    Int,
    Int,
    ApiResult(api_projects.RoleChangeResult),
  )
  AssignmentsProjectToggled(Int)
  AssignmentsUserToggled(Int)
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
  OpenTaskTypeDialog(state_types.TaskTypeDialogMode)
  CloseTaskTypeDialog
  TaskTypeCrudCreated(TaskType)
  TaskTypeCrudUpdated(TaskType)
  TaskTypeCrudDeleted(Int)
}
