import gleam/list
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{button, div, text}
import lustre/event

pub type MoveOption(msg) {
  MoveOption(label: String, testid: String, on_click: msg)
}

pub fn option(label: String, testid: String, on_click: msg) -> MoveOption(msg) {
  MoveOption(label:, testid:, on_click:)
}

pub fn view(
  trigger_label: String,
  trigger_testid: String,
  options: List(MoveOption(msg)),
) -> Element(msg) {
  case options {
    [] -> none()
    _ ->
      div([attribute.class("move-menu")], [
        button(
          [
            attribute.class("btn btn-xs btn-ghost move-menu-trigger"),
            attribute.attribute("type", "button"),
            attribute.attribute("data-testid", trigger_testid),
          ],
          [text(trigger_label)],
        ),
        div(
          [attribute.class("move-menu-actions")],
          list.map(options, fn(item) {
            let MoveOption(label:, testid:, on_click:) = item

            button(
              [
                attribute.class("btn btn-xs btn-ghost move-menu-option"),
                attribute.attribute("data-testid", testid),
                attribute.attribute("type", "button"),
                event.on_click(on_click),
              ],
              [text(label)],
            )
          }),
        ),
      ])
  }
}
