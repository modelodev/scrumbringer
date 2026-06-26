import domain/card.{type Card, type CardPhase, Active, Card, Closed, Draft}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/features/cards/card_target
import scrumbringer_client/features/cards/card_target_field
import scrumbringer_client/features/cards/card_target_picker
import scrumbringer_client/features/cards/policy as card_policy
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/i18n/locale

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn duplicate_titles_resolve_only_with_path_or_id_test() {
  let options = card_target.plan_scope_targets(cards(), depth_names())
  let assert Ok(first) = list.find(options, fn(option) { option.id == 2 })
  let assert Ok(second) = list.find(options, fn(option) { option.id == 4 })

  assert_contains(first.label, "Checkout")
  assert_contains(first.label, "Root / Web / Checkout")
  assert_contains(first.label, "Story #2")
  assert_contains(second.label, "Root / API / Checkout")
  assert_contains(second.label, "Story #4")
  let assert "" = card_target.search_value_to_card_id(options, "Checkout")
  let assert "2" = card_target.search_value_to_card_id(options, first.label)
  let assert "4" = card_target.search_value_to_card_id(options, "#4")
}

pub fn plan_scope_targets_include_only_active_cards_test() {
  let labels =
    card_target.plan_scope_targets(cards(), depth_names())
    |> list.map(fn(option) { option.label })
    |> string.join(" | ")

  assert_contains(labels, "Root")
  assert_contains(labels, "Checkout")
  assert_not_contains(labels, "Draft Idea")
  assert_not_contains(labels, "Closed Release")
}

pub fn task_card_targets_include_active_leaf_cards_and_disabled_drafts_test() {
  let options = card_target.task_card_targets(cards(), depth_names())
  let ids = list.map(options, fn(option) { option.id })

  let assert [4, 6, 2] = ids
  let assert Ok(draft) = list.find(options, fn(option) { option.id == 6 })
  let assert Some(card_target.DraftTaskTargetCannotReceiveTasks) =
    draft.disabled_reason
  let reason =
    card_target.disabled_reason_label(
      locale.Es,
      card_target.DraftTaskTargetCannotReceiveTasks,
    )
  assert_contains(reason, "Borrador")
}

pub fn card_target_filters_options_by_title_path_and_id_test() {
  let options = card_target.plan_scope_targets(cards(), depth_names())

  let by_title =
    options
    |> card_target.filter_options("checkout")
    |> list.map(fn(option) { option.id })
  let by_path =
    options
    |> card_target.filter_options("api")
    |> list.map(fn(option) { option.id })
  let by_id =
    options
    |> card_target.filter_options("#4")
    |> list.map(fn(option) { option.id })

  let assert [4, 2] = by_title
  let assert [5, 4] = by_path
  let assert [4] = by_id
}

pub fn move_destination_targets_preserve_disabled_reasons_test() {
  let root = card(1, None, "Root", Active)
  let child = card(2, Some(1), "Child", Active)
  let options =
    card_target.move_destination_targets(
      [card_policy.InvalidDestination(child, card_policy.SelfOrDescendant)],
      [root, child],
      depth_names(),
    )

  let assert [option] = options
  let assert Some(reason) = option.disabled_reason
  assert_contains(
    card_target.disabled_reason_label(locale.Es, reason),
    "propia",
  )
}

pub fn card_target_field_failed_state_renders_retry_test() {
  let html =
    card_target_field.view(card_target_field.Config(
      label: "Active card",
      placeholder: "Choose an active card",
      selected_label: "",
      query: "",
      options: [
        card_target.CardTargetOption(
          id: 7,
          title: "Checkout",
          path: "Root / Checkout",
          level_name: "Story",
          label: "Root / Checkout - Story #7",
          disabled_reason: None,
        ),
      ],
      loading: False,
      error: Some("Could not load active cards"),
      disabled: False,
      empty_title: "No active cards",
      empty_body: "Choose an active card",
      loading_label: "Loading...",
      retry_label: "Retry",
      hint: None,
      show_empty: True,
      disabled_reason_label: fn(reason) {
        card_target.disabled_reason_label(locale.En, reason)
      },
      listbox_id: "task-create-card-options",
      testid_prefix: "task-create-card",
      on_query_changed: fn(_) { Nil },
      on_selected: fn(_) { Nil },
      on_retry: Some(Nil),
    ))
    |> element.to_document_string

  assert_contains(html, "Could not load active cards")
  assert_contains(html, "Retry")
  assert_contains(html, "data-testid=\"task-create-card-retry\"")
  assert_not_contains(html, "Checkout")
}

