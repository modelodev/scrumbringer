//// Card query helpers for Scrumbringer client.
////
//// ## Mission
////
//// Provides shared helper functions to query cards from the application model.
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

import domain/card.{type Card}
import domain/remote.{Loaded}
import domain/task.{type Task, Task}
import scrumbringer_client/client_state.{type Model}
import scrumbringer_client/state/normalized_store

/// Find a card by ID in the loaded cards list.
pub fn find_card(model: Model, card_id: Int) -> option.Option(Card) {
  case
    normalized_store.get_by_id(model.member.pool.member_cards_store, card_id)
  {
    option.Some(card) -> option.Some(card)
    option.None ->
      case model.admin.cards.cards {
        Loaded(cards) ->
          list.find(cards, fn(card) { card.id == card_id })
          |> option.from_result
        _ -> option.None
      }
  }
}

/// Get all cards for the currently selected project.
pub fn get_project_cards(model: Model) -> List(Card) {
  case model.core.selected_project_id {
    option.Some(project_id) -> {
      let store_cards =
        normalized_store.get_by_project(
          model.member.pool.member_cards_store,
          project_id,
        )

      case list.is_empty(store_cards) {
        True ->
          case model.admin.cards.cards {
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

/// Resolve card title and color for a task, using task fields first and
/// falling back to loaded cards.
pub fn resolve_task_card_info(
  model: Model,
  task: Task,
) -> #(option.Option(String), option.Option(String)) {
  let Task(card_id: card_id, card_title: card_title, card_color: card_color, ..) =
    task

  case card_title {
    option.Some(ct) -> #(option.Some(ct), card_color)
    option.None -> {
      case card_id {
        option.Some(cid) ->
          case find_card(model, cid) {
            option.Some(card) -> #(option.Some(card.title), card.color)
            option.None -> #(option.None, option.None)
          }
        option.None -> #(option.None, option.None)
      }
    }
  }
}

/// Resolve card title and color for a task using a provided cards list.
pub fn resolve_task_card_info_from_cards(
  cards: List(Card),
  task: Task,
) -> #(option.Option(String), option.Option(String)) {
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
