import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/theme
import scrumbringer_client/ui/task_type_icon

pub fn task_type_icon_renders_svg_for_known_icon_test() {
  let html =
    task_type_icon.view("clipboard-document-list", 16, theme.Default)
    |> element.to_document_string

  string.contains(html, "svg") |> should.be_true
}

pub fn task_type_icon_renders_nothing_for_unknown_icon_test() {
  let html =
    task_type_icon.view("unknown-icon", 16, theme.Default)
    |> element.to_document_string

  string.contains(html, "svg") |> should.be_false
}

pub fn task_type_icon_renders_nothing_for_empty_icon_test() {
  let html =
    task_type_icon.view("", 16, theme.Default)
    |> element.to_document_string

  string.contains(html, "svg") |> should.be_false
}

pub fn task_type_icon_adds_dark_theme_class_test() {
  let html =
    task_type_icon.view("clipboard-document-list", 16, theme.Dark)
    |> element.to_document_string

  string.contains(html, "icon-theme-dark") |> should.be_true
}
