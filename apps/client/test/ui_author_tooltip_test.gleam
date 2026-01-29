//// Tests for author tooltip (AC20).

import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/tooltips/author_tooltip
import scrumbringer_client/ui/tooltips/types.{AuthorInfo}

pub fn shows_email_and_role_test() {
  let config =
    author_tooltip.Config(data: AuthorInfo(
      name: "María García",
      email: "maria@example.com",
      role: "Product Owner",
    ))

  let html = author_tooltip.view(config) |> element.to_document_string

  string.contains(html, "María García") |> should.be_true
  string.contains(html, "maria@example.com") |> should.be_true
  string.contains(html, "Product Owner") |> should.be_true
}
