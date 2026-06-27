//// Shared inspector header.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h2, span, text}

import scrumbringer_client/ui/modal_close_button

pub type Config(msg) {
  Config(
    title: String,
    title_id: String,
    state_line: opt.Option(String),
    context: opt.Option(Element(msg)),
    meta: opt.Option(Element(msg)),
    primary_action: opt.Option(Element(msg)),
    open_in: opt.Option(Element(msg)),
    secondary_actions: opt.Option(Element(msg)),
    close_label: String,
    on_close: msg,
    extra_class: String,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("inspector-header " <> config.extra_class)], [
    div([attribute.class("inspector-title-row")], [
      div([attribute.class("inspector-title-stack")], [
        h2(
          [
            attribute.id(config.title_id),
            attribute.class("inspector-title detail-title"),
          ],
          [text(config.title)],
        ),
        case config.state_line {
          opt.Some(line) ->
            span([attribute.class("inspector-state-line")], [text(line)])
          opt.None -> element.none()
        },
      ]),
      modal_close_button.view_with_label_and_class(
        config.close_label,
        "modal-close btn-icon inspector-close",
        config.on_close,
      ),
    ]),
    case config.context {
      opt.Some(context) -> context
      opt.None -> element.none()
    },
    case config.meta {
      opt.Some(meta) -> meta
      opt.None -> element.none()
    },
    view_actions(config),
  ])
}

fn view_actions(config: Config(msg)) -> Element(msg) {
  case config.primary_action, config.open_in, config.secondary_actions {
    opt.None, opt.None, opt.None -> element.none()
    _, _, _ ->
      div([attribute.class("inspector-actions")], [
        case config.primary_action {
          opt.Some(primary) ->
            div([attribute.class("inspector-primary-action")], [primary])
          opt.None -> element.none()
        },
        case config.open_in {
          opt.Some(open_in) -> open_in
          opt.None -> element.none()
        },
        case config.secondary_actions {
          opt.Some(actions) -> actions
          opt.None -> element.none()
        },
      ])
  }
}
