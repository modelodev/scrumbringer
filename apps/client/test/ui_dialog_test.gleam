import gleam/option.{None, Some}
import lustre/element
import lustre/element/html.{div, text}
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/dialog
import support/render_assertions

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

  render_assertions.not_contains(html, "dialog")
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

  render_assertions.contains(html, "Create")
  render_assertions.contains(html, "icon")
}

pub fn dialog_view_open_exposes_escape_close_contract_test() {
  let config =
    dialog.DialogConfig(
      title: "Create",
      icon: None,
      size: dialog.DialogSm,
      on_close: "close",
    )

  let rendered = dialog.view(config, True, None, [], [])
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.contains(html, "aria-keyshortcuts=\"Escape\"")
  render_assertions.contains(html, "tabindex=\"-1\"")
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

  render_assertions.contains(html, "aria-label=\"Cerrar\"")
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

  render_assertions.contains(html, "type=\"submit\"")
  render_assertions.contains(html, "form=\"project-form\"")
  render_assertions.contains(html, "btn-loading")
  render_assertions.contains(html, "Saving")
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

  render_assertions.contains(html, "type=\"button\"")
  render_assertions.contains(html, "disabled")
  render_assertions.contains(html, "Create")
}
