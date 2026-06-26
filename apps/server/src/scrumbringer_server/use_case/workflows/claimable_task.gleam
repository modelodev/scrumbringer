//// Typed boundary for task claim commands.

import domain/task as domain_task
import gleam/dynamic/decode
import gleam/option
import gleam/result
import pog

pub opaque type ClaimableTask {
  ClaimableTask(task_id: Int)
}

pub type ClaimabilityError {
  MissingCard
  InactiveCardLineage
  DbError(pog.QueryError)
}

pub fn from_task(
  db: pog.Connection,
  task: domain_task.Task,
) -> Result(ClaimableTask, ClaimabilityError) {
  use card_id <- result.try(
    task.card_id
    |> option.to_result(MissingCard),
  )
  use claimable <- result.try(card_is_claimable(db, card_id))

  case claimable {
    True -> Ok(ClaimableTask(task_id: task.id))
    False -> Error(InactiveCardLineage)
  }
}

pub fn id(task: ClaimableTask) -> Int {
  let ClaimableTask(task_id: task_id) = task
  task_id
}

fn card_is_claimable(
  db: pog.Connection,
  card_id: Int,
) -> Result(Bool, ClaimabilityError) {
  pog.query("SELECT public.task_card_claimable($1)")
  |> pog.parameter(pog.int(card_id))
  |> pog.returning(bool_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [claimable] -> Ok(claimable)
      _ -> Ok(False)
    }
  })
}

fn bool_decoder() {
  use value <- decode.field(0, decode.bool)
  decode.success(value)
}
