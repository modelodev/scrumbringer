//// JSON codecs for the people workload read model.

import domain/card
import domain/card/card_codec
import domain/people_workload.{
  type PersonWorkState, type PersonWorkload, type PersonWorkloadSummary,
  type PersonWorkloadTask, PersonWorkload, PersonWorkloadSummary,
  PersonWorkloadTask, WorkloadAvailable, parse_state, state_to_string,
}
import domain/project_role
import domain/project_role/project_role_codec
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}

pub fn people_decoder() -> decode.Decoder(List(PersonWorkload)) {
  decode.field("people", decode.list(person_decoder()), decode.success)
}

fn person_decoder() -> decode.Decoder(PersonWorkload) {
  use user_id <- decode.field("user_id", decode.int)
  use email <- decode.field("email", decode.string)
  use role <- decode.field("role", project_role_codec.project_role_decoder())
  use state <- decode.field("state", state_decoder())
  use working_now <- decode.field("working_now", decode.list(task_decoder()))
  use reserved <- decode.field("reserved", decode.list(task_decoder()))
  use attention <- decode.field("attention", decode.list(task_decoder()))
  use summary <- decode.field("summary", summary_decoder())
  decode.success(PersonWorkload(
    user_id: user_id,
    email: email,
    role: role,
    state: state,
    working_now: working_now,
    reserved: reserved,
    attention: attention,
    summary: summary,
  ))
}

fn state_decoder() -> decode.Decoder(PersonWorkState) {
  use raw <- decode.then(decode.string)
  case parse_state(raw) {
    Ok(state) -> decode.success(state)
    Error(_) -> decode.failure(WorkloadAvailable, "PersonWorkState")
  }
}

fn summary_decoder() -> decode.Decoder(PersonWorkloadSummary) {
  use working_now_count <- decode.field("working_now_count", decode.int)
  use reserved_count <- decode.field("reserved_count", decode.int)
  use attention_count <- decode.field("attention_count", decode.int)
  decode.success(PersonWorkloadSummary(
    working_now_count: working_now_count,
    reserved_count: reserved_count,
    attention_count: attention_count,
  ))
}

fn task_decoder() -> decode.Decoder(PersonWorkloadTask) {
  use task_id <- decode.field("task_id", decode.int)
  use task_version <- decode.field("task_version", decode.int)
  use owner_user_id <- decode.field("owner_user_id", decode.int)
  use title <- decode.field("title", decode.string)
  use task_type_name <- decode.field("task_type_name", decode.string)
  use capability_name <- decode.optional_field(
    "capability_name",
    None,
    decode.optional(decode.string),
  )
  use card_id <- decode.optional_field(
    "card_id",
    None,
    decode.optional(decode.int),
  )
  use card_title <- decode.optional_field(
    "card_title",
    None,
    decode.optional(decode.string),
  )
  use card_state <- decode.optional_field(
    "card_state",
    None,
    decode.optional(card_codec.card_state_decoder()),
  )
  use blocked <- decode.field("blocked", decode.bool)
  use ongoing <- decode.field("ongoing", decode.bool)
  decode.success(PersonWorkloadTask(
    task_id: task_id,
    task_version: task_version,
    owner_user_id: owner_user_id,
    title: title,
    task_type_name: task_type_name,
    capability_name: capability_name,
    card_id: card_id,
    card_title: card_title,
    card_state: card_state,
    blocked: blocked,
    ongoing: ongoing,
  ))
}

pub fn people_to_json(people: List(PersonWorkload)) -> json.Json {
  json.object([#("people", json.array(people, person_to_json))])
}

fn person_to_json(person: PersonWorkload) -> json.Json {
  let PersonWorkload(
    user_id: user_id,
    email: email,
    role: role,
    state: state,
    working_now: working_now,
    reserved: reserved,
    attention: attention,
    summary: summary,
  ) = person

  json.object([
    #("user_id", json.int(user_id)),
    #("email", json.string(email)),
    #("role", project_role.to_json(role)),
    #("state", json.string(state_to_string(state))),
    #("working_now", json.array(working_now, task_to_json)),
    #("reserved", json.array(reserved, task_to_json)),
    #("attention", json.array(attention, task_to_json)),
    #("summary", summary_to_json(summary)),
  ])
}

fn summary_to_json(summary: PersonWorkloadSummary) -> json.Json {
  let PersonWorkloadSummary(
    working_now_count: working_now_count,
    reserved_count: reserved_count,
    attention_count: attention_count,
  ) = summary

  json.object([
    #("working_now_count", json.int(working_now_count)),
    #("reserved_count", json.int(reserved_count)),
    #("attention_count", json.int(attention_count)),
  ])
}

fn task_to_json(task: PersonWorkloadTask) -> json.Json {
  let PersonWorkloadTask(
    task_id: task_id,
    task_version: task_version,
    owner_user_id: owner_user_id,
    title: title,
    task_type_name: task_type_name,
    capability_name: capability_name,
    card_id: card_id,
    card_title: card_title,
    card_state: card_state,
    blocked: blocked,
    ongoing: ongoing,
  ) = task

  json.object([
    #("task_id", json.int(task_id)),
    #("task_version", json.int(task_version)),
    #("owner_user_id", json.int(owner_user_id)),
    #("title", json.string(title)),
    #("task_type_name", json.string(task_type_name)),
    #("capability_name", optional_string_to_json(capability_name)),
    #("card_id", optional_int_to_json(card_id)),
    #("card_title", optional_string_to_json(card_title)),
    #("card_state", optional_card_state_to_json(card_state)),
    #("blocked", json.bool(blocked)),
    #("ongoing", json.bool(ongoing)),
  ])
}

fn optional_string_to_json(value: Option(String)) -> json.Json {
  case value {
    Some(inner) -> json.string(inner)
    None -> json.null()
  }
}

fn optional_int_to_json(value: Option(Int)) -> json.Json {
  case value {
    Some(inner) -> json.int(inner)
    None -> json.null()
  }
}

fn optional_card_state_to_json(value: Option(card.CardPhase)) -> json.Json {
  case value {
    Some(inner) -> json.string(card.state_to_string(inner))
    None -> json.null()
  }
}
