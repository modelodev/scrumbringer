//// JSON presenters for milestone endpoints.

import domain/milestone as milestone_domain
import gleam/int
import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/http/metrics_presenters
import scrumbringer_server/services/metrics_db
import scrumbringer_server/services/milestones_db

pub fn milestones_response(
  values: List(milestones_db.MilestoneWithProgress),
) -> json.Json {
  json.object([#("milestones", json.array(values, of: milestone_progress))])
}

pub fn milestone_progress(row: milestones_db.MilestoneWithProgress) -> json.Json {
  json.object([
    #("milestone", milestone(row.milestone)),
    #("cards_total", json.int(row.cards_total)),
    #("cards_completed", json.int(row.cards_completed)),
    #("tasks_total", json.int(row.tasks_total)),
    #("tasks_completed", json.int(row.tasks_completed)),
    #("is_completed", json.bool(milestones_db.is_completed(row))),
  ])
}

pub fn milestone(m: milestone_domain.Milestone) -> json.Json {
  json.object([
    #("id", json.int(m.id)),
    #("project_id", json.int(m.project_id)),
    #("name", json.string(m.name)),
    #("description", json_helpers.option_string_json(m.description)),
    #("state", json.string(milestone_domain.state_to_string(m.state))),
    #("position", json.int(m.position)),
    #("created_by", json.int(m.created_by)),
    #("created_at", json.string(m.created_at)),
    #("activated_at", json_helpers.option_string_json(m.activated_at)),
    #("completed_at", json_helpers.option_string_json(m.completed_at)),
  ])
}

pub fn milestone_response(value: milestone_domain.Milestone) -> json.Json {
  json.object([#("milestone", milestone(value))])
}

pub fn milestone_metrics(metrics: metrics_db.MilestoneMetrics) -> json.Json {
  let metrics_db.MilestoneMetrics(
    cards_total: cards_total,
    cards_completed: cards_completed,
    tasks_total: tasks_total,
    tasks_completed: tasks_completed,
    tasks_available: tasks_available,
    tasks_claimed: tasks_claimed,
    tasks_ongoing: tasks_ongoing,
    health: health,
    workflows: workflows,
    most_activated: most_activated,
  ) = metrics

  let metrics_db.ExecutionHealth(
    avg_rebotes: avg_rebotes,
    avg_pool_lifetime_s: avg_pool_lifetime_s,
    avg_executors: avg_executors,
  ) = health

  json.object([
    #(
      "progress",
      json.object([
        #("cards_total", json.int(cards_total)),
        #("cards_completed", json.int(cards_completed)),
        #(
          "cards_percent",
          json.int(metrics_db.percent(cards_completed, cards_total)),
        ),
        #("tasks_total", json.int(tasks_total)),
        #("tasks_completed", json.int(tasks_completed)),
        #(
          "tasks_percent",
          json.int(metrics_db.percent(tasks_completed, tasks_total)),
        ),
      ]),
    ),
    #(
      "states",
      json.object([
        #("available", json.int(tasks_available)),
        #("claimed", json.int(tasks_claimed)),
        #("ongoing", json.int(tasks_ongoing)),
        #("completed", json.int(tasks_completed)),
      ]),
    ),
    #(
      "health",
      json.object([
        #("avg_rebotes", json.int(avg_rebotes)),
        #("avg_pool_lifetime_s", json.int(avg_pool_lifetime_s)),
        #("avg_executors", json.int(avg_executors)),
      ]),
    ),
    #(
      "workflows",
      json.object([
        #("items", json.array(workflows, of: workflow_count)),
        #("most_activated", json_helpers.option_string_json(most_activated)),
      ]),
    ),
  ])
}

pub fn milestone_metrics_response(
  milestone_id: Int,
  metrics: metrics_db.MilestoneMetrics,
) -> json.Json {
  json.object([
    #("id", json.string(int.to_string(milestone_id))),
    #("metrics", milestone_metrics(metrics)),
  ])
}

pub fn activation_response(
  snapshot: milestones_db.ActivationSnapshot,
) -> json.Json {
  json.object([
    #("milestone", milestone(snapshot.milestone)),
    #(
      "activated_at",
      json_helpers.option_string_json(snapshot.milestone.activated_at),
    ),
    #("cards_released", json.int(snapshot.cards_released)),
    #("tasks_released", json.int(snapshot.tasks_released)),
  ])
}

fn workflow_count(value: metrics_db.WorkflowCount) -> json.Json {
  let metrics_db.WorkflowCount(name: name, count: count) = value
  json.object([
    #("name", json.string(metrics_presenters.workflow_name_or_default(name))),
    #("count", json.int(count)),
  ])
}
