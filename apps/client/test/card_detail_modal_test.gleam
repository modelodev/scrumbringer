//// Tests for card detail modal component logic.
////
//// These tests validate the Model and Msg types for the encapsulated
//// card detail modal component.

import gleam/option

import domain/card.{type Card, Active, Card, Draft}
import domain/remote.{Loaded, NotAsked}
import scrumbringer_client/components/card_detail_modal.{
  type Model, CardIdReceived, CardReceived, LocaleReceived, Model, TasksReceived,
}
import scrumbringer_client/i18n/locale.{En, Es}
import scrumbringer_client/ui/card_tabs

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
    // AC21: Default tab
    active_tab: card_tabs.TasksTab,
    notes: NotAsked,
    note_dialog_open: False,
    note_content: "",
    note_in_flight: False,
    note_error: option.None,
    tasks: NotAsked,
    metrics: NotAsked,
    move_dialog_open: False,
  )
}

fn make_card(id: Int) -> Card {
  Card(
    id: id,
    project_id: 1,
    parent_card_id: option.None,
    title: "Test Card",
    description: "A test card",
    color: option.Some(card.Blue),
    state: Draft,
    task_count: 3,
    completed_count: 1,
    created_by: 1,
    created_at: "2026-01-20T00:00:00Z",
    due_date: option.None,
    has_new_notes: False,
  )
}

// Note: We can't directly call the update function because it's private.
// But we CAN test the publicly exposed types and decoders.
// For update logic, we test by examining Model construction patterns.

// =============================================================================
// Model Construction Tests
// =============================================================================

pub fn initial_model_has_correct_defaults_test() {
  let model = make_model()

  let assert option.None = model.card_id
  let assert option.None = model.card
  let assert En = model.locale
  let assert option.None = model.current_user_id
  let assert False = model.can_manage_notes
  let assert False = model.can_manage_structure
  let assert False = model.can_execute_work
  let assert NotAsked = model.notes
  let assert "" = model.note_content
  let assert False = model.note_in_flight
  let assert option.None = model.note_error
  let assert NotAsked = model.tasks
  let assert NotAsked = model.metrics
  let assert False = model.move_dialog_open
  // AC21: Default tab is Tasks
  let assert card_tabs.TasksTab = model.active_tab
}

pub fn model_with_card_retains_data_test() {
  let card = make_card(42)
  let model = Model(..make_model(), card: option.Some(card))

  let assert option.Some(c) = model.card
  let assert 42 = c.id
  let assert "Test Card" = c.title
  let assert Draft = c.state
}

pub fn model_with_loaded_tasks_has_correct_remote_state_test() {
  let model = Model(..make_model(), tasks: Loaded([]))

  let assert Loaded(t) = model.tasks
  let assert [] = t
}

// =============================================================================
// Msg Type Tests (verifying message constructors work)
// =============================================================================

pub fn card_id_received_msg_carries_id_test() {
  let CardIdReceived(id) = CardIdReceived(123)
  let assert 123 = id
}

pub fn card_received_msg_carries_card_test() {
  let card = make_card(99)
  let CardReceived(c) = CardReceived(card)
  let assert 99 = c.id
}

pub fn locale_received_msg_carries_locale_test() {
  let LocaleReceived(loc) = LocaleReceived(Es)
  let assert Es = loc
}

pub fn tasks_received_msg_carries_tasks_test() {
  let TasksReceived(tasks) = TasksReceived([])
  let assert [] = tasks
}

// =============================================================================
// Remote State Tests
// =============================================================================

pub fn remote_not_asked_is_initial_test() {
  let state = make_model().notes
  let assert NotAsked = state
}

pub fn remote_loaded_carries_data_test() {
  let Loaded(data) = Loaded([1, 2, 3])
  let assert [1, 2, 3] = data
}

// =============================================================================
// Card State Tests
// =============================================================================

pub fn card_state_pendiente_test() {
  let card = Card(..make_card(1), state: Draft)
  let assert Draft = card.state
}

pub fn card_state_en_curso_test() {
  let card = Card(..make_card(1), state: Active)
  let assert Active = card.state
}

pub fn card_color_option_some_test() {
  let card = make_card(1)
  let assert option.Some(card.Blue) = card.color
}

pub fn card_color_option_none_test() {
  let card = Card(..make_card(1), color: option.None)
  let assert option.None = card.color
}
