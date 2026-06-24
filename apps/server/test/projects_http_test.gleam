import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

const secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

fn create_user_via_invite(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
  email: String,
  invite_token: String,
) {
  insert_invite_link_active(db, invite_token, email)

  let req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string(invite_token)),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)
}

fn promote_user_to_org_admin(db: pog.Connection, email: String) {
  let assert Ok(_) =
    pog.query("update users set org_role = 'admin' where email = $1")
    |> pog.parameter(pog.text(email))
    |> pog.execute(db)

  Nil
}

pub fn non_org_admin_cannot_create_project_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  create_member_user(handler, db)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  expect.expect_status(member_login_res, 200)

  let session = find_cookie_value(member_login_res.headers, "sb_session")
  let csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let req =
    simulate.request(http.Post, "/api/v1/projects")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(project_create_json("Nope"))

  let res = handler(req)
  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn project_create_returns_and_persists_card_depth_names_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  let req =
    simulate.request(http.Post, "/api/v1/projects")
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(project_create_json("Depths"))

  let res = handler(req)
  expect.expect_status(res, 200)

  let assert Ok(dynamic) = json.parse(simulate.read_body(res), decode.dynamic)

  let depth_name_decoder = {
    use depth <- decode.field("depth", decode.int)
    use singular_name <- decode.field("singular_name", decode.string)
    use plural_name <- decode.field("plural_name", decode.string)
    decode.success(#(depth, singular_name, plural_name))
  }

  let project_decoder = {
    use depth_names <- decode.field(
      "card_depth_names",
      decode.list(depth_name_decoder),
    )
    decode.success(depth_names)
  }
  let data_decoder = {
    use depth_names <- decode.field("project", project_decoder)
    decode.success(depth_names)
  }
  let response_decoder = {
    use depth_names <- decode.field("data", data_decoder)
    decode.success(depth_names)
  }

  let assert Ok(depth_names) = decode.run(dynamic, response_decoder)
  depth_names
  |> expect.equal([
    #(1, "Initiative", "Initiatives"),
    #(2, "Feature", "Features"),
    #(3, "Task group", "Task groups"),
  ])

  let project_id =
    single_int(db, "select id from projects where name = 'Depths'", [])
  let stored_depth_count =
    single_int(
      db,
      "select count(*) from project_card_depth_names where project_id = $1",
      [pog.int(project_id)],
    )
  stored_depth_count |> expect.equal(3)

  let task_group_depth =
    single_int(
      db,
      "select depth from project_card_depth_names where project_id = $1 and plural_name = 'Task groups'",
      [pog.int(project_id)],
    )
  task_group_depth |> expect.equal(3)
}

pub fn project_create_persists_default_task_type_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  let req =
    simulate.request(http.Post, "/api/v1/projects")
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(project_create_json("Defaults"))

  let res = handler(req)
  expect.expect_status(res, 200)

  let project_id =
    single_int(db, "select id from projects where name = 'Defaults'", [])

  let default_type_count =
    single_int(
      db,
      "select count(*) from task_types where project_id = $1 and name = 'General'",
      [pog.int(project_id)],
    )
  default_type_count |> expect.equal(1)

  let task_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'General'",
      [pog.int(project_id)],
    )

  let create_task_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks",
      )
      |> request.set_cookie("sb_session", admin_session)
      |> request.set_cookie("sb_csrf", admin_csrf)
      |> request.set_header("X-CSRF", admin_csrf)
      |> simulate.json_body(
        json.object([
          #("title", json.string("First task")),
          #("description", json.string("")),
          #("priority", json.int(3)),
          #("type_id", json.int(task_type_id)),
        ]),
      ),
    )

  expect.expect_status(create_task_res, 200)
}

