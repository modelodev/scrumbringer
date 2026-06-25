//// Activity support seed scenarios.
////
//// Creates notes, card notes, task positions, and work sessions used by
//// product validation for people, activity, and collaboration surfaces.

import domain/task/state as task_state
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_db

pub type TaskRef {
  TaskRef(task_id: Int, execution_state: task_state.TaskExecutionState)
}

pub type Context {
  Context(
    admin_id: Int,
    user_ids: List(Int),
    active_project_ids: List(Int),
    card_ids_by_project: List(#(Int, List(Int))),
    task_refs: List(TaskRef),
    date_range_days: Int,
  )
}

pub fn build_all(db: pog.Connection, context: Context) -> Result(Nil, String) {
  use _ <- result.try(build_task_notes(db, context))
  use _ <- result.try(build_card_notes(db, context))
  use _ <- result.try(build_task_positions(db, context))
  build_work_sessions(db, context)
}

fn build_task_notes(db: pog.Connection, context: Context) -> Result(Nil, String) {
  let available_notes =
    context.task_refs
    |> list.filter(fn(seed) { seed.execution_state == task_state.Available })
    |> list.take(2)
  let claimed_notes =
    context.task_refs
    |> list.filter(fn(seed) { is_claimed_state(seed.execution_state) })
    |> list.take(2)
  let completed_notes =
    context.task_refs
    |> list.filter(fn(seed) { is_completed_state(seed.execution_state) })
    |> list.take(1)
  let noted_tasks =
    available_notes
    |> list.append(claimed_notes)
    |> list.append(completed_notes)

  use _ <- result.try(
    list.index_map(noted_tasks, fn(seed, idx) {
      seed_db.insert_task_note_with_pinned(
        db,
        seed.task_id,
        note_author_for(context.user_ids, idx, context.admin_id),
        seed_note_content(seed.execution_state, idx),
        Some(days_ago_timestamp(int.max(1, context.date_range_days - idx))),
        idx == 0,
      )
    })
    |> result.all,
  )

  Ok(Nil)
}

fn build_card_notes(db: pog.Connection, context: Context) -> Result(Nil, String) {
  let noted_cards =
    context.active_project_ids
    |> list.flat_map(fn(project_id) {
      cards_for_project(context.card_ids_by_project, project_id)
      |> list.take(1)
    })
    |> list.take(2)

  use _ <- result.try(
    list.index_map(noted_cards, fn(card_id, idx) {
      seed_db.insert_card_note(
        db,
        card_id,
        note_author_for(context.user_ids, idx + 2, context.admin_id),
        seed_card_note_content(idx),
        Some(days_ago_timestamp(int.max(1, context.date_range_days - idx - 2))),
        idx == 0,
      )
    })
    |> result.all,
  )

  Ok(Nil)
}

fn build_task_positions(
  db: pog.Connection,
  context: Context,
) -> Result(Nil, String) {
  let tasks =
    context.task_refs
    |> list.filter(fn(seed) { seed.execution_state == task_state.Available })
    |> list.map(fn(seed) { seed.task_id })
  let users = list.take(context.user_ids, 3)

  case tasks, users {
    [], _ -> Ok(Nil)
    _, [] -> Ok(Nil)
    _, _ -> {
      use _ <- result.try(
        list.index_map(tasks, fn(task_id, idx) {
          let x = { idx % 4 } * 156
          let y = { idx / 4 } * 152

          list.try_map(users, fn(user_id) {
            seed_db.insert_task_position(db, task_id, user_id, x, y)
          })
        })
        |> result.all
        |> result.map(list.flatten),
      )
      Ok(Nil)
    }
  }
}

fn build_work_sessions(
  db: pog.Connection,
  context: Context,
) -> Result(Nil, String) {
  let claimed_tasks =
    context.task_refs
    |> list.filter(fn(seed) { is_claimed_state(seed.execution_state) })
    |> list.map(fn(seed) { seed.task_id })
  let completed_tasks =
    context.task_refs
    |> list.filter(fn(seed) { is_completed_state(seed.execution_state) })
    |> list.map(fn(seed) { seed.task_id })
  let tasks = list.append(claimed_tasks, completed_tasks)
  let tasks = list.take(tasks, 8)
  let users = context.user_ids

  case tasks, users {
    [], _ -> Ok(Nil)
    _, [] -> Ok(Nil)
    _, _ -> {
      let active_tasks = list.take(tasks, 3)
      let ended_tasks = list.drop(tasks, 3)

      use _ <- result.try(
        list.index_map(active_tasks, fn(task_id, idx) {
          let user_id = list_at_int(users, idx, context.admin_id)
          use _ <- result.try(seed_db.insert_work_session_entry(
            db,
            seed_db.WorkSessionInsertOptions(
              user_id: user_id,
              task_id: task_id,
              started_at: Some("NOW() - INTERVAL '2 hours'"),
              last_heartbeat_at: Some("NOW() - INTERVAL '5 minutes'"),
              ended_at: None,
              ended_reason: None,
              created_at: None,
            ),
          ))
          seed_db.insert_work_session(
            db,
            user_id,
            task_id,
            1200 + { idx * 300 },
          )
        })
        |> result.all,
      )

      use _ <- result.try(
        list.index_map(ended_tasks, fn(task_id, idx) {
          let user_id = list_at_int(users, idx + 1, context.admin_id)
          use _ <- result.try(seed_db.insert_work_session_entry(
            db,
            seed_db.WorkSessionInsertOptions(
              user_id: user_id,
              task_id: task_id,
              started_at: Some("NOW() - INTERVAL '2 days'"),
              last_heartbeat_at: Some("NOW() - INTERVAL '1 day'"),
              ended_at: Some("NOW() - INTERVAL '1 day'"),
              ended_reason: Some("task_closed"),
              created_at: None,
            ),
          ))
          seed_db.insert_work_session(
            db,
            user_id,
            task_id,
            7200 + { idx * 600 },
          )
        })
        |> result.all,
      )

      Ok(Nil)
    }
  }
}

fn cards_for_project(
  card_ids_by_project: List(#(Int, List(Int))),
  project_id: Int,
) -> List(Int) {
  case
    list.find(card_ids_by_project, fn(pair) {
      let #(pid, _cards) = pair
      pid == project_id
    })
  {
    Ok(#(_pid, cards)) -> cards
    Error(_) -> []
  }
}

fn is_claimed_state(execution_state: task_state.TaskExecutionState) -> Bool {
  case execution_state {
    task_state.Claimed(..) -> True
    task_state.Available | task_state.Closed(..) -> False
  }
}

fn is_completed_state(execution_state: task_state.TaskExecutionState) -> Bool {
  case execution_state {
    task_state.Closed(..) -> True
    task_state.Available | task_state.Claimed(..) -> False
  }
}

fn note_author_for(user_ids: List(Int), idx: Int, default: Int) -> Int {
  list_at_int(user_ids, idx + 1, default)
}

fn seed_note_content(
  execution_state: task_state.TaskExecutionState,
  idx: Int,
) -> String {
  let status_label = case execution_state {
    task_state.Available -> "available"
    task_state.Claimed(mode: task_state.Taken, ..) -> "claimed"
    task_state.Claimed(mode: task_state.Ongoing, ..) -> "ongoing"
    task_state.Closed(..) -> "closed"
  }

  "Seed note: " <> status_label <> " task context #" <> int.to_string(idx + 1)
}

fn seed_card_note_content(idx: Int) -> String {
  case idx {
    0 -> "Seed card note: pinned delivery decision"
    _ -> "Seed card note: follow-up context"
  }
}

fn days_ago_timestamp(days: Int) -> String {
  "NOW() - INTERVAL '" <> int.to_string(days) <> " days'"
}

fn list_at_int(items: List(Int), idx: Int, default: Int) -> Int {
  case idx, items {
    _, [] -> default
    0, [first, ..] -> first
    n, [_, ..rest] -> list_at_int(rest, n - 1, default)
  }
}
