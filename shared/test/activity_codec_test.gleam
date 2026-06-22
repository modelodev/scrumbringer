import gleam/json
import gleam/list
import gleam/option
import gleam/result

import domain/activity/activity_codec
import domain/activity/entity.{ActivityEvent}
import domain/activity/id as activity_id
import domain/activity/kind
import domain/activity/subject.{ActivityCard, ActivityTask}
import domain/card/id as card_id
import domain/project/id as project_id
import domain/task/id as task_id
import domain/user/id as user_id

pub fn activity_decoder_decodes_card_event_with_related_task_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"subject_type\":\"card\",\"subject_id\":10,\"kind\":\"task_created\",\"actor_user_id\":42,\"actor_label\":\"Ana\",\"summary\":\"Ana created task Fix OAuth\",\"related_subject_type\":\"task\",\"related_subject_id\":20,\"created_at\":\"2026-06-22T10:00:00Z\"}"

  let assert Ok(ActivityEvent(
    id: decoded_id,
    project_id: decoded_project_id,
    subject: ActivityCard(decoded_card_id),
    kind: kind.TaskCreated,
    actor_user_id: decoded_user_id,
    actor_label: "Ana",
    summary: "Ana created task Fix OAuth",
    related_subject: option.Some(ActivityTask(decoded_task_id)),
    created_at: "2026-06-22T10:00:00Z",
  )) = json.parse(body, activity_codec.activity_decoder())

  let assert 1 = activity_id.to_int(decoded_id)
  let assert 2 = project_id.to_int(decoded_project_id)
  let assert 10 = card_id.to_int(decoded_card_id)
  let assert 20 = task_id.to_int(decoded_task_id)
  let assert 42 = user_id.to_int(decoded_user_id)
}

pub fn activity_decoder_rejects_invalid_kind_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"subject_type\":\"task\",\"subject_id\":20,\"kind\":\"hover_opened\",\"actor_user_id\":42,\"actor_label\":\"Ana\",\"summary\":\"noise\",\"created_at\":\"2026-06-22T10:00:00Z\"}"

  let assert Error(_) = json.parse(body, activity_codec.activity_decoder())
}

pub fn activity_decoder_rejects_incomplete_related_subject_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"subject_type\":\"task\",\"subject_id\":20,\"kind\":\"task_claimed\",\"actor_user_id\":42,\"actor_label\":\"Ana\",\"summary\":\"Ana claimed task\",\"related_subject_type\":\"card\",\"created_at\":\"2026-06-22T10:00:00Z\"}"

  let assert Error(_) = json.parse(body, activity_codec.activity_decoder())
}

pub fn activity_to_json_roundtrips_task_event_test() {
  let event =
    ActivityEvent(
      id: activity_id.new(9),
      project_id: project_id.new(2),
      subject: ActivityTask(task_id.new(20)),
      kind: kind.TaskClaimed,
      actor_user_id: user_id.new(42),
      actor_label: "Ana",
      summary: "Ana claimed task",
      related_subject: option.None,
      created_at: "2026-06-22T11:00:00Z",
    )

  let encoded = event |> activity_codec.to_json |> json.to_string
  let assert Ok(ActivityEvent(
    subject: ActivityTask(decoded_task_id),
    kind: kind.TaskClaimed,
    related_subject: option.None,
    ..,
  )) = json.parse(encoded, activity_codec.activity_decoder())
  let assert 20 = task_id.to_int(decoded_task_id)
}

pub fn activity_kind_covers_audit_schema_values_test() {
  let schema_values = [
    "task_created",
    "task_claimed",
    "task_released",
    "task_closed",
    "card_activated",
    "card_closed",
    "card_moved",
    "task_dependency_added",
    "task_dependency_removed",
  ]

  let assert True =
    list.all(schema_values, fn(value) { kind.parse(value) |> result.is_ok })
}
