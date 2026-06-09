import gleam/option.{type Option, None, Some}
import scrumbringer_client/workspace_state.{
  type Workspace, LoadingWorkspace, NoProject, Ready, Workspace, WorkspaceError,
}

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

fn assert_true(value: Bool) {
  let assert True = value
}

fn assert_false(value: Bool) {
  let assert False = value
}

fn assert_none(value: Option(a)) {
  let assert None = value
}

// =============================================================================
// Test helpers
// =============================================================================

fn sample_workspace(project_id: Int) -> Workspace {
  Workspace(
    project_id: project_id,
    project_name: "Test Project",
    tasks: [],
    cards: [],
    members: [],
    capabilities: [],
    task_types: [],
  )
}

// =============================================================================
// init tests
// =============================================================================

pub fn init_returns_no_project_test() {
  let state = workspace_state.init()

  state |> assert_equal(NoProject)
}

// =============================================================================
// select_project tests
// =============================================================================

pub fn select_project_from_no_project_test() {
  let state =
    NoProject
    |> workspace_state.select_project(8)

  state |> assert_equal(LoadingWorkspace(8))
}

pub fn select_project_from_loading_test() {
  let state =
    LoadingWorkspace(5)
    |> workspace_state.select_project(8)

  state |> assert_equal(LoadingWorkspace(8))
}

pub fn select_project_from_ready_test() {
  let workspace = sample_workspace(5)
  let state =
    Ready(workspace)
    |> workspace_state.select_project(8)

  state |> assert_equal(LoadingWorkspace(8))
}

pub fn select_project_from_error_test() {
  let state =
    WorkspaceError(5, "Previous error")
    |> workspace_state.select_project(8)

  state |> assert_equal(LoadingWorkspace(8))
}

// =============================================================================
// workspace_loaded tests
// =============================================================================

pub fn workspace_loaded_success_test() {
  let workspace = sample_workspace(8)
  let state =
    LoadingWorkspace(8)
    |> workspace_state.workspace_loaded(workspace)

  state |> workspace_state.is_ready |> assert_true
  state |> workspace_state.get_workspace |> assert_equal(Some(workspace))
}

pub fn workspace_loaded_wrong_project_id_ignored_test() {
  let workspace = sample_workspace(999)
  let state =
    LoadingWorkspace(8)
    |> workspace_state.workspace_loaded(workspace)

  // Should still be loading because IDs don't match
  state |> workspace_state.is_loading |> assert_true
  state |> workspace_state.is_ready |> assert_false
}

pub fn workspace_loaded_from_ready_ignored_test() {
  let existing_workspace = sample_workspace(5)
  let new_workspace = sample_workspace(8)
  let state =
    Ready(existing_workspace)
    |> workspace_state.workspace_loaded(new_workspace)

  // Should keep existing workspace
  state
  |> workspace_state.get_workspace
  |> assert_equal(Some(existing_workspace))
}

pub fn workspace_loaded_from_no_project_ignored_test() {
  let workspace = sample_workspace(8)
  let state =
    NoProject
    |> workspace_state.workspace_loaded(workspace)

  state |> assert_equal(NoProject)
}

// =============================================================================
// workspace_failed tests
// =============================================================================

pub fn workspace_failed_from_loading_test() {
  let state =
    LoadingWorkspace(8)
    |> workspace_state.workspace_failed("Network error")

  state |> assert_equal(WorkspaceError(8, "Network error"))
  state
  |> workspace_state.error_message
  |> assert_equal(Some("Network error"))
  state |> workspace_state.error_project_id |> assert_equal(Some(8))
}

pub fn workspace_failed_from_ready_ignored_test() {
  let workspace = sample_workspace(8)
  let state =
    Ready(workspace)
    |> workspace_state.workspace_failed("Some error")

  // Should keep ready state
  state |> workspace_state.is_ready |> assert_true
}

pub fn workspace_failed_from_no_project_ignored_test() {
  let state =
    NoProject
    |> workspace_state.workspace_failed("Some error")

  state |> assert_equal(NoProject)
}

