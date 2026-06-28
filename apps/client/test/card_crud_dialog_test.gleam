//// Tests for card_crud_dialog Lustre component.
////
//// Tests Model construction, Msg type constructors, and DialogMode type.

import support/assertions.{assert_equal}

import lustre/effect
import lustre/element
import support/render_assertions

import api/cards/contracts as card_contracts
import domain/api_error.{ApiError}
import domain/card.{
  type Card, type CardColor, Blue, Card, Draft, Gray, Green, Orange, Pink,
  Purple, Red, Yellow,
}
import gleam/option
import scrumbringer_client/components/card_crud_dialog.{
  type Model, CreateActivationResult, CreateAndActivatePending,
  CreateAndActivateSubmitted, CreateColorChanged, CreateColorToggle,
  CreateDescriptionChanged, CreateResult, CreateSubmitted, CreateTitleChanged,
  DeleteCancelled, DeleteConfirmed, EditCancelled, EditTitleChanged,
  LocaleReceived, ModeReceived, Model, ProjectIdReceived, update_for_test,
  view_create_dialog_for_test, view_edit_dialog_for_test,
}
import scrumbringer_client/components/crud_dialog_base.{
  Closed, Creating, Deleting, Editing,
}
import scrumbringer_client/i18n/locale.{En, Es}

// =============================================================================
// Model Tests
// =============================================================================

