import gleam/int
import gleam/option.{None}
import gleam/string
import lustre/element
import support/domain_fixtures
import support/render_assertions

import domain/remote.{Loaded}
import domain/task.{type Task, type TaskDependency, Task}

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/view_config as pool_view

fn pool_callbacks() -> pool_view.Callbacks(String) {
  pool_view.Callbacks(
    on_drag_moved: fn(_, _) { "drag-moved" },
    on_drag_ended: "drag-ended",
    on_create_opened: "create-open",
    on_capability_scope_change: fn(_) { "capability-scope" },
    on_type_filter_change: fn(_) { "type-filter" },
    on_capability_filter_change: fn(_) { "capability-filter" },
    on_search_change: fn(_) { "search" },
    on_visibility_change: fn(_) { "visibility" },
    on_view_mode_change: fn(_) { "view-mode" },
    on_now_working_pause: "pause",
    on_now_working_start: fn(_) { "start" },
    on_claim: fn(_, _) { "claim" },
    on_release: fn(_, _) { "release" },
    on_close: fn(_, _) { "close" },
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

fn pool_context(model: client_state.Model) {
  pool_view.Context(
    locale: model.ui.locale,
    theme: model.ui.theme,
    has_active_projects: False,
    healthy_pool_limit: 20,
    current_user_id: None,
    active_task_id: None,
    now_working_sessions: [],
    cards: [],
    capabilities: [],
    pool: model.member.pool,
    now_working: model.member.now_working,
    skills: model.member.skills,
    notes: model.member.notes,
    positions: model.member.positions,
    callbacks: pool_callbacks(),
  )
}

fn make_dependency(depends_on_task_id: Int) -> TaskDependency {
  domain_fixtures.dependency(depends_on_task_id)
}

fn make_task(
  id: Int,
  blocked_count: Int,
  dependencies: List(TaskDependency),
) -> Task {
  Task(
    ..domain_fixtures.task(id, "Task " <> int.to_string(id), 1),
    blocked_count: blocked_count,
    dependencies: dependencies,
  )
}

pub fn pool_card_applies_highlight_classes_test() {
  let source = make_task(1, 1, [make_dependency(2)])
  let target = make_task(2, 0, [])
  let other = make_task(3, 0, [])

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: Loaded([source, target, other]),
          member_highlight_state: member_pool.BlockingHighlight(1, [2], 0),
        ),
      )
    })

  let source_html =
    pool_view.view_task_card(pool_context(model), source)
    |> element.to_document_string

  let target_html =
    pool_view.view_task_card(pool_context(model), target)
    |> element.to_document_string

  let other_html =
    pool_view.view_task_card(pool_context(model), other)
    |> element.to_document_string

  render_assertions.contains(source_html, "is-highlight-source")
  render_assertions.contains(source_html, "highlight-warning")
  render_assertions.contains(target_html, "is-highlight-target")
  render_assertions.contains(target_html, "highlight-warning")
  render_assertions.contains(other_html, "is-highlight-dimmed")
}

pub fn pool_card_shows_hidden_blockers_message_test() {
  let source = make_task(1, 1, [make_dependency(2)])

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: Loaded([source]),
          member_highlight_state: member_pool.BlockingHighlight(1, [2], 1),
        ),
      )
    })

  let html =
    pool_view.view_task_card(pool_context(model), source)
    |> element.to_document_string

  let has_hidden_message =
    string.contains(html, "1 bloqueadoras fuera de vista por filtros")
    || string.contains(html, "1 blockers out of view due to filters")

  let assert True = has_hidden_message
}

pub fn pool_card_applies_created_highlight_info_class_test() {
  let created = make_task(5, 0, [])
  let other = make_task(6, 0, [])

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: Loaded([created, other]),
          member_highlight_state: member_pool.CreatedHighlight(5),
        ),
      )
    })

  let created_html =
    pool_view.view_task_card(pool_context(model), created)
    |> element.to_document_string

  let other_html =
    pool_view.view_task_card(pool_context(model), other)
    |> element.to_document_string

  render_assertions.contains(created_html, "is-highlight-source")
  render_assertions.contains(created_html, "highlight-info")
  render_assertions.not_contains(other_html, "highlight-info")
}
