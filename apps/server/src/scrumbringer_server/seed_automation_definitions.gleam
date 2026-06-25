//// Automation definition seed scenario.
////
//// Creates task templates, workflows, rules, rule template selections, and
//// warning rules used by automation product validation.

import domain/automation
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_db
import scrumbringer_server/seed_pools

pub type Context {
  Context(
    org_id: Int,
    admin_id: Int,
    active_project_ids: List(Int),
    workflows_per_project: Int,
    inactive_workflow_count: Int,
    empty_workflow_count: Int,
    task_type_ids: List(#(Int, Int, Int, Int)),
  )
}

pub type DefinitionResult {
  DefinitionResult(
    template_ids: List(Int),
    template_ids_by_project: List(#(Int, List(Int))),
    workflow_ids: List(Int),
    workflow_ids_by_project: List(#(Int, List(Int))),
    rule_ids: List(Int),
    rule_ids_by_project: List(#(Int, List(Int))),
  )
}

pub fn build(
  db: pog.Connection,
  context: Context,
) -> Result(DefinitionResult, String) {
  use template_ids_by_project <- result.try(build_templates(db, context))
  use workflow_ids_by_project <- result.try(build_workflows(db, context))
  use rule_ids_by_project <- result.try(build_rules(
    db,
    context,
    template_ids_by_project,
    workflow_ids_by_project,
  ))

  Ok(DefinitionResult(
    template_ids: flatten_ids(template_ids_by_project),
    template_ids_by_project: template_ids_by_project,
    workflow_ids: flatten_ids(workflow_ids_by_project),
    workflow_ids_by_project: workflow_ids_by_project,
    rule_ids: flatten_ids(rule_ids_by_project),
    rule_ids_by_project: rule_ids_by_project,
  ))
}

fn build_templates(
  db: pog.Connection,
  context: Context,
) -> Result(List(#(Int, List(Int))), String) {
  let template_names = ["Code Review", "QA Verification", "Deploy to Staging"]

  list.try_map(context.task_type_ids, fn(types) {
    let #(project_id, _bug_id, _feature_id, task_type_id) = types
    use template_ids <- result.try(
      list.try_map(template_names, fn(name) {
        seed_db.insert_template(
          db,
          seed_db.TemplateInsertOptions(
            org_id: context.org_id,
            project_id: project_id,
            type_id: task_type_id,
            name: name,
            description: "Auto-created " <> name,
            priority: 3,
            created_by: context.admin_id,
            created_at: None,
          ),
        )
      }),
    )
    Ok(#(project_id, template_ids))
  })
}

fn build_workflows(
  db: pog.Connection,
  context: Context,
) -> Result(List(#(Int, List(Int))), String) {
  let wf_names = seed_pools.automation_engine_names()

  list.index_map(context.active_project_ids, fn(project_id, proj_idx) {
    use workflow_ids <- result.try(
      list.range(0, context.workflows_per_project - 1)
      |> list.try_map(fn(idx) {
        let name = list_at(wf_names, idx, "Workflow " <> int.to_string(idx + 1))
        let is_inactive =
          idx >= context.workflows_per_project - context.inactive_workflow_count

        seed_db.insert_workflow(
          db,
          seed_db.WorkflowInsertOptions(
            org_id: context.org_id,
            project_id: project_id,
            name: name <> " " <> int.to_string(proj_idx + 1),
            description: None,
            active: !is_inactive,
            created_by: context.admin_id,
            created_at: None,
          ),
        )
      }),
    )
    Ok(#(project_id, workflow_ids))
  })
  |> result.all
}

fn build_rules(
  db: pog.Connection,
  context: Context,
  template_ids_by_project: List(#(Int, List(Int))),
  workflow_ids_by_project: List(#(Int, List(Int))),
) -> Result(List(#(Int, List(Int))), String) {
  list.index_map(workflow_ids_by_project, fn(pair, project_idx) {
    let #(project_id, workflow_ids) = pair
    let task_types = task_types_for_project(context.task_type_ids, project_id)
    let templates = templates_for_project(template_ids_by_project, project_id)
    let workflow_ids = list.drop(workflow_ids, context.empty_workflow_count)

    case workflow_ids, task_types {
      [], _ -> Ok(#(project_id, []))
      _, None -> Ok(#(project_id, []))
      [active_workflow, inactive_workflow], Some(#(bug_id, feature_id, _)) -> {
        use active_rule <- result.try(seed_db.insert_rule(
          db,
          seed_rule_options(
            workflow_id: active_workflow,
            name: "On Task Closed (Active)",
            goal: Some("Auto action on task close"),
            trigger: automation.TaskCompleted(Some(bug_id)),
            active: True,
            created_at: None,
          ),
        ))
        use _ <- result.try(select_seed_template(db, active_rule, templates, 0))

        use inactive_rule <- result.try(seed_db.insert_rule(
          db,
          seed_rule_options(
            workflow_id: inactive_workflow,
            name: "On Task Closed (Inactive)",
            goal: Some("Should not trigger"),
            trigger: automation.TaskCompleted(Some(feature_id)),
            active: True,
            created_at: None,
          ),
        ))
        use _ <- result.try(select_seed_template(
          db,
          inactive_rule,
          templates,
          1,
        ))

        use warning_rules <- result.try(seed_review_warning_rules(
          db,
          project_idx,
          active_workflow,
          bug_id,
        ))

        Ok(#(project_id, [active_rule, inactive_rule, ..warning_rules]))
      }
      [single_workflow], Some(#(bug_id, _feature_id, _task_id)) -> {
        use rule_id <- result.try(seed_db.insert_rule(
          db,
          seed_rule_options(
            workflow_id: single_workflow,
            name: "On Task Closed",
            goal: Some("Auto action on task close"),
            trigger: automation.TaskCompleted(Some(bug_id)),
            active: True,
            created_at: None,
          ),
        ))
        use _ <- result.try(select_seed_template(db, rule_id, templates, 0))
        use warning_rules <- result.try(seed_review_warning_rules(
          db,
          project_idx,
          single_workflow,
          bug_id,
        ))
        Ok(#(project_id, [rule_id, ..warning_rules]))
      }
      _, _ -> Ok(#(project_id, []))
    }
  })
  |> result.all
}

fn select_seed_template(
  db: pog.Connection,
  rule_id: Int,
  templates: List(Int),
  index: Int,
) -> Result(Nil, String) {
  case list.drop(templates, index) {
    [template_id, ..] ->
      seed_db.select_rule_template(db, rule_id, template_id, 1)
    [] -> Ok(Nil)
  }
}

fn seed_review_warning_rules(
  db: pog.Connection,
  project_idx: Int,
  workflow_id: Int,
  task_type_id: Int,
) -> Result(List(Int), String) {
  case project_idx {
    2 -> {
      use rule_id <- result.try(seed_db.insert_rule(
        db,
        seed_rule_options(
          workflow_id: workflow_id,
          name: "Seed warning - template missing",
          goal: Some("Shows requires-review automation state in stress data"),
          trigger: automation.TaskCompleted(Some(task_type_id)),
          active: True,
          created_at: None,
        ),
      ))
      Ok([rule_id])
    }
    _ -> Ok([])
  }
}

fn seed_rule_options(
  workflow_id workflow_id: Int,
  name name: String,
  goal goal: Option(String),
  trigger trigger: automation.AutomationTrigger,
  active active: Bool,
  created_at created_at: Option(String),
) -> seed_db.RuleInsertOptions {
  let #(resource_type, _task_type_id, card_depth, to_state) =
    automation.trigger_to_db_values(trigger)

  seed_db.RuleInsertOptions(
    workflow_id: workflow_id,
    name: name,
    goal: goal,
    resource_type: resource_type,
    trigger_kind: automation.trigger_kind(trigger),
    task_type_id: automation.trigger_task_type_id(trigger),
    card_depth: option_from_positive_int(card_depth),
    to_state: to_state,
    active: active,
    created_at: created_at,
  )
}

fn flatten_ids(ids_by_project: List(#(Int, List(Int)))) -> List(Int) {
  ids_by_project
  |> list.map(fn(pair) {
    let #(_project_id, ids) = pair
    ids
  })
  |> list.flatten
}

fn templates_for_project(
  template_ids_by_project: List(#(Int, List(Int))),
  project_id: Int,
) -> List(Int) {
  case
    list.find(template_ids_by_project, fn(pair) {
      let #(pid, _templates) = pair
      pid == project_id
    })
  {
    Ok(#(_pid, templates)) -> templates
    Error(_) -> []
  }
}

fn task_types_for_project(
  task_type_ids: List(#(Int, Int, Int, Int)),
  project_id: Int,
) -> Option(#(Int, Int, Int)) {
  case
    list.find(task_type_ids, fn(entry) {
      let #(pid, _bug, _feature, _task) = entry
      pid == project_id
    })
  {
    Ok(#(_pid, bug_id, feature_id, task_id)) ->
      Some(#(bug_id, feature_id, task_id))
    Error(_) -> None
  }
}

fn list_at(items: List(String), idx: Int, default: String) -> String {
  list_at_helper(items, idx, default)
}

fn list_at_helper(items: List(a), idx: Int, default: a) -> a {
  case idx, items {
    _, [] -> default
    0, [first, ..] -> first
    n, [_, ..rest] -> list_at_helper(rest, n - 1, default)
  }
}

fn option_from_positive_int(value: Int) -> Option(Int) {
  case value {
    n if n > 0 -> Some(n)
    _ -> None
  }
}
