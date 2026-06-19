import gleam/dynamic/decode
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/card.{Card, Pendiente}
import domain/remote.{Loaded, Loading}
import domain/task.{Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/cards/detail_modal_entry
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn sample_card() {
  Card(
    id: 4,
    project_id: 7,
    milestone_id: None,
    title: "Customer Card",
    description: "Customer-facing card",
    color: None,
    state: Pendiente,
    task_count: 1,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}

fn sample_task(id: Int, card_id) {
  let state = task_state.Available

  Task(
    id: id,
    project_id: 7,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Task",
    description: None,
    priority: 3,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    version: 1,
    milestone_id: None,
    card_id: card_id,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn config(card) -> detail_modal_entry.Config(String) {
  detail_modal_entry.Config(
    card: card,
    cards: [],
    tasks: [],
    locale: locale.En,
    current_user_id: Some(8),
    can_manage_notes: True,
    can_manage_structure: True,
    can_execute_work: True,
    on_create_task: decode.success("create"),
    on_create_card: decode.success("create-card"),
    on_delete_card: decode.success("delete-card"),
    on_close: decode.success("close"),
  )
}

pub fn card_detail_modal_entry_renders_without_root_model_test() {
  let html =
    detail_modal_entry.view(config(Some(sample_card())))
    |> element.to_document_string

  assert_contains(html, "card-detail-modal")
  assert_contains(html, "card-id=\"4\"")
  assert_contains(html, "locale=\"en\"")
  assert_contains(html, "current-user-id=\"8\"")
  assert_contains(html, "can-manage-notes=\"true\"")
}

pub fn card_detail_modal_entry_omits_current_user_attribute_when_absent_test() {
  let html =
    detail_modal_entry.view(
      detail_modal_entry.Config(
        ..config(Some(sample_card())),
        current_user_id: None,
      ),
    )
    |> element.to_document_string

  assert_contains(html, "card-detail-modal")
  assert_not_contains(html, "current-user-id=")
}

pub fn card_detail_modal_entry_omits_missing_card_test() {
  let html =
    detail_modal_entry.view(config(None))
    |> element.to_document_string

  assert_not_contains(html, "card-detail-modal")
}

pub fn card_detail_modal_entry_filters_loaded_tasks_by_card_test() {
  let matching = sample_task(1, Some(4))
  let other_card = sample_task(2, Some(9))
  let no_card = sample_task(3, None)

  let matches =
    detail_modal_entry.tasks_for_card(
      Loaded([matching, other_card, no_card]),
      4,
    )

  let assert [task] = matches
  let assert 1 = task.id
}

pub fn card_detail_modal_entry_treats_unloaded_tasks_as_empty_test() {
  let assert [] = detail_modal_entry.tasks_for_card(Loading, 4)
}
