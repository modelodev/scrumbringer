//// Author tooltip for note author name (AC20).

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import scrumbringer_client/ui/tooltips/types.{type AuthorInfo}

pub type Config(msg) {
  Config(data: AuthorInfo)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let Config(data: data) = config
  let types.AuthorInfo(name: name, email: email, role: role) = data

  div([attribute.class("author-tooltip"), attribute.role("tooltip")], [
    div([attribute.class("author-tooltip-name")], [text(name)]),
    div([attribute.class("author-tooltip-email")], [text(email)]),
    div([attribute.class("author-tooltip-role")], [
      span([attribute.class("author-tooltip-role-icon")], [text("🏷️")]),
      text(" " <> role),
    ]),
  ])
}
