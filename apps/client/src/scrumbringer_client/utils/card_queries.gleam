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
import scrumbringer_client/client_state.{type Model, Loaded}

/// Find a card by ID in the loaded cards list.
pub fn find_card(model: Model, card_id: Int) -> option.Option(Card) {
  case model.member.member_cards {
    Loaded(cards) ->
      list.find(cards, fn(c) { c.id == card_id })
      |> option.from_result
    _ ->
      case model.admin.cards {
        Loaded(cards) ->
          list.find(cards, fn(c) { c.id == card_id })
          |> option.from_result
        _ -> option.None
      }
  }
}

/// Get all cards for the currently selected project.
pub fn get_project_cards(model: Model) -> List(Card) {
  case model.core.selected_project_id {
    option.Some(project_id) ->
      case model.member.member_cards {
        Loaded(cards) ->
          list.filter(cards, fn(c) { c.project_id == project_id })
        _ ->
          case model.admin.cards {
            Loaded(cards) ->
              list.filter(cards, fn(c) { c.project_id == project_id })
            _ -> []
          }
      }
    option.None -> []
  }
}
