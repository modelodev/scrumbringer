import gleam/option as opt
import gleam/string
import lustre/attribute
import lustre/element/html.{input}
import support/render_assertions

import scrumbringer_client/ui/form_field

pub fn view_required_shows_asterisk_test() {
  let rendered = form_field.view_required("Email", input([]))
  let html = render_assertions.html(rendered)

  render_assertions.contains(html, "required-indicator")
  render_assertions.contains(html, "*")
}

pub fn view_required_preserves_label_text_test() {
  let rendered = form_field.view_required("Password", input([]))
  let html = render_assertions.html(rendered)

  render_assertions.contains(html, "Password")
}

pub fn view_required_asterisk_has_aria_hidden_test() {
  let rendered = form_field.view_required("Email", input([]))
  let html = render_assertions.html(rendered)

  render_assertions.contains(html, "aria-hidden")
}

pub fn with_error_shows_error_when_some_test() {
  let rendered =
    form_field.with_error(
      "Password",
      input([]),
      opt.Some("La contrasena es muy corta"),
    )

  let html = render_assertions.html(rendered)
  render_assertions.contains(html, "La contrasena es muy corta")
  render_assertions.contains(html, "field-error")
}

pub fn with_error_has_role_alert_test() {
  let rendered =
    form_field.with_error("Email", input([]), opt.Some("Email invalido"))

  let html = render_assertions.html(rendered)
  render_assertions.contains(html, "role=\"alert\"")
}

pub fn with_error_hides_error_when_none_test() {
  let rendered = form_field.with_error("Email", input([]), opt.None)
  let html = render_assertions.html(rendered)

  render_assertions.not_contains(html, "field-error")
  render_assertions.not_contains(html, "role=\"alert\"")
}

pub fn with_error_preserves_label_test() {
  let rendered =
    form_field.with_error("Contrasena", input([]), opt.Some("Error"))

  let html = render_assertions.html(rendered)
  render_assertions.contains(html, "Contrasena")
}

pub fn with_error_preserves_control_test() {
  let rendered =
    form_field.with_error("Test", input([attribute.id("my-input")]), opt.None)

  let html = render_assertions.html(rendered)
  render_assertions.contains(html, "my-input")
}

pub fn with_error_shows_warning_icon_test() {
  let rendered = form_field.with_error("Test", input([]), opt.Some("Error"))
  let html = render_assertions.html(rendered)

  let has_icon =
    string.contains(html, "error-icon") || string.contains(html, "warning")

  let assert True = has_icon
}

pub fn with_error_html_in_error_is_escaped_test() {
  let rendered =
    form_field.with_error(
      "Test",
      input([]),
      opt.Some("<script>alert('xss')</script>"),
    )

  let html = render_assertions.html(rendered)
  render_assertions.contains(html, "&lt;script&gt;")
  render_assertions.not_contains(html, "<script>")
}
