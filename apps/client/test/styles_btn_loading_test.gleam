import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html

import scrumbringer_client/styles/base

fn assert_contains(haystack: String, needle: String) {
  let assert True = string.contains(haystack, needle)
}

fn assert_not_contains(haystack: String, needle: String) {
  let assert False = string.contains(haystack, needle)
}

pub fn button_with_loading_class_test() {
  let rendered =
    html.button([attribute.class("btn-loading"), attribute.disabled(True)], [
      html.text("Cargando..."),
    ])

  let html_str = element.to_document_string(rendered)
  assert_contains(html_str, "btn-loading")
}

pub fn button_without_loading_class_test() {
  let rendered = html.button([attribute.class("")], [html.text("Enviar")])

  let html_str = element.to_document_string(rendered)
  assert_not_contains(html_str, "btn-loading")
}

pub fn base_css_does_not_force_submit_buttons_to_primary_test() {
  let css = base.css() |> string.join("\n")

  assert_not_contains(css, "button[type=\"submit\"]")
  assert_contains(css, ".btn-icon-prefix")
}
