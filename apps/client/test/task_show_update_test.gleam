import gleam/dict
import gleam/option as opt
import gleam/string
import lustre/effect
import lustre/element

import domain/activity/entity.{type ActivityEvent, ActivityEvent}
import domain/activity/id as activity_id
import domain/activity/kind
import domain/activity/subject.{ActivityTask}
import domain/capability.{Capability}
import domain/org_role
import domain/project/id as project_id
import domain/remote
import domain/task
import domain/task/id as task_id
import domain/task_state
import domain/task_status
import domain/task_type.{TaskType, TaskTypeInline}
import domain/user.{User}
import domain/user/id as user_id
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/task_show_config
import scrumbringer_client/features/pool/update as pool_update
import scrumbringer_client/ui/show_tabs

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn test_context() -> pool_update.Context {
  pool_update.Context(member_refresh: fn(model) { #(model, effect.none()) })
}

fn task_show_callbacks() -> task_show_config.Callbacks(String) {
  task_show_config.Callbacks(
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
    on_edit_submitted: "edit-submit",
    on_note_dialog_opened: "note-open",
    on_note_dialog_closed: "note-close",
    on_note_content_changed: fn(value) { "note:" <> value },
    on_note_submitted: "note-submit",
    on_note_delete: fn(_) { "note-delete" },
    on_note_pin_toggle: fn(_, _) { "note-pin" },
    on_activity_more: "activity-more",
    on_open_parent_card: fn(_) { "open-card" },
    on_claim: fn(_, _) { "claim" },
    on_release: fn(_, _) { "release" },
    on_complete: fn(_, _) { "complete" },
    on_delete: fn(_) { "delete" },
  )
}

fn task_show_view(model: client_state.Model, task_id: Int) {
  task_show_config.view(
    model.ui.locale,
    model.member.pool,
    model.member.dependencies,
    model.member.notes,
    model.core.user |> opt.map(fn(user) { user.id }),
    False,
    [],
    [],
    task_id,
    task_show_callbacks(),
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
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: opt.None,
    version: 3,
    parent_card_id: opt.None,
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

  task.Task(..sample_task(), state: state)
}

fn sample_activity(id: Int) -> ActivityEvent {
  ActivityEvent(
    id: activity_id.new(id),
    project_id: project_id.new(1),
    subject: ActivityTask(task_id.new(42)),
    kind: kind.TaskClaimed,
    actor_user_id: user_id.new(7),
    actor_label: "admin@example.com",
    summary: "Task claimed",
    related_subject: opt.None,
    created_at: "2026-06-22T10:30:00Z",
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

pub fn task_show_open_sets_default_tasks_tab_test() {
  let model = model_with_task()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskShowOpened(42),
      test_context(),
    )

  let assert show_tabs.TaskDetailsTab = next.member.pool.member_task_show_tab
  let assert False = next.member.pool.member_task_show_editing
  let assert "Prepare release" = next.member.pool.member_task_show_edit_title
  let assert "Review release checklist." =
    next.member.pool.member_task_show_edit_description
}

pub fn task_show_config_uses_project_cache_when_active_list_misses_task_test() {
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
          member_task_types: remote.Loaded([
            TaskType(
              id: 1,
              name: "Bug",
              icon: "bug-ant",
              capability_id: opt.Some(5),
              tasks_count: 1,
            ),
          ]),
        ),
      )
    })

  let config =
    task_show_config.from_state(
      model.ui.locale,
      model.member.pool,
      model.member.dependencies,
      model.member.notes,
      model.core.user |> opt.map(fn(user) { user.id }),
      False,
      [],
      [Capability(id: 5, name: "Backend")],
      42,
      task_show_callbacks(),
    )

  let assert opt.Some(found) = config.task
  let assert "Prepare release" = found.title
  let assert opt.Some("Backend") = config.capability_name
}

pub fn task_show_close_resets_default_tasks_tab_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_task_show_tab: show_tabs.TaskActivityTab,
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskShowClosed,
      test_context(),
    )

  let assert show_tabs.TaskDetailsTab = next.member.pool.member_task_show_tab
  let assert False = next.member.pool.member_task_show_editing
  let assert "" = next.member.pool.member_task_show_edit_title
}

pub fn task_show_edit_submit_blank_title_sets_error_test() {
  let model =
    model_with_task()
    |> fn(model) {
      let #(opened, _fx) =
        pool_update.update(
          model,
          pool_messages.MemberTaskShowOpened(42),
          test_context(),
        )
      opened
    }
    |> fn(model) {
      let #(editing, _fx) =
        pool_update.update(
          model,
          pool_messages.MemberTaskShowEditStarted,
          test_context(),
        )
      editing
    }
    |> fn(model) {
      let #(changed, _fx) =
        pool_update.update(
          model,
          pool_messages.MemberTaskShowEditTitleChanged("   "),
          test_context(),
        )
      changed
    }

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskShowEditSubmitted,
      test_context(),
    )

  let assert True = next.member.pool.member_task_show_editing
  let assert opt.Some("Title is required") =
    next.member.pool.member_task_show_edit_error
}

pub fn task_show_surface_renders_edit_controls_for_owner_test() {
  let html =
    model_with_task()
    |> model_with_notes_task_id(42)
    |> task_show_view(42)
    |> element.to_document_string

  assert_contains(html, "task-detail-edit-toggle")
  assert_contains(html, "btn-secondary")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "Edit task")
}

pub fn task_activity_tab_renders_load_more_when_more_events_exist_test() {
  let html =
    model_with_task()
    |> model_with_notes_task_id(42)
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      let notes = member.notes
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_task_show_tab: show_tabs.TaskActivityTab,
        ),
        notes: member_notes.Model(
          ..notes,
          member_activity: remote.Loaded([sample_activity(1)]),
          member_activity_total: 2,
        ),
      )
    })
    |> task_show_view(42)
    |> element.to_document_string

  assert_contains(html, "activity-feed-more")
  assert_contains(html, "Load more (1)")
}

pub fn task_show_surface_renders_edit_controls_for_unclaimed_task_test() {
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
    |> task_show_view(42)
    |> element.to_document_string

  assert_contains(html, "task-detail-edit-toggle")
  assert_contains(html, "Edit task")
}

pub fn task_show_edit_started_allows_unclaimed_task_test() {
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
          pool_messages.MemberTaskShowOpened(42),
          test_context(),
        )
      opened
    }

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskShowEditStarted,
      test_context(),
    )

  let assert True = next.member.pool.member_task_show_editing
}

pub fn task_show_edit_started_uses_project_cache_when_active_list_misses_task_test() {
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
      pool_messages.MemberTaskShowEditStarted,
      test_context(),
    )

  let assert True = next.member.pool.member_task_show_editing
  let assert "1" = next.member.pool.member_task_show_edit_type_id
}
