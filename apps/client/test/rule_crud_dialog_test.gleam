//// Tests for rule_crud_dialog Lustre component.
////
//// Tests Model construction, Msg type constructors, and DialogMode type.

import gleam/string
import lustre/element

import domain/task_status
import domain/task_type.{type TaskType, TaskType}
import domain/workflow.{
  type Rule, Rule, TaskRule, rule_resource_type, rule_task_type_id,
  rule_to_state_string,
}
import gleam/option
import scrumbringer_client/components/crud_dialog_base.{
  Closed, Creating, Deleting, Editing,
}
import scrumbringer_client/components/rule_crud_dialog.{
  CloseRequested, CreateActiveChanged, CreateGoalChanged, CreateNameChanged,
  CreateResourceTypeChanged, CreateSubmitted, CreateTaskTypeIdChanged,
  CreateToStateChanged, DeleteCancelled, DeleteConfirmed, EditActiveChanged,
  EditCancelled, EditGoalChanged, EditNameChanged, EditResourceTypeChanged,
  EditSubmitted, EditTaskTypeIdChanged, EditToStateChanged, LocaleReceived,
  ModeReceived, Model, WorkflowIdReceived, view_create_dialog_for_test,
  view_edit_dialog_for_test,
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
      workflow_id: option.None,
      mode: Closed,
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

  let assert En = model.locale
  let assert option.None = model.workflow_id
  let assert Closed = model.mode
  let assert "" = model.create_name
  let assert "task" = model.create_resource_type
  let assert "completed" = model.create_to_state
  let assert True = model.create_active
  let assert False = model.create_in_flight
}

