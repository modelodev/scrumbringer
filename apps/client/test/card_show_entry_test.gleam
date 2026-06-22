import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/card.{Active, Card, Draft}
import domain/remote.{Loaded, Loading}
import domain/task.{Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/components/card_show
import scrumbringer_client/features/cards/show_entry
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
    parent_card_id: None,
    title: "Customer Card",
    description: "Customer-facing card",
    color: None,
    state: Draft,
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
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: card_id,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn config(card) -> show_entry.Config(String) {
  show_entry.Config(
    model: card_show.init_model(),
    card: card,
    cards: [],
    tasks: [],
    locale: locale.En,
    current_user_id: Some(8),
    can_manage_notes: True,
    can_manage_structure: True,
    can_execute_work: True,
    on_card_show_msg: fn(_msg) { "card-detail-msg" },
  )
}

pub fn card_show_entry_renders_without_root_model_test() {
  let html =
    show_entry.view(config(Some(sample_card())))
    |> element.to_document_string

  assert_contains(html, "card-show")
  assert_contains(html, "Customer Card")
  assert_contains(html, "Customer-facing card")
}

pub fn card_show_entry_renders_without_current_user_test() {
  let html =
    show_entry.view(
      show_entry.Config(..config(Some(sample_card())), current_user_id: None),
    )
    |> element.to_document_string

  assert_contains(html, "card-show")
  assert_contains(html, "Customer Card")
}

pub fn card_detail_secondary_actions_render_as_menu_items_test() {
  let html =
    show_entry.view(config(Some(sample_card())))
    |> element.to_document_string

  assert_contains(html, "data-testid=\"card-secondary-actions-trigger\"")
  assert_contains(html, "data-testid=\"card-secondary-activate-action\"")
  assert_contains(html, "data-testid=\"card-secondary-move-action\"")
  assert_contains(html, "data-testid=\"card-secondary-delete-action\"")
  assert_not_contains(html, "data-testid=\"card-activate-action\"")
  assert_not_contains(html, "data-testid=\"card-move-action\"")
  assert_not_contains(html, "data-testid=\"card-delete-action\"")
}

pub fn card_detail_header_renders_path_due_date_and_health_test() {
  let parent = Card(..sample_card(), id: 2, title: "Release", state: Active)
  let card =
    Card(
      ..sample_card(),
      id: 4,
      parent_card_id: Some(2),
      title: "API Cleanup",
      state: Active,
      task_count: 4,
      completed_count: 1,
      due_date: Some("2026-06-24"),
    )
  let ready = sample_task(1, Some(4))
  let claimed =
    Task(
      ..sample_task(2, Some(4)),
      state: task_state.Claimed(
        claimed_by: 8,
        claimed_at: "2026-06-20T10:00:00Z",
        mode: task_status.Taken,
      ),
    )
  let blocked = Task(..sample_task(3, Some(4)), blocked_count: 2)
  let blocked_again = Task(..sample_task(4, Some(4)), blocked_count: 1)

  let html =
    show_entry.view(
      show_entry.Config(..config(Some(card)), cards: [parent, card], tasks: [
        ready,
        claimed,
        blocked,
        blocked_again,
      ]),
    )
    |> element.to_document_string

  assert_contains(html, "data-testid=\"card-header-path\"")
  assert_contains(html, "Release")
  assert_contains(html, "API Cleanup")
  assert_contains(html, "data-testid=\"card-header-due\"")
  assert_contains(html, "Due 2026-06-24")
  assert_contains(html, "data-testid=\"card-health-total\"")
  assert_contains(html, "4")
  assert_contains(html, "Tasks")
  assert_contains(html, "data-testid=\"card-health-done\"")
  assert_contains(html, "1")
  assert_contains(html, "completed")
  assert_contains(html, "data-testid=\"card-health-blocked\"")
  assert_contains(html, "2")
  assert_contains(html, "Blocked")
}

pub fn card_show_entry_omits_missing_card_test() {
  let html =
    show_entry.view(config(None))
    |> element.to_document_string

  assert_not_contains(html, "card-show")
}

pub fn card_show_entry_filters_loaded_tasks_by_card_test() {
  let matching = sample_task(1, Some(4))
  let other_card = sample_task(2, Some(9))
  let no_card = sample_task(3, None)

  let matches =
    show_entry.tasks_for_card(Loaded([matching, other_card, no_card]), 4)

  let assert [task] = matches
  let assert 1 = task.id
}

pub fn card_show_entry_treats_unloaded_tasks_as_empty_test() {
  let assert [] = show_entry.tasks_for_card(Loading, 4)
}
