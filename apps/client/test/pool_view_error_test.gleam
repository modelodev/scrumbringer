import gleam/list
import gleam/option as opt
import gleam/string
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
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/view_config as pool_view

fn base_model() -> Model {
  default_model()
}

fn pool_callbacks() -> pool_view.Callbacks(String) {
  pool_view.Callbacks(
    on_drag_moved: fn(_, _) { "drag-moved" },
    on_drag_ended: "drag-ended",
    on_create_opened: "create-open",
    on_now_working_pause: "pause",
    on_now_working_start: fn(_) { "start" },
    on_claim: fn(_, _) { "claim" },
    on_release: fn(_, _) { "release" },
    on_complete: fn(_, _) { "complete" },
    on_open: fn(_) { "open" },
    on_hover_opened: fn(_) { "hover-open" },
    on_hover_closed: "hover-close",
    on_focused: fn(_) { "focus" },
    on_blurred: "blur",
    on_drag_started: fn(_, _, _) { "drag-start" },
    on_touch_started: fn(_, _, _) { "touch-start" },
    on_touch_ended: fn(_) { "touch-end" },
  )
}

fn pool_context(model: Model) {
  pool_view.Context(
    locale: model.ui.locale,
    theme: model.ui.theme,
    has_active_projects: has_active_projects(model),
    current_user_id: opt.Some(1),
    active_task_id: opt.None,
    now_working_sessions: [],
    cards: [],
    pool: model.member.pool,
    now_working: model.member.now_working,
    skills: model.member.skills,
    notes: model.member.notes,
    positions: model.member.positions,
    callbacks: pool_callbacks(),
  )
}

fn has_active_projects(model: Model) -> Bool {
  case model.core.projects {
    Loaded(projects) -> !list.is_empty(projects)
    _ -> False
  }
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
    pool_view.view_pool_main(pool_context(base_model()), test_user())
    |> element.to_document_string

  let assert True = string.contains(html, "No projects yet")
}

pub fn view_pool_main_shows_tasks_error_test() {
  let project =
    Project(
      id: 1,
      name: "Core",
      my_role: project_role.Manager,
      created_at: "2026-01-01T00:00:00Z",
      members_count: 1,
      card_depth_names: [],
    )

  let model =
    base_model()
    |> update_core(fn(core) { CoreModel(..core, projects: Loaded([project])) })
    |> update_member(fn(member) {
      let pool = member.pool

      MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: Failed(domain_api_error.ApiError(
            status: 500,
            code: "SERVER_ERROR",
            message: "Boom",
          )),
        ),
      )
    })

  let html =
    pool_view.view_pool_main(pool_context(model), test_user())
    |> element.to_document_string

  let assert True = string.contains(html, "class=\"error\"")
  let assert True = string.contains(html, "Boom")
}
