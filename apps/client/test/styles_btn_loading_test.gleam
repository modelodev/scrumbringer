import gleam/string
import gleeunit/should
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn button_with_loading_class_test() {
  let rendered =
    html.button([attribute.class("btn-loading"), attribute.disabled(True)], [
      html.text("Cargando..."),
    ])

  let html_str = element.to_document_string(rendered)
  string.contains(html_str, "btn-loading") |> should.be_true
}

pub fn button_without_loading_class_test() {
  let rendered = html.button([attribute.class("")], [html.text("Enviar")])

  let html_str = element.to_document_string(rendered)
  string.contains(html_str, "btn-loading") |> should.be_false
}
