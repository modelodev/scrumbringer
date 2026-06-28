import domain/api_error.{ApiError}
import domain/remote.{Failed, Loaded, NotAsked}
import lustre/element
import lustre/element/html.{text}
import scrumbringer_client/ui/data_table
import support/render_assertions

fn base_config() -> data_table.DataTableConfig(String, msg) {
  data_table.new()
  |> data_table.with_columns([
    data_table.column("Name", fn(name) { text(name) }),
  ])
  |> data_table.with_key(fn(name) { name })
}

pub fn view_remote_renders_loading_state_test() {
  let rendered =
    data_table.view_remote(
      NotAsked,
      loading_msg: "Loading...",
      empty_msg: "Empty",
      config: base_config(),
    )

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "Loading...")
}

pub fn view_remote_renders_error_state_test() {
  let err = ApiError(status: 500, code: "ERR", message: "Boom")

  let rendered =
    data_table.view_remote(
      Failed(err),
      loading_msg: "Loading...",
      empty_msg: "Empty",
      config: base_config(),
    )

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "Boom")
}

pub fn view_remote_renders_empty_state_test() {
  let rendered =
    data_table.view_remote(
      Loaded([]),
      loading_msg: "Loading...",
      empty_msg: "No rows",
      config: base_config(),
    )

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "No rows")
}

pub fn view_remote_renders_table_rows_test() {
  let rendered =
    data_table.view_remote(
      Loaded(["Alice"]),
      loading_msg: "Loading...",
      empty_msg: "No rows",
      config: base_config(),
    )

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "Alice")
}

pub fn view_remote_renders_table_headers_with_class_test() {
  let rendered =
    data_table.view_remote(
      Loaded(["Alice"]),
      loading_msg: "Loading...",
      empty_msg: "No rows",
      config: base_config(),
    )

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "table-header")
}

pub fn view_uses_responsive_data_table_class_by_default_test() {
  let rendered =
    data_table.new()
    |> data_table.with_columns([
      data_table.column("Very long header", fn(value) { text(value) }),
    ])
    |> data_table.with_rows(["Long value"], fn(value) { value })
    |> data_table.view()

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "data-table-scroll")
  render_assertions.contains(html, "class=\"table data-table\"")
  render_assertions.contains(html, "scope=\"col\"")
}

pub fn sortable_column_renders_keyboard_button_test() {
  let rendered =
    data_table.new()
    |> data_table.with_columns([
      data_table.sortable_column("Name", fn(value) { text(value) }, "sort-name"),
    ])
    |> data_table.with_rows(["Alice"], fn(value) { value })
    |> data_table.view()

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "table-sort-button")
  render_assertions.contains(html, "type=\"button\"")
  render_assertions.contains(html, "aria-label=\"Sort by Name\"")
  render_assertions.contains(html, "aria-hidden=\"true\"")
}

pub fn loading_state_is_announced_without_blocking_page_test() {
  let rendered =
    data_table.view_remote(
      NotAsked,
      loading_msg: "Loading unusually long translated table label...",
      empty_msg: "Empty",
      config: base_config(),
    )

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "role=\"status\"")
  render_assertions.contains(html, "aria-live=\"polite\"")
  render_assertions.contains(html, "aria-busy=\"true\"")
}

pub fn forbidden_state_is_alerted_test() {
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")

  let rendered =
    data_table.view_remote_with_forbidden(
      Failed(err),
      loading_msg: "Loading...",
      empty_msg: "Empty",
      forbidden_msg: "No permission for this table",
      config: base_config(),
    )

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "role=\"alert\"")
  render_assertions.contains(html, "No permission for this table")
}

pub fn empty_error_message_gets_safe_fallback_test() {
  let err = ApiError(status: 500, code: "SERVER", message: "")

  let rendered =
    data_table.view_remote(
      Failed(err),
      loading_msg: "Loading...",
      empty_msg: "Empty",
      config: base_config(),
    )

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "SERVER (500)")
}
