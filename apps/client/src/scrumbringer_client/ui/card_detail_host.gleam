import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option as opt

import lustre/attribute
import lustre/element
import lustre/event

import domain/card.{type Card, type CardState, Cerrada, EnCurso, Pendiente}
import domain/task.{type Task}
import domain/task_status as domain_task_status

import scrumbringer_client/i18n/locale

pub type Config(msg) {
  Config(
    card: Card,
    tasks: List(Task),
    locale: locale.Locale,
    current_user_id: Int,
    can_manage_notes: Bool,
    on_create_task: decode.Decoder(msg),
    on_close: decode.Decoder(msg),
  )
}

pub fn view(config: Config(msg)) -> element.Element(msg) {
  let Config(
    card: card,
    tasks: tasks,
    locale: loc,
    current_user_id: current_user_id,
    can_manage_notes: can_manage_notes,
    on_create_task: on_create_task,
    on_close: on_close,
  ) = config

  element.element(
    "card-detail-modal",
    [
      attribute.attribute("card-id", int.to_string(card.id)),
      attribute.attribute("locale", locale.serialize(loc)),
      attribute.attribute("current-user-id", int.to_string(current_user_id)),
      attribute.attribute("project-id", int.to_string(card.project_id)),
      attribute.attribute("can-manage-notes", bool_to_string(can_manage_notes)),
      attribute.property("card", card_to_json(card)),
      attribute.property("tasks", tasks_to_json(tasks)),
      event.on("create-task-requested", on_create_task),
      event.on("close-requested", on_close),
    ],
    [],
  )
}

fn card_to_json(card: Card) -> json.Json {
  json.object([
    #("id", json.int(card.id)),
    #("project_id", json.int(card.project_id)),
    #("title", json.string(card.title)),
    #("description", json.string(card.description)),
    #("color", case card.color {
      opt.Some(c) -> json.string(c)
      opt.None -> json.null()
    }),
    #("state", json.string(card_state_to_string(card.state))),
    #("task_count", json.int(card.task_count)),
    #("completed_count", json.int(card.completed_count)),
    #("created_by", json.int(card.created_by)),
    #("created_at", json.string(card.created_at)),
    #("has_new_notes", json.bool(card.has_new_notes)),
  ])
}

fn card_state_to_string(state: CardState) -> String {
  case state {
    Pendiente -> "pendiente"
    EnCurso -> "en_curso"
    Cerrada -> "cerrada"
  }
}

fn tasks_to_json(tasks: List(Task)) -> json.Json {
  json.array(tasks, task_to_json)
}

fn task_to_json(task: Task) -> json.Json {
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
    #("work_state", json.string(work_state_to_string(task.work_state))),
    #("created_by", json.int(task.created_by)),
    #("claimed_by", case task.claimed_by {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("claimed_at", case task.claimed_at {
      opt.Some(at) -> json.string(at)
      opt.None -> json.null()
    }),
    #("completed_at", case task.completed_at {
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
      opt.Some(c) -> json.string(c)
      opt.None -> json.null()
    }),
  ])
}

fn work_state_to_string(state: domain_task_status.WorkState) -> String {
  case state {
    domain_task_status.WorkAvailable -> "available"
    domain_task_status.WorkClaimed -> "claimed"
    domain_task_status.WorkOngoing -> "ongoing"
    domain_task_status.WorkCompleted -> "completed"
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
