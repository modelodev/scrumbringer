//// Shared inspector shell for Card Show and Task Show.

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
