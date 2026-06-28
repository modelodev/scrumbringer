//// Tests for author tooltip (AC20).

import lustre/element
import support/render_assertions

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

  render_assertions.contains(html, "María García")
  render_assertions.contains(html, "maria@example.com")
  render_assertions.contains(html, "Product Owner")
}
