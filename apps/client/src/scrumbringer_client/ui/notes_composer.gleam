//// Notes composer UI view.

import gleam/dynamic/decode
import gleam/option.{type Option}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, text, textarea}
import lustre/event

pub type Config(msg) {
  Config(
    content: String,
    placeholder: String,
    submit_label: String,
    submit_disabled: Bool,
    error: Option(String),
    on_content_change: fn(String) -> msg,
    on_submit: msg,
    /// When False, hides the submit button (for header-button pattern)
    show_button: Bool,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let Config(
    content: content,
    placeholder: placeholder,
    submit_label: submit_label,
    submit_disabled: submit_disabled,
    error: error,
    on_content_change: on_content_change,
    on_submit: on_submit,
    show_button: show_button,
  ) = config

  div([attribute.class("notes-composer")], [
    textarea(
      [
        attribute.class("form-input"),
        attribute.placeholder(placeholder),
        attribute.rows(3),
        attribute.value(content),
        event.on_input(on_content_change),
        on_ctrl_enter(on_submit),
      ],
      "",
    ),
    case error {
      option.Some(err) -> div([attribute.class("form-error")], [text(err)])
      option.None -> element.none()
    },
    case show_button {
      True ->
        div([attribute.class("notes-composer-actions")], [
          button(
            [
              attribute.class("btn btn-primary"),
              event.on_click(on_submit),
              attribute.disabled(submit_disabled),
            ],
            [text(submit_label)],
          ),
        ])
      False -> element.none()
    },
  ])
}

fn on_ctrl_enter(submit_msg: msg) -> attribute.Attribute(msg) {
  event.advanced("keydown", {
    use key <- decode.field("key", decode.string)
    use ctrl_key <- decode.field("ctrlKey", decode.bool)
    use meta_key <- decode.field("metaKey", decode.bool)

    case key {
      "Enter" ->
        case ctrl_key {
          True ->
            decode.success(event.handler(
              submit_msg,
              prevent_default: True,
              stop_propagation: True,
            ))
          False ->
            case meta_key {
              True ->
                decode.success(event.handler(
                  submit_msg,
                  prevent_default: True,
                  stop_propagation: True,
                ))
              False ->
                decode.failure(
                  event.handler(
                    submit_msg,
                    prevent_default: False,
                    stop_propagation: False,
                  ),
                  expected: "ctrl-enter",
                )
            }
        }
      _ ->
        decode.failure(
          event.handler(
            submit_msg,
            prevent_default: False,
            stop_propagation: False,
          ),
          expected: "ctrl-enter",
        )
    }
  })
}
