//// Layout normalization for member Pool task positions.

import gleam/list

import domain/remote.{Loaded}
import domain/task.{type Task, Task}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/helpers/dicts as helpers_dicts

const canvas_padding = 12

pub fn compact_loaded_pool_positions(
  model: client_state.Model,
) -> client_state.Model {
  case model.member.pool.member_tasks {
    Loaded(tasks) -> compact_task_positions(model, tasks)
    _ -> model
  }
}

fn compact_task_positions(
  model: client_state.Model,
  tasks: List(Task),
) -> client_state.Model {
  let task_ids =
    tasks
    |> list.map(fn(task) {
      let Task(id: id, ..) = task
      id
    })

  client_state.update_member(model, fn(member) {
    let positions = member.positions
    member_state.MemberModel(
      ..member,
      positions: member_positions.Model(
        ..positions,
        member_positions_by_task: helpers_dicts.compact_positions_for_task_ids(
          positions.member_positions_by_task,
          task_ids,
          canvas_padding,
        ),
      ),
    )
  })
}