pub fn depth_reduction_preview_returns_affected_cards_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "Depth Preview")
  let project_id =
    single_int(db, "select id from projects where name = 'Depth Preview'", [])
  let admin_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  let root_id = insert_card(db, project_id, admin_id, "Root", 0)
  let middle_id = insert_card(db, project_id, admin_id, "Middle", root_id)
  insert_card(db, project_id, admin_id, "Leaf", middle_id)

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/depth-reduction-preview",
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(json.object([#("new_max_depth", json.int(1))]))

  let res = handler(req)
  expect.expect_status(res, 200)

  let assert Ok(dynamic) = json.parse(simulate.read_body(res), decode.dynamic)

  let affected_card_decoder = {
    use title <- decode.field("title", decode.string)
    use depth <- decode.field("depth", decode.int)
    decode.success(#(title, depth))
  }
  let data_decoder = {
    use affected_cards_count <- decode.field("affected_cards_count", decode.int)
    use affected_cards <- decode.field(
      "affected_cards",
      decode.list(affected_card_decoder),
    )
    decode.success(#(affected_cards_count, affected_cards))
  }
  let response_decoder = {
    use data <- decode.field("data", data_decoder)
    decode.success(data)
  }

  let assert Ok(#(affected_cards_count, affected_cards)) =
    decode.run(dynamic, response_decoder)
  affected_cards_count |> expect.equal(2)
  affected_cards |> expect.equal([#("Middle", 2), #("Leaf", 3)])
}

pub fn depth_reduction_marks_card_depth_rules_requires_review_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "Depth Rule Review")
  let project_id =
    single_int(
      db,
      "select id from projects where name = 'Depth Rule Review'",
      [],
    )
  let admin_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])
  let task_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'General'",
      [pog.int(project_id)],
    )
  let workflow_id =
    insert_workflow(db, project_id, admin_id, "Depth automation")
  let template_id =
    insert_task_template(db, project_id, task_type_id, admin_id, "Depth review")
  let rule_id =
    insert_card_depth_rule(db, workflow_id, template_id, "Depth three", 3)

  let update_req =
    simulate.request(
      http.Patch,
      "/api/v1/projects/" <> int_to_string(project_id),
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(project_update_json("Depth Rule Review", 2))

  let update_res = handler(update_req)
  expect.expect_status(update_res, 200)

  single_int(
    db,
    "select count(*)::int from rules where id = $1 and active = false",
    [pog.int(rule_id)],
  )
  |> expect.equal(1)

  let list_req =
    simulate.request(
      http.Get,
      "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
    )
    |> request.set_cookie("sb_session", admin_session)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 200)
  let body = simulate.read_body(list_res)

  string.contains(body, "\"type\":\"requires_review\"") |> expect.is_true
  string.contains(body, "\"reason\":\"card_depth_no_longer_exists\"")
  |> expect.is_true
}

pub fn projects_list_is_membership_scoped_sorted_and_includes_my_role_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "Zulu")
  create_project(handler, admin_session, admin_csrf, "Alpha")

  let zulu_project_id =
    single_int(db, "select id from projects where name = 'Zulu'", [])
  let alpha_project_id =
    single_int(db, "select id from projects where name = 'Alpha'", [])

  create_member_user(handler, db)
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(
    handler,
    admin_session,
    admin_csrf,
    alpha_project_id,
    member_id,
    "manager",
  )
  add_member(
    handler,
    admin_session,
    admin_csrf,
    zulu_project_id,
    member_id,
    "member",
  )

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let req =
    simulate.request(http.Get, "/api/v1/projects")
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)

  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let project_decoder = {
    use name <- decode.field("name", decode.string)
    use my_role <- decode.field("my_role", decode.string)
    decode.success(#(name, my_role))
  }

  let data_decoder = {
    use projects <- decode.field("projects", decode.list(project_decoder))
    decode.success(projects)
  }

  let response_decoder = {
    use projects <- decode.field("data", data_decoder)
    decode.success(projects)
  }

  let assert Ok(projects) = decode.run(dynamic, response_decoder)

  projects
  |> expect.equal([#("Alpha", "manager"), #("Zulu", "member")])
}

pub fn non_manager_non_org_admin_cannot_list_add_or_remove_members_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_member_user(handler, db)
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    member_id,
    "member",
  )

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let list_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 403)

  let add_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(
      json.object([#("user_id", json.int(1)), #("role", json.string("member"))]),
    )

  let add_res = handler(add_req)
  expect.expect_status(add_res, 403)

  let del_req =
    simulate.request(
      http.Delete,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/members/"
        <> int_to_string(1),
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)

  let del_res = handler(del_req)
  expect.expect_status(del_res, 403)
}

pub fn org_admin_non_project_manager_can_list_members_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "CoreList")
  let project_id =
    single_int(db, "select id from projects where name = 'CoreList'", [])

  create_user_via_invite(handler, db, "orgadmin2@example.com", "il_orgadmin2")
  promote_user_to_org_admin(db, "orgadmin2@example.com")

  let org_admin_login_res =
    login_as(handler, "orgadmin2@example.com", "passwordpassword")
  let org_admin_session =
    find_cookie_value(org_admin_login_res.headers, "sb_session")
  let org_admin_csrf = find_cookie_value(org_admin_login_res.headers, "sb_csrf")

  let list_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members",
    )
    |> request.set_cookie("sb_session", org_admin_session)
    |> request.set_cookie("sb_csrf", org_admin_csrf)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 200)
}

