//// Local operational tree table for Plan.

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}
import lustre/element/keyed

import scrumbringer_client/ui/data_table

pub type Column(row, msg) {
  Column(
    header: String,
    render: fn(row) -> Element(msg),
    header_class: String,
    cell_class: String,
  )
}

pub type Config(row, msg) {
  Config(
    caption: String,
    class_name: String,
    columns: List(Column(row, msg)),
    rows: List(row),
    key_fn: fn(row) -> String,
    mobile_row: fn(row) -> Element(msg),
  )
}

pub fn view(config: Config(row, msg)) -> Element(msg) {
  div(
    [
      attribute.class("plan-tree-table-shell"),
      attribute.attribute("data-testid", "plan-tree-table"),
    ],
    [
      desktop_table(config),
      mobile_list(config),
    ],
  )
}

pub fn column(
  header: String,
  render: fn(row) -> Element(msg),
  header_class: String,
  cell_class: String,
) -> Column(row, msg) {
  Column(
    header: header,
    render: render,
    header_class: header_class,
    cell_class: cell_class,
  )
}

fn desktop_table(config: Config(row, msg)) -> Element(msg) {
  data_table.new()
  |> data_table.with_class(config.class_name <> " plan-tree-table-desktop")
  |> data_table.with_caption(config.caption)
  |> data_table.with_columns(
    list.map(config.columns, fn(column) {
      let Column(header:, render:, header_class:, cell_class:) = column
      data_table.column_with_class(header, render, header_class, cell_class)
    }),
  )
  |> data_table.with_rows(config.rows, config.key_fn)
  |> data_table.view
}

fn mobile_list(config: Config(row, msg)) -> Element(msg) {
  keyed.div(
    [
      attribute.class("plan-tree-mobile-list"),
      attribute.attribute("data-testid", "plan-tree-mobile-list"),
    ],
    list.map(config.rows, fn(row) {
      #(config.key_fn(row), config.mobile_row(row))
    }),
  )
}
