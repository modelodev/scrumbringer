////
//// Simple confirmation dialog wrapper.
////

import gleam/option.{type Option}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, text}
import lustre/event

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
      button(
        [
          attribute.class("btn btn-secondary btn-sm"),
          attribute.type_("button"),
          attribute.disabled(is_loading),
          event.on_click(on_cancel),
        ],
        [text(cancel_label)],
      ),
      button(
        [
          attribute.class("btn " <> confirm_class),
          attribute.type_("button"),
          attribute.disabled(is_loading),
          event.on_click(on_confirm),
        ],
        [text(confirm_label)],
      ),
    ],
  )
}
