import gleam/option
import lustre/effect
import lustre/element
import lustre/element/html
import scrumbringer_client/components/crud_dialog_base.{
  EmptyRequiredText, required_text, submit_if_idle, view_cancel_button,
  view_cancel_button_with_class, view_danger_action_button,
  view_delete_dialog_shell, view_dialog_frame, view_dialog_shell,
  view_form_error, view_primary_action_button, view_submit_button,
  with_autofocus_when, with_optional_aria_label, with_optional_placeholder,
}
import scrumbringer_client/i18n/locale
import support/render_assertions

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

pub fn view_cancel_button_renders_localized_text_test() {
  let html =
    view_cancel_button(locale.Es, Nil)
    |> render_assertions.html

  render_assertions.contains(html, "Cancelar")
}

pub fn view_cancel_button_with_class_preserves_classes_test() {
  let html =
    view_cancel_button_with_class(locale.En, Nil, "dialog-cancel")
    |> render_assertions.html

  render_assertions.contains(html, "Cancel")
  render_assertions.contains(html, "btn-secondary")
  render_assertions.contains(html, "dialog-cancel")
}

pub fn view_form_error_renders_compact_error_block_test() {
  let html =
    view_form_error(option.Some("Missing name"))
    |> render_assertions.html

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
    |> render_assertions.html

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
    |> render_assertions.html

  render_assertions.not_contains(html, "aria-label")
  render_assertions.not_contains(html, "placeholder")
  render_assertions.not_contains(html, "autofocus")
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
    |> render_assertions.html

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
    |> render_assertions.html

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
    |> render_assertions.html

  render_assertions.contains(html, "form=\"form-id\"")
  render_assertions.contains(html, "disabled")
  render_assertions.contains(html, "btn-loading")
  render_assertions.contains(html, "Saving")
}

pub fn view_primary_action_button_renders_button_action_test() {
  let html =
    view_primary_action_button(Nil, True, "Create", "Creating", "btn-compact")
    |> render_assertions.html

  render_assertions.contains(html, "type=\"button\"")
  render_assertions.contains(html, "disabled")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-compact")
  render_assertions.contains(html, "Creating")
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
    |> render_assertions.html

  render_assertions.contains(html, "type=\"button\"")
  render_assertions.contains(html, "disabled")
  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "danger-extra")
  render_assertions.contains(html, "Delete")
}

pub fn view_delete_dialog_shell_renders_danger_footer_test() {
  let html =
    view_delete_dialog_shell(
      locale.En,
      "Delete",
      element.text("!"),
      "Delete this item?",
      option.Some("Boom"),
      True,
      Nil,
      Nil,
      "Removing",
    )
    |> render_assertions.html

  render_assertions.contains(html, "dialog dialog-sm")
  render_assertions.contains(html, "dialog-error")
  render_assertions.contains(html, "Delete this item?")
  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "btn-loading")
  render_assertions.contains(html, "Removing")
}
