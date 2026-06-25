//// JSON codec for task execution state.

import gleam/dynamic/decode
import gleam/json.{type Json}

import domain/task/state.{
  type TaskClaimMode, type TaskClosedReason, type TaskExecutionState, Available,
  Claimed, Closed, ClosedByAncestor, ClosedByClaimant, ManuallyClosed, Ongoing,
  Taken,
}

pub fn decoder() -> decode.Decoder(TaskExecutionState) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "available" -> decode.success(Available)
    "claimed" -> {
      use claimed_by <- decode.field("claimed_by", decode.int)
      use claimed_at <- decode.field("claimed_at", decode.string)
      use mode <- decode.field("mode", claim_mode_decoder())
      decode.success(Claimed(
        claimed_by: claimed_by,
        claimed_at: claimed_at,
        mode: mode,
      ))
    }
    "closed" -> {
      use reason <- decode.field("reason", closed_reason_decoder())
      use closed_at <- decode.field("closed_at", decode.string)
      use closed_by <- decode.field("closed_by", decode.int)
      decode.success(Closed(
        reason: reason,
        closed_at: closed_at,
        closed_by: closed_by,
      ))
    }
    _ -> decode.failure(Available, "TaskExecutionState")
  }
}

pub fn to_json(state: TaskExecutionState) -> Json {
  case state {
    Available ->
      json.object([
        #("type", json.string("available")),
      ])
    Claimed(claimed_by, claimed_at, mode) ->
      json.object([
        #("type", json.string("claimed")),
        #("claimed_by", json.int(claimed_by)),
        #("claimed_at", json.string(claimed_at)),
        #("mode", claim_mode_to_json(mode)),
      ])
    Closed(reason, closed_at, closed_by) ->
      json.object([
        #("type", json.string("closed")),
        #("reason", closed_reason_to_json(reason)),
        #("closed_at", json.string(closed_at)),
        #("closed_by", json.int(closed_by)),
      ])
  }
}

fn claim_mode_decoder() -> decode.Decoder(TaskClaimMode) {
  use value <- decode.then(decode.string)
  case value {
    "taken" -> decode.success(Taken)
    "ongoing" -> decode.success(Ongoing)
    _ -> decode.failure(Taken, "TaskClaimMode")
  }
}

fn claim_mode_to_json(mode: TaskClaimMode) -> Json {
  case mode {
    Taken -> json.string("taken")
    Ongoing -> json.string("ongoing")
  }
}

fn closed_reason_decoder() -> decode.Decoder(TaskClosedReason) {
  use value <- decode.then(decode.string)
  case value {
    "done" -> decode.success(ClosedByClaimant)
    "manually_closed" -> decode.success(ManuallyClosed)
    "closed_by_ancestor" -> decode.success(ClosedByAncestor)
    _ -> decode.failure(ManuallyClosed, "TaskClosedReason")
  }
}

fn closed_reason_to_json(reason: TaskClosedReason) -> Json {
  case reason {
    ClosedByClaimant -> json.string("done")
    ManuallyClosed -> json.string("manually_closed")
    ClosedByAncestor -> json.string("closed_by_ancestor")
  }
}
