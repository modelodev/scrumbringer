//// Shared activity feed JSON codec.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option

import domain/activity/entity.{type ActivityEvent, ActivityEvent}
import domain/activity/id as activity_id
import domain/activity/kind
import domain/activity/subject.{type ActivitySubject, ActivityCard, ActivityTask}
import domain/card/id as card_id
import domain/project/id as project_id
import domain/task/id as task_id
import domain/user/id as user_id

pub fn subject_decoder(
  type_field: String,
  id_field: String,
) -> decode.Decoder(ActivitySubject) {
  use subject_type <- decode.field(type_field, decode.string)
  use subject_id <- decode.field(id_field, decode.int)
  case subject_type {
    "card" -> decode.success(ActivityCard(card_id.new(subject_id)))
    "task" -> decode.success(ActivityTask(task_id.new(subject_id)))
    other ->
      decode.failure(
        ActivityCard(card_id.new(subject_id)),
        "activity subject " <> other,
      )
  }
}

pub fn activity_decoder() -> decode.Decoder(ActivityEvent) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use subject <- decode.then(subject_decoder("subject_type", "subject_id"))
  use kind_raw <- decode.field("kind", decode.string)
  use kind <- decode.then(kind_decoder(kind_raw))
  use actor_user_id <- decode.field("actor_user_id", decode.int)
  use actor_label <- decode.field("actor_label", decode.string)
  use summary <- decode.field("summary", decode.string)
  use related_subject_type <- decode.optional_field(
    "related_subject_type",
    option.None,
    decode.optional(decode.string),
  )
  use related_subject_id <- decode.optional_field(
    "related_subject_id",
    option.None,
    decode.optional(decode.int),
  )
  use created_at <- decode.field("created_at", decode.string)

  case related_subject(related_subject_type, related_subject_id) {
    Ok(related_subject) ->
      decode.success(ActivityEvent(
        id: activity_id.new(id),
        project_id: project_id.new(project_id),
        subject: subject,
        kind: kind,
        actor_user_id: user_id.new(actor_user_id),
        actor_label: actor_label,
        summary: summary,
        related_subject: related_subject,
        created_at: created_at,
      ))
    Error(message) ->
      decode.failure(
        ActivityEvent(
          id: activity_id.new(id),
          project_id: project_id.new(project_id),
          subject: subject,
          kind: kind,
          actor_user_id: user_id.new(actor_user_id),
          actor_label: actor_label,
          summary: summary,
          related_subject: option.None,
          created_at: created_at,
        ),
        message,
      )
  }
}

fn kind_decoder(raw: String) -> decode.Decoder(kind.ActivityKind) {
  case kind.parse(raw) {
    Ok(value) -> decode.success(value)
    Error(other) -> decode.failure(kind.TaskCreated, "activity kind " <> other)
  }
}

fn related_subject(
  subject_type: option.Option(String),
  subject_id: option.Option(Int),
) -> Result(option.Option(ActivitySubject), String) {
  case subject_type, subject_id {
    option.None, option.None -> Ok(option.None)
    option.Some("card"), option.Some(id) ->
      Ok(option.Some(ActivityCard(card_id.new(id))))
    option.Some("task"), option.Some(id) ->
      Ok(option.Some(ActivityTask(task_id.new(id))))
    option.Some(other), option.Some(_) ->
      Error("activity related subject " <> other)
    _, _ -> Error("activity related subject incomplete")
  }
}

pub fn subject_to_json(
  subject: ActivitySubject,
  type_field: String,
  id_field: String,
) -> List(#(String, json.Json)) {
  case subject {
    ActivityCard(note_card_id) -> [
      #(type_field, json.string("card")),
      #(id_field, json.int(card_id.to_int(note_card_id))),
    ]
    ActivityTask(note_task_id) -> [
      #(type_field, json.string("task")),
      #(id_field, json.int(task_id.to_int(note_task_id))),
    ]
  }
}

pub fn to_json(event: ActivityEvent) -> json.Json {
  let related_fields = case event.related_subject {
    option.Some(subject) ->
      subject_to_json(subject, "related_subject_type", "related_subject_id")
    option.None -> [
      #("related_subject_type", json.null()),
      #("related_subject_id", json.null()),
    ]
  }

  let fields =
    [
      #("id", json.int(activity_id.to_int(event.id))),
      #("project_id", json.int(project_id.to_int(event.project_id))),
    ]
    |> list.append(subject_to_json(event.subject, "subject_type", "subject_id"))
    |> list.append([
      #("kind", json.string(kind.to_string(event.kind))),
      #("actor_user_id", json.int(user_id.to_int(event.actor_user_id))),
      #("actor_label", json.string(event.actor_label)),
      #("summary", json.string(event.summary)),
    ])
    |> list.append(related_fields)
    |> list.append([#("created_at", json.string(event.created_at))])

  json.object(fields)
}
