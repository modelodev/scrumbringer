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
    tasks: List(domain_task.Task),
    locale: Locale,
    current_user_id: Option(Int),
    can_manage_notes: Bool,
    on_create_task: decode.Decoder(msg),
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
        tasks: config.tasks,
        locale: config.locale,
        current_user_id: current_user_id_or_default(config.current_user_id),
        can_manage_notes: config.can_manage_notes,
        on_create_task: config.on_create_task,
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

fn current_user_id_or_default(current_user_id: Option(Int)) -> Int {
  case current_user_id {
    Some(id) -> id
    None -> 0
  }
}