pub fn org_admin_non_project_manager_can_add_member_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "CoreAdd")
  let project_id =
    single_int(db, "select id from projects where name = 'CoreAdd'", [])

  create_user_via_invite(handler, db, "orgadmin3@example.com", "il_orgadmin3")
  promote_user_to_org_admin(db, "orgadmin3@example.com")

  create_user_via_invite(handler, db, "candidate1@example.com", "il_candidate1")
  let candidate_id =
    single_int(
      db,
      "select id from users where email = 'candidate1@example.com'",
      [],
    )

  let org_admin_login_res =
    login_as(handler, "orgadmin3@example.com", "passwordpassword")
  let org_admin_session =
    find_cookie_value(org_admin_login_res.headers, "sb_session")
  let org_admin_csrf = find_cookie_value(org_admin_login_res.headers, "sb_csrf")

  let add_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members",
    )
    |> request.set_cookie("sb_session", org_admin_session)
    |> request.set_cookie("sb_csrf", org_admin_csrf)
    |> request.set_header("X-CSRF", org_admin_csrf)
    |> simulate.json_body(
      json.object([
        #("user_id", json.int(candidate_id)),
        #("role", json.string("member")),
      ]),
    )

  let add_res = handler(add_req)
  expect.expect_status(add_res, 200)

  let count =
    single_int(
      db,
      "select count(*) from project_members where project_id = $1 and user_id = $2",
      [pog.int(project_id), pog.int(candidate_id)],
    )
  count |> expect.equal(1)
}

pub fn org_admin_non_project_manager_can_remove_member_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "CoreRemove")
  let project_id =
    single_int(db, "select id from projects where name = 'CoreRemove'", [])

  create_user_via_invite(handler, db, "orgadmin4@example.com", "il_orgadmin4")
  promote_user_to_org_admin(db, "orgadmin4@example.com")

  create_user_via_invite(handler, db, "candidate2@example.com", "il_candidate2")
  let candidate_id =
    single_int(
      db,
      "select id from users where email = 'candidate2@example.com'",
      [],
    )

  add_member(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    candidate_id,
    "member",
  )

  let org_admin_login_res =
    login_as(handler, "orgadmin4@example.com", "passwordpassword")
  let org_admin_session =
    find_cookie_value(org_admin_login_res.headers, "sb_session")
  let org_admin_csrf = find_cookie_value(org_admin_login_res.headers, "sb_csrf")

  let del_req =
    simulate.request(
      http.Delete,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/members/"
        <> int_to_string(candidate_id),
    )
    |> request.set_cookie("sb_session", org_admin_session)
    |> request.set_cookie("sb_csrf", org_admin_csrf)
    |> request.set_header("X-CSRF", org_admin_csrf)

  let del_res = handler(del_req)
  expect.expect_status(del_res, 204)

  let count =
    single_int(
      db,
      "select count(*) from project_members where project_id = $1 and user_id = $2",
      [pog.int(project_id), pog.int(candidate_id)],
    )
  count |> expect.equal(0)
}

