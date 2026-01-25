//// Update helper functions for scrumbringer_client.
////
//// ## Mission
////
//// Provides pure helper functions and Model accessors used by the update
//// function and its handlers. Acts as a facade re-exporting domain-specific
//// helpers from specialized modules for backward compatibility.
////
//// ## Responsibilities
////
//// - Pure data transformation functions (dict conversions, option conversions)
//// - Model accessor functions (active_projects, selected_project, etc.)
//// - Time formatting helpers (format_seconds, elapsed time calculation)
//// - Remote data lookup helpers (find_task_by_id, resolve_org_user)
//// - Re-exports from:
////   - `features/auth/helpers.gleam` (auth error handling)
////   - `shared/i18n_helpers.gleam` (translation wrapper)
////
//// ## Non-responsibilities
////
//// - Effect creation (see app/effects.gleam)
//// - API calls (see api/ modules)
//// - View rendering (see features/*/view.gleam)
////
//// ## Line Count Justification
////
//// ~520 lines: Contains Model accessor functions and pure helpers used
//// throughout the update layer. Domain-specific helpers have been extracted
//// to specialized modules (auth, i18n) and are re-exported for backward
//// compatibility. Splitting remaining helpers further would create many
//// small modules with unclear ownership.
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Remote types
//// - **domain/***: Provides data types (Task, TaskPosition, OrgUser, etc.)
//// - **features/auth/helpers.gleam**: Auth-related helpers (re-exported)
//// - **shared/i18n_helpers.gleam**: i18n translation wrapper (re-exported)
//// - **scrumbringer_client.gleam**: Main consumer of these helpers

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/effect.{type Effect}

