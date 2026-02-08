//// Milestones API functions for Scrumbringer client.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}

import domain/metrics.{
  type MilestoneModalMetrics, type ModalExecutionHealth, type WorkflowBreakdown,
  MilestoneModalMetrics, ModalExecutionHealth, WorkflowBreakdown,
}
import domain/milestone.{type Milestone, type MilestoneProgress}
import domain/milestone/codec as milestone_codec

pub fn list_milestones(
  project_id: Int,
  to_msg: fn(ApiResult(List(MilestoneProgress))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "milestones",
      decode.list(milestone_codec.milestone_progress_decoder()),
      decode.success,
    )

  core.request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/milestones",
    option.None,
    decoder,
    to_msg,
  )
}

pub fn create_milestone(
  project_id: Int,
  name: String,
  description: String,
  to_msg: fn(ApiResult(Milestone)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
    ])

  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/milestones",
    option.Some(body),
    decode.field(
      "milestone",
      milestone_codec.milestone_decoder(),
      decode.success,
    ),
    to_msg,
  )
}

pub fn activate_milestone(
  milestone_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request(
    "POST",
    "/api/v1/milestones/" <> int.to_string(milestone_id) <> "/activate",
    option.Some(json.object([])),
    decode.success(Nil),
    to_msg,
  )
}

pub fn update_milestone(
  milestone_id: Int,
  name: String,
  description: String,
  to_msg: fn(ApiResult(Milestone)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(description)),
    ])

  core.request(
    "PATCH",
    "/api/v1/milestones/" <> int.to_string(milestone_id),
    option.Some(body),
    decode.field(
      "milestone",
      milestone_codec.milestone_decoder(),
      decode.success,
    ),
    to_msg,
  )
}

pub fn delete_milestone(
  milestone_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/milestones/" <> int.to_string(milestone_id),
    option.None,
    to_msg,
  )
}

pub fn get_milestone_metrics(
  milestone_id: Int,
  to_msg: fn(ApiResult(MilestoneModalMetrics)) -> msg,
) -> Effect(msg) {
  core.request(
    "GET",
    "/api/v1/milestones/" <> int.to_string(milestone_id) <> "?include=metrics",
    option.None,
    decode.field("metrics", milestone_metrics_decoder(), decode.success),
    to_msg,
  )
}

fn milestone_metrics_decoder() -> decode.Decoder(MilestoneModalMetrics) {
  use progress <- decode.field("progress", progress_decoder())
  let #(
    cards_total,
    cards_completed,
    cards_percent,
    tasks_total,
    tasks_completed,
    tasks_percent,
  ) = progress

  use states <- decode.field("states", states_decoder())
  let #(tasks_available, tasks_claimed, tasks_ongoing) = states

  use health <- decode.field("health", health_decoder())
  use workflow_data <- decode.field("workflows", workflows_decoder())
  let #(workflows, most_activated) = workflow_data

  decode.success(MilestoneModalMetrics(
    cards_total: cards_total,
    cards_completed: cards_completed,
    cards_percent: cards_percent,
    tasks_total: tasks_total,
    tasks_completed: tasks_completed,
    tasks_percent: tasks_percent,
    tasks_available: tasks_available,
    tasks_claimed: tasks_claimed,
    tasks_ongoing: tasks_ongoing,
    health: health,
    workflows: workflows,
    most_activated: most_activated,
  ))
}

fn progress_decoder() -> decode.Decoder(#(Int, Int, Int, Int, Int, Int)) {
  use cards_total <- decode.field("cards_total", decode.int)
  use cards_completed <- decode.field("cards_completed", decode.int)
  use cards_percent <- decode.field("cards_percent", decode.int)
  use tasks_total <- decode.field("tasks_total", decode.int)
  use tasks_completed <- decode.field("tasks_completed", decode.int)
  use tasks_percent <- decode.field("tasks_percent", decode.int)
  decode.success(#(
    cards_total,
    cards_completed,
    cards_percent,
    tasks_total,
    tasks_completed,
    tasks_percent,
  ))
}

fn states_decoder() -> decode.Decoder(#(Int, Int, Int)) {
  use available <- decode.field("available", decode.int)
  use claimed <- decode.field("claimed", decode.int)
  use ongoing <- decode.field("ongoing", decode.int)
  decode.success(#(available, claimed, ongoing))
}

fn workflows_decoder() -> decode.Decoder(
  #(List(WorkflowBreakdown), option.Option(String)),
) {
  use items <- decode.field("items", decode.list(workflow_breakdown_decoder()))
  use most_activated <- decode.field(
    "most_activated",
    decode.optional(decode.string),
  )
  decode.success(#(items, most_activated))
}

fn health_decoder() -> decode.Decoder(ModalExecutionHealth) {
  use avg_rebotes <- decode.field("avg_rebotes", decode.int)
  use avg_pool_lifetime_s <- decode.field("avg_pool_lifetime_s", decode.int)
  use avg_executors <- decode.field("avg_executors", decode.int)
  decode.success(ModalExecutionHealth(
    avg_rebotes: avg_rebotes,
    avg_pool_lifetime_s: avg_pool_lifetime_s,
    avg_executors: avg_executors,
  ))
}

fn workflow_breakdown_decoder() -> decode.Decoder(WorkflowBreakdown) {
  use name <- decode.field("name", decode.string)
  use count <- decode.field("count", decode.int)
  decode.success(WorkflowBreakdown(name:, count:))
}
