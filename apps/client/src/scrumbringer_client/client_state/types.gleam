//// Shared client state types for scrumbringer_client.

import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/set

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser}
import domain/project.{type Project, type ProjectMember}
import domain/project_role.{type ProjectRole}
import domain/remote.{type Remote}
import domain/task_type.{type TaskType}
import domain/workflow.{type Rule, type TaskTemplate, type Workflow}

import scrumbringer_client/assignments_view_mode

/// State of icon URL preview in task type creation.
pub type IconPreview {
  IconIdle
  IconLoading
  IconOk
  IconError
}

/// Represents a generic async operation state.
pub type OperationState {
  Idle
  InFlight
  Error(String)
}

/// Represents a dialog with form state and operation state.
pub type DialogState(form) {
  DialogClosed(operation: OperationState)
  DialogOpen(form: form, operation: OperationState)
}

/// Form state for invite link dialog.
pub type InviteLinkForm {
  InviteLinkForm(email: String)
}

/// State during drag-and-drop of a task card.
pub type DragState {
  DragIdle
  DragPending(task_id: Int)
  DragActive(task_id: Int, offset_x: Int, offset_y: Int)
}

/// Drag-to-claim state for pool interactions.
pub type PoolDragState {
  PoolDragIdle
  PoolDragPendingRect
  PoolDragDragging(over_my_tasks: Bool, rect: Rect)
}

/// Rectangle geometry for hit testing.
pub type Rect {
  Rect(left: Int, top: Int, width: Int, height: Int)
}

/// Tests if a point (x, y) is inside the rectangle (inclusive bounds).
pub fn rect_contains_point(rect: Rect, x: Int, y: Int) -> Bool {
  let Rect(left: left, top: top, width: width, height: height) = rect
  x >= left && x <= left + width && y >= top && y <= top + height
}

/// Dialog mode for Card CRUD operations.
pub type CardDialogMode {
  CardDialogCreate
  CardDialogEdit(Int)
  CardDialogDelete(Int)
}

/// Dialog mode for Workflow CRUD operations.
pub type WorkflowDialogMode {
  WorkflowDialogCreate
  WorkflowDialogEdit(Workflow)
  WorkflowDialogDelete(Workflow)
}

/// Dialog mode for Task Template CRUD operations.
pub type TaskTemplateDialogMode {
  TaskTemplateDialogCreate
  TaskTemplateDialogEdit(TaskTemplate)
  TaskTemplateDialogDelete(TaskTemplate)
}

/// Dialog mode for Rule CRUD operations.
pub type RuleDialogMode {
  RuleDialogCreate
  RuleDialogEdit(Rule)
  RuleDialogDelete(Rule)
}

/// Dialog mode for Task Type CRUD operations.
pub type TaskTypeDialogMode {
  TaskTypeDialogCreate
  TaskTypeDialogEdit(TaskType)
  TaskTypeDialogDelete(TaskType)
}

/// Represents OrgUsersSearchState.
pub type OrgUsersSearchState {
  OrgUsersSearchIdle(query: String, token: Int)
  OrgUsersSearchLoading(query: String, token: Int)
  OrgUsersSearchLoaded(query: String, token: Int, results: List(OrgUser))
  OrgUsersSearchFailed(query: String, token: Int, error: ApiError)
}

/// Represents the form payload for the projects dialog.
pub type ProjectDialogForm {
  ProjectDialogCreate(name: String)
  ProjectDialogEdit(id: Int, name: String)
  ProjectDialogDelete(id: Int, name: String)
}

/// Inline add context for assignments.
pub type AssignmentsAddContext {
  AddUserToProject(project_id: Int)
  AddProjectToUser(user_id: Int)
}

/// Represents the release-all confirmation target.
pub type ReleaseAllTarget {
  ReleaseAllTarget(user: OrgUser, claimed_count: Int)
}

/// Assignments UI state.
pub type AssignmentsModel {
  AssignmentsModel(
    view_mode: assignments_view_mode.AssignmentsViewMode,
    search_input: String,
    search_query: String,
    project_members: Dict(Int, Remote(List(ProjectMember))),
    user_projects: Dict(Int, Remote(List(Project))),
    expanded_projects: set.Set(Int),
    expanded_users: set.Set(Int),
    inline_add_context: Option(AssignmentsAddContext),
    inline_add_selection: Option(Int),
    inline_add_search: String,
    inline_add_role: ProjectRole,
    inline_add_in_flight: Bool,
    inline_remove_confirm: Option(#(Int, Int)),
    role_change_in_flight: Option(#(Int, Int)),
    role_change_previous: Option(#(Int, Int, ProjectRole)),
  )
}
