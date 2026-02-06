import gleam/list
import gleam/option

import domain/milestone
import domain/remote.{type Remote, Loaded}

pub fn find_milestone_dialog(
  remote: Remote(List(milestone.MilestoneProgress)),
  milestone_id: Int,
  build: fn(milestone.Milestone) -> result,
) -> option.Option(result) {
  case remote {
    Loaded(milestones) ->
      list.find_map(milestones, fn(progress) {
        let milestone.MilestoneProgress(milestone: m, ..) = progress
        case m.id == milestone_id {
          True -> Ok(build(m))
          False -> Error(Nil)
        }
      })
      |> option.from_result
    _ -> option.None
  }
}
