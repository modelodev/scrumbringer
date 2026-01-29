//// Reusable Note Dialog Component.
////
//// ## Mission
////
//// Provides a unified, accessible note creation dialog for use within modals
//// (card detail, task detail). Follows the Config(msg) pattern for flexibility.
////
//// ## Usage
////
//// ```gleam
//// note_dialog.view(
////   note_dialog.Config(
////     title: "Add Note",
////     content: model.note_content,
////     placeholder: "Write your note...",
////     error: model.note_error,
////     submit_label: "Add Note",
////     submit_disabled: model.note_in_flight || model.note_content == "",
////     cancel_label: "Cancel",
////     on_content_change: NoteContentChanged,
////     on_submit: NoteSubmitted,
////     on_close: NoteDialogClosed,
////   ),
//// )
//// ```
////
//// ## Relations
////
//// - **ui/notes_composer.gleam**: Reused for textarea with Ctrl+Enter support
//// - **components/card_detail_modal.gleam**: Uses this for card note creation
//// - **features/pool/dialogs.gleam**: Uses this for task note creation

import gleam/option.{type Option}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

import scrumbringer_client/ui/modal_close_button
import scrumbringer_client/ui/notes_composer

// =============================================================================
// Types
// =============================================================================

/// Configuration for the note dialog.
/// Generic over message type for flexibility across different contexts.
pub type Config(msg) {
  Config(
    title: String,
    content: String,
    placeholder: String,
    error: Option(String),
    submit_label: String,
    submit_disabled: Bool,
    cancel_label: String,
    on_content_change: fn(String) -> msg,
    on_submit: msg,
    on_close: msg,
  )
}

// =============================================================================
// View Functions
// =============================================================================

/// Render the note dialog overlay.
/// CSS class: `.note-dialog-overlay` uses `position: fixed` to overlay within
/// parent modal without clipping issues.
pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("note-dialog-overlay")], [
    div(
      [
        attribute.class("note-dialog"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
        attribute.attribute("aria-labelledby", "note-dialog-title"),
      ],
      [view_header(config), view_body(config), view_footer(config)],
    ),
  ])
}

/// Render the dialog header with title and close button.
fn view_header(config: Config(msg)) -> Element(msg) {
  div([attribute.class("note-dialog-header")], [
    span(
      [attribute.class("note-dialog-title"), attribute.id("note-dialog-title")],
      [text(config.title)],
    ),
    modal_close_button.view_with_class("btn-icon", config.on_close),
  ])
}

/// Render the dialog body with notes composer (textarea + submit button).
fn view_body(config: Config(msg)) -> Element(msg) {
  div([attribute.class("note-dialog-body")], [
    notes_composer.view(notes_composer.Config(
      content: config.content,
      placeholder: config.placeholder,
      submit_label: config.submit_label,
      submit_disabled: config.submit_disabled,
      error: config.error,
      on_content_change: config.on_content_change,
      on_submit: config.on_submit,
      show_button: True,
    )),
  ])
}

/// Render the dialog footer with cancel button.
fn view_footer(config: Config(msg)) -> Element(msg) {
  div([attribute.class("note-dialog-footer")], [
    button(
      [
        attribute.class("btn btn-secondary"),
        attribute.type_("button"),
        event.on_click(config.on_close),
      ],
      [text(config.cancel_label)],
    ),
  ])
}
