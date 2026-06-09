//// Card query helpers for Scrumbringer client.
////
//// ## Mission
////
//// Provides shared helper functions to query cards from loaded card sources.
//// These helpers are used across multiple features (admin, member, pool).
////
//// ## Responsibilities
////
//// - Find card by ID
//// - Get cards for current project
////
//// ## Non-responsibilities
////
//// - Card CRUD operations (see api/cards.gleam)
//// - Card state management (see features/admin/cards.gleam)

import gleam/list
import gleam/option

import domain/card.{type Card, type CardColor}
import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, Task}
import scrumbringer_client/state/normalized_store.{type NormalizedStore}

/// Find a card by ID in the loaded cards list.
pub fn find_card(
  member_cards_store: NormalizedStore(Int, Card),
  admin_cards: Remote(List(Card)),
  card_id: Int,
) -> option.Option(Card) {
  case normalized_store.get_by_id(member_cards_store, card_id) {
    option.Some(card) -> option.Some(card)
    option.None ->
      case admin_cards {
        Loaded(cards) ->
          list.find(cards, fn(card) { card.id == card_id })
          |> option.from_result
        _ -> option.None
      }
  }
}

/// Get all cards for the currently selected project.
pub fn get_project_cards(
  member_cards_store: NormalizedStore(Int, Card),
  admin_cards: Remote(List(Card)),
  selected_project_id: option.Option(Int),
) -> List(Card) {
  case selected_project_id {
    option.Some(project_id) -> {
      let store_cards =
        normalized_store.get_by_project(member_cards_store, project_id)

      case list.is_empty(store_cards) {
        True ->
          case admin_cards {
            Loaded(cards) ->
              list.filter(cards, fn(card) { card.project_id == project_id })
            _ -> []
          }
        False -> store_cards
      }
    }
    option.None -> []
  }
}

/// Resolve card title and color for a task using a provided cards list.
pub fn resolve_task_card_info(
  cards: List(Card),
  task: Task,
) -> #(option.Option(String), option.Option(CardColor)) {
  let Task(card_id: card_id, card_title: card_title, card_color: card_color, ..) =
    task

  case card_title {
    option.Some(ct) -> #(option.Some(ct), card_color)
    option.None -> {
      case card_id {
        option.Some(cid) ->
          case list.find(cards, fn(c) { c.id == cid }) {
            Ok(card) -> #(option.Some(card.title), card.color)
            Error(_) -> #(option.None, option.None)
          }
        option.None -> #(option.None, option.None)
      }
    }
  }
}
