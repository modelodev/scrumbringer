import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(
  primary_actions: List(Element(msg)),
  workflow_actions: List(Element(msg)),
  manage_actions: List(Element(msg)),
) -> Element(msg) {
  html.div([attribute.class("action-row")], [
    html.div([attribute.class("action-row-main")], [
      html.div([attribute.class("action-row-primary")], primary_actions),
      html.div([attribute.class("action-row-workflow")], workflow_actions),
    ]),
    html.div([attribute.class("action-row-manage")], manage_actions),
  ])
}
