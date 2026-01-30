//// Task action helpers for common task buttons.
////
//// Provides thin wrappers over action_buttons for consistent icons and
//// configuration across views.

import gleam/option.{type Option}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, text}
import lustre/event

import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/icons

pub fn icon_action(
  title: String,
  on_click: msg,
  icon: icons.NavIcon,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  action_buttons.task_icon_button(
    title,
    on_click,
    icon,
    size,
    disabled,
    extra_class,
    tooltip,
    testid,
  )
}

pub fn icon_action_with_class(
  title: String,
  on_click: msg,
  icon: icons.NavIcon,
  icon_size: icons.IconSize,
  disabled: Bool,
  class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  action_buttons.task_icon_button_with_class(
    title,
    on_click,
    icon,
    icon_size,
    disabled,
    class,
    tooltip,
    testid,
  )
}

pub fn claim_icon_with_class(
  title: String,
  on_click: msg,
  icon_size: icons.IconSize,
  disabled: Bool,
  class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  icon_action_with_class(
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
  icon_action(
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

pub fn release_icon(
  title: String,
  on_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  icon_action(
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

pub fn complete_icon(
  title: String,
  on_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  icon_action(
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
  icon_action(
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

pub fn start_icon(
  title: String,
  on_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  icon_action(
    title,
    on_click,
    icons.Play,
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

pub fn release_and_complete(
  release_title: String,
  release_click: msg,
  complete_title: String,
  complete_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  release_class: String,
  complete_class: String,
  release_tooltip: Option(String),
  complete_tooltip: Option(String),
  release_testid: Option(String),
  complete_testid: Option(String),
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
    complete_icon(
      complete_title,
      complete_click,
      size,
      disabled,
      complete_class,
      complete_tooltip,
      complete_testid,
    ),
  ]
}

pub fn pause_and_complete(
  pause_title: String,
  pause_click: msg,
  complete_title: String,
  complete_click: msg,
  size: action_buttons.ButtonSize,
  disabled: Bool,
  pause_class: String,
  complete_class: String,
  pause_tooltip: Option(String),
  complete_tooltip: Option(String),
  pause_testid: Option(String),
  complete_testid: Option(String),
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
    complete_icon(
      complete_title,
      complete_click,
      size,
      disabled,
      complete_class,
      complete_tooltip,
      complete_testid,
    ),
  ]
}
