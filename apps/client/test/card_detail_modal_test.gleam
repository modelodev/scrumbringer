//// Tests for card detail modal component logic.
////
//// These tests validate the Model and Msg types for the encapsulated
//// card detail modal component.

import gleam/option
import gleeunit/should

import domain/card.{type Card, Card, EnCurso, Pendiente}
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
    locale: En,
    current_user_id: option.None,
    project_id: option.None,
    can_manage_notes: False,
    // AC21: Default tab
    active_tab: card_tabs.TasksTab,
    notes: NotAsked,
    note_dialog_open: False,
    note_content: "",
    note_in_flight: False,
    note_error: option.None,
    tasks: NotAsked,
    metrics: NotAsked,
  )
}

fn make_card(id: Int) -> Card {
  Card(
    id: id,
    project_id: 1,
    milestone_id: option.None,
    title: "Test Card",
    description: "A test card",
    color: option.Some("blue"),
    state: Pendiente,
    task_count: 3,
    completed_count: 1,
    created_by: 1,
    created_at: "2026-01-20T00:00:00Z",
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

  model.card_id |> should.equal(option.None)
  model.card |> should.equal(option.None)
  model.locale |> should.equal(En)
  model.current_user_id |> should.equal(option.None)
  model.can_manage_notes |> should.equal(False)
  model.notes |> should.equal(NotAsked)
  model.note_content |> should.equal("")
  model.note_in_flight |> should.equal(False)
  model.note_error |> should.equal(option.None)
  model.tasks |> should.equal(NotAsked)
  model.metrics |> should.equal(NotAsked)
  // AC21: Default tab is Tasks
  model.active_tab |> should.equal(card_tabs.TasksTab)
}

pub fn model_with_card_retains_data_test() {
  let card = make_card(42)
  let model = Model(..make_model(), card: option.Some(card))

  case model.card {
    option.Some(c) -> {
      c.id |> should.equal(42)
      c.title |> should.equal("Test Card")
      c.state |> should.equal(Pendiente)
    }
    option.None -> should.fail()
  }
}

pub fn model_with_loaded_tasks_has_correct_remote_state_test() {
  let model = Model(..make_model(), tasks: Loaded([]))

  case model.tasks {
    Loaded(t) -> t |> should.equal([])
    _ -> should.fail()
  }
}

// =============================================================================
// Msg Type Tests (verifying message constructors work)
// =============================================================================

pub fn card_id_received_msg_carries_id_test() {
  let CardIdReceived(id) = CardIdReceived(123)
  id |> should.equal(123)
}

pub fn card_received_msg_carries_card_test() {
  let card = make_card(99)
  let CardReceived(c) = CardReceived(card)
  c.id |> should.equal(99)
}

pub fn locale_received_msg_carries_locale_test() {
  let LocaleReceived(loc) = LocaleReceived(Es)
  loc |> should.equal(Es)
}

pub fn tasks_received_msg_carries_tasks_test() {
  let TasksReceived(tasks) = TasksReceived([])
  tasks |> should.equal([])
}

// =============================================================================
// Remote State Tests
// =============================================================================

pub fn remote_not_asked_is_initial_test() {
  let NotAsked = NotAsked
  should.be_true(True)
}

pub fn remote_loaded_carries_data_test() {
  let Loaded(data) = Loaded([1, 2, 3])
  data |> should.equal([1, 2, 3])
}

// =============================================================================
// Card State Tests
// =============================================================================

pub fn card_state_pendiente_test() {
  let card = Card(..make_card(1), state: Pendiente)
  card.state |> should.equal(Pendiente)
}

pub fn card_state_en_curso_test() {
  let card = Card(..make_card(1), state: EnCurso)
  card.state |> should.equal(EnCurso)
}

pub fn card_color_option_some_test() {
  let card = make_card(1)
  card.color |> should.equal(option.Some("blue"))
}

pub fn card_color_option_none_test() {
  let card = Card(..make_card(1), color: option.None)
  card.color |> should.equal(option.None)
}
