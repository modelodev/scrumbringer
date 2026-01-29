//// Reusable dialog component for Scrumbringer.
////
//// ## Mission
////
//// Provides a consistent, accessible dialog/modal pattern for all admin
//// create/edit operations.
////
//// ## Usage
////
//// ```gleam
//// dialog.view(
////   DialogConfig(
////     title: "Create Capability",
////     icon: option.Some("🎯"),
////     size: DialogMd,
////     on_close: CapabilityCreateDialogClosed,
////   ),
////   model.admin.capabilities_create_dialog_open,
////   model.admin.capabilities_create_error,
////   [
////     // form fields...
////   ],
////   [
////     dialog.cancel_button(model, CapabilityCreateDialogClosed),
////     dialog.submit_button(model, is_loading, False, Create, Creating),
////   ],
//// )
//// ```

import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h3, span, text}
import lustre/event

import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/modal_close_button
import scrumbringer_client/update_helpers

// =============================================================================
// Types
// =============================================================================

/// Dialog size variants.
pub type DialogSize {
  DialogSm
  DialogMd
  DialogLg
  DialogXl
}

/// Dialog configuration.
pub type DialogConfig(msg) {
  DialogConfig(
    title: String,
    icon: Option(String),
    size: DialogSize,
    on_close: msg,
  )
}

// =============================================================================
// View Functions
// =============================================================================

/// Render a dialog when open.
pub fn view(
  config: DialogConfig(Msg),
  is_open: Bool,
  error: Option(String),
  content: List(Element(Msg)),
  footer: List(Element(Msg)),
) -> Element(Msg) {
  case is_open {
    False -> element.none()
    True -> view_dialog(config, error, content, footer)
  }
}

fn view_dialog(
  config: DialogConfig(Msg),
  error: Option(String),
  content: List(Element(Msg)),
  footer: List(Element(Msg)),
) -> Element(Msg) {
  let size_class = size_to_class(config.size)

  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog " <> size_class),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
        attribute.attribute("aria-labelledby", "dialog-title"),
      ],
      [
        // Header
        view_header(config),
        // Error banner
        view_error(error),
        // Body
        div([attribute.class("dialog-body")], content),
        // Footer
        div([attribute.class("dialog-footer")], footer),
      ],
    ),
  ])
}

fn view_header(config: DialogConfig(Msg)) -> Element(Msg) {
  div([attribute.class("dialog-header")], [
    div([attribute.class("dialog-title")], [
      case config.icon {
        Some(icon) -> span([attribute.class("dialog-icon")], [text(icon)])
        None -> element.none()
      },
      h3([attribute.id("dialog-title")], [text(config.title)]),
    ]),
    modal_close_button.view_with_class("btn-icon dialog-close", config.on_close),
  ])
}

fn view_error(error: Option(String)) -> Element(Msg) {
  case error {
    Some(msg) ->
      div(
        [
          attribute.class("dialog-error"),
          attribute.attribute("role", "alert"),
          attribute.attribute("aria-live", "assertive"),
        ],
        [
          span([attribute.attribute("aria-hidden", "true")], [text("\u{26A0}")]),
          text(" " <> msg),
        ],
      )
    None -> element.none()
  }
}

fn size_to_class(size: DialogSize) -> String {
  case size {
    DialogSm -> "dialog-sm"
    DialogMd -> "dialog-md"
    DialogLg -> "dialog-lg"
    DialogXl -> "dialog-xl"
  }
}

// =============================================================================
// Button Helpers
// =============================================================================

/// Create a cancel button for dialog footer.
pub fn cancel_button(model: Model, on_click: Msg) -> Element(Msg) {
  button([attribute.type_("button"), event.on_click(on_click)], [
    text(update_helpers.i18n_t(model, i18n_text.Cancel)),
  ])
}

/// Create a submit button for dialog footer.
pub fn submit_button(
  model: Model,
  is_loading: Bool,
  is_disabled: Bool,
  label: i18n_text.Text,
  loading_label: i18n_text.Text,
) -> Element(Msg) {
  button(
    [
      attribute.type_("submit"),
      attribute.disabled(is_loading || is_disabled),
      attribute.class(case is_loading {
        True -> "btn-loading"
        False -> ""
      }),
    ],
    [
      text(case is_loading {
        True -> update_helpers.i18n_t(model, loading_label)
        False -> update_helpers.i18n_t(model, label)
      }),
    ],
  )
}

/// Create an add button that opens a dialog.
pub fn add_button(
  model: Model,
  label: i18n_text.Text,
  on_click: Msg,
) -> Element(Msg) {
  button([attribute.class("btn-add"), event.on_click(on_click)], [
    text(update_helpers.i18n_t(model, label)),
  ])
}
