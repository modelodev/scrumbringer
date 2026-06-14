import gleam/option.{None, Some}
import gleam/string
import lustre/element
import lustre/element/html.{div, text}
import scrumbringer_client/ui/dialog

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

fn assert_not_contains(html: String, text: String) {
  let assert False = string.contains(html, text)
}

pub fn dialog_view_closed_renders_nothing_test() {
  let config =
    dialog.DialogConfig(
      title: "Test",
      icon: None,
      size: dialog.DialogSm,
      on_close: "close",
    )

  let rendered = dialog.view(config, False, None, [], [])
  let html = element.to_document_string(rendered)

  assert_not_contains(html, "dialog")
}

pub fn dialog_view_open_includes_title_and_icon_test() {
  let config =
    dialog.DialogConfig(
      title: "Create",
      icon: Some(text("icon")),
      size: dialog.DialogSm,
      on_close: "close",
    )

  let rendered = dialog.view(config, True, None, [div([], [text("Body")])], [])

  let html = element.to_document_string(rendered)

  assert_contains(html, "Create")
  assert_contains(html, "icon")
}

pub fn dialog_view_accepts_localized_close_label_test() {
  let config =
    dialog.DialogConfig(
      title: "Crear",
      icon: None,
      size: dialog.DialogSm,
      on_close: "close",
    )

  let rendered =
    dialog.view_with_close_label(config, "Cerrar", True, None, [], [])
  let html = element.to_document_string(rendered)

  assert_contains(html, "aria-label=\"Cerrar\"")
}
