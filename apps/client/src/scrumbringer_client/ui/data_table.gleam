//// DataTable component for consistent table displays.
////
//// Provides a reusable, accessible table component with:
//// - Consistent styling via CSS classes
//// - Optional sortable column headers
//// - Responsive design (collapses to card view on mobile)
//// - Semantic HTML with proper ARIA attributes
////
//// ## Usage
////
//// ```gleam
//// data_table.new()
//// |> data_table.with_columns([
////   Column("Name", fn(p) { text(p.name) }, None),
////   Column("Role", fn(p) { text(p.role) }, Some(SortByRole)),
//// ])
//// |> data_table.with_rows(projects, fn(p) { int.to_string(p.id) })
//// |> data_table.view()
//// ```

import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute.{attribute, class}
import lustre/element.{type Element}
import lustre/element/html.{caption, span, table, td, text, th, thead, tr}
import lustre/element/keyed
import lustre/event

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
  )
}

/// Configuration for a data table.
pub opaque type DataTableConfig(row, msg) {
  DataTableConfig(
    columns: List(Column(row, msg)),
    rows: List(row),
    key_fn: fn(row) -> String,
    empty_state: Option(Element(msg)),
    css_class: String,
    caption: Option(String),
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
    empty_state: None,
    css_class: "data-table",
    caption: None,
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
  caption: String,
) -> DataTableConfig(row, msg) {
  DataTableConfig(..config, caption: Some(caption))
}

// =============================================================================
// View
// =============================================================================

/// Render the data table.
pub fn view(config: DataTableConfig(row, msg)) -> Element(msg) {
  let DataTableConfig(columns:, rows:, key_fn:, empty_state:, css_class:, caption: cap) =
    config

  case rows {
    [] ->
      case empty_state {
        Some(empty) -> empty
        None -> element.none()
      }
    _ ->
      table([class(css_class), attribute("role", "grid")], [
        case cap {
          Some(c) -> caption([class("sr-only")], [text(c)])
          None -> element.none()
        },
        thead([], [tr([], list.map(columns, view_header))]),
        keyed.tbody(
          [],
          list.map(rows, fn(row) { #(key_fn(row), view_row(columns, row)) }),
        ),
      ])
  }
}

fn view_header(column: Column(row, msg)) -> Element(msg) {
  let Column(header:, on_sort:, ..) = column

  case on_sort {
    Some(msg) ->
      th(
        [
          class("sortable"),
          attribute("role", "columnheader"),
          attribute("aria-sort", "none"),
          event.on_click(msg),
        ],
        [
          span([class("header-text")], [text(header)]),
          span([class("sort-icon")], [text("⇅")]),
        ],
      )
    None -> th([attribute("role", "columnheader")], [text(header)])
  }
}

fn view_row(columns: List(Column(row, msg)), row: row) -> Element(msg) {
  tr(
    [attribute("role", "row")],
    list.map(columns, fn(col) {
      let Column(render:, header:, ..) = col
      td([attribute("role", "gridcell"), attribute("data-label", header)], [
        render(row),
      ])
    }),
  )
}

// =============================================================================
// Helper: Simple column creation
// =============================================================================

/// Create a simple column without sorting.
pub fn column(
  header: String,
  render: fn(row) -> Element(msg),
) -> Column(row, msg) {
  Column(header:, render:, on_sort: None)
}

/// Create a sortable column.
pub fn sortable_column(
  header: String,
  render: fn(row) -> Element(msg),
  on_sort: msg,
) -> Column(row, msg) {
  Column(header:, render:, on_sort: Some(on_sort))
}
