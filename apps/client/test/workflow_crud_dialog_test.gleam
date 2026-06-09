//// Tests for workflow_crud_dialog Lustre component.
////
//// Tests Model construction, Msg type constructors, and DialogMode type.

import gleam/option
import gleam/string
import lustre/element

import domain/workflow.{type Workflow, Workflow}
import scrumbringer_client/components/crud_dialog_base.{
  Closed, Creating, Deleting, Editing,
}
import scrumbringer_client/components/workflow_crud_dialog.{
  CloseRequested, CreateActiveToggled, CreateDescriptionChanged,
  CreateNameChanged, CreateSubmitted, DeleteCancelled, DeleteConfirmed,
  EditActiveToggled, EditCancelled, EditDescriptionChanged, EditNameChanged,
  EditSubmitted, LocaleReceived, ModeReceived, Model, ProjectIdReceived,
  view_create_dialog_for_test, view_edit_dialog_for_test,
}
import scrumbringer_client/i18n/locale.{En, Es}

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

// =============================================================================
// Model Tests
// =============================================================================

pub fn model_default_values_test() {
  let model =
    Model(
      locale: En,
      project_id: option.None,
      mode: Closed,
      create_name: "",
      create_description: "",
      create_active: True,
      create_in_flight: False,
      create_error: option.None,
      edit_name: "",
      edit_description: "",
      edit_active: True,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  let assert En = model.locale
  let assert option.None = model.project_id
  let assert Closed = model.mode
  let assert "" = model.create_name
  let assert True = model.create_active
  let assert False = model.create_in_flight
}

pub fn model_with_spanish_locale_test() {
  let model =
    Model(
      locale: Es,
      project_id: option.Some(42),
      mode: Creating,
      create_name: "Mi Automatización",
      create_description: "Descripción",
      create_active: True,
      create_in_flight: False,
      create_error: option.None,
      edit_name: "",
      edit_description: "",
      edit_active: True,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  let assert Es = model.locale
  let assert option.Some(42) = model.project_id
  let assert "Mi Automatización" = model.create_name
}

pub fn model_with_create_in_flight_test() {
  let model =
    Model(
      locale: En,
      project_id: option.None,
      mode: Creating,
      create_name: "Test Workflow",
      create_description: "",
      create_active: True,
      create_in_flight: True,
      create_error: option.None,
      edit_name: "",
      edit_description: "",
      edit_active: True,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  let assert True = model.create_in_flight
}

pub fn model_with_error_test() {
  let model =
    Model(
      locale: En,
      project_id: option.None,
      mode: Creating,
      create_name: "",
      create_description: "",
      create_active: True,
      create_in_flight: False,
      create_error: option.Some("Name is required"),
      edit_name: "",
      edit_description: "",
      edit_active: True,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  let assert option.Some("Name is required") = model.create_error
}

// =============================================================================
// DialogMode Type Tests
// =============================================================================

pub fn dialog_mode_create_test() {
  let mode = Creating
  assert_equal(mode, Creating)
}

pub fn dialog_mode_edit_test() {
  let workflow = make_test_workflow()
  let Editing(w) = Editing(workflow)
  let assert 1 = w.id
}

pub fn dialog_mode_delete_test() {
  let workflow = make_test_workflow()
  let Deleting(w) = Deleting(workflow)
  let assert "Test Workflow" = w.name
}

// =============================================================================
// Msg Type Tests
// =============================================================================

pub fn msg_locale_received_test() {
  let msg = LocaleReceived(Es)
  assert_equal(msg, LocaleReceived(Es))
}

pub fn msg_project_id_received_test() {
  let msg = ProjectIdReceived(option.Some(123))
  assert_equal(msg, ProjectIdReceived(option.Some(123)))
}

pub fn msg_project_id_received_none_test() {
  let msg = ProjectIdReceived(option.None)
  assert_equal(msg, ProjectIdReceived(option.None))
}

pub fn msg_mode_received_test() {
  let msg = ModeReceived(Creating)
  assert_equal(msg, ModeReceived(Creating))
}

pub fn msg_create_name_changed_test() {
  let msg = CreateNameChanged("New Workflow")
  assert_equal(msg, CreateNameChanged("New Workflow"))
}

pub fn msg_create_description_changed_test() {
  let msg = CreateDescriptionChanged("New Description")
  assert_equal(msg, CreateDescriptionChanged("New Description"))
}

pub fn msg_create_active_toggled_test() {
  let msg = CreateActiveToggled
  assert_equal(msg, CreateActiveToggled)
}

pub fn msg_create_submitted_test() {
  let msg = CreateSubmitted
  assert_equal(msg, CreateSubmitted)
}

pub fn msg_edit_name_changed_test() {
  let msg = EditNameChanged("Updated Name")
  assert_equal(msg, EditNameChanged("Updated Name"))
}

pub fn msg_edit_description_changed_test() {
  let msg = EditDescriptionChanged("Updated Description")
  assert_equal(msg, EditDescriptionChanged("Updated Description"))
}

pub fn msg_edit_active_toggled_test() {
  let msg = EditActiveToggled
  assert_equal(msg, EditActiveToggled)
}

pub fn msg_edit_submitted_test() {
  let msg = EditSubmitted
  assert_equal(msg, EditSubmitted)
}

pub fn msg_edit_cancelled_test() {
  let msg = EditCancelled
  assert_equal(msg, EditCancelled)
}

pub fn msg_delete_confirmed_test() {
  let msg = DeleteConfirmed
  assert_equal(msg, DeleteConfirmed)
}

pub fn msg_delete_cancelled_test() {
  let msg = DeleteCancelled
  assert_equal(msg, DeleteCancelled)
}

pub fn msg_close_requested_test() {
  let msg = CloseRequested
  assert_equal(msg, CloseRequested)
}

// =============================================================================
// View Tests
// =============================================================================

pub fn create_dialog_renders_shared_workflow_fields_test() {
  let html =
    view_create_dialog_for_test(En)
    |> element.to_document_string

  assert_contains(html, "workflow-create-form")
  assert_contains(html, "Create Workflow")
  assert_contains(html, "Workflow name")
  assert_contains(html, "Workflow description")
  assert_contains(html, "Active")
}

pub fn edit_dialog_renders_shared_workflow_fields_test() {
  let html =
    view_edit_dialog_for_test(En, make_test_workflow())
    |> element.to_document_string

  assert_contains(html, "workflow-edit-form")
  assert_contains(html, "Edit Workflow")
  assert_contains(html, "Test Workflow")
  assert_contains(html, "Test Description")
  assert_contains(html, "Active")
}

// =============================================================================
// Helpers
// =============================================================================

fn make_test_workflow() -> Workflow {
  Workflow(
    id: 1,
    org_id: 10,
    project_id: option.Some(100),
    name: "Test Workflow",
    description: option.Some("Test Description"),
    active: True,
    rule_count: 5,
    created_by: 1,
    created_at: "2026-01-20T00:00:00Z",
  )
}
