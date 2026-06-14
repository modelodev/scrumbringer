//// Shared helpers for CRUD dialog custom elements.
////
//// Centralizes common attribute decoding and small utilities.

import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, div, p, span, text}
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/modal_header

pub type OptionalIntParseError {
  InvalidOptionalInt(String)
}

pub type RequiredTextError {
  EmptyRequiredText
}

pub type DialogLifecycle(entity) {
  Closed
  Creating
  Editing(entity)
  Deleting(entity)
}

/// Converts optional text fields into form input values.
pub fn optional_text_input_value(value: Option(String)) -> String {
  case value {
    option.None -> ""
    option.Some(text) -> text
  }
}

/// Parses required text fields, returning the trimmed value.
pub fn required_text(value: String) -> Result(String, RequiredTextError) {
  case string.trim(value) {
    "" -> Error(EmptyRequiredText)
    trimmed -> Ok(trimmed)
  }
}

/// Runs a submit transition only when its request is not already in flight.
pub fn submit_if_idle(
  model: model,
  in_flight: Bool,
  submit: fn(model) -> #(model, Effect(msg)),
) -> #(model, Effect(msg)) {
  case in_flight {
    True -> #(model, effect.none())
    False -> submit(model)
  }
}

/// Decodes locale.
///
/// Example:
///   decode_locale(...)
pub fn decode_locale(
  value: String,
  to_msg: fn(Locale) -> msg,
) -> Result(msg, Nil) {
  locale.parse(value)
  |> result.map(to_msg)
  |> result.replace_error(Nil)
}

/// Decodes int attribute.
///
/// Example:
///   decode_int_attribute(...)
pub fn decode_int_attribute(
  value: String,
  to_msg: fn(Int) -> msg,
) -> Result(msg, Nil) {
  int.parse(value)
  |> result.map(to_msg)
  |> result.replace_error(Nil)
}

/// Decodes optional int attribute.
///
/// Example:
///   decode_optional_int_attribute(...)
pub fn decode_optional_int_attribute(
  value: String,
  to_msg: fn(Option(Int)) -> msg,
) -> Result(msg, Nil) {
  parse_optional_int(value)
  |> result.map(to_msg)
  |> result.replace_error(Nil)
}

/// Parses optional integer form/select values.
pub fn parse_optional_int(
  value: String,
) -> Result(Option(Int), OptionalIntParseError) {
  case value {
    "" | "null" | "undefined" -> Ok(option.None)
    _ ->
      case int.parse(value) {
        Ok(id) -> Ok(option.Some(id))
        Error(_) -> Error(InvalidOptionalInt(value))
      }
  }
}

/// Parses optional integer form/select values, preserving the current tolerant
/// DOM-event behaviour for components that do final validation on submit.
pub fn optional_int_or_none(value: String) -> Option(Int) {
  case parse_optional_int(value) {
    Ok(parsed) -> parsed
    Error(_) -> option.None
  }
}

/// Renders a localized cancel button for CRUD dialog footers.
pub fn view_cancel_button(locale: Locale, on_click_msg: msg) -> Element(msg) {
  button([attribute.type_("button"), event.on_click(on_click_msg)], [
    text(i18n.t(locale, i18n_text.Cancel)),
  ])
}

/// Renders a localized cancel button with dialog-specific classes.
pub fn view_cancel_button_with_class(
  locale: Locale,
  on_click_msg: msg,
  class_name: String,
) -> Element(msg) {
  button(
    [
      attribute.class(class_name),
      attribute.type_("button"),
      event.on_click(on_click_msg),
    ],
    [text(i18n.t(locale, i18n_text.Cancel))],
  )
}

/// Renders the standard CRUD dialog error block.
pub fn view_dialog_error(error: Option(String)) -> Element(msg) {
  case error {
    option.Some(message) ->
      div([attribute.class("dialog-error")], [
        span([], [text("\u{26A0}")]),
        text(" " <> message),
      ])

    option.None -> element.none()
  }
}

/// Renders the compact form-level error used by tighter CRUD dialogs.
pub fn view_form_error(error: Option(String)) -> Element(msg) {
  case error {
    option.Some(message) ->
      div([attribute.class("form-error")], [text(message)])

    option.None -> element.none()
  }
}

/// Renders the repeated CRUD dialog overlay, ARIA shell and footer while
/// leaving body structure domain-specific.
pub fn view_dialog_frame(
  class_name: String,
  header: Element(msg),
  body: List(Element(msg)),
  footer: List(Element(msg)),
) -> Element(msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class(class_name),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [header, ..body]
        |> list.append([
          div([attribute.class("dialog-footer")], footer),
        ]),
    ),
  ])
}

