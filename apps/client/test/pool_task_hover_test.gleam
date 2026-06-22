import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/note/entity.{Note}
import domain/note/id as note_id
import domain/note/subject.{TaskNoteSubject}
import domain/org_role
import domain/project/id as project_id
import domain/task.{Task, TaskDependency}
import domain/task/id as task_id
import domain/task_state
import domain/task_status.{Available, Claimed, Done, Taken}
import domain/task_type.{TaskTypeInline}
import domain/user/id as user_id
import scrumbringer_client/features/pool/task_hover
import scrumbringer_client/i18n/locale

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn task_hover_renders_pool_specific_metadata_test() {
  let html =
    task_hover.view(task_hover.Config(
      locale: locale.En,
      task: sample_task(),
      card_title: Some("Release card"),
      age_days: 2,
      hidden_blocked_count: Some(3),
      notes: [
        sample_note(1, 7, "I checked the deployment checklist."),
        sample_note(2, 9, "OAuth setup still blocks this."),
      ],
      current_user_id: Some(7),
      on_open: "open",
    ))
    |> element.to_document_string

  assert_contains(html, "task-card-preview")
  assert_contains(html, "Card")
  assert_contains(html, "Release card")
  assert_contains(html, "Age")
  assert_contains(html, "2 days ago")
  assert_contains(html, "Description")
  assert_contains(html, "Task description")
  assert_contains(html, "Blocked by 2 tasks")
  assert_contains(html, "OAuth setup")
  assert_contains(html, "API review")
  assert_not_contains(html, "Done blocker")
  assert_contains(html, "3 blockers out of view due to filters")
  assert_contains(html, "Recent notes")
  assert_contains(html, "You")
  assert_contains(html, "User #9")
  assert_contains(html, "I checked the deployment checklist.")
  assert_contains(html, "OAuth setup still blocks this.")
  assert_contains(html, "Open task")
}

pub fn task_hover_hides_empty_optional_sections_test() {
  let html =
    task_hover.view(task_hover.Config(
      locale: locale.En,
      task: Task(
        ..sample_task(),
        description: None,
        blocked_count: 0,
        dependencies: [],
      ),
      card_title: None,
      age_days: 0,
      hidden_blocked_count: Some(0),
      notes: [],
      current_user_id: Some(7),
      on_open: "open",
    ))
    |> element.to_document_string

  assert_contains(html, "Age")
  assert_contains(html, "today")
  assert_contains(html, "Open task")
  assert_not_contains(html, "Card")
  assert_not_contains(html, "Description")
  assert_not_contains(html, "Blocked by")
  assert_not_contains(html, "blockers out of view")
  assert_not_contains(html, "Recent notes")
}

fn sample_task() {
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Task description"),
    priority: 2,
    state: task_state.Available,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: Some(10),
    card_title: Some("Release card"),
    card_color: None,
    has_new_notes: False,
    blocked_count: 2,
    dependencies: [
      TaskDependency(
        depends_on_task_id: 1,
        title: "OAuth setup",
        status: Available,
        claimed_by: None,
      ),
      TaskDependency(
        depends_on_task_id: 2,
        title: "API review",
        status: Claimed(Taken),
        claimed_by: None,
      ),
      TaskDependency(
        depends_on_task_id: 3,
        title: "Done blocker",
        status: Done,
        claimed_by: None,
      ),
    ],
  )
}

fn sample_note(id: Int, user_id_value: Int, content: String) {
  Note(
    id: note_id.new(id),
    project_id: project_id.new(1),
    subject: TaskNoteSubject(task_id.new(42)),
    user_id: user_id.new(user_id_value),
    content: content,
    url: None,
    pinned: False,
    created_at: "2026-06-02T12:00:00Z",
    updated_at: "2026-06-02T12:00:00Z",
    author_email: "user@example.com",
    author_project_role: None,
    author_org_role: org_role.Member,
  )
}
