////
//// Minimal search + select list for dialog use.
////

import gleam/list as g_list

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html.{div, input, text}
import lustre/event

import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}

pub type Config(msg, item) {
  Config(
    label: String,
    placeholder: String,
    value: String,
    on_change: fn(String) -> msg,
    input_attributes: List(Attribute(msg)),
    results: Remote(List(item)),
    render_item: fn(item) -> Element(msg),
    empty_label: String,
    loading_label: String,
    error_label: fn(String) -> String,
    class: String,
  )
}

pub fn view(config: Config(msg, item)) -> Element(msg) {
  let Config(
    label: label,
    placeholder: placeholder,
    value: value,
    on_change: on_change,
    input_attributes: input_attributes,
    results: results,
    render_item: render_item,
    empty_label: empty_label,
    loading_label: loading_label,
    error_label: error_label,
    class: class,
  ) = config

  div([attribute.class("search-select " <> class)], [
    div([attribute.class("search-select-label")], [text(label)]),
    input(g_list.append(
      [
        attribute.type_("text"),
        attribute.value(value),
        attribute.placeholder(placeholder),
        event.on_input(on_change),
      ],
      input_attributes,
    )),
    case results {
      NotAsked -> div([attribute.class("empty")], [text(empty_label)])
      Loading -> div([attribute.class("empty")], [text(loading_label)])
      Failed(err) ->
        div([attribute.class("empty")], [text(error_label(err.message))])
      Loaded(items) ->
        case items {
          [] -> div([attribute.class("empty")], [text(empty_label)])
          _ ->
            div(
              [attribute.class("search-select-results")],
              g_list.map(items, render_item),
            )
        }
    },
  ])
}