// Domain types from shared
import domain/api_error.{type ApiError}
import domain/org.{type OrgUser}
import domain/project.{type Project}
import domain/task.{
  type ActiveTask, type Task, type TaskPosition, type WorkSession, ActiveTask,
  ActiveTaskPayload, Task, TaskPosition, WorkSessionsPayload,
}
import domain/task_type.{type TaskType}
import scrumbringer_client/client_state.{
  type Model, type Msg, type Remote, CoreModel, Loaded, update_core,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/shared/i18n_helpers

// =============================================================================
// Pure Data Transformations
// =============================================================================

/// Convert a list of IDs to a boolean dictionary (all True).
///
/// ## Example
///
/// ```gleam
/// ids_to_bool_dict([1, 2, 3])
/// // dict.from_list([#(1, True), #(2, True), #(3, True)])
/// ```
pub fn ids_to_bool_dict(ids: List(Int)) -> Dict(Int, Bool) {
  ids |> list.fold(dict.new(), fn(acc, id) { dict.insert(acc, id, True) })
}

/// Extract IDs where value is True from a boolean dictionary.
///
/// ## Example
///
/// ```gleam
/// bool_dict_to_ids(dict.from_list([#(1, True), #(2, False), #(3, True)]))
/// // [1, 3]
/// ```
pub fn bool_dict_to_ids(values: Dict(Int, Bool)) -> List(Int) {
  values
  |> dict.to_list
  |> list.filter_map(fn(pair) {
    let #(id, selected) = pair
    case selected {
      True -> Ok(id)
      False -> Error(Nil)
    }
  })
}

/// Convert a list of TaskPositions to a dictionary keyed by task_id.
///
/// ## Example
///
/// ```gleam
/// positions_to_dict([TaskPosition(task_id: 1, x: 100, y: 200, ..)])
/// // dict.from_list([#(1, #(100, 200))])
/// ```
pub fn positions_to_dict(
  positions: List(TaskPosition),
) -> Dict(Int, #(Int, Int)) {
  positions
  |> list.fold(dict.new(), fn(acc, pos) {
    let TaskPosition(task_id: task_id, x: x, y: y, ..) = pos
    dict.insert(acc, task_id, #(x, y))
  })
}

/// Convert empty string to None, non-empty to Some.
///
/// ## Example
///
/// ```gleam
/// empty_to_opt("")        // None
/// empty_to_opt("  ")      // None
/// empty_to_opt("hello")   // Some("hello")
/// ```
pub fn empty_to_opt(value: String) -> Option(String) {
  case string.trim(value) == "" {
    True -> None
    False -> Some(value)
  }
}

/// Convert string to Option(Int), empty string becomes None.
///
/// ## Example
///
/// ```gleam
/// empty_to_int_opt("")     // None
/// empty_to_int_opt("123")  // Some(123)
/// empty_to_int_opt("abc")  // None
/// ```
pub fn empty_to_int_opt(value: String) -> Option(Int) {
  let trimmed = string.trim(value)

  case trimmed == "" {
    True -> None
    False ->
      case int.parse(trimmed) {
        Ok(i) -> Some(i)
        Error(_) -> None
      }
  }
}

// =============================================================================
// Remote Data Lookups
// =============================================================================

/// Find a task by ID in a Remote list of tasks.
///
/// ## Example
///
/// ```gleam
/// find_task_by_id(Loaded([task1, task2]), 1)
/// // Some(task1)
/// ```
pub fn find_task_by_id(tasks: Remote(List(Task)), task_id: Int) -> Option(Task) {
  case tasks {
    Loaded(tasks) ->
      case
        list.find(tasks, fn(t) {
          let Task(id: id, ..) = t
          id == task_id
        })
      {
        Ok(t) -> Some(t)
        Error(_) -> None
      }

    _ -> None
  }
}

/// Resolve an org user from a Remote cache by user ID.
///
/// ## Example
///
/// ```gleam
/// resolve_org_user(Loaded([user1, user2]), 1)
/// // Some(user1)
/// ```
pub fn resolve_org_user(
  cache: Remote(List(OrgUser)),
  user_id: Int,
) -> Option(OrgUser) {
  case cache {
    Loaded(users) ->
      case list.find(users, fn(u) { u.id == user_id }) {
        Ok(user) -> Some(user)
        Error(_) -> None
      }

    _ -> None
  }
}

// =============================================================================
// Model Accessors
// =============================================================================

/// Get list of loaded projects from model, empty if not loaded.
///
/// ## Example
///
/// ```gleam
/// active_projects(model)
/// // [project1, project2] or []
/// ```
pub fn active_projects(model: Model) -> List(Project) {
  case model.core.projects {
    Loaded(projects) -> projects
    _ -> []
  }
}

/// Get the currently selected project, if any.
///
/// ## Example
///
/// ```gleam
/// selected_project(model)
/// // Some(project) or None
/// ```
pub fn selected_project(model: Model) -> Option(Project) {
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
/// Returns the first active work session converted to ActiveTask for compatibility.
///
/// ## Example
///
/// ```gleam
/// now_working_active_task(model)
/// // Some(active_task) or None
/// ```
pub fn now_working_active_task(model: Model) -> Option(ActiveTask) {
  // First check work sessions (new API)
  case model.member.member_work_sessions {
    Loaded(WorkSessionsPayload(active_sessions: [first, ..], ..)) ->
      Some(work_session_to_active_task(first))
    _ ->
      // Fallback to legacy active_task
      case model.member.member_active_task {
        Loaded(ActiveTaskPayload(active_task: active_task, ..)) -> active_task
        _ -> None
      }
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
///
/// ## Example
///
/// ```gleam
/// now_working_active_task_id(model)
/// // Some(42) or None
/// ```
pub fn now_working_active_task_id(model: Model) -> Option(Int) {
  case now_working_active_task(model) {
    Some(ActiveTask(task_id: task_id, ..)) -> Some(task_id)
    None -> None
  }
}

/// Returns ALL active work sessions (for multi-task EN CURSO panel).
///
/// ## Example
///
/// ```gleam
/// now_working_all_sessions(model)
/// // [WorkSession(task_id: 1, ..), WorkSession(task_id: 2, ..)]
/// ```
pub fn now_working_all_sessions(model: Model) -> List(WorkSession) {
  case model.member.member_work_sessions {
    Loaded(WorkSessionsPayload(active_sessions: sessions, ..)) -> sessions
    _ -> []
  }
}

// =============================================================================
// Time Formatting
// =============================================================================

/// Format seconds as HH:MM:SS or MM:SS string.
///
/// ## Example
///
/// ```gleam
/// format_seconds(65)     // "01:05"
/// format_seconds(3665)   // "1:01:05"
/// ```
pub fn format_seconds(value: Int) -> String {
  let hours = value / 3600
  let minutes_total = value / 60
  let minutes = minutes_total - minutes_total / 60 * 60
  let seconds = value - minutes_total * 60

  let mm = minutes |> int.to_string |> string.pad_start(2, "0")
  let ss = seconds |> int.to_string |> string.pad_start(2, "0")

  case hours {
    0 -> mm <> ":" <> ss
    _ -> int.to_string(hours) <> ":" <> mm <> ":" <> ss
  }
}

/// Calculate elapsed time string from accumulated seconds and timestamps.
///
/// ## Example
///
/// ```gleam
/// now_working_elapsed_from_ms(60, 1000, 6000)
/// // "01:05" (60s accumulated + 5s elapsed)
/// ```
pub fn now_working_elapsed_from_ms(
  accumulated_s: Int,
  started_ms: Int,
  server_now_ms: Int,
) -> String {
  let diff_ms = server_now_ms - started_ms
  let delta_s = case diff_ms < 0 {
    True -> 0
    False -> diff_ms / 1000
  }

  format_seconds(accumulated_s + delta_s)
}

// =============================================================================
// Dict Flattening
// =============================================================================

/// Flatten a Dict of project_id -> tasks into a single task list.
///
/// ## Example
///
/// ```gleam
/// flatten_tasks(dict.from_list([#(1, [t1, t2]), #(2, [t3])]))
/// // [t1, t2, t3]
/// ```
pub fn flatten_tasks(tasks_by_project: Dict(Int, List(Task))) -> List(Task) {
  tasks_by_project
  |> dict.to_list
  |> list.fold([], fn(acc, pair) {
    let #(_project_id, tasks) = pair
    list.append(acc, tasks)
  })
}

/// Flatten a Dict of project_id -> task_types into a single list.
///
/// ## Example
///
/// ```gleam
/// flatten_task_types(dict.from_list([#(1, [tt1]), #(2, [tt2, tt3])]))
/// // [tt1, tt2, tt3]
/// ```
pub fn flatten_task_types(
  task_types_by_project: Dict(Int, List(TaskType)),
) -> List(TaskType) {
  task_types_by_project
  |> dict.to_list
  |> list.fold([], fn(acc, pair) {
    let #(_project_id, types) = pair
    list.append(acc, types)
  })
}

// =============================================================================
// Internationalization (re-exported from shared/i18n_helpers.gleam)
// =============================================================================

/// Translate text using the model's current locale.
/// Re-exported from shared/i18n_helpers.gleam for backward compatibility.
pub fn i18n_t(model: Model, text: i18n_text.Text) -> String {
  i18n_helpers.i18n_t(model, text)
}

// =============================================================================
// Project/Section Selection
// =============================================================================

/// Ensure a valid project is selected from the available projects.
///
/// If current selection is valid, keep it. Otherwise, select first project
/// or None if no projects available.
///
/// ## Example
///
/// ```gleam
/// ensure_selected_project(Some(5), [project1, project2])
/// // Some(5) if project 5 exists, else Some(project1.id)
/// ```
pub fn ensure_selected_project(
  selected: Option(Int),
  projects: List(Project),
) -> Option(Int) {
  case selected {
    Some(id) ->
      case list.any(projects, fn(p) { p.id == id }) {
        True -> Some(id)
        False ->
          case projects {
            [first, ..] -> Some(first.id)
            [] -> None
          }
      }

    None ->
      case projects {
        [first, ..] -> Some(first.id)
        [] -> None
      }
  }
}

/// Ensure the current admin section is valid for the user's permissions.
///
/// If current section is not in visible sections, switch to first visible
/// section or keep current if user/projects not loaded.
///
/// ## Example
///
/// ```gleam
/// ensure_default_section(model)
/// // Model with valid active_section
/// ```
pub fn ensure_default_section(model: Model) -> Model {
  case model.core.user, model.core.projects {
    Some(user), Loaded(projects) -> {
      let visible = permissions.visible_sections(user.org_role, projects)

      case list.any(visible, fn(s) { s == model.core.active_section }) {
        True -> model
        False ->
          case visible {
            [first, ..] ->
              update_core(model, fn(core) {
                CoreModel(..core, active_section: first)
              })
            [] -> model
          }
      }
    }

    _, _ -> model
  }
}

// =============================================================================
// Auth Helpers (re-exported from features/auth/helpers.gleam)
// =============================================================================

import scrumbringer_client/features/auth/helpers as auth_helpers

/// Clear all drag-related state from the model.
/// Re-exported from features/auth/helpers.gleam for backward compatibility.
pub fn clear_drag_state(model: Model) -> Model {
  auth_helpers.clear_drag_state(model)
}

/// Reset model to login page, clearing user and drag state.
/// Re-exported from features/auth/helpers.gleam for backward compatibility.
pub fn reset_to_login(model: Model) -> #(Model, Effect(Msg)) {
  auth_helpers.reset_to_login(model)
}

/// Handle common API auth errors (401/403).
/// Re-exported from features/auth/helpers.gleam for backward compatibility.
pub fn handle_auth_error(
  model: Model,
  err: ApiError,
) -> Option(#(Model, Effect(Msg))) {
  auth_helpers.handle_auth_error(model, err)
}

// =============================================================================
// Form Validation Helpers
// =============================================================================

/// Validate that a string is not empty after trimming.
///
/// Returns Ok with trimmed string, or Error with translated message.
///
/// ## Example
///
/// ```gleam
/// validate_required_string(model, "  hello  ", i18n_text.NameRequired)
/// // Ok("hello")
///
/// validate_required_string(model, "   ", i18n_text.NameRequired)
/// // Error("Name is required")
/// ```
pub fn validate_required_string(
  model: Model,
  value: String,
  error_text: i18n_text.Text,
) -> Result(String, String) {
  let trimmed = string.trim(value)
  case trimmed == "" {
    True -> Error(i18n_t(model, error_text))
    False -> Ok(trimmed)
  }
}

/// Validate multiple required fields and return first error.
///
/// ## Example
///
/// ```gleam
/// validate_required_fields(model, [
///   #(name, i18n_text.NameRequired),
///   #(email, i18n_text.EmailRequired),
/// ])
/// // Ok([trimmed_name, trimmed_email]) or Error("Name is required")
/// ```
pub fn validate_required_fields(
  model: Model,
  fields: List(#(String, i18n_text.Text)),
) -> Result(List(String), String) {
  fields
  |> list.try_map(fn(field) {
    let #(value, error_text) = field
    validate_required_string(model, value, error_text)
  })
}
