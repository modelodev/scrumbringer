import gleam/list
import gleam/result
import pog
import scrumbringer_server/sql

pub type SetCapabilitiesError {
  InvalidCapabilityId(Int)
  DbError(pog.QueryError)
}

pub fn get_selected_capability_ids(
  db: pog.Connection,
  user_id: Int,
  org_id: Int,
) -> Result(List(Int), pog.QueryError) {
  use returned <- result.try(sql.user_capabilities_list(db, user_id, org_id))

  returned.rows
  |> list.map(fn(row) { row.capability_id })
  |> Ok
}

pub fn set_selected_capability_ids(
  db: pog.Connection,
  user_id: Int,
  org_id: Int,
  capability_ids: List(Int),
) -> Result(List(Int), SetCapabilitiesError) {
  let capability_ids = dedupe_ints(capability_ids)

  pog.transaction(db, fn(tx) {
    use _ <- result.try(validate_capability_ids(tx, org_id, capability_ids))

    use _ <- result.try(
      sql.user_capabilities_delete_all(tx, user_id)
      |> result.map(fn(_) { Nil })
      |> result.map_error(DbError),
    )

    use _ <- result.try(insert_all(tx, user_id, capability_ids))

    Ok(capability_ids)
  })
  |> result.map_error(transaction_error_to_set_error)
}

fn validate_capability_ids(
  db: pog.Connection,
  org_id: Int,
  capability_ids: List(Int),
) -> Result(Nil, SetCapabilitiesError) {
  case capability_ids {
    [] -> Ok(Nil)

    [capability_id, ..rest] -> {
      case sql.capabilities_is_in_org(db, capability_id, org_id) {
        Ok(pog.Returned(rows: [row, ..], ..)) ->
          case row.ok {
            True -> validate_capability_ids(db, org_id, rest)
            False -> Error(InvalidCapabilityId(capability_id))
          }

        Ok(pog.Returned(rows: [], ..)) ->
          Error(InvalidCapabilityId(capability_id))
        Error(e) -> Error(DbError(e))
      }
    }
  }
}

fn insert_all(
  db: pog.Connection,
  user_id: Int,
  capability_ids: List(Int),
) -> Result(Nil, SetCapabilitiesError) {
  case capability_ids {
    [] -> Ok(Nil)

    [capability_id, ..rest] -> {
      use _ <- result.try(
        sql.user_capabilities_insert(db, user_id, capability_id)
        |> result.map(fn(_) { Nil })
        |> result.map_error(DbError),
      )

      insert_all(db, user_id, rest)
    }
  }
}

fn dedupe_ints(values: List(Int)) -> List(Int) {
  dedupe_ints_loop(values, [])
}

fn dedupe_ints_loop(values: List(Int), acc: List(Int)) -> List(Int) {
  case values {
    [] -> list.reverse(acc)

    [value, ..rest] ->
      case int_list_contains(acc, value) {
        True -> dedupe_ints_loop(rest, acc)
        False -> dedupe_ints_loop(rest, [value, ..acc])
      }
  }
}

fn int_list_contains(values: List(Int), target: Int) -> Bool {
  case values {
    [] -> False
    [x, ..rest] -> x == target || int_list_contains(rest, target)
  }
}

fn transaction_error_to_set_error(
  error: pog.TransactionError(SetCapabilitiesError),
) -> SetCapabilitiesError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> DbError(err)
  }
}
