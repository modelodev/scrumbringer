import gleam/option as opt
import gleam/string
import gleeunit/should
import lustre/attribute
import lustre/element
import lustre/element/html.{input}

import scrumbringer_client/ui/form_field

pub fn view_required_shows_asterisk_test() {
  let rendered = form_field.view_required("Email", input([]))
  let html = element.to_document_string(rendered)

  string.contains(html, "required-indicator") |> should.be_true
  string.contains(html, "*") |> should.be_true
}

pub fn view_required_preserves_label_text_test() {
  let rendered = form_field.view_required("Password", input([]))
  let html = element.to_document_string(rendered)

  string.contains(html, "Password") |> should.be_true
}

pub fn view_required_asterisk_has_aria_hidden_test() {
  let rendered = form_field.view_required("Email", input([]))
  let html = element.to_document_string(rendered)

  string.contains(html, "aria-hidden") |> should.be_true
}

pub fn with_error_shows_error_when_some_test() {
  let rendered =
    form_field.with_error(
      "Password",
      input([]),
      opt.Some("La contrasena es muy corta"),
    )

  let html = element.to_document_string(rendered)
  string.contains(html, "La contrasena es muy corta") |> should.be_true
  string.contains(html, "field-error") |> should.be_true
}

pub fn with_error_has_role_alert_test() {
  let rendered =
    form_field.with_error("Email", input([]), opt.Some("Email invalido"))

  let html = element.to_document_string(rendered)
  string.contains(html, "role=\"alert\"") |> should.be_true
}

pub fn with_error_hides_error_when_none_test() {
  let rendered = form_field.with_error("Email", input([]), opt.None)
  let html = element.to_document_string(rendered)

  string.contains(html, "field-error") |> should.be_false
  string.contains(html, "role=\"alert\"") |> should.be_false
}

pub fn with_error_preserves_label_test() {
  let rendered =
    form_field.with_error("Contrasena", input([]), opt.Some("Error"))

  let html = element.to_document_string(rendered)
  string.contains(html, "Contrasena") |> should.be_true
}

pub fn with_error_preserves_control_test() {
  let rendered =
    form_field.with_error("Test", input([attribute.id("my-input")]), opt.None)

  let html = element.to_document_string(rendered)
  string.contains(html, "my-input") |> should.be_true
}

pub fn with_error_shows_warning_icon_test() {
  let rendered = form_field.with_error("Test", input([]), opt.Some("Error"))
  let html = element.to_document_string(rendered)

  let has_icon =
    string.contains(html, "error-icon") || string.contains(html, "warning")

  has_icon |> should.be_true
}

pub fn with_error_html_in_error_is_escaped_test() {
  let rendered =
    form_field.with_error(
      "Test",
      input([]),
      opt.Some("<script>alert('xss')</script>"),
    )

  let html = element.to_document_string(rendered)
  string.contains(html, "&lt;script&gt;") |> should.be_true
  string.contains(html, "<script>") |> should.be_false
}
