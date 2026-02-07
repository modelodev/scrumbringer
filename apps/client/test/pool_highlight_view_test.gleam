import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import domain/remote.{Loaded}
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task_state
import domain/task_type.{TaskTypeInline}

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/view as pool_view

fn make_dependency(depends_on_task_id: Int) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: depends_on_task_id,
    title: "Dependency",
    status: task_state.to_status(task_state.Available),
    claimed_by: None,
  )
}

fn make_task(
  id: Int,
  blocked_count: Int,
  dependencies: List(TaskDependency),
) -> Task {
  let state = task_state.Available

  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Task " <> int.to_string(id),
    description: Some("Task description"),
    priority: 3,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    version: 1,
    milestone_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
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
    pool_view.view_task_card(model, source)
    |> element.to_document_string

  let target_html =
    pool_view.view_task_card(model, target)
    |> element.to_document_string

  let other_html =
    pool_view.view_task_card(model, other)
    |> element.to_document_string

  string.contains(source_html, "is-highlight-source") |> should.be_true
  string.contains(source_html, "highlight-warning") |> should.be_true
  string.contains(target_html, "is-highlight-target") |> should.be_true
  string.contains(target_html, "highlight-warning") |> should.be_true
  string.contains(other_html, "is-highlight-dimmed") |> should.be_true
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
    pool_view.view_task_card(model, source)
    |> element.to_document_string

  let has_hidden_message =
    string.contains(html, "1 bloqueadoras fuera de vista por filtros")
    || string.contains(html, "1 blockers out of view due to filters")

  has_hidden_message |> should.be_true
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
    pool_view.view_task_card(model, created)
    |> element.to_document_string

  let other_html =
    pool_view.view_task_card(model, other)
    |> element.to_document_string

  string.contains(created_html, "is-highlight-source") |> should.be_true
  string.contains(created_html, "highlight-info") |> should.be_true
  string.contains(other_html, "highlight-info") |> should.be_false
}