// =============================================================================
// clear_project tests
// =============================================================================

pub fn clear_project_from_ready_test() {
  let workspace = sample_workspace(8)
  let state =
    Ready(workspace)
    |> workspace_state.clear_project

  state |> assert_equal(NoProject)
}

pub fn clear_project_from_loading_test() {
  let state =
    LoadingWorkspace(8)
    |> workspace_state.clear_project

  state |> assert_equal(NoProject)
}

pub fn clear_project_from_error_test() {
  let state =
    WorkspaceError(8, "error")
    |> workspace_state.clear_project

  state |> assert_equal(NoProject)
}

// =============================================================================
// update_workspace tests
// =============================================================================

pub fn update_workspace_when_ready_test() {
  let workspace = sample_workspace(8)
  let state =
    Ready(workspace)
    |> workspace_state.update_workspace(fn(ws) {
      Workspace(..ws, project_name: "Updated Name")
    })

  let assert Some(updated) = workspace_state.get_workspace(state)
  updated.project_name |> assert_equal("Updated Name")
}

pub fn update_workspace_when_loading_ignored_test() {
  let state =
    LoadingWorkspace(8)
    |> workspace_state.update_workspace(fn(ws) {
      Workspace(..ws, project_name: "Updated Name")
    })

  state |> assert_equal(LoadingWorkspace(8))
}

// =============================================================================
// query tests
// =============================================================================

pub fn is_ready_test() {
  NoProject |> workspace_state.is_ready |> assert_false
  LoadingWorkspace(8) |> workspace_state.is_ready |> assert_false
  Ready(sample_workspace(8)) |> workspace_state.is_ready |> assert_true
  WorkspaceError(8, "e") |> workspace_state.is_ready |> assert_false
}

pub fn is_loading_test() {
  NoProject |> workspace_state.is_loading |> assert_false
  LoadingWorkspace(8) |> workspace_state.is_loading |> assert_true
  Ready(sample_workspace(8)) |> workspace_state.is_loading |> assert_false
  WorkspaceError(8, "e") |> workspace_state.is_loading |> assert_false
}

pub fn has_error_test() {
  NoProject |> workspace_state.has_error |> assert_false
  LoadingWorkspace(8) |> workspace_state.has_error |> assert_false
  Ready(sample_workspace(8)) |> workspace_state.has_error |> assert_false
  WorkspaceError(8, "e") |> workspace_state.has_error |> assert_true
}

pub fn loading_project_id_test() {
  NoProject
  |> workspace_state.loading_project_id
  |> assert_none

  LoadingWorkspace(8)
  |> workspace_state.loading_project_id
  |> assert_equal(Some(8))
}

pub fn current_project_id_test() {
  NoProject
  |> workspace_state.current_project_id
  |> assert_none

  LoadingWorkspace(8)
  |> workspace_state.current_project_id
  |> assert_equal(Some(8))

  Ready(sample_workspace(5))
  |> workspace_state.current_project_id
  |> assert_equal(Some(5))

  WorkspaceError(3, "e")
  |> workspace_state.current_project_id
  |> assert_equal(Some(3))
}

// =============================================================================
// retry workflow test
// =============================================================================

pub fn can_retry_from_error_test() {
  let workspace = sample_workspace(8)
  let state =
    WorkspaceError(8, "Previous error")
    |> workspace_state.select_project(8)
    |> workspace_state.workspace_loaded(workspace)

  state |> workspace_state.is_ready |> assert_true
}

// =============================================================================
// project change cancels loading test
// =============================================================================

pub fn changing_project_cancels_previous_load_test() {
  let workspace = sample_workspace(8)
  let state =
    NoProject
    |> workspace_state.select_project(8)
    |> workspace_state.select_project(9)
    |> workspace_state.workspace_loaded(workspace)

  // Should still be loading project 9 (ignored old response for project 8)
  state |> workspace_state.is_loading |> assert_true
  state |> workspace_state.loading_project_id |> assert_equal(Some(9))
}
