//// Project restriction checks for Bearer tokens.

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/services/api_tokens.{
  type VerifiedToken, AllProjects, ProjectOnly,
}
import scrumbringer_server/services/persisted_field

pub type AccessError {
  InvalidRouteId
  ProjectMismatch
  ResourceNotFound
  DbError(pog.QueryError)
}

pub fn require_token_project(
  db: pog.Connection,
  token: VerifiedToken,
  method: http.Method,
  segments: List(String),
) -> Result(Nil, AccessError) {
  case token.project_grant {
    AllProjects -> Ok(Nil)
    ProjectOnly(project_id) ->
      require_matching_project(db, project_id, method, segments)
  }
}

fn require_matching_project(
  db: pog.Connection,
  allowed_project_id: Int,
  method: http.Method,
  segments: List(String),
) -> Result(Nil, AccessError) {
  use request_project_id <- result.try(project_id_for_request(
    db,
    method,
    segments,
  ))

  case request_project_id {
    None -> Ok(Nil)
    Some(project_id) if project_id == allowed_project_id -> Ok(Nil)
    Some(_) -> Error(ProjectMismatch)
  }
}

fn project_id_for_request(
  db: pog.Connection,
  method: http.Method,
  segments: List(String),
) -> Result(Option(Int), AccessError) {
  case method, segments {
    http.Get, ["api", "v1", "projects"] -> Ok(None)

    _, ["api", "v1", "projects", project_id, "tasks"] ->
      parse_project_id(project_id)
    _, ["api", "v1", "projects", project_id, "cards"] ->
      parse_project_id(project_id)
    _, ["api", "v1", "projects", project_id, "milestones"] ->
      parse_project_id(project_id)

    _, ["api", "v1", "tasks", task_id] -> task_project_id(db, task_id)
    _, ["api", "v1", "tasks", task_id, "claim"] -> task_project_id(db, task_id)
    _, ["api", "v1", "tasks", task_id, "release"] ->
      task_project_id(db, task_id)
    _, ["api", "v1", "tasks", task_id, "complete"] ->
      task_project_id(db, task_id)
    _, ["api", "v1", "tasks", task_id, "notes"] -> task_project_id(db, task_id)

    _, ["api", "v1", "cards", card_id] -> card_project_id(db, card_id)
    _, ["api", "v1", "cards", card_id, "notes"] -> card_project_id(db, card_id)
    _, ["api", "v1", "cards", card_id, "notes", _] ->
      card_project_id(db, card_id)

    _, ["api", "v1", "milestones", milestone_id] ->
      milestone_project_id(db, milestone_id)

    _, _ -> Ok(None)
  }
}

fn parse_project_id(value: String) -> Result(Option(Int), AccessError) {
  case int.parse(value) {
    Ok(project_id) -> Ok(Some(project_id))
    Error(_) -> Error(InvalidRouteId)
  }
}

fn task_project_id(
  db: pog.Connection,
  task_id: String,
) -> Result(Option(Int), AccessError) {
  use id <- result.try(parse_id(task_id))
  select_project_id(db, "select project_id from tasks where id = $1", id)
}

fn card_project_id(
  db: pog.Connection,
  card_id: String,
) -> Result(Option(Int), AccessError) {
  use id <- result.try(parse_id(card_id))
  select_project_id(db, "select project_id from cards where id = $1", id)
}

fn milestone_project_id(
  db: pog.Connection,
  milestone_id: String,
) -> Result(Option(Int), AccessError) {
  use id <- result.try(parse_id(milestone_id))
  select_project_id(db, "select project_id from milestones where id = $1", id)
}

fn parse_id(value: String) -> Result(Int, AccessError) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(InvalidRouteId)
  }
}

fn select_project_id(
  db: pog.Connection,
  sql: String,
  id: Int,
) -> Result(Option(Int), AccessError) {
  let decoder = {
    use project_id <- decode.field(0, decode.int)
    decode.success(project_id)
  }

  use returned <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(id))
    |> pog.returning(decoder)
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  case persisted_field.query_row(returned.rows) {
    Ok(project_id) -> Ok(Some(project_id))
    Error(_) -> Error(ResourceNotFound)
  }
}
