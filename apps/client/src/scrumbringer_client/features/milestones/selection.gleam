import domain/milestone.{type MilestoneProgress, Active, Ready}
import gleam/list
import gleam/option
import scrumbringer_client/client_state/member/pool as member_pool

pub fn selected_progress(
  items: List(MilestoneProgress),
  selected_id: option.Option(Int),
) -> option.Option(MilestoneProgress) {
  case selected_id {
    option.Some(id) ->
      case list.find(items, fn(progress) { progress.milestone.id == id }) {
        Ok(progress) -> option.Some(progress)
        Error(_) -> default_selected_progress(items)
      }
    option.None -> default_selected_progress(items)
  }
}

pub fn select_milestone(
  model: member_pool.Model,
  milestone_id: Int,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_selected_milestone_id: option.Some(milestone_id),
    member_milestone_dialog_in_flight: False,
    member_milestone_dialog_error: option.None,
  )
}

fn default_selected_progress(
  items: List(MilestoneProgress),
) -> option.Option(MilestoneProgress) {
  case list.find(items, fn(progress) { progress.milestone.state == Active }) {
    Ok(progress) -> option.Some(progress)
    Error(_) ->
      case
        list.find(items, fn(progress) { progress.milestone.state == Ready })
      {
        Ok(progress) -> option.Some(progress)
        Error(_) -> list.first(items) |> option.from_result
      }
  }
}
