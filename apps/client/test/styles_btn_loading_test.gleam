import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html

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
