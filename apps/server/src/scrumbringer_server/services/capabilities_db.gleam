//// Database operations for organization capabilities (skills).
////
//// Capabilities represent skills or competencies that can be assigned to
//// users and required for tasks within an organization.

import gleam/list
import gleam/result
import gleam/string
import pog
import scrumbringer_server/sql

/// A capability (skill) defined within an organization.
pub type Capability {
  Capability(id: Int, org_id: Int, name: String, created_at: String)
}

/// Errors that can occur when creating a capability.
pub type CreateCapabilityError {
  AlreadyExists
  DbError(pog.QueryError)
  NoRowReturned
}

/// Lists all capabilities defined for an organization.
///
/// ## Example
/// ```gleam
/// case capabilities_db.list_capabilities_for_org(db, org_id) {
///   Ok(capabilities) -> render_skills_list(capabilities)
///   Error(_) -> Error(DatabaseError)
/// }
/// ```
pub fn list_capabilities_for_org(
  db: pog.Connection,
  org_id: Int,
) -> Result(List(Capability), pog.QueryError) {
  use returned <- result.try(sql.capabilities_list(db, org_id))

  returned.rows
  |> list.map(fn(row) {
    Capability(
      id: row.id,
      org_id: row.org_id,
      name: row.name,
      created_at: row.created_at,
    )
  })
  |> Ok
}

/// Creates a new capability for an organization.
///
/// Returns `AlreadyExists` if a capability with the same name already exists.
///
/// ## Example
/// ```gleam
/// case capabilities_db.create_capability(db, org_id, "Gleam") {
///   Ok(cap) -> Ok(cap.id)
///   Error(AlreadyExists) -> Error(DuplicateSkill)
///   Error(DbError(_)) -> Error(DatabaseError)
///   Error(NoRowReturned) -> Error(InternalError)
/// }
/// ```
pub fn create_capability(
  db: pog.Connection,
  org_id: Int,
  name: String,
) -> Result(Capability, CreateCapabilityError) {
  case sql.capabilities_create(db, org_id, name) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(Capability(
        id: row.id,
        org_id: row.org_id,
        name: row.name,
        created_at: row.created_at,
      ))

    Ok(pog.Returned(rows: [], ..)) -> Error(NoRowReturned)

    Error(error) ->
      case error {
        pog.ConstraintViolated(constraint: constraint, ..) ->
          case string.contains(constraint, "capabilities") {
            True -> Error(AlreadyExists)
            False -> Error(DbError(error))
          }

        _ -> Error(DbError(error))
      }
  }
}
