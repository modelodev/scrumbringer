//// Task action helpers for common task buttons.
////
//// Provides semantic task actions with consistent icons across views.

import gleam/option.{type Option}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, text}
import lustre/event

import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/icons

pub fn claim_icon_with_class(
  title: String,
  on_click: msg,
  icon_size: icons.IconSize,
  disabled: Bool,
  class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  action_buttons.task_icon_button_with_class(
    title,
    on_click,
    icons.HandRaised,
    icon_size,
    disabled,
    class,
    tooltip,
    testid,
  )
}

pub fn text_action(
  label: String,
  on_click: msg,
  class: String,
  title: String,
  disabled: Bool,
) -> Element(msg) {
  button(
    [
      attribute.class(class),
      attribute.attribute("title", title),
      attribute.attribute("aria-label", title),
      attribute.disabled(disabled),
      event.on_click(on_click),
    ],
    [text(label)],
  )
}

pub fn claim_icon(
  title: String,
  on_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  action_buttons.task_icon_button(
    title,
    on_click,
    icons.HandRaised,
    size,
    disabled,
    extra_class,
    tooltip,
    testid,
  )
}

pub fn claim_icon_blocked(
  reason: String,
  on_click: msg,
  size: action_buttons.ButtonSize,
  extra_class: String,
  testid: Option(String),
) -> Element(msg) {
  action_buttons.blocked_task_icon_button(
    reason,
    on_click,
    icons.HandRaised,
    size,
    extra_class,
    testid,
  )
}

pub fn release_icon(
  title: String,
  on_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  action_buttons.task_icon_button(
    title,
    on_click,
    icons.Refresh,
    size,
    disabled,
    extra_class,
    tooltip,
    testid,
  )
}

pub fn close_icon(
  title: String,
  on_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  action_buttons.task_icon_button(
    title,
    on_click,
    icons.CheckCircle,
    size,
    disabled,
    extra_class,
    tooltip,
    testid,
  )
}

pub fn pause_icon(
  title: String,
  on_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  action_buttons.task_icon_button(
    title,
    on_click,
    icons.Pause,
    size,
    disabled,
    extra_class,
    tooltip,
    testid,
  )
}

pub fn claim_only(
  title: String,
  on_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> List(Element(msg)) {
  [claim_icon(title, on_click, size, disabled, extra_class, tooltip, testid)]
}

pub fn release_and_close(
  release_title: String,
  release_click: msg,
  close_title: String,
  close_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  release_class: String,
  close_class: String,
  release_tooltip: Option(String),
  close_tooltip: Option(String),
  release_testid: Option(String),
  close_testid: Option(String),
) -> List(Element(msg)) {
  [
    release_icon(
      release_title,
      release_click,
      size,
      disabled,
      release_class,
      release_tooltip,
      release_testid,
    ),
    close_icon(
      close_title,
      close_click,
      size,
      disabled,
      close_class,
      close_tooltip,
      close_testid,
    ),
  ]
}

pub fn pause_and_close(
  pause_title: String,
  pause_click: msg,
  close_title: String,
  close_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  pause_class: String,
  close_class: String,
  pause_tooltip: Option(String),
  close_tooltip: Option(String),
  pause_testid: Option(String),
  close_testid: Option(String),
) -> List(Element(msg)) {
  [
    pause_icon(
      pause_title,
      pause_click,
      size,
      disabled,
      pause_class,
      pause_tooltip,
      pause_testid,
    ),
    close_icon(
      close_title,
      close_click,
      size,
      disabled,
      close_class,
      close_tooltip,
      close_testid,
    ),
  ]
}
