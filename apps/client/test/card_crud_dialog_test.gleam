//// Tests for card_crud_dialog Lustre component.

import lustre/effect
import support/render_assertions

import api/cards/contracts as card_contracts
import domain/api_error.{ApiError}
import domain/card.{type Card, Card, Draft}
import gleam/option
import scrumbringer_client/components/card_crud_dialog.{
  type Model, CreateActivationResult, CreateAndActivatePending,
  CreateAndActivateSubmitted, CreateResult, Model, update_for_test,
  view_create_dialog_for_test, view_edit_dialog_for_test,
}
import scrumbringer_client/components/crud_dialog_base.{Closed, Creating}
import scrumbringer_client/i18n/locale.{En}

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
    |> render_assertions.html

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
    |> render_assertions.html

  render_assertions.contains(html, "card-edit-form")
  render_assertions.contains(html, "Edit Card")
  render_assertions.contains(html, "Test Card")
  render_assertions.contains(html, "Test Description")
  render_assertions.contains(html, "Color")
  render_assertions.contains(html, "Blue")
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