/// Renders the repeated CRUD dialog overlay, shell, error, body and footer
/// structure while leaving headers, fields and actions domain-specific.
pub fn view_dialog_shell(
  class_name: String,
  header: Element(msg),
  error: Option(String),
  body: List(Element(msg)),
  footer: List(Element(msg)),
) -> Element(msg) {
  view_dialog_frame(
    class_name,
    header,
    [
      view_dialog_error(error),
      div([attribute.class("dialog-body")], body),
    ],
    footer,
  )
}

/// Renders the standard submit button used by CRUD create/edit forms.
pub fn view_submit_button(
  form_id: String,
  in_flight: Bool,
  idle_label: String,
  in_flight_label: String,
) -> Element(msg) {
  button(
    [
      attribute.type_("submit"),
      attribute.form(form_id),
      attribute.disabled(in_flight),
      attribute.class(case in_flight {
        True -> "btn-loading"
        False -> ""
      }),
    ],
    [
      text(case in_flight {
        True -> in_flight_label
        False -> idle_label
      }),
    ],
  )
}

/// Renders a button-based primary CRUD action for forms that submit by message.
pub fn view_primary_action_button(
  on_click_msg: msg,
  in_flight: Bool,
  idle_label: String,
  in_flight_label: String,
  class_name: String,
) -> Element(msg) {
  button(
    [
      attribute.class(class_name),
      attribute.type_("button"),
      attribute.disabled(in_flight),
      event.on_click(on_click_msg),
    ],
    [
      text(case in_flight {
        True -> in_flight_label
        False -> idle_label
      }),
    ],
  )
}

/// Renders the standard danger action button used by CRUD delete dialogs.
pub fn view_danger_button(
  on_click_msg: msg,
  in_flight: Bool,
  idle_label: String,
  in_flight_label: String,
) -> Element(msg) {
  button(
    [
      event.on_click(on_click_msg),
      attribute.disabled(in_flight),
      attribute.class("btn-danger"),
    ],
    [
      text(case in_flight {
        True -> in_flight_label
        False -> idle_label
      }),
    ],
  )
}

/// Renders the common small delete confirmation dialog used by CRUD custom
/// elements that do not need domain-specific delete guards.
pub fn view_delete_dialog_shell(
  locale: Locale,
  title: String,
  icon: Element(msg),
  confirm_text: String,
  error: Option(String),
  in_flight: Bool,
  on_cancel: msg,
  on_confirm: msg,
  in_flight_label: String,
) -> Element(msg) {
  view_dialog_shell(
    "dialog dialog-sm",
    modal_header.view_dialog_with_icon_and_close_label(
      title,
      icon,
      on_cancel,
      i18n.t(locale, i18n_text.Close),
    ),
    error,
    [p([], [text(confirm_text)])],
    [
      view_cancel_button(locale, on_cancel),
      view_danger_button(on_confirm, in_flight, title, in_flight_label),
    ],
  )
}

/// Renders a danger CRUD action with dialog-specific class and extra guards.
pub fn view_danger_action_button(
  on_click_msg: msg,
  in_flight: Bool,
  disabled: Bool,
  idle_label: String,
  in_flight_label: String,
  class_name: String,
) -> Element(msg) {
  button(
    [
      attribute.class(class_name),
      attribute.type_("button"),
      attribute.disabled(disabled),
      event.on_click(on_click_msg),
    ],
    [
      text(case in_flight {
        True -> in_flight_label
        False -> idle_label
      }),
    ],
  )
}

/// Decodes create mode.
///
/// Example:
///   decode_create_mode(...)
pub fn decode_create_mode(
  value: String,
  create_mode: mode,
  to_msg: fn(mode) -> msg,
) -> Result(msg, Nil) {
  case value {
    "create" -> Ok(to_msg(create_mode))
    _ -> Error(Nil)
  }
}

/// Decodes the `_mode` property for entity-backed edit/delete dialogs.
pub fn decode_entity_mode(
  value: String,
  entity: entity,
  edit_mode: fn(entity) -> mode,
  delete_mode: fn(entity) -> mode,
  to_msg: fn(mode) -> msg,
) -> decode.Decoder(msg) {
  case value {
    "delete" -> decode.success(to_msg(delete_mode(entity)))
    _ -> decode.success(to_msg(edit_mode(entity)))
  }
}