pub fn org_admin_non_project_manager_can_release_all_tasks_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "CoreRelease")
  let project_id =
    single_int(db, "select id from projects where name = 'CoreRelease'", [])

  create_user_via_invite(handler, db, "orgadmin5@example.com", "il_orgadmin5")
  promote_user_to_org_admin(db, "orgadmin5@example.com")

  create_user_via_invite(handler, db, "candidate3@example.com", "il_candidate3")
  let candidate_id =
    single_int(
      db,
      "select id from users where email = 'candidate3@example.com'",
      [],
    )

  add_member(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    candidate_id,
    "member",
  )

  let org_admin_login_res =
    login_as(handler, "orgadmin5@example.com", "passwordpassword")
  let org_admin_session =
    find_cookie_value(org_admin_login_res.headers, "sb_session")
  let org_admin_csrf = find_cookie_value(org_admin_login_res.headers, "sb_csrf")

  let release_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/members/"
        <> int_to_string(candidate_id)
        <> "/release-all-tasks",
    )
    |> request.set_cookie("sb_session", org_admin_session)
    |> request.set_cookie("sb_csrf", org_admin_csrf)
    |> request.set_header("X-CSRF", org_admin_csrf)

  let release_res = handler(release_req)
  expect.expect_status(release_res, 200)
  string.contains(simulate.read_body(release_res), "released_count")
  |> expect.is_true
}

pub fn project_manager_can_still_add_member_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "CorePM")
  let project_id =
    single_int(db, "select id from projects where name = 'CorePM'", [])

  create_user_via_invite(handler, db, "pm@example.com", "il_pm")
  let pm_id =
    single_int(db, "select id from users where email = 'pm@example.com'", [])

  add_member(handler, admin_session, admin_csrf, project_id, pm_id, "manager")

  create_user_via_invite(handler, db, "candidate4@example.com", "il_candidate4")
  let candidate_id =
    single_int(
      db,
      "select id from users where email = 'candidate4@example.com'",
      [],
    )

  let pm_login_res = login_as(handler, "pm@example.com", "passwordpassword")
  let pm_session = find_cookie_value(pm_login_res.headers, "sb_session")
  let pm_csrf = find_cookie_value(pm_login_res.headers, "sb_csrf")

  let add_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members",
    )
    |> request.set_cookie("sb_session", pm_session)
    |> request.set_cookie("sb_csrf", pm_csrf)
    |> request.set_header("X-CSRF", pm_csrf)
    |> simulate.json_body(
      json.object([
        #("user_id", json.int(candidate_id)),
        #("role", json.string("member")),
      ]),
    )

  let add_res = handler(add_req)
  expect.expect_status(add_res, 200)
}

pub fn adding_member_from_different_org_is_rejected_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  insert_other_org_user(db, 2, 200)

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members",
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(
      json.object([
        #("user_id", json.int(200)),
        #("role", json.string("member")),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 422)

  let count =
    single_int(
      db,
      "select count(*) from project_members where project_id = $1 and user_id = 200",
      [pog.int(project_id)],
    )
  count |> expect.equal(0)
}

pub fn cannot_remove_last_project_manager_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "Solo")
  let project_id =
    single_int(db, "select id from projects where name = 'Solo'", [])

  let req =
    simulate.request(
      http.Delete,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members/1",
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)

  let res = handler(req)
  expect.expect_status(res, 422)

  let admin_count =
    single_int(
      db,
      "select count(*) from project_members where project_id = $1 and role = 'manager'",
      [pog.int(project_id)],
    )
  admin_count |> expect.equal(1)
}

// =============================================================================
// Role Change Tests (Story 4.2)
// =============================================================================

