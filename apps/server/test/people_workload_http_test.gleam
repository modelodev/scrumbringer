import domain/card
import domain/people_workload.{
  PersonWorkload, PersonWorkloadSummary, PersonWorkloadTask, WorkloadReserved,
}
import domain/people_workload/people_workload_codec
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import pog
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

import fixtures

pub fn people_workload_includes_claimed_tasks_in_draft_cards_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "People workload")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Draft card")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Draft claimed task",
    )

  let assert Ok(admin_id) =
    fixtures.query_int(db, "select id from users where email = $1", [
      pog.text("admin@example.com"),
    ])
  mark_task_claimed(db, task_id, admin_id)

  let res = people_workload_request(handler, session, project_id)
  expect.expect_status(res, 200)

  let people = decode_people_workload(simulate.read_body(res))
  let assert Ok(admin) =
    list.find(people, fn(person) { person.user_id == admin_id })
  let assert PersonWorkload(
    state: WorkloadReserved,
    reserved: [
      PersonWorkloadTask(
        task_id: returned_task_id,
        title: "Draft claimed task",
        card_id: option.Some(returned_card_id),
        card_title: option.Some("Draft card"),
        card_state: option.Some(card.Draft),
        outside_active_work_scope: True,
        blocked: False,
        ongoing: False,
        ..,
      ),
    ],
    summary: PersonWorkloadSummary(
      working_now_count: 0,
      reserved_count: 1,
      attention_count: 0,
    ),
    ..,
  ) = admin
  returned_task_id |> expect.equal(task_id)
  returned_card_id |> expect.equal(card_id)
}

pub fn people_workload_rejects_authenticated_non_project_member_test() {
  let assert Ok(#(app, handler, admin_session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) =
    fixtures.create_project(handler, admin_session, "Private workload")
  let assert Ok(_user_id) =
    fixtures.create_member_user(
      handler,
      db,
      "outsider@example.com",
      "outsider_invite",
    )
  let assert Ok(outsider_session) =
    fixtures.login(handler, "outsider@example.com", "passwordpassword")

  let res = people_workload_request(handler, outsider_session, project_id)

  expect.expect_status(res, 403)
}

fn people_workload_request(
  handler: fixtures.Handler,
  session: fixtures.Session,
  project_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/people/workload",
    )
    |> fixtures.with_auth(session),
  )
}

fn decode_people_workload(body: String) {
  let decoder =
    decode.field("data", people_workload_codec.people_decoder(), decode.success)
  let assert Ok(people) = json.parse(from: body, using: decoder)
  people
}

fn mark_task_claimed(db: pog.Connection, task_id: Int, user_id: Int) {
  let assert Ok(_) =
    pog.query(
      "update tasks set execution_state = 'claimed', claimed_by = $1, claimed_at = now(), claimed_mode = 'taken' where id = $2",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  Nil
}
