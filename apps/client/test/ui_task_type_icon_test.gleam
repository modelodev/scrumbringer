import gleam/string
import lustre/element

import scrumbringer_client/theme
import scrumbringer_client/ui/task_type_icon

fn assert_contains(haystack: String, needle: String) {
  let assert True = string.contains(haystack, needle)
}

fn assert_not_contains(haystack: String, needle: String) {
  let assert False = string.contains(haystack, needle)
}

pub fn task_type_icon_renders_svg_for_known_icon_test() {
  let html =
    task_type_icon.view("clipboard-document-list", 16, theme.Default)
    |> element.to_document_string

  assert_contains(html, "svg")
}

pub fn task_type_icon_renders_nothing_for_unknown_icon_test() {
  let html =
    task_type_icon.view("unknown-icon", 16, theme.Default)
    |> element.to_document_string

  assert_not_contains(html, "svg")
}

pub fn task_type_icon_renders_nothing_for_empty_icon_test() {
  let html =
    task_type_icon.view("", 16, theme.Default)
    |> element.to_document_string

  assert_not_contains(html, "svg")
}

pub fn task_type_icon_adds_dark_theme_class_test() {
  let html =
    task_type_icon.view("clipboard-document-list", 16, theme.Dark)
    |> element.to_document_string

  assert_contains(html, "icon-theme-dark")
}