pub fn org_admin_can_change_member_to_manager_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "RoleTest")
  let project_id =
    single_int(db, "select id from projects where name = 'RoleTest'", [])

  create_member_user(handler, db)
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    member_id,
    "member",
  )

  // Promote member to manager
  let req =
    simulate.request(
      http.Patch,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/members/"
        <> int_to_string(member_id),
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(json.object([#("role", json.string("manager"))]))

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  string.contains(body, "\"role\":\"manager\"") |> expect.is_true
  string.contains(body, "\"previous_role\":\"member\"") |> expect.is_true

  // Verify in database
  let role =
    single_string(
      db,
      "select role from project_members where project_id = $1 and user_id = $2",
      [pog.int(project_id), pog.int(member_id)],
    )
  role |> expect.equal("manager")
}

pub fn org_admin_can_change_manager_to_member_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "DemoteTest")
  let project_id =
    single_int(db, "select id from projects where name = 'DemoteTest'", [])

  create_member_user(handler, db)
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  // Add as manager first (so we have 2 managers)
  add_member(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    member_id,
    "manager",
  )

  // Demote to member (should work since there are 2 managers)
  let req =
    simulate.request(
      http.Patch,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/members/"
        <> int_to_string(member_id),
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(json.object([#("role", json.string("member"))]))

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  string.contains(body, "\"role\":\"member\"") |> expect.is_true
  string.contains(body, "\"previous_role\":\"manager\"") |> expect.is_true
}

pub fn cannot_demote_last_project_manager_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "LastManager")
  let project_id =
    single_int(db, "select id from projects where name = 'LastManager'", [])

  // Try to demote the only manager (user_id 1)
  let req =
    simulate.request(
      http.Patch,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members/1",
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(json.object([#("role", json.string("member"))]))

  let res = handler(req)
  expect.expect_status(res, 422)

  let body = simulate.read_body(res)
  string.contains(body, "VALIDATION_ERROR") |> expect.is_true
  string.contains(body, "last") |> expect.is_true

  // Verify role unchanged in database
  let role =
    single_string(
      db,
      "select role from project_members where project_id = $1 and user_id = 1",
      [pog.int(project_id)],
    )
  role |> expect.equal("manager")
}

pub fn project_manager_cannot_change_roles_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "PermTest")
  let project_id =
    single_int(db, "select id from projects where name = 'PermTest'", [])

  create_member_user(handler, db)
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  // Add as project manager (not org admin)
  add_member(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    member_id,
    "manager",
  )

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  // Project manager tries to change role - should fail (403)
  let req =
    simulate.request(
      http.Patch,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members/1",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(json.object([#("role", json.string("member"))]))

  let res = handler(req)
  expect.expect_status(res, 403)
}

pub fn change_role_user_not_member_returns_404_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "NotMemberTest")
  let project_id =
    single_int(db, "select id from projects where name = 'NotMemberTest'", [])

  create_member_user(handler, db)
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  // Try to change role for user who is not a member
  let req =
    simulate.request(
      http.Patch,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/members/"
        <> int_to_string(member_id),
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(json.object([#("role", json.string("manager"))]))

  let res = handler(req)
  expect.expect_status(res, 404)
}

pub fn change_role_idempotent_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "IdempotentTest")
  let project_id =
    single_int(db, "select id from projects where name = 'IdempotentTest'", [])

  // Change to same role (manager -> manager)
  let req =
    simulate.request(
      http.Patch,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members/1",
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(json.object([#("role", json.string("manager"))]))

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  string.contains(body, "\"role\":\"manager\"") |> expect.is_true
  string.contains(body, "\"previous_role\":\"manager\"") |> expect.is_true
}

pub fn change_role_invalid_value_returns_400_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "InvalidRoleTest")
  let project_id =
    single_int(db, "select id from projects where name = 'InvalidRoleTest'", [])

  let req =
    simulate.request(
      http.Patch,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members/1",
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(json.object([#("role", json.string("admin"))]))

  let res = handler(req)
  expect.expect_status(res, 400)
}

fn create_project(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  name: String,
) {
  let req =
    simulate.request(http.Post, "/api/v1/projects")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(project_create_json(name))

  let res = handler(req)
  expect.expect_status(res, 200)
}

fn project_create_json(name: String) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #("healthy_pool_limit", json.int(20)),
    #(
      "card_depth_names",
      json.array(
        [
          project_depth_name_json(1, "Initiative", "Initiatives"),
          project_depth_name_json(2, "Feature", "Features"),
          project_depth_name_json(3, "Task group", "Task groups"),
        ],
        of: fn(value) { value },
      ),
    ),
  ])
}

fn project_update_json(name: String, max_depth: Int) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #("healthy_pool_limit", json.int(20)),
    #(
      "card_depth_names",
      json.array(depth_names_for_count(max_depth), of: fn(value) { value }),
    ),
  ])
}

fn depth_names_for_count(max_depth: Int) -> List(json.Json) {
  case max_depth {
    1 -> [project_depth_name_json(1, "Initiative", "Initiatives")]
    2 -> [
      project_depth_name_json(1, "Initiative", "Initiatives"),
      project_depth_name_json(2, "Feature", "Features"),
    ]
    _ -> [
      project_depth_name_json(1, "Initiative", "Initiatives"),
      project_depth_name_json(2, "Feature", "Features"),
      project_depth_name_json(3, "Task group", "Task groups"),
    ]
  }
}

fn project_depth_name_json(
  depth: Int,
  singular_name: String,
  plural_name: String,
) -> json.Json {
  json.object([
    #("depth", json.int(depth)),
    #("singular_name", json.string(singular_name)),
    #("plural_name", json.string(plural_name)),
  ])
}

fn add_member(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  user_id: Int,
  role: String,
) {
  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("user_id", json.int(user_id)),
        #("role", json.string(role)),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)
}

fn insert_other_org_user(db: pog.Connection, org_id: Int, user_id: Int) {
  let assert Ok(_) =
    pog.query("insert into organizations (id, name) values ($1, 'Other')")
    |> pog.parameter(pog.int(org_id))
    |> pog.execute(db)

  let assert Ok(_) =
    pog.query(
      "insert into users (id, email, password_hash, org_id, org_role) values ($1, $2, 'x', $3, 'member')",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text("other@example.com"))
    |> pog.parameter(pog.int(org_id))
    |> pog.execute(db)

  Nil
}

fn new_test_app() -> scrumbringer_server.App {
  let database_url = require_database_url()
  let assert Ok(app) = scrumbringer_server.new_app(secret, database_url)
  app
}

fn bootstrap_app() -> scrumbringer_server.App {
  let app = new_test_app()
  let handler = scrumbringer_server.handler(app)
  let scrumbringer_server.App(db: db, ..) = app

  reset_db(db)

  let res =
    handler(bootstrap_request("admin@example.com", "passwordpassword", "Acme"))
  expect.expect_status(res, 200)

  app
}

fn bootstrap_request(email: String, password: String, org_name: String) {
  simulate.request(http.Post, "/api/v1/auth/register")
  |> simulate.json_body(
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
      #("org_name", json.string(org_name)),
    ]),
  )
}

fn create_member_user(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
) {
  insert_invite_link_active(db, "il_member", "member@example.com")

  let req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string("il_member")),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)
}

