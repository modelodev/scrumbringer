//// Action Button Components for consistent UI across Scrumbringer.
////
//// ## Mission
////
//// Provide type-safe, consistently styled action buttons (edit, delete, etc.)
//// that ensure visual homogeneity across all views.
////
//// ## Pattern
////
//// All action buttons follow the same visual pattern:
//// - Icon-only buttons with hover effects
//// - Edit: neutral icon, primary hover
//// - Delete: red icon, red hover background
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/ui/action_buttons
////
//// // In a table row
//// div([], [
////   action_buttons.edit_button("Edit item", EditClicked(item.id)),
////   action_buttons.delete_button("Delete item", DeleteClicked(item.id)),
//// ])
//// ```
////
//// ## Responsibilities
////
//// - Consistent button styling across all CRUD views
//// - Type-safe button generation
//// - Accessibility (title, aria-label)
////
//// ## Non-responsibilities
////
//// - Click handlers (passed as parameter)
//// - Confirmation dialogs (handled by caller)

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button}
import lustre/event

import scrumbringer_client/ui/icons

// =============================================================================
// Action Button Types
// =============================================================================

/// Size variants for action buttons.
pub type ButtonSize {
  /// Extra small (for table rows)
  SizeXs
  /// Small (for cards)
  SizeSm
}

// =============================================================================
// Task Action Buttons
// =============================================================================

/// Generic icon-only task action button.
///
/// Use this for claim/release/complete/pause actions to keep styling consistent.
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
  let size_class = case size {
    SizeXs -> "btn-xs"
    SizeSm -> "btn-sm"
  }

  let class = case string.is_empty(extra_class) {
    True -> "btn-icon " <> size_class
    False -> "btn-icon " <> size_class <> " " <> extra_class
  }

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

  button(attrs_with_testid, [icons.nav_icon(icon, icons.Small)])
}

/// Generic task action button with full class control.
///
/// Use this when the view uses a non-standard class (e.g. mobile/kanban).
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

// =============================================================================
// Edit Button
// =============================================================================

/// Creates an edit button with pencil icon.
///
/// Uses neutral styling that highlights on hover.
///
/// ## Example
/// ```gleam
/// action_buttons.edit_button("Edit task type", OpenEditDialog(item))
/// ```
pub fn edit_button(title: String, on_click: msg) -> Element(msg) {
  edit_button_with_size(title, on_click, SizeXs)
}

/// Creates an edit button with custom size.
pub fn edit_button_with_size(
  title: String,
  on_click: msg,
  size: ButtonSize,
) -> Element(msg) {
  let size_class = case size {
    SizeXs -> "btn-xs"
    SizeSm -> "btn-sm"
  }

  button(
    [
      attribute.class("btn-icon " <> size_class),
      attribute.attribute("title", title),
      attribute.attribute("aria-label", title),
      event.on_click(on_click),
    ],
    [icons.nav_icon(icons.Pencil, icons.Small)],
  )
}

/// Creates an edit button with a data-testid attribute.
pub fn edit_button_with_testid(
  title: String,
  on_click: msg,
  testid: String,
) -> Element(msg) {
  button(
    [
      attribute.class("btn-icon btn-xs"),
      attribute.attribute("title", title),
      attribute.attribute("aria-label", title),
      attribute.attribute("data-testid", testid),
      event.on_click(on_click),
    ],
    [icons.nav_icon(icons.Pencil, icons.Small)],
  )
}

// =============================================================================
// Delete Button
// =============================================================================

/// Creates a delete button with trash icon.
///
/// Uses danger styling: red icon, red hover background.
/// This is the standard pattern for all delete buttons in the app.
///
/// ## Example
/// ```gleam
/// action_buttons.delete_button("Delete task type", OpenDeleteDialog(item))
/// ```
pub fn delete_button(title: String, on_click: msg) -> Element(msg) {
  delete_button_with_size(title, on_click, SizeXs)
}

/// Creates a delete button with custom size.
pub fn delete_button_with_size(
  title: String,
  on_click: msg,
  size: ButtonSize,
) -> Element(msg) {
  let size_class = case size {
    SizeXs -> "btn-xs"
    SizeSm -> "btn-sm"
  }

  button(
    [
      // btn-danger-icon: red icon color, transparent bg, red bg on hover
      attribute.class("btn-icon " <> size_class <> " btn-danger-icon"),
      attribute.attribute("title", title),
      attribute.attribute("aria-label", title),
      event.on_click(on_click),
    ],
    [icons.nav_icon(icons.Trash, icons.Small)],
  )
}

/// Creates a delete button with a data-testid attribute.
pub fn delete_button_with_testid(
  title: String,
  on_click: msg,
  testid: String,
) -> Element(msg) {
  button(
    [
      attribute.class("btn-icon btn-xs btn-danger-icon"),
      attribute.attribute("title", title),
      attribute.attribute("aria-label", title),
      attribute.attribute("data-testid", testid),
      event.on_click(on_click),
    ],
    [icons.nav_icon(icons.Trash, icons.Small)],
  )
}

// =============================================================================
// Settings/Config Button
// =============================================================================

/// Creates a settings button with cog icon.
///
/// Used for configuration actions (e.g., member capabilities).
pub fn settings_button(title: String, on_click: msg) -> Element(msg) {
  button(
    [
      attribute.class("btn-icon btn-xs"),
      attribute.attribute("title", title),
      attribute.attribute("aria-label", title),
      event.on_click(on_click),
    ],
    [icons.nav_icon(icons.Cog, icons.Small)],
  )
}

// =============================================================================
// Action Button Row (for table cells)
// =============================================================================

/// Creates a row of action buttons (commonly edit + delete).
///
/// This is the standard pattern for table action columns.
///
/// ## Example
/// ```gleam
/// action_buttons.edit_delete_row(
///   edit_title: "Edit task type",
///   edit_click: OpenEditDialog(item),
///   delete_title: "Delete task type",
///   delete_click: OpenDeleteDialog(item),
/// )
/// ```
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

// =============================================================================
// Create Task in Card Button (Story 4.12 AC8-AC9-AC16)
// =============================================================================

/// Creates a button to add a new task to a specific card.
///
/// Used in card views (config/cards table, kanban) to quickly create
/// a task pre-assigned to that card.
///
/// ## Example
/// ```gleam
/// action_buttons.create_task_in_card_button(
///   "Nueva tarea en Release",
///   OpenCreateDialogWithCard(card_id),
/// )
/// ```
pub fn create_task_in_card_button(title: String, on_click: msg) -> Element(msg) {
  button(
    [
      attribute.class("btn-icon btn-xs btn-add-task"),
      attribute.attribute("title", title),
      attribute.attribute("aria-label", title),
      event.on_click(on_click),
    ],
    [icons.nav_icon(icons.Plus, icons.Small)],
  )
}

/// Creates a create-task-in-card button with custom size.
pub fn create_task_in_card_button_with_size(
  title: String,
  on_click: msg,
  size: ButtonSize,
) -> Element(msg) {
  let size_class = case size {
    SizeXs -> "btn-xs"
    SizeSm -> "btn-sm"
  }

  button(
    [
      attribute.class("btn-icon " <> size_class <> " btn-add-task"),
      attribute.attribute("title", title),
      attribute.attribute("aria-label", title),
      event.on_click(on_click),
    ],
    [icons.nav_icon(icons.Plus, icons.Small)],
  )
}
