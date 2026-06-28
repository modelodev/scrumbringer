import gleam/option
import gleam/string
import lustre/effect
import lustre/element
import lustre/element/html
import scrumbringer_client/components/crud_dialog_base.{
  EmptyRequiredText, InvalidOptionalInt, optional_int_or_none,
  optional_text_input_value, parse_optional_int, prepend_fields, required_text,
  submit_if_idle, view_cancel_button, view_cancel_button_with_class,
  view_danger_action_button, view_danger_button, view_dialog_error,
  view_dialog_frame, view_dialog_shell, view_form_error,
  view_primary_action_button, view_submit_button, with_autofocus_when,
  with_optional_aria_label, with_optional_placeholder,
}
import scrumbringer_client/i18n/locale
import support/render_assertions

pub fn optional_text_input_value_uses_empty_input_for_absent_text_test() {
  let assert "" = optional_text_input_value(option.None)
}

pub fn optional_text_input_value_preserves_present_text_test() {
  let assert "done" = optional_text_input_value(option.Some("done"))
}

pub fn prepend_fields_preserves_existing_payload_merge_order_test() {
  let assert [#("extra_b", 2), #("extra_a", 1), #("base", 0)] =
    prepend_fields([#("base", 0)], [#("extra_a", 1), #("extra_b", 2)])
}

pub fn required_text_trims_valid_input_test() {
  let assert Ok("Name") = required_text("  Name  ")
}

pub fn required_text_rejects_blank_input_test() {
  let assert Error(EmptyRequiredText) = required_text("   ")
}

pub fn submit_if_idle_blocks_duplicate_submit_test() {
  let #(next, _) =
    submit_if_idle(1, True, fn(value) { #(value + 1, effect.none()) })

  let assert 1 = next
}

pub fn submit_if_idle_runs_submit_when_idle_test() {
  let #(next, _) =
    submit_if_idle(1, False, fn(value) { #(value + 1, effect.none()) })

  let assert 2 = next
}

pub fn parse_optional_int_accepts_empty_values_test() {
  let assert Ok(option.None) = parse_optional_int("")
  let assert Ok(option.None) = parse_optional_int("null")
  let assert Ok(option.None) = parse_optional_int("undefined")
}

pub fn parse_optional_int_accepts_integer_test() {
  let assert Ok(option.Some(42)) = parse_optional_int("42")
}

pub fn parse_optional_int_rejects_invalid_integer_test() {
  let assert Error(InvalidOptionalInt("bad")) = parse_optional_int("bad")
}

pub fn optional_int_or_none_keeps_tolerant_dom_event_fallback_test() {
  let assert option.Some(7) = optional_int_or_none("7")
  let assert option.None = optional_int_or_none("bad")
}

pub fn view_cancel_button_renders_localized_text_test() {
  let html =
    view_cancel_button(locale.Es, Nil)
    |> element.to_document_string

  render_assertions.contains(html, "Cancelar")
}

pub fn view_cancel_button_with_class_preserves_classes_test() {
  let html =
    view_cancel_button_with_class(locale.En, Nil, "dialog-cancel")
    |> element.to_document_string

  render_assertions.contains(html, "Cancel")
  render_assertions.contains(html, "btn-secondary")
  render_assertions.contains(html, "dialog-cancel")
}

pub fn view_dialog_error_renders_standard_error_block_test() {
  let html =
    view_dialog_error(option.Some("Boom"))
    |> element.to_document_string

  render_assertions.contains(html, "dialog-error")
  render_assertions.contains(html, "Boom")
}

pub fn view_form_error_renders_compact_error_block_test() {
  let html =
    view_form_error(option.Some("Missing name"))
    |> element.to_document_string

  render_assertions.contains(html, "form-error")
  render_assertions.contains(html, "Missing name")
}

pub fn optional_field_attributes_are_added_only_when_present_test() {
  let html =
    html.input(
      []
      |> with_optional_aria_label(option.Some("Visible label"))
      |> with_optional_placeholder(option.Some("Type here"))
      |> with_autofocus_when(True),
    )
    |> element.to_document_string

  render_assertions.contains(html, "aria-label=\"Visible label\"")
  render_assertions.contains(html, "placeholder=\"Type here\"")
  render_assertions.contains(html, "autofocus")
}

pub fn optional_field_attributes_are_omitted_when_absent_test() {
  let html =
    html.input(
      []
      |> with_optional_aria_label(option.None)
      |> with_optional_placeholder(option.None)
      |> with_autofocus_when(False),
    )
    |> element.to_document_string

  let assert False = string.contains(html, "aria-label")
  let assert False = string.contains(html, "placeholder")
  let assert False = string.contains(html, "autofocus")
}

pub fn view_dialog_shell_renders_standard_structure_test() {
  let html =
    view_dialog_shell(
      "dialog dialog-md",
      element.text("Header"),
      option.Some("Boom"),
      [element.text("Body")],
      [element.text("Footer")],
    )
    |> element.to_document_string

  render_assertions.contains(html, "dialog-overlay")
  render_assertions.contains(html, "dialog dialog-md")
  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.contains(html, "dialog-error")
  render_assertions.contains(html, "Header")
  render_assertions.contains(html, "Body")
  render_assertions.contains(html, "Footer")
}

pub fn view_dialog_frame_preserves_custom_body_structure_test() {
  let html =
    view_dialog_frame(
      "dialog dialog-lg dialog-lg-tight",
      element.text("Header"),
      [element.text("Custom body")],
      [element.text("Footer")],
    )
    |> element.to_document_string

  render_assertions.contains(html, "dialog-overlay")
  render_assertions.contains(html, "dialog dialog-lg dialog-lg-tight")
  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.contains(html, "Custom body")
  render_assertions.contains(html, "dialog-footer")
}

pub fn view_submit_button_renders_form_and_loading_state_test() {
  let html =
    view_submit_button("form-id", True, "Save", "Saving")
    |> element.to_document_string

  render_assertions.contains(html, "form=\"form-id\"")
  render_assertions.contains(html, "disabled")
  render_assertions.contains(html, "btn-loading")
  render_assertions.contains(html, "Saving")
}

pub fn view_primary_action_button_renders_button_action_test() {
  let html =
    view_primary_action_button(Nil, True, "Create", "Creating", "btn-compact")
    |> element.to_document_string

  render_assertions.contains(html, "type=\"button\"")
  render_assertions.contains(html, "disabled")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-compact")
  render_assertions.contains(html, "Creating")
}

pub fn view_danger_button_renders_danger_class_and_loading_label_test() {
  let html =
    view_danger_button(Nil, True, "Delete", "Removing")
    |> element.to_document_string

  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "disabled")
  render_assertions.contains(html, "Removing")
}

pub fn view_danger_action_button_renders_extra_disabled_state_test() {
  let html =
    view_danger_action_button(
      Nil,
      False,
      True,
      "Delete",
      "Deleting",
      "danger-extra",
    )
    |> element.to_document_string

  render_assertions.contains(html, "type=\"button\"")
  render_assertions.contains(html, "disabled")
  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "danger-extra")
  render_assertions.contains(html, "Delete")
}
