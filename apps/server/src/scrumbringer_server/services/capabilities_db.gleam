import gleam/list
import gleam/result
import gleam/string
import pog
import scrumbringer_server/sql

pub type Capability {
  Capability(id: Int, org_id: Int, name: String, created_at: String)
}

pub type CreateCapabilityError {
  AlreadyExists
  DbError(pog.QueryError)
  NoRowReturned
}

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
