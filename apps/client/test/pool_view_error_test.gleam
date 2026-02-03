import gleam/string
import gleeunit/should
import lustre/element

import domain/api_error as domain_api_error
import domain/org_role
import domain/project.{Project}
import domain/project_role
import domain/remote.{Failed, Loaded}
import domain/user.{type User, User}

import scrumbringer_client/client_state.{
  type Model, CoreModel, default_model, update_core, update_member,
}
import scrumbringer_client/client_state/member.{MemberModel}
import scrumbringer_client/features/pool/view as pool_view

fn base_model() -> Model {
  default_model()
}

fn test_user() -> User {
  User(
    id: 1,
    email: "member@example.com",
    org_id: 1,
    org_role: org_role.Member,
    created_at: "2026-01-01T00:00:00Z",
  )
}

pub fn view_pool_main_shows_no_projects_empty_state_test() {
  let html =
    pool_view.view_pool_main(base_model(), test_user())
    |> element.to_document_string

  string.contains(html, "No projects yet") |> should.be_true
}

pub fn view_pool_main_shows_tasks_error_test() {
  let project =
    Project(
      id: 1,
      name: "Core",
      my_role: project_role.Manager,
      created_at: "2026-01-01T00:00:00Z",
      members_count: 1,
    )

  let model =
    base_model()
    |> update_core(fn(core) { CoreModel(..core, projects: Loaded([project])) })
    |> update_member(fn(member) {
      MemberModel(
        ..member,
        member_tasks: Failed(domain_api_error.ApiError(
          status: 500,
          code: "SERVER_ERROR",
          message: "Boom",
        )),
      )
    })

  let html =
    pool_view.view_pool_main(model, test_user()) |> element.to_document_string

  string.contains(html, "class=\"error\"") |> should.be_true
  string.contains(html, "Boom") |> should.be_true
}
