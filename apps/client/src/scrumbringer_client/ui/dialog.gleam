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

import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h3, span, text}
import lustre/event

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
        ..escape_close_attributes(config.on_close)
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

fn escape_close_attributes(on_close: msg) -> List(attribute.Attribute(msg)) {
  [
    attribute.attribute("aria-keyshortcuts", "Escape"),
    attribute.attribute("tabindex", "-1"),
    on_escape(on_close),
  ]
}

fn on_escape(on_close: msg) -> attribute.Attribute(msg) {
  event.advanced("keydown", {
    use key <- decode.field("key", decode.string)

    case key {
      "Escape" ->
        decode.success(event.handler(
          on_close,
          prevent_default: True,
          stop_propagation: True,
        ))
      _ ->
        decode.failure(
          event.handler(
            on_close,
            prevent_default: False,
            stop_propagation: False,
          ),
          expected: "escape",
        )
    }
  })
}

fn panel_base_attributes(title_id: String) -> List(attribute.Attribute(msg)) {
  [
    attribute.attribute("role", "dialog"),
    attribute.attribute("aria-modal", "true"),
    attribute.attribute("aria-labelledby", title_id),
  ]
}

/// Attributes for feature-local panels that close through the application
/// shortcut layer instead of a local keydown handler.
pub fn passive_panel_attributes(
  title_id: String,
) -> List(attribute.Attribute(msg)) {
  panel_base_attributes(title_id)
}

/// Attributes for feature-local panels that use a visible heading as their label
/// and own their Escape close behavior.
pub fn panel_attributes(
  title_id: String,
  on_close: msg,
) -> List(attribute.Attribute(msg)) {
  list.append(
    panel_base_attributes(title_id),
    escape_close_attributes(on_close),
  )
}

/// Attributes for a visible panel heading used as the dialog label.
pub fn panel_title_attributes(
  title_id: String,
) -> List(attribute.Attribute(msg)) {
  [attribute.id(title_id)]
}

/// Attributes for a panel heading that is also the initial focus target.
pub fn focused_panel_title_attributes(
  title_id: String,
) -> List(attribute.Attribute(msg)) {
  [
    attribute.id(title_id),
    attribute.attribute("tabindex", "-1"),
    attribute.autofocus(True),
  ]
}

/// Attributes for the feature content behind an open panel.
pub fn panel_background_attributes(
  is_panel_open: Bool,
) -> List(attribute.Attribute(msg)) {
  case is_panel_open {
    True -> [
      attribute.inert(True),
      attribute.attribute("aria-hidden", "true"),
    ]
    False -> []
  }
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
  submit_button(locale, is_loading, is_disabled, label, loading_label)
  |> ui_button.view
}

/// Create a submit button targeting an external form.
pub fn submit_button_with_locale_form(
  locale: Locale,
  form_id: String,
  is_loading: Bool,
  is_disabled: Bool,
  label: i18n_text.Text,
  loading_label: i18n_text.Text,
) -> Element(msg) {
  submit_button(locale, is_loading, is_disabled, label, loading_label)
  |> ui_button.with_form(form_id)
  |> ui_button.view
}

/// Create a submit-like action button for forms handled by message.
pub fn submit_button_with_locale_click(
  locale: Locale,
  on_click: msg,
  is_loading: Bool,
  is_disabled: Bool,
  label: i18n_text.Text,
  loading_label: i18n_text.Text,
) -> Element(msg) {
  ui_button.text(
    submit_label(locale, is_loading, label, loading_label),
    on_click,
    ui_button.Primary,
    ui_button.EntityAction,
  )
  |> ui_button.with_disabled(is_loading || is_disabled)
  |> with_loading_class(is_loading)
  |> ui_button.view
}

fn submit_button(
  locale: Locale,
  is_loading: Bool,
  is_disabled: Bool,
  label: i18n_text.Text,
  loading_label: i18n_text.Text,
) -> ui_button.Config(msg) {
  ui_button.submit(
    submit_label(locale, is_loading, label, loading_label),
    ui_button.Primary,
    ui_button.EntityAction,
  )
  |> ui_button.with_disabled(is_loading || is_disabled)
  |> with_loading_class(is_loading)
}

fn submit_label(
  locale: Locale,
  is_loading: Bool,
  label: i18n_text.Text,
  loading_label: i18n_text.Text,
) -> String {
  case is_loading {
    True -> i18n.t(locale, loading_label)
    False -> i18n.t(locale, label)
  }
}

fn with_loading_class(
  button: ui_button.Config(msg),
  is_loading: Bool,
) -> ui_button.Config(msg) {
  case is_loading {
    True -> button |> ui_button.with_class("btn-loading")
    False -> button
  }
}

/// Create an add button that opens a dialog using an explicit locale.
pub fn add_button_with_locale(
  locale: Locale,
  label: i18n_text.Text,
  on_click: msg,
) -> Element(msg) {
  add_button(locale, label, on_click)
  |> ui_button.view
}

/// Create an add button with a stable HTML id.
pub fn add_button_with_locale_and_id(
  locale: Locale,
  label: i18n_text.Text,
  on_click: msg,
  id: String,
) -> Element(msg) {
  add_button(locale, label, on_click)
  |> ui_button.with_id(id)
  |> ui_button.view
}

fn add_button(
  locale: Locale,
  label: i18n_text.Text,
  on_click: msg,
) -> ui_button.Config(msg) {
  ui_button.text(
    i18n.t(locale, label),
    on_click,
    ui_button.Primary,
    ui_button.GlobalAction,
  )
  |> ui_button.with_class("btn-add")
}
