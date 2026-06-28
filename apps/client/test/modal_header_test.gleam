//// Tests for live modal_header UI contracts.

import gleam/option.{None, Some}
import lustre/element
import lustre/element/html.{span, text}
import support/render_assertions

import scrumbringer_client/ui/modal_header

pub fn dialog_header_renders_title_and_banner_role_test() {
  let html =
    modal_header.view_dialog_with_close_label("Create Task", None, Nil, "Close")
    |> element.to_string()

  render_assertions.contains(html, "dialog-header")
  render_assertions.contains(html, "role=\"banner\"")
  render_assertions.contains(html, "<h3")
  render_assertions.contains(html, "Create Task")
}

pub fn dialog_header_renders_localized_close_label_test() {
  let html =
    modal_header.view_dialog_with_close_label("Crear", None, Nil, "Cerrar")
    |> element.to_string()

  render_assertions.contains(html, "dialog-close")
  render_assertions.contains(html, "aria-label=\"Cerrar\"")
}

pub fn dialog_header_renders_optional_icon_test() {
  let icon = span([], [text("icon")])

  let html =
    modal_header.view_dialog_with_close_label(
      "With Icon",
      Some(icon),
      Nil,
      "Close",
    )
    |> element.to_string()

  render_assertions.contains(html, "modal-header-icon")
  render_assertions.contains(html, "icon")
}

pub fn icon_dialog_header_renders_title_wrapper_test() {
  let html =
    modal_header.view_dialog_with_icon_and_close_label(
      "Create Task",
      text("icon"),
      Nil,
      "Close",
    )
    |> element.to_string()

  render_assertions.contains(html, "dialog-title")
  render_assertions.contains(html, "dialog-icon")
  render_assertions.contains(html, "<h3")
  render_assertions.contains(html, "Create Task")
}

pub fn icon_dialog_header_uses_icon_close_class_and_label_test() {
  let html =
    modal_header.view_dialog_with_icon_and_close_label(
      "Crear",
      text("icon"),
      Nil,
      "Cerrar",
    )
    |> element.to_string()

  render_assertions.contains(html, "btn-icon dialog-close")
  render_assertions.contains(html, "aria-label=\"Cerrar\"")
}
