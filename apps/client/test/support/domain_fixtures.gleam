import gleam/option

import domain/capability.{type Capability, Capability}
import domain/card.{type Card, Card, Draft}
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task/state as task_state
import domain/task_type.{type TaskType, TaskType, TaskTypeInline}

pub fn card(id: Int, project_id: Int, title: String) -> Card {
  Card(
    id: id,
    project_id: project_id,
    parent_card_id: option.None,
    title: title,
    description: "",
    color: option.None,
    state: Draft,
    task_count: 0,
    closed_count: 0,
    created_by: 1,
    created_at: "2026-02-01T00:00:00Z",
    due_date: option.None,
    has_new_notes: False,
  )
}

pub fn child_card(
  id: Int,
  project_id: Int,
  parent_id: Int,
  title: String,
) -> Card {
  Card(..card(id, project_id, title), parent_card_id: option.Some(parent_id))
}

pub fn card_id(card: Card) -> Int {
  let Card(id: id, ..) = card
  id
}

pub fn task(id: Int, title: String, type_id: Int) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: type_id,
    task_type: TaskTypeInline(id: type_id, name: "Bug", icon: "bug-ant"),
    ongoing_by: option.None,
    title: title,
    description: option.Some("Task description"),
    priority: 3,
    state: task_state.Available,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: option.None,
    version: 1,
    parent_card_id: option.None,
    card_id: option.None,
    card_title: option.None,
    card_color: option.None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: option.None,
  )
}

pub fn dependency(depends_on_task_id: Int) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: depends_on_task_id,
    title: "Dependency",
    state: task_state.Available,
    claimed_by: option.None,
  )
}

pub fn task_type(id: Int, name: String) -> TaskType {
  TaskType(
    id: id,
    name: name,
    icon: "bug-ant",
    capability_id: option.None,
    tasks_count: 0,
  )
}

pub fn capability(id: Int, name: String) -> Capability {
  Capability(id: id, name: name)
}
