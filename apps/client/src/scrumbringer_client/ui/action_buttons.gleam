//// Semantic wrappers for common icon-only actions.
////
//// Keep feature code on domain names like edit/delete/claim while delegating the
//// shared visual contract to `ui/button`.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button}
import lustre/event

import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/icons

/// Size variants for action buttons.
pub type ButtonSize {
  SizeXs
  SizeSm
}

/// Stable availability of an entity action.
pub type Availability {
  Available
  Busy
  Blocked(reason: String)
}

fn button_size(size: ButtonSize) -> ui_button.Size {
  case size {
    SizeXs -> ui_button.ExtraSmall
    SizeSm -> ui_button.Small
  }
}

fn with_optional_class(
  config: ui_button.Config(msg),
  class_name: String,
) -> ui_button.Config(msg) {
  case string.is_empty(class_name) {
    True -> config
    False -> ui_button.with_class(config, class_name)
  }
}

fn with_optional_testid(
  config: ui_button.Config(msg),
  testid: Option(String),
) -> ui_button.Config(msg) {
  case testid {
    Some(value) -> ui_button.with_testid(config, value)
    None -> config
  }
}

fn with_optional_tooltip(
  config: ui_button.Config(msg),
  tooltip: Option(String),
) -> ui_button.Config(msg) {
  case tooltip {
    Some(value) -> ui_button.with_tooltip(config, value)
    None -> config
  }
}

fn icon_button(
  title: String,
  on_click: msg,
  icon: icons.NavIcon,
  intent: ui_button.Intent,
  size: ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  ui_button.icon(title, on_click, icon, intent, ui_button.EntityAction)
  |> ui_button.with_size(button_size(size))
  |> ui_button.with_disabled(disabled)
  |> with_optional_class(extra_class)
  |> with_optional_tooltip(tooltip)
  |> with_optional_testid(testid)
  |> ui_button.view
}

fn blocked_icon_button(
  reason: String,
  on_click: msg,
  icon: icons.NavIcon,
  intent: ui_button.Intent,
  size: ButtonSize,
  extra_class: String,
  testid: Option(String),
) -> Element(msg) {
  ui_button.icon(reason, on_click, icon, intent, ui_button.EntityAction)
  |> ui_button.with_size(button_size(size))
  |> with_optional_class(extra_class)
  |> ui_button.with_blocked_reason(reason)
  |> with_optional_testid(testid)
  |> ui_button.view
}

/// Generic blocked icon-only task action button.
pub fn blocked_task_icon_button(
  reason: String,
  on_click: msg,
  icon: icons.NavIcon,
  size: ButtonSize,
  extra_class: String,
  testid: Option(String),
) -> Element(msg) {
  blocked_icon_button(
    reason,
    on_click,
    icon,
    ui_button.Neutral,
    size,
    extra_class,
    testid,
  )
}

/// Generic icon-only task action button.
pub fn task_icon_button(
  title: String,
  on_click: msg,
  icon: icons.NavIcon,
  size: ButtonSize,
  disabled: Bool,
  extra_class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  icon_button(
    title,
    on_click,
    icon,
    ui_button.Neutral,
    size,
    disabled,
    extra_class,
    tooltip,
    testid,
  )
}

/// Generic task action button with full class control for legacy layouts.
pub fn task_icon_button_with_class(
  title: String,
  on_click: msg,
  icon: icons.NavIcon,
  icon_size: icons.IconSize,
  disabled: Bool,
  class: String,
  tooltip: Option(String),
  testid: Option(String),
) -> Element(msg) {
  let tooltip_attr = case tooltip {
    Some(value) -> [attribute.attribute("data-tooltip", value)]
    None -> []
  }

  let testid_attr = case testid {
    Some(value) -> [attribute.attribute("data-testid", value)]
    None -> []
  }

  let base_attrs = [
    attribute.class(class),
    attribute.attribute("title", title),
    attribute.attribute("aria-label", title),
    attribute.disabled(disabled),
    event.on_click(on_click),
  ]

  let attrs = list.append(base_attrs, tooltip_attr)
  let attrs_with_testid = list.append(attrs, testid_attr)

  button(attrs_with_testid, [icons.nav_icon(icon, icon_size)])
}

/// Creates an edit button with pencil icon.
pub fn edit_button(title: String, on_click: msg) -> Element(msg) {
  edit_button_with_size(title, on_click, SizeXs)
}

/// Creates an edit button with custom size.
pub fn edit_button_with_size(
  title: String,
  on_click: msg,
  size: ButtonSize,
) -> Element(msg) {
  icon_button(
    title,
    on_click,
    icons.Pencil,
    ui_button.Neutral,
    size,
    False,
    "",
    None,
    None,
  )
}

/// Creates an edit button with a data-testid attribute.
pub fn edit_button_with_testid(
  title: String,
  on_click: msg,
  testid: String,
) -> Element(msg) {
  icon_button(
    title,
    on_click,
    icons.Pencil,
    ui_button.Neutral,
    SizeXs,
    False,
    "",
    None,
    Some(testid),
  )
}

