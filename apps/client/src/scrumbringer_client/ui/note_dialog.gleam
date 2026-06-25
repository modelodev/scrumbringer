//// Reusable Note Dialog Component.
////
//// ## Mission
////
//// Provides a unified, accessible note creation dialog for use within modals
//// (Card Show, Task Show). Follows the Config(msg) pattern for flexibility.
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
////     close_label: "Close",
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
//// - **features/cards/show.gleam**: Uses this for card note creation
//// - **features/tasks/show/view.gleam**: Uses this for task note creation

import gleam/option.{type Option}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import scrumbringer_client/ui/button
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
    close_label: String,
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
    modal_close_button.view_with_label_and_class(
      config.close_label,
      "btn-icon",
      config.on_close,
    ),
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
    button.text(
      config.cancel_label,
      config.on_close,
      button.Secondary,
      button.EntityAction,
    )
    |> button.view,
  ])
}
