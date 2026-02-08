//// Shared entry for rendering card detail modal.

import gleam/dynamic/decode
import gleam/list
import gleam/option
import lustre/element as el

import domain/remote.{Loaded}
import domain/task as domain_task
import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/ui/card_detail_host
import scrumbringer_client/utils/card_queries

pub type Config {
  Config(
    can_manage_notes: Bool,
    on_create_task: decode.Decoder(Msg),
    on_close: decode.Decoder(Msg),
  )
}

pub fn view(model: Model, config: Config) -> el.Element(Msg) {
  case model.member.pool.card_detail_open {
    option.None -> el.none()
    option.Some(card_id) -> {
      let card_opt = card_queries.find_card(model, card_id)

      case card_opt {
        option.None -> el.none()
        option.Some(card) -> {
          let current_user_id = case model.core.user {
            option.Some(user) -> user.id
            option.None -> 0
          }

          card_detail_host.view(card_detail_host.Config(
            card: card,
            tasks: get_card_tasks(model, card_id),
            locale: model.ui.locale,
            current_user_id: current_user_id,
            can_manage_notes: config.can_manage_notes,
            on_create_task: config.on_create_task,
            on_close: config.on_close,
          ))
        }
      }
    }
  }
}

fn get_card_tasks(model: Model, card_id: Int) -> List(domain_task.Task) {
  case model.member.pool.member_tasks {
    Loaded(tasks) ->
      list.filter(tasks, fn(t) {
        case t.card_id {
          option.Some(cid) -> cid == card_id
          option.None -> False
        }
      })
    _ -> []
  }
}
