import gleeunit/should
import lustre/effect

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/update as pool_update
import scrumbringer_client/ui/task_tabs

fn test_context() -> pool_update.Context {
  pool_update.Context(member_refresh: fn(model) { #(model, effect.none()) })
}

pub fn task_details_open_sets_default_tasks_tab_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskDetailsOpened(42),
      test_context(),
    )

  next.member.pool.member_task_detail_tab
  |> should.equal(task_tabs.TasksTab)
}

pub fn task_details_close_resets_default_tasks_tab_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_task_detail_tab: task_tabs.MetricsTab,
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberTaskDetailsClosed,
      test_context(),
    )

  next.member.pool.member_task_detail_tab
  |> should.equal(task_tabs.TasksTab)
}