pub fn model_default_values_test() {
  let model =
    Model(
      locale: En,
      project_id: option.None,
      mode: Closed,
      create_parent_card_id: option.None,
      create_title: "",
      create_description: "",
      create_color: option.None,
      create_color_open: False,
      create_in_flight: False,
      create_pending_action: option.None,
      create_error: option.None,
      edit_title: "",
      edit_description: "",
      edit_color: option.None,
      edit_color_open: False,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  let assert En = model.locale
  let assert option.None = model.project_id
  let assert Closed = model.mode
  let assert "" = model.create_title
  let assert False = model.create_in_flight
}

pub fn model_with_spanish_locale_test() {
  let model =
    Model(
      locale: Es,
      project_id: option.Some(42),
      mode: Creating,
      create_parent_card_id: option.Some(9),
      create_title: "Mi Ficha",
      create_description: "Descripción",
      create_color: option.Some("blue"),
      create_color_open: True,
      create_in_flight: False,
      create_pending_action: option.None,
      create_error: option.None,
      edit_title: "",
      edit_description: "",
      edit_color: option.None,
      edit_color_open: False,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  let assert Es = model.locale
  let assert option.Some(42) = model.project_id
  let assert "Mi Ficha" = model.create_title
  let assert option.Some("blue") = model.create_color
  let assert True = model.create_color_open
}

// =============================================================================
// DialogMode Type Tests
// =============================================================================

pub fn dialog_mode_create_test() {
  let mode = Creating
  assert_equal(mode, Creating)
}

pub fn dialog_mode_edit_test() {
  let card = make_test_card()
  let Editing(c) = Editing(card)
  let assert 1 = c.id
}

pub fn dialog_mode_delete_test() {
  let card = make_test_card()
  let Deleting(c) = Deleting(card)
  let assert "Test Card" = c.title
}

// =============================================================================
// Msg Type Tests
// =============================================================================

pub fn msg_locale_received_test() {
  let msg = LocaleReceived(Es)
  assert_equal(msg, LocaleReceived(Es))
}

pub fn msg_project_id_received_test() {
  let msg = ProjectIdReceived(123)
  assert_equal(msg, ProjectIdReceived(123))
}

pub fn msg_mode_received_test() {
  let msg = ModeReceived(Creating)
  assert_equal(msg, ModeReceived(Creating))
}

pub fn msg_create_title_changed_test() {
  let msg = CreateTitleChanged("New Title")
  assert_equal(msg, CreateTitleChanged("New Title"))
}

pub fn msg_create_description_changed_test() {
  let msg = CreateDescriptionChanged("New Description")
  assert_equal(msg, CreateDescriptionChanged("New Description"))
}

pub fn msg_create_color_toggle_test() {
  let msg = CreateColorToggle
  assert_equal(msg, CreateColorToggle)
}

pub fn msg_create_color_changed_test() {
  let msg = CreateColorChanged(option.Some("red"))
  assert_equal(msg, CreateColorChanged(option.Some("red")))
}

pub fn msg_create_submitted_test() {
  let msg = CreateSubmitted
  assert_equal(msg, CreateSubmitted)
}

pub fn msg_create_and_activate_submitted_test() {
  let msg = CreateAndActivateSubmitted
  assert_equal(msg, CreateAndActivateSubmitted)
}

pub fn msg_edit_title_changed_test() {
  let msg = EditTitleChanged("Updated Title")
  assert_equal(msg, EditTitleChanged("Updated Title"))
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

pub fn create_error_keeps_dialog_open_for_retry_test() {
  let model =
    Model(
      locale: En,
      project_id: option.Some(10),
      mode: Creating,
      create_parent_card_id: option.Some(7),
      create_title: "Card with context",
      create_description: "desc",
      create_color: option.None,
      create_color_open: False,
      create_in_flight: True,
      create_pending_action: option.Some(CreateAndActivatePending),
      create_error: option.None,
      edit_title: "",
      edit_description: "",
      edit_color: option.None,
      edit_color_open: False,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  let #(next, fx) =
    update_for_test(
      model,
      CreateResult(
        Error(ApiError(
          status: 422,
          code: "VALIDATION_ERROR",
          message: "validation failed",
        )),
      ),
    )

  let assert Creating = next.mode
  let assert False = next.create_in_flight
  let assert option.Some("validation failed") = next.create_error
  let assert True = fx == effect.none()
}

pub fn create_and_activate_submit_marks_activation_pending_test() {
  let model =
    Model(
      locale: En,
      project_id: option.Some(10),
      mode: Creating,
      create_parent_card_id: option.Some(7),
      create_title: "Release card",
      create_description: "",
      create_color: option.None,
      create_color_open: False,
      create_in_flight: False,
      create_pending_action: option.None,
      create_error: option.None,
      edit_title: "",
      edit_description: "",
      edit_color: option.None,
      edit_color_open: False,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  let #(next, fx) = update_for_test(model, CreateAndActivateSubmitted)

  let assert True = next.create_in_flight
  let assert option.Some(CreateAndActivatePending) = next.create_pending_action
  let assert False = fx == effect.none()
}

pub fn create_activation_success_closes_with_active_card_test() {
  let model = creating_and_activating_model()

  let #(next, fx) =
    update_for_test(
      model,
      CreateActivationResult(make_test_card(), Ok(action_response())),
    )

  let assert Closed = next.mode
  let assert False = next.create_in_flight
  let assert option.None = next.create_pending_action
  let assert False = fx == effect.none()
}

pub fn create_activation_failure_closes_with_created_draft_test() {
  let model = creating_and_activating_model()

  let #(next, fx) =
    update_for_test(
      model,
      CreateActivationResult(
        make_test_card(),
        Error(ApiError(
          status: 409,
          code: "CARD_CONFLICT",
          message: "cannot activate",
        )),
      ),
    )

  let assert Closed = next.mode
  let assert False = next.create_in_flight
  let assert option.None = next.create_pending_action
  let assert False = fx == effect.none()
}

// =============================================================================
// View Tests
// =============================================================================

pub fn create_dialog_renders_shared_card_fields_test() {
  let html =
    view_create_dialog_for_test(En)
    |> element.to_document_string

  render_assertions.contains(html, "card-create-form")
  render_assertions.contains(html, "Create Card")
  render_assertions.contains(html, "Card title")
  render_assertions.contains(html, "Card description")
  render_assertions.contains(html, "Color")
  render_assertions.contains(html, "None")
  render_assertions.contains(html, "Save draft")
  render_assertions.contains(html, "Create and activate")
  render_assertions.contains(html, "data-testid=\"card-create-and-activate\"")
  render_assertions.contains(html, "btn-icon-text")
  render_assertions.contains(html, "form=\"card-create-form\"")
  render_assertions.not_contains(html, "Create draft")
}

pub fn edit_dialog_renders_shared_card_fields_test() {
  let html =
    view_edit_dialog_for_test(En, make_test_card())
    |> element.to_document_string

  render_assertions.contains(html, "card-edit-form")
  render_assertions.contains(html, "Edit Card")
  render_assertions.contains(html, "Test Card")
  render_assertions.contains(html, "Test Description")
  render_assertions.contains(html, "Color")
  render_assertions.contains(html, "Blue")
}

// =============================================================================
// CardColor Type Tests
// =============================================================================

pub fn card_color_all_variants_test() {
  let colors = [Gray, Red, Orange, Yellow, Green, Blue, Purple, Pink]
  let assert False = colors == []
}

pub fn card_color_gray_test() {
  let color: CardColor = Gray
  assert_equal(color, Gray)
}

pub fn card_color_red_test() {
  let color: CardColor = Red
  assert_equal(color, Red)
}

pub fn card_color_blue_test() {
  let color: CardColor = Blue
  assert_equal(color, Blue)
}

// =============================================================================
// Helpers
// =============================================================================

fn make_test_card() -> Card {
  Card(
    id: 1,
    project_id: 10,
    parent_card_id: option.None,
    title: "Test Card",
    description: "Test Description",
    color: option.Some(card.Blue),
    state: Draft,
    task_count: 5,
    closed_count: 2,
    created_by: 1,
    created_at: "2026-01-20T00:00:00Z",
    due_date: option.None,
    has_new_notes: False,
  )
}

fn creating_and_activating_model() -> Model {
  Model(
    locale: En,
    project_id: option.Some(10),
    mode: Creating,
    create_parent_card_id: option.None,
    create_title: "Test Card",
    create_description: "Test Description",
    create_color: option.None,
    create_color_open: False,
    create_in_flight: True,
    create_pending_action: option.Some(CreateAndActivatePending),
    create_error: option.None,
    edit_title: "",
    edit_description: "",
    edit_color: option.None,
    edit_color_open: False,
    edit_in_flight: False,
    edit_error: option.None,
    delete_in_flight: False,
    delete_error: option.None,
  )
}

fn action_response() -> card_contracts.CardActionResponse {
  card_contracts.CardActionResponse(
    card_id: 1,
    pool_impact: 0,
    pool_open_after: 0,
    healthy_pool_limit: 10,
    pool_health: card_contracts.PoolWithinHealthyLimit,
  )
}
