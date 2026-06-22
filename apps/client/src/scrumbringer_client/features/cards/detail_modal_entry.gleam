//// Shared entry for rendering card detail modal.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element as el
import lustre/event

import domain/card.{type Card, color_to_string, state_to_string}
import domain/remote.{type Remote, Loaded}
import domain/task as domain_task
import domain/task_status as domain_task_status
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/attribute_value

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
    Some(card) -> view_host(config, card)
  }
}

fn view_host(config: Config(msg), card: Card) -> el.Element(msg) {
  let attributes = [
    attribute.attribute("card-id", int.to_string(card.id)),
    attribute.attribute("locale", locale.serialize(config.locale)),
    attribute.attribute("project-id", int.to_string(card.project_id)),
    attribute.attribute(
      "can-manage-notes",
      attribute_value.boolean(config.can_manage_notes),
    ),
    attribute.attribute(
      "can-manage-structure",
      attribute_value.boolean(config.can_manage_structure),
    ),
    attribute.attribute(
      "can-execute-work",
      attribute_value.boolean(config.can_execute_work),
    ),
    attribute.property("card", card_to_json(card)),
    attribute.property("cards", cards_to_json(config.cards)),
    attribute.property("tasks", tasks_to_json(config.tasks)),
    event.on("create-task-requested", config.on_create_task),
    event.on("create-card-requested", config.on_create_card),
    event.on("activate-requested", config.on_activate_card),
    event.on("move-card-requested", config.on_move_card),
    event.on("delete-card-requested", config.on_delete_card),
    event.on("close-requested", config.on_close),
  ]
  let attributes = case config.current_user_id {
    Some(user_id) -> [
      attribute.attribute("current-user-id", int.to_string(user_id)),
      ..attributes
    ]
    None -> attributes
  }

  el.element("card-detail-modal", attributes, [])
}

fn card_to_json(card: Card) -> json.Json {
  json.object([
    #("id", json.int(card.id)),
    #("project_id", json.int(card.project_id)),
    #("parent_card_id", case card.parent_card_id {
      Some(id) -> json.int(id)
      None -> json.null()
    }),
    #("title", json.string(card.title)),
    #("description", json.string(card.description)),
    #("color", case card.color {
      Some(c) -> json.string(color_to_string(c))
      None -> json.null()
    }),
    #("state", json.string(state_to_string(card.state))),
    #("task_count", json.int(card.task_count)),
    #("completed_count", json.int(card.completed_count)),
    #("created_by", json.int(card.created_by)),
    #("created_at", json.string(card.created_at)),
    #("due_date", optional_string(card.due_date)),
    #("has_new_notes", json.bool(card.has_new_notes)),
  ])
}

fn cards_to_json(cards: List(Card)) -> json.Json {
  json.array(cards, card_to_json)
}

fn tasks_to_json(tasks: List(domain_task.Task)) -> json.Json {
  json.array(tasks, task_to_json)
}

fn task_to_json(task: domain_task.Task) -> json.Json {
  json.object([
    #("id", json.int(task.id)),
    #("project_id", json.int(task.project_id)),
    #("type_id", json.int(task.type_id)),
    #(
      "task_type",
      json.object([
        #("id", json.int(task.task_type.id)),
        #("name", json.string(task.task_type.name)),
        #("icon", json.string(task.task_type.icon)),
      ]),
    ),
    #("ongoing_by", case task.ongoing_by {
      Some(ob) -> json.object([#("user_id", json.int(ob.user_id))])
      None -> json.null()
    }),
    #("title", json.string(task.title)),
    #("description", optional_string(task.description)),
    #("priority", json.int(task.priority)),
    #(
      "status",
      json.string(
        domain_task_status.task_status_to_string(domain_task.status(task)),
      ),
    ),
    #(
      "work_state",
      json.string(
        domain_task_status.work_state_to_string(domain_task.work_state(task)),
      ),
    ),
    #("created_by", json.int(task.created_by)),
    #("claimed_by", optional_int(domain_task.claimed_by(task))),
    #("claimed_at", optional_string(domain_task.claimed_at(task))),
    #("completed_at", optional_string(domain_task.completed_at(task))),
    #("created_at", json.string(task.created_at)),
    #("due_date", optional_string(task.due_date)),
    #("version", json.int(task.version)),
    #("card_id", optional_int(task.card_id)),
    #("card_title", optional_string(task.card_title)),
    #("card_color", case task.card_color {
      Some(c) -> json.string(color_to_string(c))
      None -> json.null()
    }),
  ])
}

fn optional_int(value: Option(Int)) -> json.Json {
  case value {
    Some(id) -> json.int(id)
    None -> json.null()
  }
}

fn optional_string(value: Option(String)) -> json.Json {
  case value {
    Some(value) -> json.string(value)
    None -> json.null()
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
