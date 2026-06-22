import domain/activity/activity_codec
import domain/activity/entity.{type ActivityEvent, ActivityEvent}
import domain/activity/kind
import domain/activity/subject.{ActivityCard, ActivityTask}
import domain/card/id as card_id_domain
import domain/task/id as task_id_domain
import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

pub fn task_activity_lists_real_audit_events_with_limit_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Fix callback")

  let claim_res = claim_task(handler, session, task_id)
  expect.expect_status(claim_res, 200)

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/activity?limit=1",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 200)
  let events = decode_activity(simulate.read_body(res))
  let assert [event] = events
  let ActivityEvent(
    subject: subject,
    kind: event_kind,
    summary: summary,
    actor_label: actor_label,
    ..,
  ) = event

  let assert ActivityTask(event_task_id) = subject
  task_id_domain.to_int(event_task_id) |> expect.equal(task_id)
  event_kind |> expect.equal(kind.TaskClaimed)
  summary |> expect.equal("Task claimed")
  actor_label |> expect.equal("admin@example.com")
}

pub fn task_activity_paginates_with_offset_and_metadata_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Fix callback")

  let claim_res = claim_task(handler, session, task_id)
  expect.expect_status(claim_res, 200)

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/"
          <> int.to_string(task_id)
          <> "/activity?limit=1&offset=1",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 200)
  let body = simulate.read_body(res)
  expect.expect_json_field_int(body, ["data", "pagination", "limit"], 1)
  expect.expect_json_field_int(body, ["data", "pagination", "offset"], 1)
  expect.expect_json_field_int(body, ["data", "pagination", "total"], 2)

  let events = decode_activity(body)
  let assert [event] = events
  event.kind |> expect.equal(kind.TaskCreated)
}

pub fn card_activity_includes_descendant_task_activity_items_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug")
  let assert Ok(parent_card_id) =
    fixtures.create_card(handler, session, project_id, "API Cleanup")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      parent_card_id,
      "Fix callback",
    )

  let activate_res = activate_card(handler, session, parent_card_id)
  expect.expect_status(activate_res, 200)

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/cards/" <> int.to_string(parent_card_id) <> "/activity",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 200)
  let events = decode_activity(simulate.read_body(res))

  events
  |> list.any(fn(event) {
    event.kind == kind.CardActivated
    && event.subject == ActivityCard(card_id_domain.new(parent_card_id))
  })
  |> expect.is_true

  events
  |> list.any(fn(event) {
    event.kind == kind.TaskCreated
    && event.subject == ActivityTask(task_id_domain.new(task_id))
    && event.related_subject
    == option.Some(ActivityCard(card_id_domain.new(parent_card_id)))
  })
  |> expect.is_true
}

pub fn activity_requires_project_membership_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Fix callback")
  let assert Ok(_) =
    fixtures.create_member_user(
      handler,
      db,
      "outsider@example.com",
      "outsider-token",
    )
  let assert Ok(outsider_session) =
    fixtures.login(handler, "outsider@example.com", "passwordpassword")

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/activity",
      )
      |> fixtures.with_auth(outsider_session),
    )

  expect.expect_status(res, 404)
}

pub fn activity_rejects_invalid_limit_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Fix callback")

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/activity?limit=101",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 400)
}

pub fn activity_rejects_invalid_offset_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Fix callback")

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/activity?offset=-1",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 400)
}

fn claim_task(
  handler: fixtures.Handler,
  session: fixtures.Session,
  task_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("version", json.int(1))])),
  )
}

fn activate_card(
  handler: fixtures.Handler,
  session: fixtures.Session,
  card_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int.to_string(card_id) <> "/activate",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([])),
  )
}

fn decode_activity(body: String) -> List(ActivityEvent) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)
  let decoder =
    decode.at(
      ["data", "activity"],
      decode.list(activity_codec.activity_decoder()),
    )
  let assert Ok(activity) = decode.run(dynamic, decoder)
  activity
}
