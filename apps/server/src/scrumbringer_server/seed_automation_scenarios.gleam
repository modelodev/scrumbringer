//// Automation seed scenarios.
////
//// Creates realistic Scrum automation engines, task templates, rules, and
//// historical executions so local QA can exercise automation configuration and
//// metrics without hand-crafted setup.

import domain/automation
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server/seed_db
import scrumbringer_server/seed_pools
import scrumbringer_server/seed_task_scenarios
import scrumbringer_server/use_case/rules_db
import scrumbringer_server/use_case/task_templates_db
import scrumbringer_server/use_case/workflows_db

pub type ConfigContext {
  ConfigContext(
    org_id: Int,
    admin_id: Int,
    active_task_types: List(#(Int, List(Int))),
  )
}

pub type HistoryContext {
  HistoryContext(
    admin_id: Int,
    rule_seeds: List(RuleSeed),
    task_seeds: List(seed_task_scenarios.TaskSeed),
    card_ids_by_project: List(#(Int, List(Int))),
  )
}

pub type ConfigResult {
  ConfigResult(
    workflow_ids_by_project: List(#(Int, List(Int))),
    template_ids_by_project: List(#(Int, List(Int))),
    rule_ids_by_project: List(#(Int, List(Int))),
    rule_seeds: List(RuleSeed),
    rule_count: Int,
  )
}

pub type HistoryResult {
  HistoryResult(rule_executions: Int)
}

pub type RuleSeed {
  RuleSeed(
    project_id: Int,
    rule_id: Int,
    template_id: Int,
    target: RuleExecutionTarget,
  )
}

pub type RuleExecutionTarget {
  TaskExecutionTarget
  CardExecutionTarget
}

type ProjectAutomationResult {
  ProjectAutomationResult(
    project_id: Int,
    workflow_ids: List(Int),
    template_ids: List(Int),
    rule_seeds: List(RuleSeed),
    rule_count: Int,
  )
}

pub fn build_config(
  db: pog.Connection,
  context: ConfigContext,
) -> Result(ConfigResult, String) {
  use project_results <- result.try(
    context.active_task_types
    |> list.try_map(fn(entry) {
      let #(project_id, task_type_ids) = entry
      build_project_automation(db, context, project_id, task_type_ids)
    }),
  )

  Ok(ConfigResult(
    workflow_ids_by_project: list.map(project_results, fn(project) {
      let ProjectAutomationResult(project_id:, workflow_ids:, ..) = project
      #(project_id, workflow_ids)
    }),
    template_ids_by_project: list.map(project_results, fn(project) {
      let ProjectAutomationResult(project_id:, template_ids:, ..) = project
      #(project_id, template_ids)
    }),
    rule_ids_by_project: list.map(project_results, fn(project) {
      let ProjectAutomationResult(project_id:, rule_seeds:, ..) = project
      #(project_id, list.map(rule_seeds, fn(rule) { rule.rule_id }))
    }),
    rule_seeds: project_results
      |> list.map(fn(project) {
        let ProjectAutomationResult(rule_seeds:, ..) = project
        rule_seeds
      })
      |> list.flatten,
    rule_count: project_results
      |> list.map(fn(project) {
        let ProjectAutomationResult(rule_count:, ..) = project
        rule_count
      })
      |> sum,
  ))
}

pub fn build_history(
  db: pog.Connection,
  context: HistoryContext,
) -> Result(HistoryResult, String) {
  use execution_ids <- result.try(
    context.rule_seeds
    |> list.index_map(fn(rule, idx) {
      insert_seed_execution(db, context, rule, idx)
    })
    |> result.all,
  )

  Ok(HistoryResult(rule_executions: list.length(execution_ids)))
}

fn build_project_automation(
  db: pog.Connection,
  context: ConfigContext,
  project_id: Int,
  task_type_ids: List(Int),
) -> Result(ProjectAutomationResult, String) {
  let requirement_type = type_id_at(task_type_ids, 0)
  let design_type = type_id_at(task_type_ids, 1)
  let frontend_type = type_id_at(task_type_ids, 3)
  let backend_type = type_id_at(task_type_ids, 4)
  let qa_type = type_id_at(task_type_ids, 5)

  use refinement_template <- result.try(create_template(
    db,
    context,
    project_id,
    "Refine acceptance criteria for {task_title}",
    "Functional analyst reviews {task_title} and prepares Given/When/Then acceptance criteria.",
    requirement_type,
    3,
  ))
  use design_template <- result.try(create_template(
    db,
    context,
    project_id,
    "Prepare UI handoff for {card_title}",
    "Designer updates interaction states, responsive notes, and handoff assets for {card_title}.",
    design_type,
    3,
  ))
  use contract_template <- result.try(create_template(
    db,
    context,
    project_id,
    "Review API contract for {task_title}",
    "Backend developer validates request/response contract, errors, and monitoring notes before frontend integration.",
    backend_type,
    4,
  ))
  use regression_template <- result.try(create_template(
    db,
    context,
    project_id,
    "Run regression checks for {task_title}",
    "QA executes smoke, regression, and edge-case checks linked to {task_title}.",
    qa_type,
    4,
  ))

  use delivery_workflow <- result.try(create_workflow(
    db,
    context,
    project_id,
    "Scrum delivery automation",
    "Creates follow-up work when sprint items enter or leave delivery states.",
    True,
  ))
  use quality_workflow <- result.try(create_workflow(
    db,
    context,
    project_id,
    "Quality gates automation",
    "Keeps QA and contract checks explicit after backend or frontend work changes state.",
    True,
  ))
  use release_workflow <- result.try(create_workflow(
    db,
    context,
    project_id,
    "Release readiness automation",
    "Paused example for release hardening experiments.",
    False,
  ))

  use card_rule <- result.try(create_rule_with_template(
    db,
    project_id,
    delivery_workflow,
    "Card activated -> UI handoff",
    "When a sprint card starts, create the design handoff task.",
    automation.CardActivated(automation.AnyCard),
    design_template,
    automation.Active,
    CardExecutionTarget,
  ))
  use frontend_rule <- result.try(create_rule_with_template(
    db,
    project_id,
    delivery_workflow,
    "Frontend created -> API contract review",
    "When frontend work appears, make the backend contract explicit.",
    automation.TaskCreated(Some(frontend_type)),
    contract_template,
    automation.Active,
    TaskExecutionTarget,
  ))
  use backend_rule <- result.try(create_rule_with_template(
    db,
    project_id,
    quality_workflow,
    "Backend closed -> QA regression",
    "When backend work is completed, create the corresponding QA verification.",
    automation.TaskClosed(Some(backend_type)),
    regression_template,
    automation.Active,
    TaskExecutionTarget,
  ))
  use _paused_rule <- result.try(create_rule_with_template(
    db,
    project_id,
    release_workflow,
    "Requirement created -> refinement check",
    "Paused template showing how product refinement could be automated.",
    automation.TaskCreated(Some(requirement_type)),
    refinement_template,
    automation.Paused,
    TaskExecutionTarget,
  ))

  Ok(ProjectAutomationResult(
    project_id: project_id,
    workflow_ids: [delivery_workflow, quality_workflow, release_workflow],
    template_ids: [
      refinement_template,
      design_template,
      contract_template,
      regression_template,
    ],
    rule_seeds: [card_rule, frontend_rule, backend_rule],
    rule_count: 4,
  ))
}

fn create_template(
  db: pog.Connection,
  context: ConfigContext,
  project_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
) -> Result(Int, String) {
  use template <- result.try(
    task_templates_db.create_template(
      db,
      context.org_id,
      project_id,
      name,
      description,
      type_id,
      priority,
      context.admin_id,
    )
    |> result.map_error(fn(error) {
      "create seed task template: " <> string.inspect(error)
    }),
  )
  let task_templates_db.TaskTemplate(id:, ..) = template
  Ok(id)
}

fn create_workflow(
  db: pog.Connection,
  context: ConfigContext,
  project_id: Int,
  name: String,
  description: String,
  active: Bool,
) -> Result(Int, String) {
  use workflow <- result.try(
    workflows_db.create_workflow(
      db,
      context.org_id,
      project_id,
      name,
      description,
      active,
      context.admin_id,
    )
    |> result.map_error(fn(error) {
      "create seed workflow: " <> string.inspect(error)
    }),
  )
  let workflows_db.WorkflowRecord(id:, ..) = workflow
  Ok(id)
}

fn create_rule_with_template(
  db: pog.Connection,
  project_id: Int,
  workflow_id: Int,
  name: String,
  goal: String,
  trigger: automation.AutomationTrigger,
  template_id: Int,
  status: automation.AutomationRuleStatus,
  target: RuleExecutionTarget,
) -> Result(RuleSeed, String) {
  use rule <- result.try(
    rules_db.create_rule(
      db,
      workflow_id,
      name,
      goal,
      trigger,
      automation.CreateTask(template_id),
      status,
    )
    |> result.map_error(fn(error) {
      "create seed rule: " <> string.inspect(error)
    }),
  )
  let rules_db.RuleRecord(id: rule_id, ..) = rule

  use Nil <- result.try(
    rules_db.select_template(db, rule_id, template_id, 1)
    |> result.map_error(fn(error) {
      "select seed rule template: " <> string.inspect(error)
    }),
  )

  Ok(RuleSeed(
    project_id: project_id,
    rule_id: rule_id,
    template_id: template_id,
    target: target,
  ))
}

fn insert_seed_execution(
  db: pog.Connection,
  context: HistoryContext,
  rule: RuleSeed,
  idx: Int,
) -> Result(Int, String) {
  use target <- result.try(rule_execution_target(context, rule))
  let #(task_id, card_id, resource_id) = target
  let created_task_id = created_task_for_rule(context.task_seeds, rule.rule_id)
  let event_key =
    "seed:" <> int.to_string(rule.rule_id) <> ":" <> int.to_string(resource_id)

  seed_db.insert_rule_execution(
    db,
    seed_db.RuleExecutionInsertOptions(
      rule_id: rule.rule_id,
      event_key: event_key,
      task_id: task_id,
      card_id: card_id,
      outcome: "applied",
      suppression_reason: None,
      user_id: Some(context.admin_id),
      template_id: Some(rule.template_id),
      template_version: Some(1),
      created_task_id: created_task_id,
      created_at: Some(seed_pools.days_ago_timestamp(int.max(1, 6 - idx))),
    ),
  )
}

fn rule_execution_target(
  context: HistoryContext,
  rule: RuleSeed,
) -> Result(#(Option(Int), Option(Int), Int), String) {
  case rule.target {
    TaskExecutionTarget -> {
      use task_id <- result.try(source_task_for_rule(
        context.task_seeds,
        rule.project_id,
        rule.rule_id,
      ))
      Ok(#(Some(task_id), None, task_id))
    }
    CardExecutionTarget -> {
      use card_id <- result.try(first_card_for_project(
        context.card_ids_by_project,
        rule.project_id,
      ))
      Ok(#(None, Some(card_id), card_id))
    }
  }
}

fn source_task_for_rule(
  task_seeds: List(seed_task_scenarios.TaskSeed),
  project_id: Int,
  rule_id: Int,
) -> Result(Int, String) {
  task_seeds
  |> list.find(fn(seed) {
    let seed_task_scenarios.TaskSeed(
      project_id: task_project_id,
      created_from_rule_id: created_from_rule_id,
      ..,
    ) = seed
    task_project_id == project_id && created_from_rule_id != Some(rule_id)
  })
  |> result.map(fn(seed) {
    let seed_task_scenarios.TaskSeed(task_id:, ..) = seed
    task_id
  })
  |> result.map_error(fn(_) { "No source task for automation seed rule" })
}

fn created_task_for_rule(
  task_seeds: List(seed_task_scenarios.TaskSeed),
  rule_id: Int,
) -> Option(Int) {
  case
    task_seeds
    |> list.find(fn(seed) {
      let seed_task_scenarios.TaskSeed(created_from_rule_id:, ..) = seed
      created_from_rule_id == Some(rule_id)
    })
  {
    Ok(seed) -> {
      let seed_task_scenarios.TaskSeed(task_id:, ..) = seed
      Some(task_id)
    }
    Error(_) -> None
  }
}

fn first_card_for_project(
  card_ids_by_project: List(#(Int, List(Int))),
  project_id: Int,
) -> Result(Int, String) {
  use card_ids <- result.try(
    card_ids_by_project
    |> list.find(fn(entry) {
      let #(pid, _) = entry
      pid == project_id
    })
    |> result.map(fn(entry) {
      let #(_, ids) = entry
      ids
    })
    |> result.map_error(fn(_) { "No cards for automation seed project" }),
  )

  case card_ids {
    [card_id, ..] -> Ok(card_id)
    [] -> Error("No cards for automation seed project")
  }
}

fn type_id_at(task_type_ids: List(Int), idx: Int) -> Int {
  seed_pools.list_at(
    task_type_ids,
    idx,
    seed_pools.list_at(task_type_ids, 0, 0),
  )
}

fn sum(values: List(Int)) -> Int {
  list.fold(values, 0, fn(total, value) { total + value })
}
