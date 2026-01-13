import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/sql

pub type Task {
  Task(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: Option(String),
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Option(Int),
    claimed_at: Option(String),
    completed_at: Option(String),
    created_at: String,
    version: Int,
  )
}

pub type CreateTaskError {
  InvalidTypeId
  CreateDbError(pog.QueryError)
}

pub type NotFoundOrDbError {
  NotFound
  DbError(pog.QueryError)
}

pub fn list_tasks_for_project(
  db: pog.Connection,
  project_id: Int,
  status: String,
  type_id: Int,
  capability_id: Int,
  q: String,
) -> Result(List(Task), pog.QueryError) {
  use returned <- result.try(sql.tasks_list(
    db,
    project_id,
    status,
    type_id,
    capability_id,
    q,
  ))

  returned.rows
  |> list.map(task_from_list_row)
  |> Ok
}

pub fn create_task(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
  title: String,
  description: String,
  priority: Int,
  created_by: Int,
) -> Result(Task, CreateTaskError) {
  case
    sql.tasks_create(
      db,
      type_id,
      project_id,
      title,
      description,
      priority,
      created_by,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(task_from_create_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(InvalidTypeId)
    Error(e) -> Error(CreateDbError(e))
  }
}

pub fn get_task_for_user(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Task, NotFoundOrDbError) {
  case sql.tasks_get_for_user(db, task_id, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(task_from_get_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

pub fn update_task_claimed_by_user(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  title: String,
  description: String,
  priority: Int,
  type_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  case
    sql.tasks_update(
      db,
      task_id,
      user_id,
      title,
      description,
      priority,
      type_id,
      version,
    )
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(task_from_update_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

pub fn claim_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  case sql.tasks_claim(db, task_id, user_id, version) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(task_from_claim_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

pub fn release_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  case sql.tasks_release(db, task_id, user_id, version) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(task_from_release_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

pub fn complete_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  version: Int,
) -> Result(Task, NotFoundOrDbError) {
  case sql.tasks_complete(db, task_id, user_id, version) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(task_from_complete_row(row))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

fn task_from_list_row(row: sql.TasksListRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_get_row(row: sql.TasksGetForUserRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_create_row(row: sql.TasksCreateRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_update_row(row: sql.TasksUpdateRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_claim_row(row: sql.TasksClaimRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_release_row(row: sql.TasksReleaseRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_complete_row(row: sql.TasksCompleteRow) -> Task {
  task_from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
  )
}

fn task_from_fields(
  id id: Int,
  project_id project_id: Int,
  type_id type_id: Int,
  title title: String,
  description description: String,
  priority priority: Int,
  status status: String,
  created_by created_by: Int,
  claimed_by claimed_by: Int,
  claimed_at claimed_at: String,
  completed_at completed_at: String,
  created_at created_at: String,
  version version: Int,
) -> Task {
  Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    title: title,
    description: string_option(description),
    priority: priority,
    status: status,
    created_by: created_by,
    claimed_by: int_option(claimed_by),
    claimed_at: string_option(claimed_at),
    completed_at: string_option(completed_at),
    created_at: created_at,
    version: version,
  )
}

fn int_option(value: Int) -> Option(Int) {
  case value {
    0 -> None
    v -> Some(v)
  }
}

fn string_option(value: String) -> Option(String) {
  case value {
    "" -> None
    v -> Some(v)
  }
}
