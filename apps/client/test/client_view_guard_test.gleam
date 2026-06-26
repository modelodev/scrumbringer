import gleam/dict
import gleam/list
import gleam/option as opt
import gleam/string
import lustre/element

import domain/card
import domain/org_role
import domain/people_workload.{
  type PersonWorkload, PersonWorkload, PersonWorkloadSummary, PersonWorkloadTask,
  WorkloadReserved,
}
import domain/project_role
import domain/remote
import domain/user.{User}
import domain/view_mode
import scrumbringer_client/client_state.{
  type Model, Admin, CoreModel, default_model, update_core, update_ui,
}
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/client_view
import scrumbringer_client/features/people/state as people_state
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/permissions
import scrumbringer_client/state/normalized_store

fn base_model() -> Model {
  default_model()
}

pub fn admin_page_without_user_shows_login_test() {
  let model =
    update_core(base_model(), fn(core) {
      CoreModel(..core, page: Admin, user: opt.None)
    })

  let html = client_view.view(model) |> element.to_document_string

  let assert True = string.contains(html, "login-email")
}

pub fn admin_section_without_permission_shows_not_permitted_test() {
  let model =
    update_core(base_model(), fn(core) {
      CoreModel(
        ..core,
        page: Admin,
        active_section: permissions.Invites,
        user: opt.Some(User(
          id: 1,
          email: "member@example.com",
          org_id: 1,
          org_role: org_role.Member,
          created_at: "2026-01-01T00:00:00Z",
        )),
      )
    })

  let html = client_view.view(model) |> element.to_document_string

  let assert True = string.contains(html, "not-permitted")
}

pub fn new_task_shortcut_is_global_without_open_card_test() {
  let assert client_state.PoolMsg(pool_messages.MemberCreateDialogOpened) =
    client_view.new_task_msg(base_model())
}

pub fn new_task_shortcut_uses_open_card_context_test() {
  let model =
    model_with_open_card_context([test_card(16, opt.None, card.Active)])

  let assert client_state.PoolMsg(pool_messages.MemberCreateDialogOpenedWithCard(
    16,
  )) = client_view.new_task_msg(model)
}

pub fn new_task_shortcut_ignores_draft_open_card_context_test() {
  let model =
    model_with_open_card_context([test_card(16, opt.None, card.Draft)])

  let assert client_state.PoolMsg(pool_messages.MemberCreateDialogOpened) =
    client_view.new_task_msg(model)
}

pub fn new_task_shortcut_ignores_parent_card_context_test() {
  let model =
    model_with_open_card_context([
      test_card(16, opt.None, card.Active),
      test_card(17, opt.Some(16), card.Active),
    ])

  let assert client_state.PoolMsg(pool_messages.MemberCreateDialogOpened) =
    client_view.new_task_msg(model)
}

fn model_with_open_card_context(cards: List(card.Card)) -> Model {
  base_model()
  |> update_core(fn(core) {
    CoreModel(..core, selected_project_id: opt.Some(1))
  })
  |> client_state.update_member(fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      card_show_open: opt.Some(16),
      pool: member_pool.Model(
        ..pool,
        member_cards_store: normalized_store.upsert(
          normalized_store.new(),
          1,
          cards,
          fn(card) { card.id },
        ),
      ),
    )
  })
}

pub fn mobile_admin_team_uses_team_title_test() {
  let model =
    base_model()
    |> update_core(fn(core) {
      CoreModel(
        ..core,
        page: Admin,
        active_section: permissions.Team,
        user: opt.Some(User(
          id: 1,
          email: "admin@example.com",
          org_id: 1,
          org_role: org_role.Admin,
          created_at: "2026-01-01T00:00:00Z",
        )),
      )
    })
    |> update_ui(fn(ui) { ui_state.UiModel(..ui, is_mobile: True) })

  let html = client_view.view(model) |> element.to_document_string

  let assert True = string.contains(html, "topbar-title-mobile")
  let assert True = string.contains(html, "Team")
}

pub fn mobile_admin_automation_modes_use_single_console_title_test() {
  [permissions.Workflows, permissions.TaskTemplates, permissions.RuleMetrics]
  |> list.each(fn(section) {
    let model = admin_mobile_model(section)

    let html = client_view.view(model) |> element.to_document_string

    let assert True = string.contains(html, "topbar-title-mobile")
    let assert True =
      string.contains(html, "class=\"topbar-title-mobile\">Automations<")
  })
}

pub fn member_people_view_renders_task_and_card_ctas_from_client_config_test() {
  let model =
    base_model()
    |> update_core(fn(core) {
      CoreModel(
        ..core,
        page: client_state.Member,
        user: opt.Some(User(
          id: 1,
          email: "admin@example.com",
          org_id: 1,
          org_role: org_role.Admin,
          created_at: "2026-01-01T00:00:00Z",
        )),
        selected_project_id: opt.Some(1),
      )
    })
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          view_mode: view_mode.People,
          people_workload: remote.Loaded([people_with_card_work()]),
          people_expansions: dict.from_list([#(2, people_state.Expanded)]),
        ),
      )
    })

  let html = client_view.view(model) |> element.to_document_string

  let assert True = string.contains(html, "Work for beta@example.com")
  let assert True = string.contains(html, "Open task")
  let assert True = string.contains(html, "Open card")
}

fn admin_mobile_model(section: permissions.AdminSection) -> Model {
  base_model()
  |> update_core(fn(core) {
    CoreModel(
      ..core,
      page: Admin,
      active_section: section,
      user: opt.Some(User(
        id: 1,
        email: "admin@example.com",
        org_id: 1,
        org_role: org_role.Admin,
        created_at: "2026-01-01T00:00:00Z",
      )),
    )
  })
  |> update_ui(fn(ui) { ui_state.UiModel(..ui, is_mobile: True) })
}

fn people_with_card_work() -> PersonWorkload {
  let card_task =
    PersonWorkloadTask(
      task_id: 46,
      task_version: 1,
      owner_user_id: 2,
      title: "P2 - Task Extra #46",
      task_type_name: "Bug",
      capability_name: opt.Some("Security"),
      card_id: opt.Some(4),
      card_title: opt.Some("P2 - Release Notes #4"),
      card_state: opt.Some(card.Active),
      blocked: False,
      ongoing: False,
    )

  PersonWorkload(
    user_id: 2,
    email: "beta@example.com",
    role: project_role.Member,
    state: WorkloadReserved,
    working_now: [],
    reserved: [
      card_task,
      PersonWorkloadTask(..card_task, task_id: 47, title: "Review release"),
    ],
    attention: [],
    summary: PersonWorkloadSummary(
      working_now_count: 0,
      reserved_count: 2,
      attention_count: 0,
    ),
  )
}

fn test_card(
  id: Int,
  parent_card_id: opt.Option(Int),
  state: card.CardPhase,
) -> card.Card {
  card.Card(
    id: id,
    project_id: 1,
    parent_card_id: parent_card_id,
    title: "Card",
    description: "",
    color: opt.None,
    state: state,
    task_count: 0,
    closed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    has_new_notes: False,
  )
}
