//// Milestone JSON decoders.

import domain/milestone.{
  type Milestone, type MilestoneProgress, Milestone, MilestoneProgress,
  state_from_string,
}
import gleam/dynamic/decode
import gleam/option

pub fn milestone_decoder() -> decode.Decoder(Milestone) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use name <- decode.field("name", decode.string)
  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )
  use state_raw <- decode.field("state", decode.string)
  use position <- decode.field("position", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use activated_at <- decode.optional_field(
    "activated_at",
    option.None,
    decode.optional(decode.string),
  )
  use completed_at <- decode.optional_field(
    "completed_at",
    option.None,
    decode.optional(decode.string),
  )

  decode.success(Milestone(
    id: id,
    project_id: project_id,
    name: name,
    description: description,
    state: state_from_string(state_raw),
    position: position,
    created_by: created_by,
    created_at: created_at,
    activated_at: activated_at,
    completed_at: completed_at,
  ))
}

pub fn milestone_progress_decoder() -> decode.Decoder(MilestoneProgress) {
  use milestone <- decode.field("milestone", milestone_decoder())
  use cards_total <- decode.field("cards_total", decode.int)
  use cards_completed <- decode.field("cards_completed", decode.int)
  use tasks_total <- decode.field("tasks_total", decode.int)
  use tasks_completed <- decode.field("tasks_completed", decode.int)

  decode.success(MilestoneProgress(
    milestone: milestone,
    cards_total: cards_total,
    cards_completed: cards_completed,
    tasks_total: tasks_total,
    tasks_completed: tasks_completed,
  ))
}
