//// Shared inspector shell for Card Show and Task Show.

import gleam/list

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import scrumbringer_client/ui/dialog

pub type Config(msg) {
  Config(
    root_class: String,
    panel_class: String,
    title_id: String,
    testid: String,
  )
}

pub fn view(config: Config(msg), children: List(Element(msg))) -> Element(msg) {
  div(
    [
      attribute.class(config.root_class <> " inspector-shell"),
      attribute.attribute("data-testid", config.testid),
    ],
    [
      div(
        [
          attribute.class(config.panel_class <> " inspector-panel"),
          ..dialog.passive_panel_attributes(config.title_id)
        ],
        children,
      ),
    ],
  )
}

pub fn detail(
  config: Config(msg),
  header_block_class: String,
  body_class: String,
  header: Element(msg),
  tabs: Element(msg),
  body: Element(msg),
  overlays: List(Element(msg)),
) -> Element(msg) {
  view(
    config,
    list.append(
      [
        div([attribute.class(header_block_class <> " detail-header-block")], [
          header,
          tabs,
        ]),
        div([attribute.class(body_class)], [body]),
      ],
      overlays,
    ),
  )
}
