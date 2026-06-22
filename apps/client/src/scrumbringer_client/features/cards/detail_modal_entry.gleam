//// Shared entry for rendering Card Show.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element as el

import domain/card.{type Card}
import domain/remote.{type Remote, Loaded}
import domain/task as domain_task
import scrumbringer_client/components/card_detail_modal
import scrumbringer_client/i18n/locale.{type Locale}

/// Data and parent callback needed to render Card Show.
pub type Config(msg) {
  Config(
    model: card_detail_modal.Model,
    card: Option(Card),
    cards: List(Card),
    tasks: List(domain_task.Task),
    locale: Locale,
    current_user_id: Option(Int),
    can_manage_notes: Bool,
    can_manage_structure: Bool,
    can_execute_work: Bool,
    on_card_detail_msg: fn(card_detail_modal.Msg) -> msg,
  )
}

/// Render Card Show when a selected card is available.
pub fn view(config: Config(msg)) -> el.Element(msg) {
  case config.card {
    None -> el.none()
    Some(card) -> {
      card_detail_modal.hydrate(
        config.model,
        card,
        config.cards,
        config.tasks,
        config.locale,
        config.current_user_id,
        Some(card.project_id),
        config.can_manage_notes,
        config.can_manage_structure,
        config.can_execute_work,
      )
      |> card_detail_modal.view
      |> el.map(config.on_card_detail_msg)
    }
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
