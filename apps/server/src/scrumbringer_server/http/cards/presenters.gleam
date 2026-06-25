//// JSON presenters for card endpoints.

import domain/card as domain_card
import gleam/int
import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/http/metrics_presenters
import scrumbringer_server/use_case/metrics_db

pub fn card(card: domain_card.Card) -> json.Json {
  json.object([
    #("id", json.int(card.id)),
    #("project_id", json.int(card.project_id)),
    #("parent_card_id", json_helpers.option_int_json(card.parent_card_id)),
    #("title", json.string(card.title)),
    #("description", json.string(card.description)),
    #("color", json.string(domain_card.optional_color_to_string(card.color))),
    #("state", json.string(domain_card.state_to_string(card.state))),
    #("task_count", json.int(card.task_count)),
    #("completed_count", json.int(card.completed_count)),
    #("created_by", json.int(card.created_by)),
    #("created_at", json.string(card.created_at)),
    #("due_date", json_helpers.option_string_json(card.due_date)),
    #("has_new_notes", json.bool(card.has_new_notes)),
  ])
}

pub fn cards(cards: List(domain_card.Card)) -> json.Json {
  json.array(cards, of: card)
}

pub fn cards_response(values: List(domain_card.Card)) -> json.Json {
  json.object([#("cards", cards(values))])
}

pub fn card_response(value: domain_card.Card) -> json.Json {
  json.object([#("card", card(value))])
}

pub fn card_metrics_response(
  card_id: Int,
  metrics: metrics_db.CardMetrics,
) -> json.Json {
  json.object([
    #("id", json.string(int.to_string(card_id))),
    #("metrics", card_metrics(metrics)),
  ])
}

pub fn card_metrics(metrics: metrics_db.CardMetrics) -> json.Json {
  let metrics_db.CardMetrics(
    tasks_total: tasks_total,
    tasks_closed: tasks_closed,
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
        #("tasks_total", json.int(tasks_total)),
        #("tasks_closed", json.int(tasks_closed)),
        #(
          "tasks_percent",
          json.int(metrics_db.percent(tasks_closed, tasks_total)),
        ),
      ]),
    ),
    #(
      "states",
      json.object([
        #("available", json.int(tasks_available)),
        #("claimed", json.int(tasks_claimed)),
        #("ongoing", json.int(tasks_ongoing)),
        #("closed", json.int(tasks_closed)),
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

fn workflow_count(value: metrics_db.WorkflowCount) -> json.Json {
  let metrics_db.WorkflowCount(name: name, count: count) = value
  json.object([
    #("name", json.string(metrics_presenters.workflow_name_or_default(name))),
    #("count", json.int(count)),
  ])
}
