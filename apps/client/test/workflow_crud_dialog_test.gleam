//// Tests for workflow_crud_dialog Lustre component.
////
//// Tests Model construction, Msg type constructors, and DialogMode type.

import gleeunit/should

import scrumbringer_client/components/workflow_crud_dialog.{
  CloseRequested, CreateActiveToggled, CreateDescriptionChanged,
  CreateNameChanged, CreateSubmitted, DeleteCancelled, DeleteConfirmed,
  EditActiveToggled, EditCancelled, EditDescriptionChanged, EditNameChanged,
  EditSubmitted, LocaleReceived, ModeCreate, ModeDelete, ModeEdit, Model,
  ModeReceived, ProjectIdReceived,
}
import scrumbringer_client/i18n/locale.{En, Es}
import gleam/option

// =============================================================================
// Model Tests
// =============================================================================

pub fn model_default_values_test() {
  let model =
    Model(
      locale: En,
      project_id: option.None,
      mode: option.None,
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

  model.locale |> should.equal(En)
  model.project_id |> should.equal(option.None)
  model.mode |> should.equal(option.None)
  model.create_name |> should.equal("")
  model.create_active |> should.equal(True)
  model.create_in_flight |> should.equal(False)
}

pub fn model_with_spanish_locale_test() {
  let model =
    Model(
      locale: Es,
      project_id: option.Some(42),
      mode: option.Some(ModeCreate),
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

  model.locale |> should.equal(Es)
  model.project_id |> should.equal(option.Some(42))
  model.create_name |> should.equal("Mi Automatización")
}

pub fn model_with_create_in_flight_test() {
  let model =
    Model(
      locale: En,
      project_id: option.None,
      mode: option.Some(ModeCreate),
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

  model.create_in_flight |> should.equal(True)
}

pub fn model_with_error_test() {
  let model =
    Model(
      locale: En,
      project_id: option.None,
      mode: option.Some(ModeCreate),
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

  model.create_error |> should.equal(option.Some("Name is required"))
}

// =============================================================================
// DialogMode Type Tests
// =============================================================================

pub fn dialog_mode_create_test() {
  let mode = ModeCreate
  should.equal(mode, ModeCreate)
}

pub fn dialog_mode_edit_test() {
  let workflow = make_test_workflow()
  let ModeEdit(w) = ModeEdit(workflow)
  w.id |> should.equal(1)
}

pub fn dialog_mode_delete_test() {
  let workflow = make_test_workflow()
  let ModeDelete(w) = ModeDelete(workflow)
  w.name |> should.equal("Test Workflow")
}

// =============================================================================
// Msg Type Tests
// =============================================================================

pub fn msg_locale_received_test() {
  let msg = LocaleReceived(Es)
  case msg {
    LocaleReceived(loc) -> loc |> should.equal(Es)
  }
}

pub fn msg_project_id_received_test() {
  let msg = ProjectIdReceived(option.Some(123))
  case msg {
    ProjectIdReceived(id) -> id |> should.equal(option.Some(123))
  }
}

pub fn msg_project_id_received_none_test() {
  let msg = ProjectIdReceived(option.None)
  case msg {
    ProjectIdReceived(id) -> id |> should.equal(option.None)
  }
}

pub fn msg_mode_received_test() {
  let msg = ModeReceived(ModeCreate)
  case msg {
    ModeReceived(mode) -> should.equal(mode, ModeCreate)
  }
}

pub fn msg_create_name_changed_test() {
  let msg = CreateNameChanged("New Workflow")
  case msg {
    CreateNameChanged(name) -> name |> should.equal("New Workflow")
  }
}

pub fn msg_create_description_changed_test() {
  let msg = CreateDescriptionChanged("New Description")
  case msg {
    CreateDescriptionChanged(desc) -> desc |> should.equal("New Description")
  }
}

pub fn msg_create_active_toggled_test() {
  let msg = CreateActiveToggled
  should.equal(msg, CreateActiveToggled)
}

pub fn msg_create_submitted_test() {
  let msg = CreateSubmitted
  should.equal(msg, CreateSubmitted)
}

pub fn msg_edit_name_changed_test() {
  let msg = EditNameChanged("Updated Name")
  case msg {
    EditNameChanged(name) -> name |> should.equal("Updated Name")
  }
}

pub fn msg_edit_description_changed_test() {
  let msg = EditDescriptionChanged("Updated Description")
  case msg {
    EditDescriptionChanged(desc) -> desc |> should.equal("Updated Description")
  }
}

pub fn msg_edit_active_toggled_test() {
  let msg = EditActiveToggled
  should.equal(msg, EditActiveToggled)
}

pub fn msg_edit_submitted_test() {
  let msg = EditSubmitted
  should.equal(msg, EditSubmitted)
}

pub fn msg_edit_cancelled_test() {
  let msg = EditCancelled
  should.equal(msg, EditCancelled)
}

pub fn msg_delete_confirmed_test() {
  let msg = DeleteConfirmed
  should.equal(msg, DeleteConfirmed)
}

pub fn msg_delete_cancelled_test() {
  let msg = DeleteCancelled
  should.equal(msg, DeleteCancelled)
}

pub fn msg_close_requested_test() {
  let msg = CloseRequested
  should.equal(msg, CloseRequested)
}

// =============================================================================
// Helpers
// =============================================================================

import domain/workflow.{type Workflow, Workflow}

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
