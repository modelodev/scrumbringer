import gleam/option.{None, Some}
import gleam/string
import support/domain_fixtures
import support/render_assertions

import domain/card.{Active, Card, Draft}
import domain/remote.{Loaded, Loading}
import domain/task.{Task}
import domain/task/state as task_state
import scrumbringer_client/features/cards/show as card_show
import scrumbringer_client/features/cards/show_entry
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/show_tabs

fn forbidden_fragment(parts: List(String)) -> String {
  string.join(parts, "")
}

fn sample_card() {
  Card(
    ..domain_fixtures.card(4, 7, "Customer Card"),
    description: "Customer-facing card",
    state: Draft,
    task_count: 1,
  )
}

fn sample_task(id: Int, card_id) {
  Task(
    ..domain_fixtures.task(id, "Task", 1),
    description: None,
    card_id: card_id,
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
    on_card_show_msg: fn(_msg) { "card-show-msg" },
  )
}

pub fn card_show_entry_renders_without_root_model_test() {
  let html =
    show_entry.view(config(Some(sample_card())))
    |> render_assertions.html

  render_assertions.contains(html, "card-show")
  render_assertions.contains(html, "inspector-shell")
  render_assertions.contains(html, "data-testid=\"inspector-open-in-trigger\"")
  render_assertions.contains(html, "Customer Card")
  render_assertions.contains(html, "data-testid=\"entity-tabs\"")
  render_assertions.not_contains(
    html,
    forbidden_fragment(["card", "-scoped-navigation"]),
  )
  render_assertions.not_contains(html, "card-progress")
}

pub fn card_show_entry_renders_without_current_user_test() {
  let html =
    show_entry.view(
      show_entry.Config(..config(Some(sample_card())), current_user_id: None),
    )
    |> render_assertions.html

  render_assertions.contains(html, "card-show")
  render_assertions.contains(html, "Customer Card")
}

pub fn card_show_secondary_actions_render_as_menu_items_test() {
  let html =
    show_entry.view(config(Some(sample_card())))
    |> render_assertions.html

  render_assertions.contains(
    html,
    "data-testid=\"card-primary-activate-action\"",
  )
  render_assertions.contains(
    html,
    "data-testid=\"inspector-more-actions-trigger\"",
  )
  render_assertions.not_contains(
    html,
    "data-testid=\"card-secondary-activate-action\"",
  )
  render_assertions.contains(html, "data-testid=\"card-secondary-move-action\"")
  render_assertions.contains(
    html,
    "data-testid=\"card-secondary-delete-action\"",
  )
  render_assertions.not_contains(html, "card-secondary-actions-menu")
  render_assertions.not_contains(html, "card-open-in-menu")
  render_assertions.not_contains(html, "data-testid=\"card-activate-action\"")
  render_assertions.not_contains(html, "data-testid=\"card-move-action\"")
  render_assertions.not_contains(html, "data-testid=\"card-delete-action\"")
}

pub fn card_show_task_group_uses_single_header_create_action_test() {
  let card = Card(..sample_card(), task_count: 2, state: Active)

  let html =
    show_entry.view(config(Some(card)))
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"card-create-task-action\"")
  render_assertions.contains(html, "Add task")
  render_assertions.not_contains(html, "Add subcard")
  render_assertions.not_contains(html, "New Card")
}

pub fn card_show_header_renders_path_due_date_and_health_test() {
  let parent = Card(..sample_card(), id: 2, title: "Release", state: Active)
  let card =
    Card(
      ..sample_card(),
      id: 4,
      parent_card_id: Some(2),
      title: "API Cleanup",
      state: Active,
      task_count: 4,
      closed_count: 1,
      due_date: Some("2026-06-24"),
    )
  let ready = sample_task(1, Some(4))
  let claimed =
    Task(
      ..sample_task(2, Some(4)),
      state: task_state.Claimed(
        claimed_by: 8,
        claimed_at: "2026-06-20T10:00:00Z",
        mode: task_state.Taken,
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
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"card-header-path\"")
  render_assertions.contains(html, "Release")
  render_assertions.contains(html, "API Cleanup")
  render_assertions.contains(
    html,
    "Active · Due 2026-06-24 · 1 closed · 4 Tasks",
  )
  render_assertions.contains(html, "data-testid=\"card-header-due\"")
  render_assertions.contains(html, "Due 2026-06-24")
  render_assertions.contains(html, "data-testid=\"card-task-metric-total\"")
  render_assertions.contains(html, "task-metric-chip is-compact")
  render_assertions.contains(html, "title=\"Total: 4\"")
  render_assertions.contains(html, "4")
  render_assertions.contains(html, "data-testid=\"card-task-metric-closed\"")
  render_assertions.contains(html, "title=\"Closed: 1\"")
  render_assertions.contains(html, "1")
  render_assertions.contains(html, "data-testid=\"card-task-metric-blocked\"")
  render_assertions.contains(html, "title=\"Blocked: 2\"")
  render_assertions.contains(html, "2")
  render_assertions.not_contains(html, "task-metric-chip-label")
}

pub fn empty_card_show_offers_balanced_task_and_subcard_creation_test() {
  let empty_card =
    Card(..sample_card(), task_count: 0, closed_count: 0, state: Active)

  let html =
    show_entry.view(config(Some(empty_card)))
    |> render_assertions.html

  render_assertions.contains(html, "inspector-empty-work")
  render_assertions.not_contains(html, "card-empty-work-decision")
  render_assertions.contains(html, "Active")
  render_assertions.contains(html, "Active · No due date · No tasks")
  render_assertions.not_contains(html, "detail-meta")
  render_assertions.not_contains(html, "card-state-badge")
  render_assertions.not_contains(html, "data-testid=\"card-header-due\"")
  render_assertions.contains(html, "empty-state-actions")
  render_assertions.contains(html, "This card has no work yet")
  render_assertions.contains(html, "Add subcard")
  render_assertions.contains(html, "Add task")
  render_assertions.not_contains(html, "In Progress")
  render_assertions.not_contains(html, forbidden_fragment(["0", "/", "0"]))
}

pub fn card_show_summary_uses_diagnostic_summary_without_raw_fractions_test() {
  let card =
    Card(
      ..sample_card(),
      task_count: 0,
      closed_count: 0,
      state: Active,
      description: "Ready root card dominated by loose documentation.",
    )

  let html =
    show_entry.view(
      show_entry.Config(
        ..config(Some(card)),
        model: card_show.Model(
          ..card_show.init_model(),
          active_tab: show_tabs.CardSummaryTab,
        ),
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "card-summary-block")
  render_assertions.contains(html, "card-summary-signal")
  render_assertions.contains(html, "card-summary-metrics")
  render_assertions.contains(html, "detail-section-kicker")
  render_assertions.contains(html, "Description")
  render_assertions.contains(html, "Structure")
  render_assertions.contains(html, "Define the work")
  render_assertions.contains(
    html,
    "Ready root card dominated by loose documentation.",
  )
  render_assertions.not_contains(
    html,
    forbidden_fragment(["detail", "-summary-grid"]),
  )
  render_assertions.not_contains(html, "card-progress")
  render_assertions.not_contains(html, "Tasks0")
  render_assertions.not_contains(html, "Progress0%")
  render_assertions.not_contains(html, forbidden_fragment(["0", "/", "0"]))
}

pub fn card_show_entry_omits_missing_card_test() {
  let html =
    show_entry.view(config(None))
    |> render_assertions.html

  render_assertions.not_contains(html, "card-show")
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
