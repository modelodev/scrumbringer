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
