//// Selectors for root client state and related submodels.

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/project.{type Project}
import domain/remote.{Loaded}
import domain/task.{type WorkSession, WorkSession, WorkSessionsPayload}
import domain/user.{type User}
import scrumbringer_client/client_state
import scrumbringer_client/permissions

/// Get list of loaded projects from model, empty if not loaded.
pub fn active_projects(model: client_state.Model) -> List(Project) {
  case model.core.projects {
    Loaded(projects) -> projects
    _ -> []
  }
}

/// Get the currently selected project, if any.
pub fn selected_project(model: client_state.Model) -> Option(Project) {
  case model.core.selected_project_id, model.core.projects {
    Some(id), Loaded(projects) ->
      case list.find(projects, fn(p) { p.id == id }) {
        Ok(project) -> Some(project)
        Error(_) -> None
      }

    _, _ -> None
  }
}

/// Get the first active work session, if any.
fn now_working_active_session(model: client_state.Model) -> Option(WorkSession) {
  case model.member.metrics.member_work_sessions {
    Loaded(WorkSessionsPayload(active_sessions: [first, ..], ..)) -> Some(first)
    _ -> None
  }
}

/// Get the task ID of the currently active task, if any.
pub fn now_working_active_task_id(model: client_state.Model) -> Option(Int) {
  case now_working_active_session(model) {
    Some(WorkSession(task_id: task_id, ..)) -> Some(task_id)
    None -> None
  }
}

/// Returns ALL active work sessions (for multi-task EN CURSO panel).
pub fn now_working_all_sessions(model: client_state.Model) -> List(WorkSession) {
  case model.member.metrics.member_work_sessions {
    Loaded(WorkSessionsPayload(active_sessions: sessions, ..)) -> sessions
    _ -> []
  }
}

/// Ensure a valid project is selected from the available projects.
pub fn ensure_selected_project(
  selected: Option(Int),
  projects: List(Project),
) -> Option(Int) {
  case selected {
    Some(id) -> ensure_selected_project_for_id(id, projects)
    None -> first_project_id(projects)
  }
}

fn ensure_selected_project_for_id(
  id: Int,
  projects: List(Project),
) -> Option(Int) {
  case list.any(projects, fn(p) { p.id == id }) {
    True -> Some(id)
    False -> first_project_id(projects)
  }
}

fn first_project_id(projects: List(Project)) -> Option(Int) {
  case projects {
    [first, ..] -> Some(first.id)
    [] -> None
  }
}

/// Ensure the current admin section is valid for the user's permissions.
pub fn ensure_default_section(model: client_state.Model) -> client_state.Model {
  case model.core.user, model.core.projects {
    Some(user), Loaded(projects) ->
      ensure_default_section_for_user(model, user, projects)

    _, _ -> model
  }
}

fn ensure_default_section_for_user(
  model: client_state.Model,
  user: User,
  projects: List(Project),
) -> client_state.Model {
  let visible = permissions.visible_sections(user.org_role, projects)
  let selected = selected_project(model)

  case
    list.any(visible, fn(s) { s == model.core.active_section })
    || allowed_internal_automation_section(
      model.core.active_section,
      user,
      projects,
      selected,
    )
  {
    True -> model
    False -> set_first_visible_section(model, visible)
  }
}

fn allowed_internal_automation_section(
  section: permissions.AdminSection,
  user: User,
  projects: List(Project),
  selected_project: Option(Project),
) -> Bool {
  case section {
    permissions.TaskTemplates | permissions.RuleMetrics ->
      permissions.can_access_section(
        section,
        user.org_role,
        projects,
        selected_project,
      )
    _ -> False
  }
}

fn set_first_visible_section(
  model: client_state.Model,
  visible: List(permissions.AdminSection),
) -> client_state.Model {
  case visible {
    [first, ..] ->
      client_state.update_core(model, fn(core) {
        client_state.CoreModel(..core, active_section: first)
      })
    [] -> model
  }
}
