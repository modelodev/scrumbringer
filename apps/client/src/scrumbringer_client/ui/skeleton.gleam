//// Skeleton loading placeholders.
////
//// ## Mission
////
//// Provide animated placeholder UI during content loading.
////
//// ## Responsibilities
////
//// - Render skeleton lines and shapes with pulse animation.
////
//// ## Non-responsibilities
////
//// - State management (caller handles Remote state).
////
//// ## Relations
////
//// - **data_table.gleam**: Can use skeleton for loading state.
//// - **Remote type**: Complements Loading variant rendering.

import gleam/list

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

pub fn skeleton_line(width: String, height: String) -> Element(msg) {
  div(
    [
      attribute.class("skeleton"),
      attribute.style("width", width),
      attribute.style("height", height),
    ],
    [],
  )
}

pub fn skeleton_card() -> Element(msg) {
  div(
    [
      attribute.class("skeleton"),
      attribute.style("width", "100%"),
      attribute.style("height", "120px"),
    ],
    [],
  )
}

/// Renders a skeleton table placeholder with n rows.
pub fn skeleton_table(rows: Int) -> Element(msg) {
  div([attribute.class("skeleton-table")], {
    list.range(1, rows)
    |> list.map(fn(_) {
      div([attribute.class("skeleton-row")], [
        skeleton_line("30%", "14px"),
        skeleton_line("20%", "14px"),
        skeleton_line("15%", "14px"),
      ])
    })
  })
}

/// Renders a compact skeleton list placeholder.
pub fn skeleton_list(rows: Int) -> Element(msg) {
  div([attribute.class("skeleton-list")], {
    list.range(1, rows)
    |> list.map(fn(_) {
      skeleton_line("100%", "40px")
    })
  })
}