pub fn card_target_picker_hides_options_when_selected_without_query_test() {
  let options = card_target.task_card_targets(cards(), depth_names())

  let presentation =
    card_target_picker.present(
      options,
      "",
      Some(4),
      card_target_picker.CreateTask,
      "Search all",
      "Refine",
    )

  let assert [] = presentation.options
  let assert None = presentation.hint
  let assert False = presentation.show_empty
}

pub fn card_target_picker_create_task_empty_query_is_search_first_test() {
  let options =
    many_cards()
    |> card_target.task_card_targets(depth_names())

  let presentation =
    card_target_picker.present(
      options,
      "",
      None,
      card_target_picker.CreateTask,
      "Search all",
      "Refine",
    )

  let assert [] = presentation.options
  let assert Some("Search all") = presentation.hint
  let assert False = presentation.show_empty
}

pub fn card_target_picker_retarget_task_empty_query_is_search_first_test() {
  let options = card_target.task_card_targets(cards(), depth_names())

  let presentation =
    card_target_picker.present(
      options,
      "",
      None,
      card_target_picker.RetargetTask,
      "Search all",
      "Refine",
    )

  let assert [] = presentation.options
  let assert Some("Search all") = presentation.hint
  let assert False = presentation.show_empty
}

pub fn card_target_picker_scope_empty_query_keeps_actionable_suggestions_test() {
  let options = card_target.plan_scope_targets(cards(), depth_names())

  let presentation =
    card_target_picker.present(
      options,
      "",
      None,
      card_target_picker.ScopeView,
      "Search all",
      "Refine",
    )

  let ids = presentation.options |> list.map(fn(option) { option.id })
  let assert True = presentation.options != []
  let assert False = list.contains(ids, 6)
  let assert Some("Search all") = presentation.hint
  let assert False = presentation.show_empty
}

pub fn card_target_picker_scope_empty_query_limits_suggestions_test() {
  let options =
    many_cards()
    |> card_target.plan_scope_targets(depth_names())

  let presentation =
    card_target_picker.present(
      options,
      "",
      None,
      card_target_picker.ScopeView,
      "Search all",
      "Refine",
    )

  let assert 8 = list.length(presentation.options)
  let assert Some("Search all") = presentation.hint
  let assert False = presentation.show_empty
}

pub fn card_target_picker_limits_search_results_and_shows_refine_hint_test() {
  let options =
    many_cards()
    |> card_target.plan_scope_targets(depth_names())
    |> card_target.filter_options("Card")

  let presentation =
    card_target_picker.present(
      options,
      "Card",
      None,
      card_target_picker.ScopeView,
      "Search all",
      "Refine",
    )

  let assert 20 = list.length(presentation.options)
  let assert Some("Refine") = presentation.hint
  let assert False = presentation.show_empty
}

pub fn card_target_picker_search_without_matches_shows_empty_state_test() {
  let options = card_target.plan_scope_targets(cards(), depth_names())

  let presentation =
    card_target_picker.present(
      options |> card_target.filter_options("missing"),
      "missing",
      None,
      card_target_picker.CreateTask,
      "Search all",
      "Refine",
    )

  let assert [] = presentation.options
  let assert None = presentation.hint
  let assert True = presentation.show_empty
}

fn depth_names() -> List(scope_view.DepthName) {
  [
    scope_view.DepthName(1, "Initiative", "Initiatives"),
    scope_view.DepthName(2, "Feature", "Features"),
    scope_view.DepthName(3, "Story", "Stories"),
  ]
}

fn cards() -> List(Card) {
  [
    card(1, None, "Root", Active),
    card(3, Some(1), "Web", Active),
    card(2, Some(3), "Checkout", Active),
    card(5, Some(1), "API", Active),
    card(4, Some(5), "Checkout", Active),
    card(6, Some(1), "Draft Idea", Draft),
    card(7, Some(1), "Closed Release", Closed),
  ]
}

fn many_cards() -> List(Card) {
  list.range(1, 30)
  |> list.map(fn(id) { card(id, None, "Card " <> int.to_string(id), Active) })
}

fn card(
  id: Int,
  parent_card_id: Option(Int),
  title: String,
  state: CardPhase,
) -> Card {
  Card(
    id: id,
    project_id: 1,
    parent_card_id: parent_card_id,
    title: title,
    description: "",
    color: None,
    state: state,
    task_count: 0,
    closed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}
