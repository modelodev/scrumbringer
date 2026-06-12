////
//// Simple confirmation dialog wrapper.
////

import gleam/option.{type Option}
import gleam/string

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
    confirm_class: String,
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
    confirm_class: confirm_class,
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
        confirm_intent(confirm_class),
        button.EntityAction,
      )
        |> button.with_disabled(is_loading)
        |> button.with_class(confirm_class)
        |> button.view,
    ],
  )
}

fn confirm_intent(confirm_class: String) -> button.Intent {
  case string.contains(confirm_class, "danger") {
    True -> button.Danger
    False -> button.Primary
  }
}
