import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiResult, ApiError}
import domain/card.{type Card, Active, Card, Draft}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/plan_move_update

fn card(id: Int, parent_card_id: opt.Option(Int), title: String) -> Card {
  Card(
    id: id,
    project_id: 1,
    parent_card_id: parent_card_id,
    title: title,
    description: "",
    color: opt.None,
    state: Draft,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    has_new_notes: False,
  )
}

fn cards() -> List(Card) {
  [
    Card(..card(1, opt.None, "Root"), state: Active),
    Card(..card(2, opt.Some(1), "Current parent"), state: Active),
    card(3, opt.Some(2), "Moving story"),
    Card(..card(4, opt.Some(1), "New parent"), state: Active),
  ]
}

fn context() -> plan_move_update.Context(Nil) {
  plan_move_update.Context(
    cards: cards(),
    tasks: [],
    on_card_moved: fn(_result: ApiResult(Card)) { Nil },
    on_success_toast: fn(_message) { effect.none() },
    on_error_toast: fn(_message) { effect.none() },
  )
}

pub fn move_requested_enters_inline_mode_and_closes_detail_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      card_detail_open: opt.Some(3),
    )

  let assert opt.Some(#(next, fx)) =
    plan_move_update.try_update(
      model,
      pool_messages.MemberPlanMoveRequested(3),
      context(),
    )

  let assert member_pool.PlanMovingCard(3, "") = next.member_plan_move_mode
  let assert opt.None = next.card_detail_open
  let assert opt.None = next.member_plan_move_error
  let assert True = fx == effect.none()
}

pub fn destination_search_updates_query_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_plan_move_mode: member_pool.PlanMovingCard(3, ""),
    )

  let assert opt.Some(#(next, fx)) =
    plan_move_update.try_update(
      model,
      pool_messages.MemberPlanMoveDestinationSearchChanged("New"),
      context(),
    )

  let assert member_pool.PlanMovingCard(3, "New") = next.member_plan_move_mode
  let assert True = fx == effect.none()
}

pub fn valid_destination_starts_api_effect_with_in_flight_state_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_plan_move_mode: member_pool.PlanMovingCard(3, ""),
    )

  let assert opt.Some(#(next, fx)) =
    plan_move_update.try_update(
      model,
      pool_messages.MemberPlanMoveDestinationSelected(4),
      context(),
    )

  let assert True = next.member_plan_move_in_flight
  let assert opt.None = next.member_plan_move_error
  let assert False = fx == effect.none()
}

pub fn invalid_destination_keeps_mode_and_sets_reason_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_plan_move_mode: member_pool.PlanMovingCard(3, ""),
    )

  let assert opt.Some(#(next, fx)) =
    plan_move_update.try_update(
      model,
      pool_messages.MemberPlanMoveDestinationSelected(2),
      context(),
    )

  let assert member_pool.PlanMovingCard(3, "") = next.member_plan_move_mode
  let assert opt.Some("Ya esta dentro de esta card.") =
    next.member_plan_move_error
  let assert True = fx == effect.none()
}

pub fn api_error_keeps_move_mode_and_shows_feedback_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_plan_move_mode: member_pool.PlanMovingCard(3, "New"),
      member_plan_move_in_flight: True,
    )
  let err = ApiError(status: 422, code: "INVALID_MOVE", message: "No")

  let assert opt.Some(#(next, _fx)) =
    plan_move_update.try_update(
      model,
      pool_messages.MemberPlanCardMoved(Error(err)),
      context(),
    )

  let assert member_pool.PlanMovingCard(3, "New") = next.member_plan_move_mode
  let assert False = next.member_plan_move_in_flight
  let assert opt.Some("No se pudo mover la card: No") =
    next.member_plan_move_error
}

pub fn cancel_clears_move_mode_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_plan_move_mode: member_pool.PlanMovingCard(3, "New"),
      member_plan_move_error: opt.Some("error"),
      member_plan_move_in_flight: True,
    )

  let assert opt.Some(#(next, fx)) =
    plan_move_update.try_update(
      model,
      pool_messages.MemberPlanMoveCancelled,
      context(),
    )

  let assert member_pool.PlanNotMoving = next.member_plan_move_mode
  let assert opt.None = next.member_plan_move_error
  let assert False = next.member_plan_move_in_flight
  let assert True = fx == effect.none()
}
