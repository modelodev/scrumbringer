////
//// Simple confirmation dialog wrapper.
////

import gleam/option.{type Option}

import lustre/element.{type Element}

import scrumbringer_client/ui/button
import scrumbringer_client/ui/dialog

pub type ConfirmConfig(msg) {
  ConfirmConfig(
    title: String,
    body: List(Element(msg)),
    confirm_label: String,
    cancel_label: String,
    on_confirm: msg,
    on_cancel: msg,
    is_open: Bool,
    is_loading: Bool,
    error: Option(String),
    confirm_intent: button.Intent,
  )
}

pub fn view(config: ConfirmConfig(msg)) -> Element(msg) {
  let ConfirmConfig(
    title: title,
    body: body,
    confirm_label: confirm_label,
    cancel_label: cancel_label,
    on_confirm: on_confirm,
    on_cancel: on_cancel,
    is_open: is_open,
    is_loading: is_loading,
    error: error,
    confirm_intent: confirm_intent,
  ) = config

  dialog.view(
    dialog.DialogConfig(
      title: title,
      icon: option.None,
      size: dialog.DialogSm,
      on_close: on_cancel,
    ),
    is_open,
    error,
    body,
    [
      button.text(
        cancel_label,
        on_cancel,
        button.Secondary,
        button.EntityAction,
      )
        |> button.with_disabled(is_loading)
        |> button.view,
      button.text(
        confirm_label,
        on_confirm,
        confirm_intent,
        button.EntityAction,
      )
        |> button.with_disabled(is_loading)
        |> with_loading_class(is_loading)
        |> button.view,
    ],
  )
}

fn with_loading_class(
  config: button.Config(msg),
  is_loading: Bool,
) -> button.Config(msg) {
  case is_loading {
    True -> button.with_class(config, "btn-loading")
    False -> config
  }
}
