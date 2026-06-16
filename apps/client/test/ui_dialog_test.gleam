import gleam/option.{None, Some}
import gleam/string
import lustre/element
import lustre/element/html.{div, text}
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text as i18n_text
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

pub fn submit_button_with_locale_form_targets_external_form_test() {
  let html =
    dialog.submit_button_with_locale_form(
      locale.En,
      "project-form",
      True,
      False,
      i18n_text.Save,
      i18n_text.Saving,
    )
    |> element.to_document_string

  assert_contains(html, "type=\"submit\"")
  assert_contains(html, "form=\"project-form\"")
  assert_contains(html, "btn-loading")
  assert_contains(html, "Saving")
}

pub fn submit_button_with_locale_click_renders_click_action_test() {
  let html =
    dialog.submit_button_with_locale_click(
      locale.En,
      "submit",
      False,
      True,
      i18n_text.Create,
      i18n_text.Creating,
    )
    |> element.to_document_string

  assert_contains(html, "type=\"button\"")
  assert_contains(html, "disabled")
  assert_contains(html, "Create")
}
