//// Audit log for automation configuration changes.
////
//// Records manager mutations to engines, rules, and templates without mixing
//// configuration history into task/card activity events.

import gleam/json
import gleam/result
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/service_error.{type ServiceError, DbError}

pub type EntityType {
  Engine
  Rule
  Template
}

pub type ChangeType {
  Created
  Updated
  Paused
  Reactivated
  Deleted
  Archived
}

pub fn insert(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  actor_user_id: Int,
  entity_type: EntityType,
  entity_id: Int,
  change_type: ChangeType,
  payload: json.Json,
) -> Result(Nil, ServiceError) {
  sql.automation_config_events_insert(
    db,
    org_id,
    project_id,
    actor_user_id,
    entity_type_to_string(entity_type),
    entity_id,
    change_type_to_string(change_type),
    payload,
  )
  |> result.map(fn(_) { Nil })
  |> result.map_error(DbError)
}

pub fn entity_type_to_string(entity_type: EntityType) -> String {
  case entity_type {
    Engine -> "engine"
    Rule -> "rule"
    Template -> "template"
  }
}

pub fn change_type_to_string(change_type: ChangeType) -> String {
  case change_type {
    Created -> "created"
    Updated -> "updated"
    Paused -> "paused"
    Reactivated -> "reactivated"
    Deleted -> "deleted"
    Archived -> "archived"
  }
}