fn login_as(
  handler: fn(wisp.Request) -> wisp.Response,
  email: String,
  password: String,
) -> wisp.Response {
  let req =
    simulate.request(http.Post, "/api/v1/auth/login")
    |> simulate.json_body(
      json.object([
        #("email", json.string(email)),
        #("password", json.string(password)),
      ]),
    )

  handler(req)
}

fn set_cookie_headers(headers: List(#(String, String))) -> List(String) {
  headers
  |> list.filter_map(fn(h) {
    case h.0 {
      "set-cookie" -> Ok(h.1)
      _ -> Error(Nil)
    }
  })
}

fn find_cookie_value(headers: List(#(String, String)), name: String) -> String {
  let target = name <> "="

  let assert Ok(header) =
    set_cookie_headers(headers)
    |> list.find(fn(h) { string.starts_with(h, target) })

  let assert Ok(#(value, _)) =
    header
    |> string.drop_start(string.length(target))
    |> string.split_once(";")

  value
}

fn require_database_url() -> String {
  case getenv("DATABASE_URL", "") {
    "" -> {
      expect.fail()
      ""
    }

    url -> url
  }
}

fn reset_db(db: pog.Connection) {
  let assert Ok(_) =
    pog.query(
      "TRUNCATE project_members, org_invite_links, org_invites, users, projects, organizations RESTART IDENTITY CASCADE",
    )
    |> pog.execute(db)

  Nil
}

fn insert_invite_link_active(db: pog.Connection, token: String, email: String) {
  let assert Ok(_) =
    pog.query(
      "insert into org_invite_links (org_id, email, token, created_by) values (1, $1, $2, 1)",
    )
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(token))
    |> pog.execute(db)

  Nil
}

fn single_int(db: pog.Connection, sql: String, params: List(pog.Value)) -> Int {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    query
    |> pog.returning(decoder)
    |> pog.execute(db)

  value
}

fn single_string(
  db: pog.Connection,
  sql: String,
  params: List(pog.Value),
) -> String {
  let decoder = {
    use value <- decode.field(0, decode.string)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    query
    |> pog.returning(decoder)
    |> pog.execute(db)

  value
}

fn insert_card(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  title: String,
  parent_card_id: Int,
) -> Int {
  single_int(
    db,
    "insert into cards (project_id, title, description, created_by, parent_card_id) values ($1, $2, '', $3, case when $4 <= 0 then null else $4 end) returning id",
    [
      pog.int(project_id),
      pog.text(title),
      pog.int(user_id),
      pog.int(parent_card_id),
    ],
  )
}

fn insert_workflow(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  name: String,
) -> Int {
  single_int(
    db,
    "insert into workflows (org_id, project_id, name, active, created_by) values (1, $1, $2, true, $3) returning id",
    [pog.int(project_id), pog.text(name), pog.int(user_id)],
  )
}

fn insert_task_template(
  db: pog.Connection,
  project_id: Int,
  task_type_id: Int,
  user_id: Int,
  name: String,
) -> Int {
  single_int(
    db,
    "insert into task_templates (org_id, project_id, name, type_id, priority, created_by) values (1, $1, $2, $3, 3, $4) returning id",
    [
      pog.int(project_id),
      pog.text(name),
      pog.int(task_type_id),
      pog.int(user_id),
    ],
  )
}

fn insert_card_depth_rule(
  db: pog.Connection,
  workflow_id: Int,
  template_id: Int,
  name: String,
  card_depth: Int,
) -> Int {
  let rule_id =
    single_int(
      db,
      "insert into rules (workflow_id, name, goal, resource_type, trigger_kind, card_depth, to_state, active) values ($1, $2, '', 'card', 'card_activated', $3, 'en_curso', true) returning id",
      [pog.int(workflow_id), pog.text(name), pog.int(card_depth)],
    )

  let assert Ok(_) =
    pog.query(
      "insert into rule_templates (rule_id, template_id, execution_order) values ($1, $2, 1)",
    )
    |> pog.parameter(pog.int(rule_id))
    |> pog.parameter(pog.int(template_id))
    |> pog.execute(db)

  rule_id
}

fn int_to_string(value: Int) -> String {
  value
  |> int_to_string_unsafe
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string_unsafe(value: Int) -> String

fn getenv(key: String, default: String) -> String {
  getenv_charlist(charlist.from_string(key), charlist.from_string(default))
  |> charlist.to_string
}

@external(erlang, "os", "getenv")
fn getenv_charlist(
  key: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist
