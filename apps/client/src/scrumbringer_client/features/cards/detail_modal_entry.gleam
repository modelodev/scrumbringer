//// Shared entry for rendering card detail modal.

import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element as el

import domain/card.{type Card}
import domain/remote.{type Remote, Loaded}
import domain/task as domain_task
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/card_detail_host

/// Data and parent callbacks needed to render the card detail custom element.
pub type Config(msg) {
  Config(
    card: Option(Card),
    cards: List(Card),
    tasks: List(domain_task.Task),
    locale: Locale,
    current_user_id: Option(Int),
    can_manage_notes: Bool,
    can_manage_structure: Bool,
    can_execute_work: Bool,
    on_create_task: decode.Decoder(msg),
    on_create_card: decode.Decoder(msg),
    on_activate_card: decode.Decoder(msg),
    on_move_card: decode.Decoder(msg),
    on_delete_card: decode.Decoder(msg),
    on_close: decode.Decoder(msg),
  )
}

/// Render the modal host when a selected card is available.
pub fn view(config: Config(msg)) -> el.Element(msg) {
  case config.card {
    None -> el.none()
    Some(card) ->
      card_detail_host.view(card_detail_host.Config(
        card: card,
        cards: config.cards,
        tasks: config.tasks,
        locale: config.locale,
        current_user_id: config.current_user_id,
        can_manage_notes: config.can_manage_notes,
        can_manage_structure: config.can_manage_structure,
        can_execute_work: config.can_execute_work,
        on_create_task: config.on_create_task,
        on_create_card: config.on_create_card,
        on_activate_card: config.on_activate_card,
        on_move_card: config.on_move_card,
        on_delete_card: config.on_delete_card,
        on_close: config.on_close,
      ))
  }
}

/// Return only the loaded tasks that belong to a card.
pub fn tasks_for_card(
  tasks: Remote(List(domain_task.Task)),
  card_id: Int,
) -> List(domain_task.Task) {
  case tasks {
    Loaded(tasks) ->
      list.filter(tasks, fn(t) {
        case t.card_id {
          Some(cid) -> cid == card_id
          None -> False
        }
      })
    _ -> []
  }
}
