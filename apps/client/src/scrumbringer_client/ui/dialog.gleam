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
////     icon: option.Some(icons.nav_icon(icons.Target, icons.Small)),
////     size: DialogMd,
////     on_close: CapabilityCreateDialogClosed,
////   ),
////   model.admin.capabilities.capabilities_dialog_mode == dialog_mode.DialogCreate,
////   model.admin.capabilities.capabilities_create_error,
////   [
////     // form fields...
////   ],
////   [
////     dialog.cancel_button_with_locale(locale, CapabilityCreateDialogClosed),
////     dialog.submit_button_with_locale(locale, is_loading, False, Create, Creating),
////   ],
//// )
//// ```

import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h3, span, text}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/modal_close_button

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
    icon: Option(Element(msg)),
    size: DialogSize,
    on_close: msg,
  )
}

// =============================================================================
// View Functions
// =============================================================================

/// Render a dialog when open.
pub fn view(
  config: DialogConfig(msg),
  is_open: Bool,
  error: Option(String),
  content: List(Element(msg)),
  footer: List(Element(msg)),
) -> Element(msg) {
  view_with_close_label(config, "Close", is_open, error, content, footer)
}

/// Render a dialog when open with a localized accessible close label.
pub fn view_with_close_label(
  config: DialogConfig(msg),
  close_label: String,
  is_open: Bool,
  error: Option(String),
  content: List(Element(msg)),
  footer: List(Element(msg)),
) -> Element(msg) {
  case is_open {
    False -> element.none()
    True -> view_dialog(config, close_label, error, content, footer)
  }
}

fn view_dialog(
  config: DialogConfig(msg),
  close_label: String,
  error: Option(String),
  content: List(Element(msg)),
  footer: List(Element(msg)),
) -> Element(msg) {
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
        view_header(config, close_label),
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

fn view_header(config: DialogConfig(msg), close_label: String) -> Element(msg) {
  div([attribute.class("dialog-header")], [
    div([attribute.class("dialog-title")], [
      case config.icon {
        Some(icon) -> span([attribute.class("dialog-icon")], [icon])
        None -> element.none()
      },
      h3([attribute.id("dialog-title")], [text(config.title)]),
    ]),
    modal_close_button.view_with_label_and_class(
      close_label,
      "btn-icon dialog-close",
      config.on_close,
    ),
  ])
}

fn view_error(error: Option(String)) -> Element(msg) {
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

/// Create a cancel button for dialog footer using an explicit locale.
pub fn cancel_button_with_locale(locale: Locale, on_click: msg) -> Element(msg) {
  ui_button.text(
    i18n.t(locale, i18n_text.Cancel),
    on_click,
    ui_button.Secondary,
    ui_button.EntityAction,
  )
  |> ui_button.view
}

/// Create a submit button for dialog footer using an explicit locale.
pub fn submit_button_with_locale(
  locale: Locale,
  is_loading: Bool,
  is_disabled: Bool,
  label: i18n_text.Text,
  loading_label: i18n_text.Text,
) -> Element(msg) {
  submit_button_with_locale_attrs(
    locale,
    [],
    is_loading,
    is_disabled,
    label,
    loading_label,
  )
}

/// Create a submit button with explicit locale and additional attributes.
pub fn submit_button_with_locale_attrs(
  locale: Locale,
  extra_attrs: List(attribute.Attribute(msg)),
  is_loading: Bool,
  is_disabled: Bool,
  label: i18n_text.Text,
  loading_label: i18n_text.Text,
) -> Element(msg) {
  button(
    list.append(
      [
        attribute.type_("submit"),
        attribute.disabled(is_loading || is_disabled),
        attribute.class(case is_loading {
          True -> "btn-loading"
          False -> ""
        }),
      ],
      extra_attrs,
    ),
    [
      text(case is_loading {
        True -> i18n.t(locale, loading_label)
        False -> i18n.t(locale, label)
      }),
    ],
  )
}

/// Create an add button that opens a dialog using an explicit locale.
pub fn add_button_with_locale(
  locale: Locale,
  label: i18n_text.Text,
  on_click: msg,
) -> Element(msg) {
  ui_button.text(
    i18n.t(locale, label),
    on_click,
    ui_button.Primary,
    ui_button.GlobalAction,
  )
  |> ui_button.with_class("btn-add")
  |> ui_button.view
}
