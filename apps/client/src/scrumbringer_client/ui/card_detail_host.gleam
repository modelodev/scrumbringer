import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option as opt

import lustre/attribute
import lustre/element
import lustre/event

import domain/card.{type Card, color_to_string, state_to_string}
import domain/task as task_domain
import domain/task_status as domain_task_status

import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/attribute_value

pub type Config(msg) {
  Config(
    card: Card,
    cards: List(Card),
    tasks: List(task_domain.Task),
    locale: locale.Locale,
    current_user_id: opt.Option(Int),
    can_manage_notes: Bool,
    can_manage_structure: Bool,
    can_execute_work: Bool,
    on_create_task: decode.Decoder(msg),
    on_create_card: decode.Decoder(msg),
    on_activate_card: decode.Decoder(msg),
    on_delete_card: decode.Decoder(msg),
    on_close: decode.Decoder(msg),
  )
}

pub fn view(config: Config(msg)) -> element.Element(msg) {
  let Config(
    card: card,
    cards: cards,
    tasks: tasks,
    locale: loc,
    current_user_id: current_user_id,
    can_manage_notes: can_manage_notes,
    can_manage_structure: can_manage_structure,
    can_execute_work: can_execute_work,
    on_create_task: on_create_task,
    on_create_card: on_create_card,
    on_activate_card: on_activate_card,
    on_delete_card: on_delete_card,
    on_close: on_close,
  ) = config

  let attributes = [
    attribute.attribute("card-id", int.to_string(card.id)),
    attribute.attribute("locale", locale.serialize(loc)),
    attribute.attribute("project-id", int.to_string(card.project_id)),
    attribute.attribute(
      "can-manage-notes",
      attribute_value.boolean(can_manage_notes),
    ),
    attribute.attribute(
      "can-manage-structure",
      attribute_value.boolean(can_manage_structure),
    ),
    attribute.attribute(
      "can-execute-work",
      attribute_value.boolean(can_execute_work),
    ),
    attribute.property("card", card_to_json(card)),
    attribute.property("cards", cards_to_json(cards)),
    attribute.property("tasks", tasks_to_json(tasks)),
    event.on("create-task-requested", on_create_task),
    event.on("create-card-requested", on_create_card),
    event.on("activate-requested", on_activate_card),
    event.on("delete-card-requested", on_delete_card),
    event.on("close-requested", on_close),
  ]
  let attributes = case current_user_id {
    opt.Some(user_id) -> [
      attribute.attribute("current-user-id", int.to_string(user_id)),
      ..attributes
    ]
    opt.None -> attributes
  }

  element.element("card-detail-modal", attributes, [])
}

fn card_to_json(card: Card) -> json.Json {
  json.object([
    #("id", json.int(card.id)),
    #("project_id", json.int(card.project_id)),
    #("parent_card_id", case card.parent_card_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("title", json.string(card.title)),
    #("description", json.string(card.description)),
    #("color", case card.color {
      opt.Some(c) -> json.string(color_to_string(c))
      opt.None -> json.null()
    }),
    #("state", json.string(state_to_string(card.state))),
    #("task_count", json.int(card.task_count)),
    #("completed_count", json.int(card.completed_count)),
    #("created_by", json.int(card.created_by)),
    #("created_at", json.string(card.created_at)),
    #("has_new_notes", json.bool(card.has_new_notes)),
  ])
}

fn cards_to_json(cards: List(Card)) -> json.Json {
  json.array(cards, card_to_json)
}

fn tasks_to_json(tasks: List(task_domain.Task)) -> json.Json {
  json.array(tasks, task_to_json)
}

fn task_to_json(task: task_domain.Task) -> json.Json {
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
      opt.Some(ob) -> json.object([#("user_id", json.int(ob.user_id))])
      opt.None -> json.null()
    }),
    #("title", json.string(task.title)),
    #("description", case task.description {
      opt.Some(d) -> json.string(d)
      opt.None -> json.null()
    }),
    #("priority", json.int(task.priority)),
    #(
      "status",
      json.string(domain_task_status.task_status_to_string(task.status)),
    ),
    #(
      "work_state",
      json.string(domain_task_status.work_state_to_string(task.work_state)),
    ),
    #("created_by", json.int(task.created_by)),
    #("claimed_by", case task_domain.claimed_by(task) {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("claimed_at", case task_domain.claimed_at(task) {
      opt.Some(at) -> json.string(at)
      opt.None -> json.null()
    }),
    #("completed_at", case task_domain.completed_at(task) {
      opt.Some(at) -> json.string(at)
      opt.None -> json.null()
    }),
    #("created_at", json.string(task.created_at)),
    #("version", json.int(task.version)),
    #("card_id", case task.card_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("card_title", case task.card_title {
      opt.Some(t) -> json.string(t)
      opt.None -> json.null()
    }),
    #("card_color", case task.card_color {
      opt.Some(c) -> json.string(color_to_string(c))
      opt.None -> json.null()
    }),
  ])
}
