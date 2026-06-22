import gleam/option
import gleam/string
import lustre/element

import scrumbringer_client/ui/note_content

fn render(content: String) -> String {
  note_content.view(content, option.None)
  |> element.fragment
  |> element.to_document_string
}

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn note_content_escapes_user_html_test() {
  let html = render("<script>alert(1)</script>")

  assert_contains(html, "&lt;script&gt;alert(1)&lt;/script&gt;")
  assert_not_contains(html, "<script>")
}

pub fn note_content_renders_detected_link_test() {
  let html = render("See https://example.com/spec")

  assert_contains(html, "href=\"https://example.com/spec\"")
  assert_contains(html, "rel=\"noopener noreferrer\"")
}

pub fn note_content_renders_explicit_url_test() {
  let html =
    note_content.view("Spec", option.Some("https://example.com/spec"))
    |> element.fragment
    |> element.to_document_string

  assert_contains(html, "Spec")
  assert_contains(html, "href=\"https://example.com/spec\"")
}
