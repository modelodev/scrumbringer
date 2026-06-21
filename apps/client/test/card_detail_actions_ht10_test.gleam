import gleam/int
import gleam/option as opt
import gleam/string
import lustre/element

import domain/card.{type Card, type CardPhase, Active, Card, Closed, Draft}
import domain/remote.{Loaded}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{type TaskType, TaskType, TaskTypeInline}
import scrumbringer_client/features/cards/detail_policy
import scrumbringer_client/features/pool/create_dialog
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn card(id: Int, parent_id: opt.Option(Int), state: CardPhase) -> Card {
  Card(
    id: id,
    project_id: 7,
    parent_card_id: parent_id,
    title: "Card " <> int.to_string(id),
    description: "",
    color: opt.None,
    state: state,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    has_new_notes: False,
  )
}

fn task(id: Int, card_id: opt.Option(Int), created_by: Int) -> Task {
  let state = task_state.Available
  Task(
    id: id,
    project_id: 7,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Build", icon: "hammer"),
    ongoing_by: opt.None,
    title: "Task " <> int.to_string(id),
    description: opt.None,
    priority: 3,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: created_by,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    version: 1,
    parent_card_id: opt.None,
    card_id: card_id,
    card_title: opt.None,
    card_color: opt.None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn task_type() -> TaskType {
  TaskType(
    id: 1,
    name: "Build",
    icon: "hammer",
    capability_id: opt.None,
    tasks_count: 0,
  )
}

fn create_config(card_id: opt.Option(Int), cards: List(Card)) {
  create_dialog.Config(
    locale: locale.En,
    error: opt.None,
    title: "Do work",
    description: "",
    priority: "3",
    type_id: "1",
    card_id: card_id,
    in_flight: False,
    task_types: Loaded([task_type()]),
    cards: cards,
    on_close: "close",
    on_submit: "submit",
    on_title_changed: fn(value) { "title-" <> value },
    on_description_changed: fn(value) { "description-" <> value },
    on_priority_changed: fn(value) { "priority-" <> value },
    on_type_id_changed: fn(value) { "type-" <> value },
    on_type_options_retry_clicked: "retry",
  )
}

pub fn empty_card_detail_offers_create_card_or_task_test() {
  let policy =
    detail_policy.policy_for(card(1, opt.None, Draft), [], [], True, True)

  let assert True = policy.can_create_card
  let assert True = policy.can_create_task
}

pub fn card_group_detail_offers_create_card_only_test() {
  let parent = card(1, opt.None, Draft)
  let child = card(2, opt.Some(1), Draft)
  let policy = detail_policy.policy_for(parent, [child], [], True, True)

  let assert True = policy.can_create_card
  let assert False = policy.can_create_task
}

pub fn task_group_detail_offers_create_task_only_test() {
  let parent = card(1, opt.None, Draft)
  let policy =
    detail_policy.policy_for(parent, [], [task(9, opt.Some(1), 4)], True, True)

  let assert False = policy.can_create_card
  let assert True = policy.can_create_task
}

pub fn pool_create_task_explains_root_pool_manage_flow_impact_test() {
  let html =
    create_dialog.view(create_config(opt.None, []))
    |> element.to_document_string

  assert_contains(html, "Root Pool")
  assert_contains(html, "manage flow")
}

pub fn draft_card_create_task_does_not_auto_claim_test() {
  let html =
    create_dialog.view(create_config(opt.Some(1), [card(1, opt.None, Draft)]))
    |> element.to_document_string

  assert_contains(html, "will not be auto-claimed")
}

pub fn draft_card_create_task_explains_prepared_until_activation_test() {
  let html =
    create_dialog.view(create_config(opt.Some(1), [card(1, opt.None, Draft)]))
    |> element.to_document_string

  assert_contains(html, "prepared until this card is activated")
}

pub fn active_card_create_task_adds_task_to_pool_test() {
  let html =
    create_dialog.view(create_config(opt.Some(1), [card(1, opt.None, Active)]))
    |> element.to_document_string

  assert_contains(html, "enter the Pool")
}

pub fn active_card_create_task_explains_pool_entry_test() {
  let html =
    create_dialog.view(create_config(opt.Some(1), [card(1, opt.None, Active)]))
    |> element.to_document_string

  assert_contains(html, "available for someone with the matching capability")
}

pub fn move_card_dialog_lists_only_valid_same_level_destinations_test() {
  let moving = card(3, opt.Some(1), Draft)
  let root = card(1, opt.None, Draft)
  let valid_parent = card(2, opt.None, Draft)
  let too_deep = card(4, opt.Some(2), Draft)
  let task_group = Card(..card(5, opt.None, Draft), task_count: 1)

  let options =
    detail_policy.move_destinations(moving, [
      root,
      valid_parent,
      too_deep,
      task_group,
    ])

  let assert [destination] = options
  let assert 2 = destination.id
}

pub fn delete_disabled_when_card_has_operational_history_test() {
  let policy =
    detail_policy.policy_for(
      Card(..card(1, opt.None, Draft), task_count: 1),
      [],
      [task(9, opt.Some(1), 4)],
      True,
      True,
    )

  let assert False = policy.can_delete
  let assert opt.Some(detail_policy.CardHasOperationalHistory) =
    policy.delete_disabled_reason
}

pub fn closed_card_detail_disables_create_actions_with_reason_test() {
  let policy =
    detail_policy.policy_for(card(1, opt.None, Closed), [], [], True, True)

  let assert False = policy.can_create_card
  let assert False = policy.can_create_task
  let assert opt.Some(detail_policy.ClosedCardCannotReceiveChildren) =
    policy.create_disabled_reason
}

pub fn move_card_dialog_explains_invalid_destinations_test() {
  let root = card(1, opt.None, Draft)
  let moving = card(3, opt.Some(1), Draft)
  let task_group = Card(..card(5, opt.None, Draft), task_count: 1)
  let explanation =
    detail_policy.invalid_move_explanation(moving, task_group, [
      root,
      moving,
      task_group,
    ])

  assert_contains(explanation, "Contiene tasks directas")
}

pub fn move_policy_marks_valid_and_invalid_destinations_with_reasons_test() {
  let root = card(1, opt.None, Draft)
  let current_parent = card(2, opt.Some(1), Draft)
  let moving = card(3, opt.Some(2), Draft)
  let valid_parent = card(4, opt.Some(1), Draft)
  let child = card(5, opt.Some(3), Draft)
  let closed_parent = card(6, opt.Some(1), Closed)

  let entries =
    detail_policy.move_destination_entries(
      moving,
      [
        root,
        current_parent,
        moving,
        valid_parent,
        child,
        closed_parent,
      ],
      [],
    )

  let assert [
    detail_policy.InvalidDestination(_, detail_policy.WouldChangeLevel),
    detail_policy.InvalidDestination(_, detail_policy.SameParent),
    detail_policy.InvalidDestination(_, detail_policy.SelfOrDescendant),
    detail_policy.ValidDestination(destination),
    detail_policy.InvalidDestination(_, detail_policy.SelfOrDescendant),
    detail_policy.InvalidDestination(_, detail_policy.ClosedDestination),
  ] = entries
  let assert 4 = destination.id
}

pub fn root_card_cannot_move_reason_is_spanish_test() {
  let reason =
    detail_policy.move_unavailable_reason(
      card(1, opt.None, Draft),
      [
        card(1, opt.None, Draft),
      ],
      [],
    )

  let assert opt.Some(detail_policy.RootCardCannotMove) = reason
  assert_contains(
    detail_policy.move_blocked_reason_label(detail_policy.RootCardCannotMove),
    "cards raiz",
  )
}

pub fn create_task_never_auto_claims_for_creator_test() {
  let created = task(9, opt.Some(1), 4)

  let assert False = detail_policy.task_is_auto_claimed(created, 4)
}
