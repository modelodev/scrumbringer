import lustre/element
import support/render_assertions

import scrumbringer_client/theme
import scrumbringer_client/ui/task_type_icon

pub fn task_type_icon_renders_svg_for_known_icon_test() {
  let html =
    task_type_icon.view("clipboard-document-list", 16, theme.Default)
    |> element.to_document_string

  render_assertions.contains(html, "svg")
}

pub fn task_type_icon_renders_nothing_for_unknown_icon_test() {
  let html =
    task_type_icon.view("unknown-icon", 16, theme.Default)
    |> element.to_document_string

  render_assertions.not_contains(html, "svg")
}

pub fn task_type_icon_renders_nothing_for_empty_icon_test() {
  let html =
    task_type_icon.view("", 16, theme.Default)
    |> element.to_document_string

  render_assertions.not_contains(html, "svg")
}

pub fn task_type_icon_adds_dark_theme_class_test() {
  let html =
    task_type_icon.view("clipboard-document-list", 16, theme.Dark)
    |> element.to_document_string

  render_assertions.contains(html, "icon-theme-dark")
}
