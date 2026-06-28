//// Tests for Card Show component logic.

import gleam/option

import support/domain_fixtures
import support/render_assertions

import domain/activity/entity.{type ActivityEvent, ActivityEvent}
import domain/activity/id as activity_id
import domain/activity/kind
import domain/activity/subject.{ActivityCard}
import domain/card.{type Card, Card, Draft}
import domain/card/id as card_id
import domain/project/id as project_id
import domain/remote.{Loaded, NotAsked}
import domain/user/id as user_id
import scrumbringer_client/features/cards/show.{type Model, Model, view}
import scrumbringer_client/i18n/locale.{En}
import scrumbringer_client/ui/show_tabs

// =============================================================================
// Test Helpers
// =============================================================================

fn make_model() -> Model {
  Model(
    card_id: option.None,
    card: option.None,
    cards: [],
    locale: En,
    current_user_id: option.None,
    project_id: option.None,
    can_manage_notes: False,
    can_manage_structure: False,
    can_execute_work: False,
    active_tab: show_tabs.default_card_tab(),
    notes: NotAsked,
    note_dialog_open: False,
    note_content: "",
    note_in_flight: False,
    note_error: option.None,
    note_pin_in_flight: option.None,
    activity: NotAsked,
    activity_total: 0,
    activity_loading_more: False,
    tasks: NotAsked,
    activation_confirm_open: False,
  )
}

fn make_card(id: Int) -> Card {
  Card(
    ..domain_fixtures.card(id, 1, "Test Card"),
    description: "A test card",
    color: option.Some(card.Blue),
    state: Draft,
    task_count: 3,
    closed_count: 1,
    created_at: "2026-01-20T00:00:00Z",
  )
}

fn sample_activity(id: Int) -> ActivityEvent {
  ActivityEvent(
    id: activity_id.new(id),
    project_id: project_id.new(1),
    subject: ActivityCard(card_id.new(42)),
    kind: kind.CardActivated,
    actor_user_id: user_id.new(7),
    actor_label: "admin@example.com",
    summary: "Card activated",
    related_subject: option.None,
    created_at: "2026-06-22T10:30:00Z",
  )
}

pub fn card_activity_tab_renders_load_more_when_more_events_exist_test() {
  let html =
    Model(
      ..make_model(),
      card: option.Some(make_card(42)),
      active_tab: show_tabs.CardActivityTab,
      activity: Loaded([sample_activity(1)]),
      activity_total: 2,
    )
    |> view
    |> render_assertions.html

  render_assertions.contains(html, "activity-feed-more")
  render_assertions.contains(html, "Load more (1)")
}

pub fn card_show_renders_as_panel_not_modal_test() {
  let html =
    Model(..make_model(), card: option.Some(make_card(42)))
    |> view
    |> render_assertions.html

  render_assertions.contains(html, "card-show-panel")
  render_assertions.contains(html, "inspector-shell")
  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.not_contains(html, "modal-backdrop")
}
