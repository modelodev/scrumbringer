import gleam/dict
import gleam/option as opt
import lustre/effect
import support/domain_fixtures

import domain/remote.{Loading}
import domain/task.{type Task, Task}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/refresh_update

pub fn task_fetch_preserves_existing_positions_test() {
  let model =
    client_state.update_member(client_state.default_model(), fn(member) {
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..member.pool,
          member_tasks: Loading,
          member_tasks_pending: 1,
        ),
        positions: member_positions.Model(
          ..member.positions,
          member_positions_by_task: dict.from_list([
            #(10, #(61, 195)),
            #(11, #(283, 210)),
            #(99, #(0, 0)),
          ]),
        ),
      )
    })

  let assert opt.Some(#(next, fx)) =
    refresh_update.try_project_update(
      model,
      pool_messages.MemberProjectTasksFetched(1, Ok([task(10), task(11)])),
    )

  let result = next.member.positions.member_positions_by_task
  let assert Ok(#(61, 195)) = dict.get(result, 10)
  let assert Ok(#(283, 210)) = dict.get(result, 11)
  let assert Ok(#(0, 0)) = dict.get(result, 99)
  let assert True = fx == effect.none()
}

fn task(id: Int) -> Task {
  Task(
    ..domain_fixtures.task(id, "Task", 1),
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug"),
    description: opt.None,
    priority: 1,
  )
}