/// Creates a delete button with trash icon.
pub fn delete_button(title: String, on_click: msg) -> Element(msg) {
  delete_button_with_size(title, on_click, SizeXs)
}

/// Creates a delete button with custom size.
pub fn delete_button_with_size(
  title: String,
  on_click: msg,
  size: ButtonSize,
) -> Element(msg) {
  icon_button(
    title,
    on_click,
    icons.Trash,
    ui_button.Danger,
    size,
    False,
    "",
    None,
    None,
  )
}

/// Creates a delete button with a data-testid attribute.
pub fn delete_button_with_testid(
  title: String,
  on_click: msg,
  testid: String,
) -> Element(msg) {
  icon_button(
    title,
    on_click,
    icons.Trash,
    ui_button.Danger,
    SizeXs,
    False,
    "",
    None,
    Some(testid),
  )
}

/// Creates a delete button with disabled state and a data-testid attribute.
pub fn delete_button_with_disabled_and_testid(
  title: String,
  on_click: msg,
  disabled: Bool,
  testid: String,
) -> Element(msg) {
  icon_button(
    title,
    on_click,
    icons.Trash,
    ui_button.Danger,
    SizeXs,
    disabled,
    "",
    None,
    Some(testid),
  )
}

/// Creates a delete button from an explicit action availability.
pub fn delete_button_with_availability_and_testid(
  title: String,
  on_click: msg,
  availability: Availability,
  testid: String,
) -> Element(msg) {
  case availability {
    Available -> delete_button_with_testid(title, on_click, testid)
    Busy ->
      delete_button_with_disabled_and_testid(title, on_click, True, testid)
    Blocked(reason) ->
      delete_button_blocked_with_testid(reason, on_click, testid)
  }
}

/// Creates a delete button for blocked destructive actions.
pub fn delete_button_blocked_with_testid(
  reason: String,
  on_click: msg,
  testid: String,
) -> Element(msg) {
  blocked_icon_button(
    reason,
    on_click,
    icons.Trash,
    ui_button.Danger,
    SizeXs,
    "btn-delete-blocked",
    Some(testid),
  )
}

/// Creates an add button with plus icon.
pub fn add_button_with_size(
  title: String,
  on_click: msg,
  size: ButtonSize,
) -> Element(msg) {
  add_button_with_size_and_testid(title, on_click, size, None)
}

pub fn add_button_with_size_and_testid(
  title: String,
  on_click: msg,
  size: ButtonSize,
  testid: Option(String),
) -> Element(msg) {
  add_icon_button_with_size_and_testid(
    title,
    on_click,
    size,
    icons.Plus,
    testid,
    None,
  )
}

pub fn add_icon_button_with_size_and_testid(
  title: String,
  on_click: msg,
  size: ButtonSize,
  icon: icons.NavIcon,
  testid: Option(String),
  extra_class: Option(String),
) -> Element(msg) {
  let class_name = case extra_class {
    Some(value) -> value
    None -> ""
  }

  icon_button(
    title,
    on_click,
    icon,
    ui_button.Neutral,
    size,
    False,
    class_name,
    None,
    testid,
  )
}

/// Creates a settings button with cog icon.
pub fn settings_button(title: String, on_click: msg) -> Element(msg) {
  icon_button(
    title,
    on_click,
    icons.Cog,
    ui_button.Neutral,
    SizeXs,
    False,
    "",
    None,
    None,
  )
}

/// Creates a settings button with a data-testid attribute.
pub fn settings_button_with_testid(
  title: String,
  on_click: msg,
  testid: String,
) -> Element(msg) {
  icon_button(
    title,
    on_click,
    icons.Cog,
    ui_button.Neutral,
    SizeXs,
    False,
    "",
    None,
    Some(testid),
  )
}

/// Creates a row of action buttons (commonly edit + delete).
pub fn edit_delete_row(
  edit_title edit_title: String,
  edit_click edit_click: msg,
  delete_title delete_title: String,
  delete_click delete_click: msg,
) -> Element(msg) {
  html.div([], [
    edit_button(edit_title, edit_click),
    delete_button(delete_title, delete_click),
  ])
}

/// Creates a row with edit, delete and data-testid attributes.
pub fn edit_delete_row_with_testid(
  edit_title edit_title: String,
  edit_click edit_click: msg,
  edit_testid edit_testid: String,
  delete_title delete_title: String,
  delete_click delete_click: msg,
  delete_testid delete_testid: String,
) -> Element(msg) {
  html.div([], [
    edit_button_with_testid(edit_title, edit_click, edit_testid),
    delete_button_with_testid(delete_title, delete_click, delete_testid),
  ])
}

/// Creates a button to add a new task to a specific card.
pub fn create_task_in_card_button(title: String, on_click: msg) -> Element(msg) {
  icon_button(
    title,
    on_click,
    icons.Plus,
    ui_button.Neutral,
    SizeXs,
    False,
    "btn-add-task",
    None,
    None,
  )
}

/// Creates a create-task-in-card button with custom size.
pub fn create_task_in_card_button_with_size(
  title: String,
  on_click: msg,
  size: ButtonSize,
) -> Element(msg) {
  add_button_with_size(title, on_click, size)
}
