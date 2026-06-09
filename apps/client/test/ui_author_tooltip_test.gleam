//// Tests for author tooltip (AC20).

import gleam/string
import lustre/element

import scrumbringer_client/ui/tooltips/author_tooltip
import scrumbringer_client/ui/tooltips/types.{AuthorInfo}

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

pub fn shows_email_and_role_test() {
  let config =
    author_tooltip.Config(data: AuthorInfo(
      name: "María García",
      email: "maria@example.com",
      role: "Product Owner",
    ))

  let html = author_tooltip.view(config) |> element.to_document_string

  assert_contains(html, "María García")
  assert_contains(html, "maria@example.com")
  assert_contains(html, "Product Owner")
}
