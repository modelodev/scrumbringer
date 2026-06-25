import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

import domain/card.{type Card, type CardColor}
import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, type WorkSession, WorkSession}
import domain/task/state as task_state
import scrumbringer_client/features/layout/right_panel
import scrumbringer_client/helpers/time as helpers_time

pub fn loaded_tasks_or_empty(tasks: Remote(List(Task))) -> List(Task) {
  case tasks {
    Loaded(items) -> items
    _ -> []
  }
}

pub fn find_loaded_task(tasks: Remote(List(Task)), task_id: Int) -> Option(Task) {
  tasks
  |> loaded_tasks_or_empty
  |> find_task(task_id)
}

fn find_task(tasks: List(Task), task_id: Int) -> Option(Task) {
  case list.find(tasks, fn(task) { task.id == task_id }) {
    Ok(task) -> Some(task)
    Error(_) -> None
  }
}

pub fn claimed_tasks(tasks: List(Task), user_id: Int) -> List(Task) {
  list.filter(tasks, fn(task) {
    case task.state {
      task_state.Claimed(claimed_by: claimed_by, mode: task_state.Taken, ..) ->
        claimed_by == user_id
      _ -> False
    }
  })
}

pub fn my_cards(
  cards: List(Card),
  tasks: List(Task),
  user_id: Int,
) -> List(right_panel.MyCardProgress) {
  cards
  |> list.filter_map(fn(card) {
    let card_tasks =
      list.filter(tasks, fn(task) { task.card_id == Some(card.id) })
    let has_claimed_task =
      list.any(card_tasks, fn(task) {
        case task.state {
          task_state.Claimed(claimed_by: claimed_by, ..) ->
            claimed_by == user_id
          _ -> False
        }
      })
    case has_claimed_task {
      False -> Error(Nil)
      True -> {
        let completed =
          list.count(card_tasks, fn(task) {
            case task.state {
              task_state.Closed(..) -> True
              task_state.Available | task_state.Claimed(..) -> False
            }
          })
        Ok(right_panel.MyCardProgress(
          card_id: card.id,
          card_title: card.title,
          card_color: card.color,
          completed: completed,
          total: list.length(card_tasks),
        ))
      }
    }
  })
}

pub fn active_tasks(
  sessions: List(WorkSession),
  tasks: List(Task),
  server_offset_ms: Int,
  now_ms: Int,
  parse_iso_ms: fn(String) -> Int,
  task_card_color: fn(Task) -> Option(CardColor),
) -> List(right_panel.ActiveTaskInfo) {
  let server_now_ms = now_ms - server_offset_ms
  list.map(sessions, fn(session) {
    let WorkSession(
      task_id: task_id,
      started_at: started_at,
      accumulated_s: accumulated_s,
    ) = session
    let #(title, type_icon, card_color) =
      active_task_display(task_id, tasks, task_card_color)
    let elapsed =
      helpers_time.now_working_elapsed_from_ms(
        accumulated_s,
        parse_iso_ms(started_at),
        server_now_ms,
      )
    right_panel.ActiveTaskInfo(
      task_id: task_id,
      task_title: title,
      task_type_icon: type_icon,
      card_color: card_color,
      elapsed_display: elapsed,
      is_paused: False,
    )
  })
}

fn active_task_display(
  task_id: Int,
  tasks: List(Task),
  task_card_color: fn(Task) -> Option(CardColor),
) -> #(String, String, Option(CardColor)) {
  case list.find(tasks, fn(task) { task.id == task_id }) {
    Ok(task) -> #(task.title, task.task_type.icon, task_card_color(task))
    Error(_) -> #(
      "Task #" <> int.to_string(task_id),
      "clipboard-document",
      None,
    )
  }
}
