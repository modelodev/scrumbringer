//// Helpers for model selection and now-working accessors.

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/project.{type Project}
import domain/remote.{Loaded}
import domain/task.{
  type ActiveTask, type WorkSession, ActiveTask, WorkSessionsPayload,
}
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

/// Get the currently active task from work sessions, if any.
pub fn now_working_active_task(
  model: client_state.Model,
) -> Option(ActiveTask) {
  case model.member.metrics.member_work_sessions {
    Loaded(WorkSessionsPayload(active_sessions: [first, ..], ..)) ->
      Some(work_session_to_active_task(first))
    _ -> None
  }
}

/// Convert a WorkSession to an ActiveTask for backward compatibility.
fn work_session_to_active_task(session: WorkSession) -> ActiveTask {
  ActiveTask(
    task_id: session.task_id,
    project_id: 0,
    // Not available in WorkSession, using 0 as placeholder
    started_at: session.started_at,
    accumulated_s: session.accumulated_s,
  )
}

/// Get the task ID of the currently active task, if any.
pub fn now_working_active_task_id(
  model: client_state.Model,
) -> Option(Int) {
  case now_working_active_task(model) {
    Some(ActiveTask(task_id: task_id, ..)) -> Some(task_id)
    None -> None
  }
}

/// Returns ALL active work sessions (for multi-task EN CURSO panel).
pub fn now_working_all_sessions(
  model: client_state.Model,
) -> List(WorkSession) {
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
pub fn ensure_default_section(
  model: client_state.Model,
) -> client_state.Model {
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

  case list.any(visible, fn(s) { s == model.core.active_section }) {
    True -> model
    False -> set_first_visible_section(model, visible)
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
