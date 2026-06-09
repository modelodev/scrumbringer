import domain/api_error.{ApiError}
import domain/remote.{Failed, Loaded, NotAsked}
import gleam/string
import lustre/element
import lustre/element/html.{text}
import scrumbringer_client/ui/data_table

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

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
  assert_contains(html, "Loading...")
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
  assert_contains(html, "Boom")
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
  assert_contains(html, "No rows")
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
  assert_contains(html, "Alice")
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
  assert_contains(html, "table-header")
}
