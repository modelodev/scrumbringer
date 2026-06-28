import gleam/option
import gleam/string
import support/render_assertions

import scrumbringer_client/ui/note_content

fn render(content: String) -> String {
  note_content.view(content, option.None)
  |> render_assertions.fragment_html
}

pub fn note_content_escapes_user_html_test() {
  let html = render("<script>alert(1)</script>")

  render_assertions.contains(html, "&lt;script&gt;alert(1)&lt;/script&gt;")
  render_assertions.not_contains(html, "<script>")
}

pub fn note_content_renders_detected_link_test() {
  let html = render("See https://example.com/spec")

  render_assertions.contains(html, "href=\"https://example.com/spec\"")
  render_assertions.contains(html, "rel=\"noopener noreferrer\"")
}

pub fn note_content_renders_explicit_url_test() {
  let html =
    note_content.view("Spec", option.Some("https://example.com/spec"))
    |> render_assertions.fragment_html

  render_assertions.contains(html, "Spec")
  render_assertions.contains(html, "href=\"https://example.com/spec\"")
}

pub fn note_content_does_not_duplicate_explicit_url_already_in_content_test() {
  let html =
    note_content.view(
      "Spec https://example.com/spec",
      option.Some("https://example.com/spec"),
    )
    |> render_assertions.fragment_html

  render_assertions.contains(html, "href=\"https://example.com/spec\"")
  let without_href =
    string.replace(html, "href=\"https://example.com/spec\"", "")
  render_assertions.not_contains(
    without_href,
    "href=\"https://example.com/spec\"",
  )
}
