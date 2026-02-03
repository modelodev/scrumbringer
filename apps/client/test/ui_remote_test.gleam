import domain/api_error.{type ApiError, ApiError}
import domain/remote as remote_state
import gleam/string
import gleeunit/should
import lustre/element
import lustre/element/html.{div, text}
import scrumbringer_client/ui/remote

pub fn view_remote_renders_loading_for_not_asked_test() {
  let rendered =
    remote.view_remote(
      remote_state.NotAsked,
      loading: fn() { div([], [text("Loading")]) },
      error: fn(_err) { div([], [text("Error")]) },
      loaded: fn(_data) { div([], [text("Loaded")]) },
    )

  let html = element.to_document_string(rendered)
  string.contains(html, "Loading") |> should.be_true
}

pub fn view_remote_renders_error_for_failed_test() {
  let err = ApiError(status: 500, code: "ERR", message: "Boom")

  let rendered =
    remote.view_remote(
      remote_state.Failed(err),
      loading: fn() { div([], [text("Loading")]) },
      error: fn(e: ApiError) { div([], [text(e.message)]) },
      loaded: fn(_data) { div([], [text("Loaded")]) },
    )

  let html = element.to_document_string(rendered)
  string.contains(html, "Boom") |> should.be_true
}

pub fn view_remote_renders_loaded_for_loaded_test() {
  let rendered =
    remote.view_remote(
      remote_state.Loaded([1]),
      loading: fn() { div([], [text("Loading")]) },
      error: fn(_err) { div([], [text("Error")]) },
      loaded: fn(_data) { div([], [text("Loaded")]) },
    )

  let html = element.to_document_string(rendered)
  string.contains(html, "Loaded") |> should.be_true
}

pub fn view_remote_panel_uses_loading_panel_test() {
  let rendered =
    remote.view_remote_panel(
      remote: remote_state.NotAsked,
      title: "Metrics",
      loading_msg: "Loading metrics...",
      loaded: fn(_data) { div([], [text("Loaded")]) },
    )

  let html = element.to_document_string(rendered)
  string.contains(html, "Metrics") |> should.be_true
  string.contains(html, "Loading metrics...") |> should.be_true
}

pub fn view_remote_inline_uses_error_view_test() {
  let err = ApiError(status: 500, code: "ERR", message: "Oops")

  let rendered =
    remote.view_remote_inline(
      remote: remote_state.Failed(err),
      loading_msg: "Loading...",
      loaded: fn(_data) { div([], [text("Loaded")]) },
    )

  let html = element.to_document_string(rendered)
  string.contains(html, "Oops") |> should.be_true
}
