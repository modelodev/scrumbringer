import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element
import lustre/element/html.{div, text}
import scrumbringer_client/client_state
import scrumbringer_client/ui/dialog

pub fn dialog_view_closed_renders_nothing_test() {
  let config =
    dialog.DialogConfig(
      title: "Test",
      icon: None,
      size: dialog.DialogSm,
      on_close: client_state.NoOp,
    )

  let rendered = dialog.view(config, False, None, [], [])
  let html = element.to_document_string(rendered)

  string.contains(html, "dialog") |> should.be_false
}

pub fn dialog_view_open_includes_title_and_icon_test() {
  let config =
    dialog.DialogConfig(
      title: "Create",
      icon: Some("icon"),
      size: dialog.DialogSm,
      on_close: client_state.NoOp,
    )

  let rendered =
    dialog.view(
      config,
      True,
      None,
      [div([], [text("Body")])],
      [],
    )

  let html = element.to_document_string(rendered)

  string.contains(html, "Create") |> should.be_true
  string.contains(html, "icon") |> should.be_true
}
