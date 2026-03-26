import gleam/list
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{button, div, text}
import lustre/event

pub type Item(msg) {
  Item(label: String, testid: String, on_click: msg)
}

pub fn item(label: String, testid: String, on_click: msg) -> Item(msg) {
  Item(label, testid, on_click)
}

pub fn view(
  trigger_label: String,
  trigger_testid: String,
  menu_class: String,
  trigger_class: String,
  items_class: String,
  item_class: String,
  items: List(Item(msg)),
) -> Element(msg) {
  case items {
    [] -> none()
    _ ->
      div([attribute.class(menu_class)], [
        button(
          [
            attribute.class(trigger_class),
            attribute.attribute("type", "button"),
            attribute.attribute("data-testid", trigger_testid),
            attribute.attribute("aria-haspopup", "menu"),
            attribute.attribute("aria-expanded", "false"),
          ],
          [text(trigger_label)],
        ),
        div(
          [
            attribute.class(items_class),
            attribute.attribute("role", "menu"),
          ],
          list.map(items, fn(menu_item) {
            let Item(label:, testid:, on_click:) = menu_item

            button(
              [
                attribute.class(item_class),
                attribute.attribute("data-testid", testid),
                attribute.attribute("type", "button"),
                attribute.attribute("role", "menuitem"),
                event.on_click(on_click),
              ],
              [text(label)],
            )
          }),
        ),
      ])
  }
}
