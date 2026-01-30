//// Remote data rendering utilities.
////
//// ## Mission
////
//// Provides pattern-based rendering for Remote(a) data states,
//// eliminating boilerplate case expressions in views.
////
//// ## Responsibilities
////
//// - Unified rendering for NotAsked/Loading/Failed/Loaded states
//// - Panel wrappers for common UI patterns
////
//// ## Non-responsibilities
////
//// - State management (see client_state.gleam)
//// - Individual loading/error components (see loading.gleam, error.gleam)

import lustre/element.{type Element}

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state.{
  type Remote, Failed, Loaded, Loading, NotAsked,
}
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/loading as ui_loading

/// Render a Remote value with custom handlers for each state.
///
/// ## Example
///
/// ```gleam
/// view_remote(
///   model.tasks,
///   loading: fn() { loading("Loading...") },
///   error: fn(err) { error(err) },
///   loaded: fn(tasks) { view_tasks(tasks) },
/// )
/// ```
pub fn view_remote(
  remote: Remote(a),
  loading loading_view: fn() -> Element(msg),
  error error_view: fn(ApiError) -> Element(msg),
  loaded loaded_view: fn(a) -> Element(msg),
) -> Element(msg) {
  case remote {
    NotAsked | Loading -> loading_view()
    Failed(err) -> error_view(err)
    Loaded(data) -> loaded_view(data)
  }
}

/// Render a Remote value inside a panel with consistent loading/error states.
///
/// Uses standard CSS classes: "panel", "loading", "error".
///
/// ## Example
///
/// ```gleam
/// view_remote_panel(
///   remote: model.metrics,
///   title: "Metrics Overview",
///   loading_msg: "Loading metrics...",
///   loaded: fn(metrics) { view_metrics(metrics) },
/// )
/// ```
pub fn view_remote_panel(
  remote remote: Remote(a),
  title title: String,
  loading_msg loading_msg: String,
  loaded loaded_view: fn(a) -> Element(msg),
) -> Element(msg) {
  case remote {
    NotAsked | Loading -> ui_loading.loading_panel(title, loading_msg)
    Failed(err) -> error_notice.view_panel(title, err.message)
    Loaded(data) -> loaded_view(data)
  }
}

/// Render a Remote value with simple inline loading/error (no panel wrapper).
///
/// ## Example
///
/// ```gleam
/// view_remote_inline(
///   remote: model.tasks,
///   loading_msg: "Loading...",
///   loaded: fn(tasks) { view_tasks(tasks) },
/// )
/// ```
pub fn view_remote_inline(
  remote remote: Remote(a),
  loading_msg loading_msg: String,
  loaded loaded_view: fn(a) -> Element(msg),
) -> Element(msg) {
  case remote {
    NotAsked | Loading -> ui_loading.loading(loading_msg)
    Failed(err) -> error_notice.view(err.message)
    Loaded(data) -> loaded_view(data)
  }
}