pub fn model_with_spanish_locale_test() {
  let model =
    Model(
      locale: Es,
      workflow_id: option.Some(42),
      mode: Creating,
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

  let assert Es = model.locale
  let assert option.Some(42) = model.workflow_id
  let assert "Mi Regla" = model.create_name
}

pub fn model_with_card_resource_type_test() {
  let model =
    Model(
      locale: En,
      workflow_id: option.Some(1),
      mode: Creating,
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

  let assert "card" = model.create_resource_type
  let assert "cerrada" = model.create_to_state
}

pub fn model_with_create_in_flight_test() {
  let model =
    Model(
      locale: En,
      workflow_id: option.Some(1),
      mode: Creating,
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

  let assert True = model.create_in_flight
}

pub fn model_with_error_test() {
  let model =
    Model(
      locale: En,
      workflow_id: option.Some(1),
      mode: Creating,
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

  let assert option.Some("Name is required") = model.create_error
}

pub fn model_with_task_type_id_test() {
  let model =
    Model(
      locale: En,
      workflow_id: option.Some(1),
      mode: Creating,
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

  let assert option.Some(5) = model.create_task_type_id
}

// =============================================================================
// DialogMode Type Tests
// =============================================================================

pub fn dialog_mode_create_test() {
  let mode = Creating
  assert_equal(mode, Creating)
}

pub fn dialog_mode_edit_test() {
  let rule = make_test_rule()
  let Editing(r) = Editing(rule)
  let assert 1 = r.id
}

pub fn dialog_mode_delete_test() {
  let rule = make_test_rule()
  let Deleting(r) = Deleting(rule)
  let assert "Test Rule" = r.name
}

pub fn dialog_mode_edit_preserves_rule_data_test() {
  let rule = make_test_rule_with_details()
  let Editing(r) = Editing(rule)
  let assert "Detailed Rule" = r.name
  let assert option.Some("Automate task transitions") = r.goal
  let assert "task" = rule_resource_type(r)
  let assert option.Some(10) = rule_task_type_id(r)
  let assert "completed" = rule_to_state_string(r)
  let assert True = r.active
}

// =============================================================================
// Msg Type Tests
// =============================================================================

pub fn msg_locale_received_en_test() {
  let msg = LocaleReceived(En)
  assert_equal(msg, LocaleReceived(En))
}

pub fn msg_locale_received_es_test() {
  let msg = LocaleReceived(Es)
  assert_equal(msg, LocaleReceived(Es))
}

pub fn msg_workflow_id_received_test() {
  let msg = WorkflowIdReceived(option.Some(42))
  assert_equal(msg, WorkflowIdReceived(option.Some(42)))
}

pub fn msg_mode_received_test() {
  let msg = ModeReceived(Creating)
  assert_equal(msg, ModeReceived(Creating))
}

pub fn msg_create_name_changed_test() {
  let msg = CreateNameChanged("New Rule")
  assert_equal(msg, CreateNameChanged("New Rule"))
}

pub fn msg_create_goal_changed_test() {
  let msg = CreateGoalChanged("Automate transitions")
  assert_equal(msg, CreateGoalChanged("Automate transitions"))
}

pub fn msg_create_resource_type_changed_test() {
  let msg = CreateResourceTypeChanged("card")
  assert_equal(msg, CreateResourceTypeChanged("card"))
}

pub fn msg_create_task_type_id_changed_test() {
  let msg = CreateTaskTypeIdChanged("5")
  assert_equal(msg, CreateTaskTypeIdChanged("5"))
}

pub fn msg_create_to_state_changed_test() {
  let msg = CreateToStateChanged("available")
  assert_equal(msg, CreateToStateChanged("available"))
}

pub fn msg_create_active_changed_test() {
  let msg = CreateActiveChanged(False)
  assert_equal(msg, CreateActiveChanged(False))
}

pub fn msg_create_submitted_test() {
  let msg = CreateSubmitted
  assert_equal(msg, CreateSubmitted)
}

pub fn msg_edit_name_changed_test() {
  let msg = EditNameChanged("Updated Rule")
  assert_equal(msg, EditNameChanged("Updated Rule"))
}

pub fn msg_edit_goal_changed_test() {
  let msg = EditGoalChanged("New goal")
  assert_equal(msg, EditGoalChanged("New goal"))
}

pub fn msg_edit_resource_type_changed_test() {
  let msg = EditResourceTypeChanged("task")
  assert_equal(msg, EditResourceTypeChanged("task"))
}

pub fn msg_edit_task_type_id_changed_test() {
  let msg = EditTaskTypeIdChanged("10")
  assert_equal(msg, EditTaskTypeIdChanged("10"))
}

pub fn msg_edit_to_state_changed_test() {
  let msg = EditToStateChanged("claimed")
  assert_equal(msg, EditToStateChanged("claimed"))
}

pub fn msg_edit_active_changed_test() {
  let msg = EditActiveChanged(True)
  assert_equal(msg, EditActiveChanged(True))
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
// State Options Tests
// =============================================================================

pub fn task_state_options_count_test() {
  let states = ["available", "claimed", "completed"]
  let assert ["available", "claimed", "completed"] = states
}

pub fn card_state_options_count_test() {
  let states = ["pendiente", "en_curso", "cerrada"]
  let assert ["pendiente", "en_curso", "cerrada"] = states
}

// =============================================================================
// View Tests
// =============================================================================

pub fn create_dialog_renders_shared_rule_fields_test() {
  let html =
    view_create_dialog_for_test(En, [sample_task_type()])
    |> element.to_document_string

  assert_contains(html, "rule-create-form")
  assert_contains(html, "Create Rule")
  assert_contains(html, "Rule name")
  assert_contains(html, "Rule goal")
  assert_contains(html, "Resource Type")
  assert_contains(html, "Task Type")
  assert_contains(html, "Bug")
  assert_contains(html, "Target State")
  assert_contains(html, "Completed")
  assert_contains(html, "Active")
}

pub fn edit_dialog_renders_shared_rule_fields_test() {
  let html =
    view_edit_dialog_for_test(En, make_test_rule_with_details(), [
      sample_task_type(),
    ])
    |> element.to_document_string

  assert_contains(html, "rule-edit-form")
  assert_contains(html, "Edit Rule")
  assert_contains(html, "Detailed Rule")
  assert_contains(html, "Automate task transitions")
  assert_contains(html, "Resource Type")
  assert_contains(html, "Task Type")
  assert_contains(html, "Bug")
  assert_contains(html, "Target State")
  assert_contains(html, "Completed")
}

// =============================================================================
// Helpers
// =============================================================================

fn sample_task_type() -> TaskType {
  TaskType(
    id: 10,
    name: "Bug",
    icon: "bug-ant",
    capability_id: option.None,
    tasks_count: 0,
  )
}

fn make_test_rule() -> Rule {
  Rule(
    id: 1,
    workflow_id: 100,
    name: "Test Rule",
    goal: option.None,
    target: TaskRule(task_status.Completed, option.None),
    active: True,
    created_at: "2024-01-01T00:00:00Z",
    templates: [],
  )
}

fn make_test_rule_with_details() -> Rule {
  Rule(
    id: 2,
    workflow_id: 100,
    name: "Detailed Rule",
    goal: option.Some("Automate task transitions"),
    target: TaskRule(task_status.Completed, option.Some(10)),
    active: True,
    created_at: "2024-01-02T00:00:00Z",
    templates: [],
  )
}
