//// Audit event seed scenario.
////
//// Replays deterministic task-created, claim/release/reclaim, and closed
//// events so activity and metrics surfaces have realistic historical data.

import domain/task/state as task_state
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_db
import scrumbringer_server/use_case/audit_events_db

pub type TaskRef {
  TaskRef(
    task_id: Int,
    project_id: Int,
    execution_state: task_state.TaskExecutionState,
    created_at: String,
    created_by: Int,
    claimed_by: Option(Int),
  )
}

pub type Context {
  Context(
    org_id: Int,
    admin_id: Int,
    user_ids: List(Int),
    task_ids: List(Int),
    task_refs: List(TaskRef),
    user_count: Int,
    inactive_user_count: Int,
    date_range_days: Int,
  )
}

pub fn build(db: pog.Connection, context: Context) -> Result(Int, String) {
  case context.task_refs {
    [] -> Ok(0)
    seeds -> {
      let created_events =
        seeds
        |> list.map(fn(seed) {
          seed_db.AuditEventInsertOptions(
            org_id: context.org_id,
            project_id: seed.project_id,
            task_id: seed.task_id,
            actor_user_id: seed.created_by,
            event_type: audit_events_db.TaskCreated,
            created_at: Some(seed.created_at),
          )
        })

      let per_audit_events =
        seeds
        |> list.index_map(fn(seed, idx) {
          audit_event_options_for_seed(seed, idx, context)
        })
        |> list.flatten

      let per_user_events = first_claim_events_for_users(context, seeds)

      let all_events =
        created_events
        |> list.append(per_audit_events)
        |> list.append(per_user_events)

      use _ <- result.try(
        list.try_map(all_events, fn(opts) {
          seed_db.insert_audit_event(db, opts)
        }),
      )

      Ok(list.length(all_events))
    }
  }
}

fn audit_event_options_for_seed(
  seed: TaskRef,
  idx: Int,
  context: Context,
) -> List(seed_db.AuditEventInsertOptions) {
  let actor_id = case seed.claimed_by {
    Some(user_id) -> user_id
    None -> seed.created_by
  }
  let days_ago = int.max(1, { idx % context.date_range_days } + 1)
  let claim_time = timestamp_days_hours(days_ago, 2 + { idx % 4 })
  let release_time = timestamp_days_hours(days_ago, 6 + { idx % 5 })
  let reclaim_time = timestamp_days_hours(days_ago, 10 + { idx % 6 })
  let complete_time = timestamp_days_hours(days_ago, 14 + { idx % 8 })

  let claim_event = case seed.execution_state {
    task_state.Claimed(..) ->
      Some(seed_db.AuditEventInsertOptions(
        org_id: context.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: audit_events_db.TaskClaimed,
        created_at: Some(claim_time),
      ))
    task_state.Closed(..) ->
      Some(seed_db.AuditEventInsertOptions(
        org_id: context.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: audit_events_db.TaskClaimed,
        created_at: Some(claim_time),
      ))
    task_state.Available -> None
  }

  let release_event = case idx % 4 == 0 {
    True ->
      Some(seed_db.AuditEventInsertOptions(
        org_id: context.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: audit_events_db.TaskReleased,
        created_at: Some(release_time),
      ))
    False -> None
  }

  let reclaim_event = case idx % 6 == 0 {
    True ->
      Some(seed_db.AuditEventInsertOptions(
        org_id: context.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: audit_events_db.TaskClaimed,
        created_at: Some(reclaim_time),
      ))
    False -> None
  }

  let complete_event = case seed.execution_state {
    task_state.Closed(..) ->
      Some(seed_db.AuditEventInsertOptions(
        org_id: context.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: audit_events_db.TaskClosed,
        created_at: Some(complete_time),
      ))
    task_state.Available | task_state.Claimed(..) -> None
  }

  compact_options([claim_event, release_event, reclaim_event, complete_event])
}

fn first_claim_events_for_users(
  context: Context,
  seeds: List(TaskRef),
) -> List(seed_db.AuditEventInsertOptions) {
  let active_count = context.user_count - 1 - context.inactive_user_count
  let active_users =
    list.drop(context.user_ids, 1)
    |> list.take(active_count)
  let login_days = context.date_range_days / 2
  let offsets = [1, 2, 8, 30]

  active_users
  |> list.index_map(fn(user_id, idx) {
    let seed =
      task_ref_at(
        seeds,
        idx,
        TaskRef(
          task_id: list_at_int(context.task_ids, 0, 0),
          project_id: context.org_id,
          execution_state: claimed_state_template(task_state.Taken),
          created_at: timestamp_days_hours(login_days, 0),
          created_by: context.admin_id,
          claimed_by: Some(user_id),
        ),
      )
    let hours = list_at_int(offsets, idx, 2)
    seed_db.AuditEventInsertOptions(
      org_id: context.org_id,
      project_id: seed.project_id,
      task_id: seed.task_id,
      actor_user_id: user_id,
      event_type: audit_events_db.TaskClaimed,
      created_at: Some(timestamp_days_hours(login_days, hours)),
    )
  })
}

fn timestamp_days_hours(days: Int, hours: Int) -> String {
  "NOW() - INTERVAL '"
  <> int.to_string(days)
  <> " days' + INTERVAL '"
  <> int.to_string(hours)
  <> " hours'"
}

fn compact_options(items: List(Option(a))) -> List(a) {
  items
  |> list.fold([], fn(acc, item) {
    case item {
      Some(value) -> [value, ..acc]
      None -> acc
    }
  })
  |> list.reverse
}

fn task_ref_at(items: List(TaskRef), idx: Int, default: TaskRef) -> TaskRef {
  case idx, items {
    _, [] -> default
    0, [first, ..] -> first
    n, [_, ..rest] -> task_ref_at(rest, n - 1, default)
  }
}

fn list_at_int(items: List(Int), idx: Int, default: Int) -> Int {
  case idx, items {
    _, [] -> default
    0, [first, ..] -> first
    n, [_, ..rest] -> list_at_int(rest, n - 1, default)
  }
}

fn claimed_state_template(
  mode: task_state.TaskClaimMode,
) -> task_state.TaskExecutionState {
  task_state.Claimed(claimed_by: 0, claimed_at: "", mode: mode)
}
