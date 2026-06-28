//// DataTable component for consistent table displays.
////
//// Provides a reusable, accessible table component with:
//// - Consistent styling via CSS classes
//// - Optional sortable column headers
//// - Per-column CSS classes for headers and cells
//// - Remote data state handling (NotAsked/Loading/Failed/Loaded)
//// - Responsive design (collapses to card view on mobile)
//// - Semantic HTML with proper ARIA attributes
////
//// ## Usage
////
//// ```gleam
//// // Simple table
//// data_table.new()
//// |> data_table.with_columns([
////   data_table.column("Name", fn(p) { text(p.name) }),
////   data_table.column("Role", fn(p) { text(p.role) }),
//// ])
//// |> data_table.with_rows(projects, fn(p) { int.to_string(p.id) })
//// |> data_table.view()
////
//// // With column classes
//// data_table.new()
//// |> data_table.with_columns([
////   data_table.column("Name", fn(p) { text(p.name) }),
////   data_table.column_with_class("Actions", render_actions, "col-actions", "cell-actions"),
//// ])
//// |> data_table.with_rows(items, fn(i) { int.to_string(i.id) })
//// |> data_table.view()
////
//// // With Remote data
//// data_table.view_remote(
////   model.core.projects,
////   loading_msg: "Loading...",
////   empty_msg: "No projects yet",
////   config: data_table.new()
////     |> data_table.with_columns([...])
////     |> data_table.with_key(fn(p) { int.to_string(p.id) }),
//// )
//// ```

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute.{type Attribute, attribute, class}
import lustre/element.{type Element}
import lustre/element/html.{
  button, caption, div, span, table, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import domain/api_error.{type ApiError}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/ui/error_notice

// =============================================================================
// Types
// =============================================================================

/// Column definition for a data table.
pub type Column(row, msg) {
  Column(
    /// Column header text
    header: String,
    /// Function to render cell content for this column
    render: fn(row) -> Element(msg),
    /// Optional sort message when header is clicked
    on_sort: Option(msg),
    /// CSS class for header (th) element
    header_class: Option(String),
    /// CSS class for cell (td) elements in this column
    cell_class: Option(String),
  )
}

/// Configuration for a data table.
pub opaque type DataTableConfig(row, msg) {
  DataTableConfig(
    columns: List(Column(row, msg)),
    rows: List(row),
    key_fn: fn(row) -> String,
    row_attrs_fn: fn(row) -> List(Attribute(msg)),
    empty_state: Option(Element(msg)),
    css_class: String,
    caption: Option(String),
    /// Error message prefix for failed state (used with view_remote)
    error_prefix: Option(String),
  )
}

// =============================================================================
// Builder API
// =============================================================================

/// Create a new data table configuration.
pub fn new() -> DataTableConfig(row, msg) {
  DataTableConfig(
    columns: [],
    rows: [],
    key_fn: fn(_) { "" },
    row_attrs_fn: fn(_) { [] },
    empty_state: None,
    css_class: "table data-table",
    caption: None,
    error_prefix: None,
  )
}

/// Set the columns for the table.
pub fn with_columns(
  config: DataTableConfig(row, msg),
  columns: List(Column(row, msg)),
) -> DataTableConfig(row, msg) {
  DataTableConfig(..config, columns: columns)
}

/// Set the rows and key function for the table.
pub fn with_rows(
  config: DataTableConfig(row, msg),
  rows: List(row),
  key_fn: fn(row) -> String,
) -> DataTableConfig(row, msg) {
  DataTableConfig(..config, rows: rows, key_fn: key_fn)
}

/// Set an empty state element to show when there are no rows.
pub fn with_empty_state(
  config: DataTableConfig(row, msg),
  empty: Element(msg),
) -> DataTableConfig(row, msg) {
  DataTableConfig(..config, empty_state: Some(empty))
}

/// Add a custom CSS class to the table.
pub fn with_class(
  config: DataTableConfig(row, msg),
  css: String,
) -> DataTableConfig(row, msg) {
  DataTableConfig(..config, css_class: config.css_class <> " " <> css)
}

/// Add a caption for accessibility.
pub fn with_caption(
  config: DataTableConfig(row, msg),
  cap: String,
) -> DataTableConfig(row, msg) {
  DataTableConfig(..config, caption: Some(cap))
}

/// Set only the key function (useful with view_remote).
pub fn with_key(
  config: DataTableConfig(row, msg),
  key_fn: fn(row) -> String,
) -> DataTableConfig(row, msg) {
  DataTableConfig(..config, key_fn: key_fn)
}

/// Set attributes to apply to each rendered row.
pub fn with_row_attrs(
  config: DataTableConfig(row, msg),
  row_attrs_fn: fn(row) -> List(Attribute(msg)),
) -> DataTableConfig(row, msg) {
  DataTableConfig(..config, row_attrs_fn: row_attrs_fn)
}

/// Set error message prefix for failed Remote state.
pub fn with_error_prefix(
  config: DataTableConfig(row, msg),
  prefix: String,
) -> DataTableConfig(row, msg) {
  DataTableConfig(..config, error_prefix: Some(prefix))
}

// =============================================================================
// View
// =============================================================================

/// Render the data table.
pub fn view(config: DataTableConfig(row, msg)) -> Element(msg) {
  let DataTableConfig(
    columns:,
    rows:,
    key_fn:,
    row_attrs_fn:,
    empty_state:,
    css_class:,
    caption: cap,
    ..,
  ) = config

  case rows {
    [] ->
      case empty_state {
        Some(empty) -> empty
        None -> element.none()
      }
    _ ->
      div([class("data-table-scroll")], [
        table([class(css_class)], [
          case cap {
            Some(c) -> caption([class("sr-only")], [text(c)])
            None -> element.none()
          },
          thead([], [tr([], list.map(columns, view_header))]),
          keyed.tbody(
            [],
            list.map(rows, fn(row) {
              #(key_fn(row), view_row(columns, row, row_attrs_fn(row)))
            }),
          ),
        ]),
      ])
  }
}

fn view_header(column: Column(row, msg)) -> Element(msg) {
  let Column(header:, on_sort:, header_class:, ..) = column

  let base_attrs = [attribute("scope", "col")]
  let class_attrs = case header_class {
    Some(css) -> [class("table-header " <> css), ..base_attrs]
    None -> [class("table-header"), ..base_attrs]
  }

  case on_sort {
    Some(sort_msg) ->
      th(
        [
          class(case header_class {
            Some(css) -> "table-header sortable " <> css
            None -> "table-header sortable"
          }),
          attribute("scope", "col"),
          attribute("aria-sort", "none"),
        ],
        [
          button(
            [
              class("table-sort-button"),
              attribute("type", "button"),
              attribute("aria-label", "Sort by " <> header),
              event.on_click(sort_msg),
            ],
            [
              span([class("header-text")], [text(header)]),
              span([class("sort-icon"), attribute("aria-hidden", "true")], [
                text("⇅"),
              ]),
            ],
          ),
        ],
      )
    None -> th(class_attrs, [text(header)])
  }
}

fn view_row(
  columns: List(Column(row, msg)),
  row: row,
  row_attrs: List(Attribute(msg)),
) -> Element(msg) {
  tr(
    list.append([attribute("role", "row")], row_attrs),
    list.map(columns, fn(col) {
      let Column(render:, header:, cell_class:, ..) = col
      let base_attrs = [attribute("data-label", header)]
      let attrs = case cell_class {
        Some(css) -> [class(css), ..base_attrs]
        None -> base_attrs
      }
      td(attrs, [render(row)])
    }),
  )
}

// =============================================================================
// Helper: Column creation
// =============================================================================

/// Create a simple column without sorting or custom classes.
pub fn column(
  header: String,
  render: fn(row) -> Element(msg),
) -> Column(row, msg) {
  Column(header:, render:, on_sort: None, header_class: None, cell_class: None)
}

/// Create a column with CSS classes for header and cells.
pub fn column_with_class(
  header: String,
  render: fn(row) -> Element(msg),
  header_class: String,
  cell_class: String,
) -> Column(row, msg) {
  Column(
    header:,
    render:,
    on_sort: None,
    header_class: Some(header_class),
    cell_class: Some(cell_class),
  )
}

/// Create a sortable column.
pub fn sortable_column(
  header: String,
  render: fn(row) -> Element(msg),
  on_sort: msg,
) -> Column(row, msg) {
  Column(
    header:,
    render:,
    on_sort: Some(on_sort),
    header_class: None,
    cell_class: None,
  )
}

// =============================================================================
// Remote Data Support
// =============================================================================

/// Render a table with Remote data, handling all states automatically.
///
/// Shows loading spinner for NotAsked/Loading, error for Failed,
/// empty state or table for Loaded.
///
/// ## Example
///
/// ```gleam
/// data_table.view_remote(
///   model.core.projects,
///   loading_msg: "Loading projects...",
///   empty_msg: "No projects yet",
///   config: data_table.new()
///     |> data_table.with_columns([
///       data_table.column("Name", fn(p) { text(p.name) }),
///     ])
///     |> data_table.with_key(fn(p) { int.to_string(p.id) }),
/// )
/// ```
pub fn view_remote(
  remote: Remote(List(row)),
  loading_msg loading_msg: String,
  empty_msg empty_msg: String,
  config config: DataTableConfig(row, msg),
) -> Element(msg) {
  case remote {
    NotAsked | Loading -> view_loading(loading_msg)

    Failed(err) -> view_error(config.error_prefix, err)

    Loaded(rows) ->
      case rows {
        [] -> view_empty(config.empty_state, empty_msg)
        _ -> view(DataTableConfig(..config, rows: rows))
      }
  }
}

/// Render a table with Remote data and custom error handling.
///
/// Use when you need special handling for 403/forbidden errors.
/// If config has an empty_state set via with_empty_state(), it will be used
/// instead of the empty_msg text.
pub fn view_remote_with_forbidden(
  remote: Remote(List(row)),
  loading_msg loading_msg: String,
  empty_msg empty_msg: String,
  forbidden_msg forbidden_msg: String,
  config config: DataTableConfig(row, msg),
) -> Element(msg) {
  case remote {
    NotAsked | Loading -> view_loading(loading_msg)

    Failed(err) ->
      case err.status == 403 {
        True ->
          div(
            [
              class("not-permitted data-table-state"),
              attribute("role", "alert"),
            ],
            [text(forbidden_msg)],
          )
        False -> view_error(config.error_prefix, err)
      }

    Loaded(rows) ->
      case rows {
        [] -> view_empty(config.empty_state, empty_msg)
        _ -> view(DataTableConfig(..config, rows: rows))
      }
  }
}

/// Helper to render empty state - uses custom element if provided, otherwise text
fn view_empty(
  empty_state: Option(Element(msg)),
  empty_msg: String,
) -> Element(msg) {
  case empty_state {
    Some(custom) -> custom
    None ->
      div(
        [
          class("empty data-table-state"),
          attribute("role", "status"),
          attribute("aria-live", "polite"),
        ],
        [text(empty_msg)],
      )
  }
}

fn view_loading(message: String) -> Element(msg) {
  div(
    [
      class("empty data-table-state data-table-loading"),
      attribute("role", "status"),
      attribute("aria-live", "polite"),
      attribute("aria-busy", "true"),
    ],
    [text(message)],
  )
}

fn view_error(prefix: Option(String), err: ApiError) -> Element(msg) {
  let safe_message = case string.is_empty(string.trim(err.message)) {
    True -> fallback_error_message(err)
    False -> err.message
  }
  let message = case prefix {
    Some(p) -> p <> safe_message
    None -> safe_message
  }
  error_notice.view(message)
}

fn fallback_error_message(err: ApiError) -> String {
  case string.is_empty(string.trim(err.code)) {
    True -> "Request failed (" <> int.to_string(err.status) <> ")"
    False -> err.code <> " (" <> int.to_string(err.status) <> ")"
  }
}
