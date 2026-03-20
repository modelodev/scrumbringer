import gleam/option as opt
import gleam/string
import gleeunit/should
import lustre/effect
import lustre/element

import domain/org_role
import domain/remote
import domain/task
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import domain/user.{User}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/dialogs as pool_dialogs
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/update as pool_update
import scrumbringer_client/ui/task_tabs

fn test_context() -> pool_update.Context {
  pool_update.Context(member_refresh: fn(model) { #(model, effect.none()) })
}

fn model_with_notes_task_id(
  model: client_state.Model,
  task_id: Int,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let notes = member.notes
    member_state.MemberModel(
      ..member,
      notes: member_notes.Model(
        ..notes,
        member_notes_task_id: opt.Some(task_id),
      ),
    )
  })
}

fn sample_task() -> task.Task {
  let state =
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-03-20T15:00:00Z",
      mode: task_status.Taken,
    )

  task.Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: opt.None,
    title: "Prepare release",
    description: opt.Some("Review release checklist."),
    priority: 2,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    version: 3,
    milestone_id: opt.None,
    card_id: opt.None,
    card_title: opt.None,
    card_color: opt.None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn unclaimed_task() -> task.Task {
  let state = task_state.Available

  task.Task(
    ..sample_task(),
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
  )
}

fn model_with_task() -> client_state.Model {
  client_state.default_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(
      ..core,
      user: opt.Some(User(
        id: 7,
        email: "owner@example.com",
        org_id: 1,
        org_role: org_role.Member,
        created_at: "2026-03-20T14:00:00Z",
      )),
    )
  })
  |> client_state.update_member(fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        member_tasks: remote.Loaded([sample_task()]),
      ),
    )
  })
}

pub fn task_details_open_sets_default_tasks_tab_test() {
  let model = model_with_task()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskDetailsOpened(42),
      test_context(),
    )

  next.member.pool.member_task_detail_tab
  |> should.equal(task_tabs.TasksTab)
  next.member.pool.member_task_detail_editing |> should.equal(False)
  next.member.pool.member_task_detail_edit_title
  |> should.equal("Prepare release")
  next.member.pool.member_task_detail_edit_description
  |> should.equal("Review release checklist.")
}

pub fn task_details_close_resets_default_tasks_tab_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_task_detail_tab: task_tabs.MetricsTab,
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskDetailsClosed,
      test_context(),
    )

  next.member.pool.member_task_detail_tab
  |> should.equal(task_tabs.TasksTab)
  next.member.pool.member_task_detail_editing |> should.equal(False)
  next.member.pool.member_task_detail_edit_title |> should.equal("")
}

pub fn task_detail_edit_submit_blank_title_sets_error_test() {
  let model =
    model_with_task()
    |> fn(model) {
      let #(opened, _fx) =
        pool_update.update(
          model,
          pool_messages.MemberTaskDetailsOpened(42),
          test_context(),
        )
      opened
    }
    |> fn(model) {
      let #(editing, _fx) =
        pool_update.update(
          model,
          pool_messages.MemberTaskDetailEditStarted,
          test_context(),
        )
      editing
    }
    |> fn(model) {
      let #(changed, _fx) =
        pool_update.update(
          model,
          pool_messages.MemberTaskDetailEditTitleChanged("   "),
          test_context(),
        )
      changed
    }

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskDetailEditSubmitted,
      test_context(),
    )

  next.member.pool.member_task_detail_editing |> should.equal(True)
  next.member.pool.member_task_detail_edit_error
  |> should.equal(opt.Some("Title is required"))
}

pub fn task_detail_modal_renders_edit_controls_for_owner_test() {
  let html =
    model_with_task()
    |> model_with_notes_task_id(42)
    |> pool_dialogs.view_task_details(42)
    |> element.to_document_string

  string.contains(html, "task-detail-edit-toggle") |> should.be_true
  string.contains(html, "Edit task") |> should.be_true
}

pub fn task_detail_modal_renders_edit_controls_for_unclaimed_task_test() {
  let html =
    model_with_task()
    |> model_with_notes_task_id(42)
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: remote.Loaded([unclaimed_task()]),
        ),
      )
    })
    |> pool_dialogs.view_task_details(42)
    |> element.to_document_string

  string.contains(html, "task-detail-edit-toggle") |> should.be_true
  string.contains(html, "Edit task") |> should.be_true
}

pub fn task_detail_edit_started_allows_unclaimed_task_test() {
  let model =
    model_with_task()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: remote.Loaded([unclaimed_task()]),
        ),
      )
    })
    |> fn(model) {
      let #(opened, _fx) =
        pool_update.update(
          model,
          pool_messages.MemberTaskDetailsOpened(42),
          test_context(),
        )
      opened
    }

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskDetailEditStarted,
      test_context(),
    )

  next.member.pool.member_task_detail_editing |> should.equal(True)
}
