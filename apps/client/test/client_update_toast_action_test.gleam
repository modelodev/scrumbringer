import gleeunit/should

import scrumbringer_client/client_state
import scrumbringer_client/client_update
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/ui/toast

pub fn toast_action_view_task_maps_to_member_task_details_opened_test() {
  client_update.toast_action_to_msg(toast.ViewTask(42))
  |> should.equal(
    client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(42)),
  )
}

pub fn toast_action_clear_filters_maps_to_member_clear_filters_test() {
  client_update.toast_action_to_msg(toast.ClearPoolFilters)
  |> should.equal(client_state.pool_msg(pool_messages.MemberClearFilters))
}
