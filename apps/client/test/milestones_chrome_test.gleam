import gleam/string
import lustre/element
import lustre/element/html.{button, text}

import scrumbringer_client/features/milestones/chrome
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn milestones_chrome_renders_loading_without_root_model_test() {
  let html =
    chrome.loading(locale.En)
    |> element.to_document_string

  assert_contains(html, "milestones-loading")
  assert_contains(html, "Loading")
}

pub fn milestones_chrome_renders_error_without_root_model_test() {
  let html =
    chrome.error(locale.En)
    |> element.to_document_string

  assert_contains(html, "milestones-error")
  assert_contains(html, "Could not load milestones")
}

pub fn milestones_chrome_renders_header_without_root_model_test() {
  let html =
    chrome.header(locale.En, button([], [text("Create")]))
    |> element.to_document_string

  assert_contains(html, "milestones-header")
  assert_contains(html, "milestones-toolbar-actions")
  assert_contains(html, ">Milestones<")
  assert_contains(html, ">Create<")
}
