//// Shared inspector header.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h2, span, text}

import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/modal_close_button

pub type Config(msg) {
  Config(
    title: String,
    title_id: String,
    state_line: opt.Option(String),
    context: opt.Option(Element(msg)),
    meta: opt.Option(Element(msg)),
    actions: opt.Option(Element(msg)),
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
            attribute.class("inspector-title detail-title"),
            ..dialog.focused_panel_title_attributes(config.title_id)
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
    case config.actions {
      opt.Some(actions) -> actions
      opt.None -> element.none()
    },
  ])
}
