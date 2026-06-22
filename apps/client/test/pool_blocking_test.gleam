import gleam/option.{None, Some}

import domain/remote.{Loaded, NotAsked}
import domain/task.{type TaskDependency, Task, TaskDependency}
import domain/task_state
import domain/task_status.{Available, Done}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/blocking

pub fn incomplete_dependencies_excludes_completed_dependencies_test() {
  let task =
    sample_task(1, [
      dependency(2, Available),
      dependency(3, Done),
    ])

  let assert [dep] = blocking.incomplete_dependencies(task)
  let assert 2 = dep.depends_on_task_id
  let assert [2] = blocking.incomplete_dependency_ids(task)
  let assert 1 =
    blocking.incomplete_dependency_count([
      dependency(2, Available),
      dependency(3, Done),
    ])
}

pub fn incomplete_dependencies_or_empty_defaults_missing_task_test() {
  let assert [] = blocking.incomplete_dependencies_or_empty(None)

  let task = sample_task(1, [dependency(2, Available)])
  let assert [dep] = blocking.incomplete_dependencies_or_empty(Some(task))
  let assert 2 = dep.depends_on_task_id
}

pub fn hidden_count_counts_blockers_not_present_in_loaded_tasks_test() {
  let visible = sample_task(2, [])

  let assert 1 = blocking.hidden_count(Loaded([visible]), [2, 3])
  let assert 2 = blocking.hidden_count(NotAsked, [2, 3])
}

fn dependency(id: Int, status) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: id,
    title: "Dependency",
    status: status,
    claimed_by: None,
  )
}

fn sample_task(id: Int, dependencies: List(TaskDependency)) {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    ongoing_by: None,
    title: "Task",
    description: None,
    priority: 2,
    state: task_state.Available,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: dependencies,
  )
}
