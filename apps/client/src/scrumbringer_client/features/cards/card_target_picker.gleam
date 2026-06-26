//// Presentation policy for card target pickers.

import gleam/list
import gleam/option.{type Option, None, Some}

import scrumbringer_client/features/cards/card_target.{
  type CardTargetOption, CardTargetOption,
}

pub type Intent {
  CreateTask
  RetargetTask
  ScopeView
}

pub type Presentation {
  Presentation(
    options: List(CardTargetOption),
    hint: Option(String),
    show_empty: Bool,
  )
}

pub fn present(
  options: List(CardTargetOption),
  query: String,
  selected_card_id: Option(Int),
  intent: Intent,
  search_all_hint: String,
  refine_search_hint: String,
) -> Presentation {
  case query, selected_card_id {
    "", Some(_) -> hidden()
    "", None -> empty_query(options, intent, search_all_hint)
    _, _ -> search_results(options, refine_search_hint)
  }
}

fn hidden() -> Presentation {
  Presentation(options: [], hint: None, show_empty: False)
}

fn empty_query(
  options: List(CardTargetOption),
  intent: Intent,
  search_all_hint: String,
) -> Presentation {
  case intent {
    CreateTask | RetargetTask ->
      Presentation(options: [], hint: Some(search_all_hint), show_empty: False)
    ScopeView -> scope_suggestions(options, search_all_hint)
  }
}

fn scope_suggestions(
  options: List(CardTargetOption),
  search_all_hint: String,
) -> Presentation {
  let visible =
    options
    |> enabled_only
    |> take(8)

  Presentation(
    options: visible,
    hint: Some(search_all_hint),
    show_empty: list.is_empty(visible),
  )
}

fn search_results(
  options: List(CardTargetOption),
  refine_search_hint: String,
) -> Presentation {
  let visible = take(options, 20)
  let hint = case list.length(options) > 20 {
    True -> Some(refine_search_hint)
    False -> None
  }

  Presentation(options: visible, hint: hint, show_empty: list.is_empty(visible))
}

fn enabled_only(options: List(CardTargetOption)) -> List(CardTargetOption) {
  options
  |> list.filter(fn(option) {
    let CardTargetOption(disabled_reason: disabled_reason, ..) = option
    disabled_reason == None
  })
}

fn take(items: List(a), limit: Int) -> List(a) {
  take_loop(items, limit, [])
}

fn take_loop(items: List(a), limit: Int, acc: List(a)) -> List(a) {
  case items, limit <= 0 {
    _, True -> list.reverse(acc)
    [], False -> list.reverse(acc)
    [item, ..rest], False -> take_loop(rest, limit - 1, [item, ..acc])
  }
}
