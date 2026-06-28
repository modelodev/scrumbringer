import gleam/string
import lustre/attribute
import lustre/element/html

import support/render_assertions

import scrumbringer_client/styles/base

pub fn button_with_loading_class_test() {
  let rendered =
    html.button([attribute.class("btn-loading"), attribute.disabled(True)], [
      html.text("Cargando..."),
    ])

  let html_str = render_assertions.html(rendered)
  render_assertions.contains(html_str, "btn-loading")
}

pub fn button_without_loading_class_test() {
  let rendered = html.button([attribute.class("")], [html.text("Enviar")])

  let html_str = render_assertions.html(rendered)
  render_assertions.not_contains(html_str, "btn-loading")
}

pub fn base_css_does_not_force_submit_buttons_to_primary_test() {
  let css = base.css() |> string.join("\n")

  render_assertions.not_contains(css, "button[type=\"submit\"]")
  render_assertions.contains(css, ".btn-icon-prefix")
}
