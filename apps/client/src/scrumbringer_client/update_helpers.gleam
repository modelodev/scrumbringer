//// Update helper functions for scrumbringer_client.
////
//// ## Mission
////
//// Provides pure helper functions and Model accessors used by the update
//// function and its handlers. Extracted to reduce coupling and enable
//// future domain-based handler extraction.
////
//// ## Responsibilities
////
//// - Pure data transformation functions (dict conversions, option conversions)
//// - Model accessor functions (active_projects, selected_project, etc.)
//// - Time formatting helpers (format_seconds, elapsed time calculation)
//// - Remote data lookup helpers (find_task_by_id, resolve_org_user)
////
//// ## Non-responsibilities
////
//// - Effect creation (see scrumbringer_client.gleam)
//// - API calls (see api.gleam)
//// - View rendering (see scrumbringer_client.gleam)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Remote types
//// - **api.gleam**: Provides data types (Task, TaskPosition, OrgUser, etc.)
//// - **scrumbringer_client.gleam**: Main consumer of these helpers

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import scrumbringer_client/api
import scrumbringer_client/client_state.{type Model, type Remote, Loaded}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

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
  positions: List(api.TaskPosition),
) -> Dict(Int, #(Int, Int)) {
  positions
  |> list.fold(dict.new(), fn(acc, pos) {
    let api.TaskPosition(task_id: task_id, x: x, y: y, ..) = pos
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
pub fn find_task_by_id(
  tasks: Remote(List(api.Task)),
  task_id: Int,
) -> Option(api.Task) {
  case tasks {
    Loaded(tasks) ->
      case
        list.find(tasks, fn(t) {
          let api.Task(id: id, ..) = t
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
  cache: Remote(List(api.OrgUser)),
  user_id: Int,
) -> Option(api.OrgUser) {
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
pub fn active_projects(model: Model) -> List(api.Project) {
  case model.projects {
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
pub fn selected_project(model: Model) -> Option(api.Project) {
  case model.selected_project_id, model.projects {
    Some(id), Loaded(projects) ->
      case list.find(projects, fn(p) { p.id == id }) {
        Ok(project) -> Some(project)
        Error(_) -> None
      }

    _, _ -> None
  }
}

/// Get the currently active task from member_active_task, if any.
///
/// ## Example
///
/// ```gleam
/// now_working_active_task(model)
/// // Some(active_task) or None
/// ```
pub fn now_working_active_task(model: Model) -> Option(api.ActiveTask) {
  case model.member_active_task {
    Loaded(api.ActiveTaskPayload(active_task: active_task, ..)) -> active_task
    _ -> None
  }
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
    Some(api.ActiveTask(task_id: task_id, ..)) -> Some(task_id)
    None -> None
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
pub fn flatten_tasks(
  tasks_by_project: Dict(Int, List(api.Task)),
) -> List(api.Task) {
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
  task_types_by_project: Dict(Int, List(api.TaskType)),
) -> List(api.TaskType) {
  task_types_by_project
  |> dict.to_list
  |> list.fold([], fn(acc, pair) {
    let #(_project_id, types) = pair
    list.append(acc, types)
  })
}

// =============================================================================
// Internationalization
// =============================================================================

/// Translate text using the model's current locale.
///
/// Convenience wrapper around `i18n.t` that extracts locale from model.
///
/// ## Example
///
/// ```gleam
/// i18n_t(model, i18n_text.Welcome)
/// // "Welcome" or "Bienvenido" depending on locale
/// ```
pub fn i18n_t(model: Model, text: i18n_text.Text) -> String {
  i18n.t(model.locale, text)
}
