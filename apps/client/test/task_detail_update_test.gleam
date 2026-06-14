import gleam/dict
import gleam/option as opt
import gleam/string
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
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/task_details_dialog_config as task_details_dialog
import scrumbringer_client/features/pool/update as pool_update
import scrumbringer_client/ui/task_tabs

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn test_context() -> pool_update.Context {
  pool_update.Context(member_refresh: fn(model) { #(model, effect.none()) })
}

fn task_details_callbacks() -> task_details_dialog.Callbacks(String) {
  task_details_dialog.Callbacks(
    on_close: "close",
    on_tab_clicked: fn(_) { "tab" },
    on_dependency_dialog_opened: "dependency-open",
    on_dependency_dialog_closed: "dependency-close",
    on_dependency_add_submitted: "dependency-add",
    on_dependency_search_changed: fn(value) { "dependency-search:" <> value },
    on_dependency_selected: fn(_) { "dependency-selected" },
    on_dependency_remove: fn(_) { "dependency-remove" },
    on_edit_started: "edit-start",
    on_edit_cancelled: "edit-cancel",
    on_edit_title_changed: fn(value) { "title:" <> value },
    on_edit_description_changed: fn(value) { "description:" <> value },
    on_edit_priority_changed: fn(value) { "priority:" <> value },
    on_edit_type_id_changed: fn(value) { "type:" <> value },
    on_edit_card_id_changed: fn(value) { "card:" <> value },
    on_edit_milestone_id_changed: fn(value) { "milestone:" <> value },
    on_edit_submitted: "edit-submit",
    on_note_dialog_opened: "note-open",
    on_note_dialog_closed: "note-close",
    on_note_content_changed: fn(value) { "note:" <> value },
    on_note_submitted: "note-submit",
    on_note_delete: fn(_) { "note-delete" },
    on_claim: fn(_, _) { "claim" },
    on_release: fn(_, _) { "release" },
    on_complete: fn(_, _) { "complete" },
  )
}

fn task_detail_view(model: client_state.Model, task_id: Int) {
  task_details_dialog.view(
    model.ui.locale,
    model.member.pool,
    model.member.dependencies,
    model.member.notes,
    model.core.user |> opt.map(fn(user) { user.id }),
    False,
    [],
    task_id,
    task_details_callbacks(),
  )
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

  let assert task_tabs.TasksTab = next.member.pool.member_task_detail_tab
  let assert False = next.member.pool.member_task_detail_editing
  let assert "Prepare release" = next.member.pool.member_task_detail_edit_title
  let assert "Review release checklist." =
    next.member.pool.member_task_detail_edit_description
}

pub fn task_details_config_uses_project_cache_when_active_list_misses_task_test() {
  let model =
    model_with_task()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: remote.Loaded([]),
          member_tasks_by_project: dict.from_list([#(1, [sample_task()])]),
        ),
      )
    })

  let config =
    task_details_dialog.from_state(
      model.ui.locale,
      model.member.pool,
      model.member.dependencies,
      model.member.notes,
      model.core.user |> opt.map(fn(user) { user.id }),
      False,
      [],
      42,
      task_details_callbacks(),
    )

  let assert opt.Some(found) = config.task
  let assert "Prepare release" = found.title
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

  let assert task_tabs.TasksTab = next.member.pool.member_task_detail_tab
  let assert False = next.member.pool.member_task_detail_editing
  let assert "" = next.member.pool.member_task_detail_edit_title
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

  let assert True = next.member.pool.member_task_detail_editing
  let assert opt.Some("Title is required") =
    next.member.pool.member_task_detail_edit_error
}

pub fn task_detail_modal_renders_edit_controls_for_owner_test() {
  let html =
    model_with_task()
    |> model_with_notes_task_id(42)
    |> task_detail_view(42)
    |> element.to_document_string

  assert_contains(html, "task-detail-edit-toggle")
  assert_contains(html, "Edit task")
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
    |> task_detail_view(42)
    |> element.to_document_string

  assert_contains(html, "task-detail-edit-toggle")
  assert_contains(html, "Edit task")
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

  let assert True = next.member.pool.member_task_detail_editing
}

pub fn task_detail_edit_started_uses_project_cache_when_active_list_misses_task_test() {
  let model =
    model_with_task()
    |> model_with_notes_task_id(42)
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: remote.Loaded([]),
          member_tasks_by_project: dict.from_list([#(1, [sample_task()])]),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskDetailEditStarted,
      test_context(),
    )

  let assert True = next.member.pool.member_task_detail_editing
  let assert "1" = next.member.pool.member_task_detail_edit_type_id
}
