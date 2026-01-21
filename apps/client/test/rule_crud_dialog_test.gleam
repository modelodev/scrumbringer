//// Tests for rule_crud_dialog Lustre component.
////
//// Tests Model construction, Msg type constructors, and DialogMode type.

import gleeunit/should

import scrumbringer_client/components/rule_crud_dialog.{
  CloseRequested, CreateActiveChanged, CreateGoalChanged, CreateNameChanged,
  CreateResourceTypeChanged, CreateSubmitted, CreateTaskTypeIdChanged,
  CreateToStateChanged, DeleteCancelled, DeleteConfirmed, EditActiveChanged,
  EditCancelled, EditGoalChanged, EditNameChanged, EditResourceTypeChanged,
  EditSubmitted, EditTaskTypeIdChanged, EditToStateChanged, LocaleReceived,
  ModeCreate, ModeDelete, ModeEdit, Model, ModeReceived, WorkflowIdReceived,
}
import scrumbringer_client/i18n/locale.{En, Es}
import domain/workflow.{type Rule, Rule}
import gleam/option

// =============================================================================
// Model Tests
// =============================================================================

pub fn model_default_values_test() {
  let model =
    Model(
      locale: En,
      workflow_id: option.None,
      mode: option.None,
      task_types: [],
      create_name: "",
      create_goal: "",
      create_resource_type: "task",
      create_task_type_id: option.None,
      create_to_state: "completed",
      create_active: True,
      create_in_flight: False,
      create_error: option.None,
      edit_name: "",
      edit_goal: "",
      edit_resource_type: "task",
      edit_task_type_id: option.None,
      edit_to_state: "completed",
      edit_active: True,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  model.locale |> should.equal(En)
  model.workflow_id |> should.equal(option.None)
  model.mode |> should.equal(option.None)
  model.create_name |> should.equal("")
  model.create_resource_type |> should.equal("task")
  model.create_to_state |> should.equal("completed")
  model.create_active |> should.equal(True)
  model.create_in_flight |> should.equal(False)
}

pub fn model_with_spanish_locale_test() {
  let model =
    Model(
      locale: Es,
      workflow_id: option.Some(42),
      mode: option.Some(ModeCreate),
      task_types: [],
      create_name: "Mi Regla",
      create_goal: "Automatizar tareas",
      create_resource_type: "task",
      create_task_type_id: option.None,
      create_to_state: "completed",
      create_active: True,
      create_in_flight: False,
      create_error: option.None,
      edit_name: "",
      edit_goal: "",
      edit_resource_type: "task",
      edit_task_type_id: option.None,
      edit_to_state: "completed",
      edit_active: True,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  model.locale |> should.equal(Es)
  model.workflow_id |> should.equal(option.Some(42))
  model.create_name |> should.equal("Mi Regla")
}

pub fn model_with_card_resource_type_test() {
  let model =
    Model(
      locale: En,
      workflow_id: option.Some(1),
      mode: option.Some(ModeCreate),
      task_types: [],
      create_name: "Card Rule",
      create_goal: "",
      create_resource_type: "card",
      create_task_type_id: option.None,
      create_to_state: "cerrada",
      create_active: True,
      create_in_flight: False,
      create_error: option.None,
      edit_name: "",
      edit_goal: "",
      edit_resource_type: "card",
      edit_task_type_id: option.None,
      edit_to_state: "cerrada",
      edit_active: True,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  model.create_resource_type |> should.equal("card")
  model.create_to_state |> should.equal("cerrada")
}

pub fn model_with_create_in_flight_test() {
  let model =
    Model(
      locale: En,
      workflow_id: option.Some(1),
      mode: option.Some(ModeCreate),
      task_types: [],
      create_name: "Test Rule",
      create_goal: "",
      create_resource_type: "task",
      create_task_type_id: option.None,
      create_to_state: "completed",
      create_active: True,
      create_in_flight: True,
      create_error: option.None,
      edit_name: "",
      edit_goal: "",
      edit_resource_type: "task",
      edit_task_type_id: option.None,
      edit_to_state: "completed",
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
      workflow_id: option.Some(1),
      mode: option.Some(ModeCreate),
      task_types: [],
      create_name: "",
      create_goal: "",
      create_resource_type: "task",
      create_task_type_id: option.None,
      create_to_state: "completed",
      create_active: True,
      create_in_flight: False,
      create_error: option.Some("Name is required"),
      edit_name: "",
      edit_goal: "",
      edit_resource_type: "task",
      edit_task_type_id: option.None,
      edit_to_state: "completed",
      edit_active: True,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  model.create_error |> should.equal(option.Some("Name is required"))
}

pub fn model_with_task_type_id_test() {
  let model =
    Model(
      locale: En,
      workflow_id: option.Some(1),
      mode: option.Some(ModeCreate),
      task_types: [],
      create_name: "Type-specific Rule",
      create_goal: "",
      create_resource_type: "task",
      create_task_type_id: option.Some(5),
      create_to_state: "completed",
      create_active: True,
      create_in_flight: False,
      create_error: option.None,
      edit_name: "",
      edit_goal: "",
      edit_resource_type: "task",
      edit_task_type_id: option.None,
      edit_to_state: "completed",
      edit_active: True,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  model.create_task_type_id |> should.equal(option.Some(5))
}

// =============================================================================
// DialogMode Type Tests
// =============================================================================

pub fn dialog_mode_create_test() {
  let mode = ModeCreate
  should.equal(mode, ModeCreate)
}

pub fn dialog_mode_edit_test() {
  let rule = make_test_rule()
  let ModeEdit(r) = ModeEdit(rule)
  r.id |> should.equal(1)
}

pub fn dialog_mode_delete_test() {
  let rule = make_test_rule()
  let ModeDelete(r) = ModeDelete(rule)
  r.name |> should.equal("Test Rule")
}

pub fn dialog_mode_edit_preserves_rule_data_test() {
  let rule = make_test_rule_with_details()
  let ModeEdit(r) = ModeEdit(rule)
  r.name |> should.equal("Detailed Rule")
  r.goal |> should.equal(option.Some("Automate task transitions"))
  r.resource_type |> should.equal("task")
  r.task_type_id |> should.equal(option.Some(10))
  r.to_state |> should.equal("completed")
  r.active |> should.equal(True)
}

// =============================================================================
// Msg Type Tests
// =============================================================================

pub fn msg_locale_received_en_test() {
  let msg = LocaleReceived(En)
  case msg {
    LocaleReceived(locale) -> locale |> should.equal(En)
  }
}

pub fn msg_locale_received_es_test() {
  let msg = LocaleReceived(Es)
  case msg {
    LocaleReceived(locale) -> locale |> should.equal(Es)
  }
}

pub fn msg_workflow_id_received_test() {
  let msg = WorkflowIdReceived(option.Some(42))
  case msg {
    WorkflowIdReceived(id) -> id |> should.equal(option.Some(42))
  }
}

pub fn msg_mode_received_test() {
  let msg = ModeReceived(ModeCreate)
  case msg {
    ModeReceived(mode) -> should.equal(mode, ModeCreate)
  }
}

pub fn msg_create_name_changed_test() {
  let msg = CreateNameChanged("New Rule")
  case msg {
    CreateNameChanged(name) -> name |> should.equal("New Rule")
  }
}

pub fn msg_create_goal_changed_test() {
  let msg = CreateGoalChanged("Automate transitions")
  case msg {
    CreateGoalChanged(goal) -> goal |> should.equal("Automate transitions")
  }
}

pub fn msg_create_resource_type_changed_test() {
  let msg = CreateResourceTypeChanged("card")
  case msg {
    CreateResourceTypeChanged(rt) -> rt |> should.equal("card")
  }
}

pub fn msg_create_task_type_id_changed_test() {
  let msg = CreateTaskTypeIdChanged("5")
  case msg {
    CreateTaskTypeIdChanged(id) -> id |> should.equal("5")
  }
}

pub fn msg_create_to_state_changed_test() {
  let msg = CreateToStateChanged("available")
  case msg {
    CreateToStateChanged(state) -> state |> should.equal("available")
  }
}

pub fn msg_create_active_changed_test() {
  let msg = CreateActiveChanged(False)
  case msg {
    CreateActiveChanged(active) -> active |> should.equal(False)
  }
}

pub fn msg_create_submitted_test() {
  let msg = CreateSubmitted
  should.equal(msg, CreateSubmitted)
}

pub fn msg_edit_name_changed_test() {
  let msg = EditNameChanged("Updated Rule")
  case msg {
    EditNameChanged(name) -> name |> should.equal("Updated Rule")
  }
}

pub fn msg_edit_goal_changed_test() {
  let msg = EditGoalChanged("New goal")
  case msg {
    EditGoalChanged(goal) -> goal |> should.equal("New goal")
  }
}

pub fn msg_edit_resource_type_changed_test() {
  let msg = EditResourceTypeChanged("task")
  case msg {
    EditResourceTypeChanged(rt) -> rt |> should.equal("task")
  }
}

pub fn msg_edit_task_type_id_changed_test() {
  let msg = EditTaskTypeIdChanged("10")
  case msg {
    EditTaskTypeIdChanged(id) -> id |> should.equal("10")
  }
}

pub fn msg_edit_to_state_changed_test() {
  let msg = EditToStateChanged("claimed")
  case msg {
    EditToStateChanged(state) -> state |> should.equal("claimed")
  }
}

pub fn msg_edit_active_changed_test() {
  let msg = EditActiveChanged(True)
  case msg {
    EditActiveChanged(active) -> active |> should.equal(True)
  }
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
// State Options Tests
// =============================================================================

pub fn task_state_options_count_test() {
  let states = ["available", "claimed", "completed"]
  states |> should.equal(["available", "claimed", "completed"])
}

pub fn card_state_options_count_test() {
  let states = ["pendiente", "en_curso", "cerrada"]
  states |> should.equal(["pendiente", "en_curso", "cerrada"])
}

// =============================================================================
// Helpers
// =============================================================================

fn make_test_rule() -> Rule {
  Rule(
    id: 1,
    workflow_id: 100,
    name: "Test Rule",
    goal: option.None,
    resource_type: "task",
    task_type_id: option.None,
    to_state: "completed",
    active: True,
    created_at: "2024-01-01T00:00:00Z",
  )
}

fn make_test_rule_with_details() -> Rule {
  Rule(
    id: 2,
    workflow_id: 100,
    name: "Detailed Rule",
    goal: option.Some("Automate task transitions"),
    resource_type: "task",
    task_type_id: option.Some(10),
    to_state: "completed",
    active: True,
    created_at: "2024-01-02T00:00:00Z",
  )
}
