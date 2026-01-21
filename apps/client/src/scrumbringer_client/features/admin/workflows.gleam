//// Admin workflows update handlers.
////
//// ## Mission
////
//// Handles workflow, rule, and task template CRUD operations in the admin panel.
////
//// ## Responsibilities
////
//// - Workflow list fetch and CRUD
//// - Rule list fetch and CRUD within workflows
//// - Task template list fetch and CRUD
//// - Rule-template attachment management
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **view.gleam**: Renders the workflows UI using model state

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow,
}
import scrumbringer_client/client_state.{
  type Model, type Msg, type TaskTemplateDialogMode, type WorkflowDialogMode,
  Failed, Loaded, Loading, Model, NotAsked, RuleCreated, RuleDeleted,
  RuleMetricsFetched, RuleTemplateAttached, RuleTemplateDetached, RuleUpdated,
  RulesFetched, TaskTemplatesOrgFetched, TaskTemplatesProjectFetched,
  TaskTypesFetched, WorkflowsOrgFetched, WorkflowsProjectFetched,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/api/workflows as api_workflows

// =============================================================================
// Workflow Fetch Handlers
// =============================================================================

/// Handle org workflows fetch success.
pub fn handle_workflows_org_fetched_ok(
  model: Model,
  workflows: List(Workflow),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, workflows_org: Loaded(workflows)), effect.none())
}

/// Handle org workflows fetch error.
pub fn handle_workflows_org_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, workflows_org: Failed(err)), effect.none())
  }
}

/// Handle project workflows fetch success.
pub fn handle_workflows_project_fetched_ok(
  model: Model,
  workflows: List(Workflow),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, workflows_project: Loaded(workflows)), effect.none())
}

/// Handle project workflows fetch error.
pub fn handle_workflows_project_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, workflows_project: Failed(err)), effect.none())
  }
}

// =============================================================================
// Workflow Dialog Handlers (Component Pattern)
// =============================================================================

/// Handle opening a workflow dialog (create, edit, or delete).
pub fn handle_open_workflow_dialog(
  model: Model,
  mode: WorkflowDialogMode,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, workflows_dialog_mode: opt.Some(mode)), effect.none())
}

/// Handle closing any open workflow dialog.
pub fn handle_close_workflow_dialog(model: Model) -> #(Model, Effect(Msg)) {
  #(Model(..model, workflows_dialog_mode: opt.None), effect.none())
}

// =============================================================================
// Workflow Component Event Handlers
// =============================================================================

/// Handle workflow created event from component.
/// Adds the new workflow to the list and shows a toast.
pub fn handle_workflow_crud_created(
  model: Model,
  workflow: Workflow,
) -> #(Model, Effect(Msg)) {
  // Add to org or project list based on project_id
  let #(org, project) = case workflow.project_id {
    opt.Some(_) -> {
      let project = case model.workflows_project {
        Loaded(existing) -> Loaded([workflow, ..existing])
        _ -> Loaded([workflow])
      }
      #(model.workflows_org, project)
    }
    opt.None -> {
      let org = case model.workflows_org {
        Loaded(existing) -> Loaded([workflow, ..existing])
        _ -> Loaded([workflow])
      }
      #(org, model.workflows_project)
    }
  }
  #(
    Model(
      ..model,
      workflows_org: org,
      workflows_project: project,
      workflows_dialog_mode: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.WorkflowCreated)),
    ),
    effect.none(),
  )
}

/// Handle workflow updated event from component.
/// Updates the workflow in the list and shows a toast.
pub fn handle_workflow_crud_updated(
  model: Model,
  updated_workflow: Workflow,
) -> #(Model, Effect(Msg)) {
  let update_list = fn(workflows: List(Workflow)) {
    list.map(workflows, fn(w: Workflow) {
      case w.id == updated_workflow.id {
        True -> updated_workflow
        False -> w
      }
    })
  }
  let org = case model.workflows_org {
    Loaded(existing) -> Loaded(update_list(existing))
    other -> other
  }
  let project = case model.workflows_project {
    Loaded(existing) -> Loaded(update_list(existing))
    other -> other
  }
  #(
    Model(
      ..model,
      workflows_org: org,
      workflows_project: project,
      workflows_dialog_mode: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.WorkflowUpdated)),
    ),
    effect.none(),
  )
}

/// Handle workflow deleted event from component.
/// Removes the workflow from the list and shows a toast.
pub fn handle_workflow_crud_deleted(
  model: Model,
  workflow_id: Int,
) -> #(Model, Effect(Msg)) {
  let filter_list = fn(workflows: List(Workflow)) {
    list.filter(workflows, fn(w: Workflow) { w.id != workflow_id })
  }
  let org = case model.workflows_org {
    Loaded(existing) -> Loaded(filter_list(existing))
    other -> other
  }
  let project = case model.workflows_project {
    Loaded(existing) -> Loaded(filter_list(existing))
    other -> other
  }
  #(
    Model(
      ..model,
      workflows_org: org,
      workflows_project: project,
      workflows_dialog_mode: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.WorkflowDeleted)),
    ),
    effect.none(),
  )
}

/// Handle workflow rules clicked (navigate to rules view).
pub fn handle_workflow_rules_clicked(
  model: Model,
  workflow_id: Int,
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      rules_workflow_id: opt.Some(workflow_id),
      rules: Loading,
      rules_metrics: Loading,
    )

  let task_types_effect = case model.selected_project_id {
    opt.Some(project_id) ->
      api_tasks.list_task_types(project_id, TaskTypesFetched)
    opt.None -> effect.none()
  }

  #(
    model,
    effect.batch([
      api_workflows.list_rules(workflow_id, RulesFetched),
      api_workflows.get_workflow_metrics(workflow_id, RuleMetricsFetched),
      task_types_effect,
    ]),
  )
}

// =============================================================================
// Rules Fetch Handlers
// =============================================================================

/// Handle rules fetch success.
pub fn handle_rules_fetched_ok(
  model: Model,
  rules: List(Rule),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules: Loaded(rules)), effect.none())
}

/// Handle rules fetch error.
pub fn handle_rules_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, rules: Failed(err)), effect.none())
  }
}

/// Handle rule metrics fetch success.
pub fn handle_rule_metrics_fetched_ok(
  model: Model,
  metrics: api_workflows.WorkflowMetrics,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_metrics: Loaded(metrics)), effect.none())
}

/// Handle rule metrics fetch error.
pub fn handle_rule_metrics_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, rules_metrics: Failed(err)), effect.none())
  }
}

/// Handle rules back clicked (return to workflows view).
pub fn handle_rules_back_clicked(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      rules_workflow_id: opt.None,
      rules: NotAsked,
      rules_metrics: NotAsked,
    ),
    effect.none(),
  )
}

// =============================================================================
// Rule Dialog Handlers
// =============================================================================

/// Handle rule create dialog open.
pub fn handle_rule_create_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_create_dialog_open: True), effect.none())
}

/// Handle rule create dialog close.
pub fn handle_rule_create_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      rules_create_dialog_open: False,
      rules_create_name: "",
      rules_create_goal: "",
      rules_create_resource_type: "task",
      rules_create_task_type_id: opt.None,
      rules_create_to_state: "completed",
      rules_create_active: True,
      rules_create_error: opt.None,
    ),
    effect.none(),
  )
}

// =============================================================================
// Rule Create Handlers
// =============================================================================

/// Handle rule create name change.
pub fn handle_rule_create_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_create_name: name), effect.none())
}

/// Handle rule create goal change.
pub fn handle_rule_create_goal_changed(
  model: Model,
  goal: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_create_goal: goal), effect.none())
}

/// Handle rule create resource type change.
/// Resets to_state to a valid default for the new resource type (AC11).
pub fn handle_rule_create_resource_type_changed(
  model: Model,
  resource_type: String,
) -> #(Model, Effect(Msg)) {
  let task_type_id = case resource_type {
    "task" -> model.rules_create_task_type_id
    _ -> opt.None
  }
  // Reset to_state to first valid option for the resource type
  let to_state = case resource_type {
    "task" -> "available"
    _ -> "pendiente"
  }
  #(
    Model(
      ..model,
      rules_create_resource_type: resource_type,
      rules_create_task_type_id: task_type_id,
      rules_create_to_state: to_state,
    ),
    effect.none(),
  )
}

/// Handle rule create task type id change.
pub fn handle_rule_create_task_type_id_changed(
  model: Model,
  task_type_id_str: String,
) -> #(Model, Effect(Msg)) {
  let task_type_id = case task_type_id_str {
    "" -> opt.None
    s ->
      case int.parse(s) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }
  }
  #(Model(..model, rules_create_task_type_id: task_type_id), effect.none())
}

/// Handle rule create to_state change.
pub fn handle_rule_create_to_state_changed(
  model: Model,
  to_state: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_create_to_state: to_state), effect.none())
}

/// Handle rule create active change.
pub fn handle_rule_create_active_changed(
  model: Model,
  active: Bool,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_create_active: active), effect.none())
}

/// Handle rule create form submission.
pub fn handle_rule_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.rules_create_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.rules_workflow_id {
        opt.None -> #(model, effect.none())
        opt.Some(workflow_id) -> {
          case model.rules_create_name {
            "" -> #(
              Model(
                ..model,
                rules_create_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.NameRequired,
                )),
              ),
              effect.none(),
            )
            name -> {
              let model =
                Model(
                  ..model,
                  rules_create_in_flight: True,
                  rules_create_error: opt.None,
                )
              #(
                model,
                api_workflows.create_rule(
                  workflow_id,
                  name,
                  model.rules_create_goal,
                  model.rules_create_resource_type,
                  model.rules_create_task_type_id,
                  model.rules_create_to_state,
                  model.rules_create_active,
                  RuleCreated,
                ),
              )
            }
          }
        }
      }
    }
  }
}

/// Handle rule created success.
pub fn handle_rule_created_ok(model: Model, rule: Rule) -> #(Model, Effect(Msg)) {
  let rules = case model.rules {
    Loaded(existing) -> Loaded([rule, ..existing])
    _ -> Loaded([rule])
  }
  #(
    Model(
      ..model,
      rules: rules,
      rules_create_dialog_open: False,
      rules_create_name: "",
      rules_create_goal: "",
      rules_create_resource_type: "task",
      rules_create_task_type_id: opt.None,
      rules_create_to_state: "completed",
      rules_create_active: True,
      rules_create_in_flight: False,
      rules_create_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle rule created error.
pub fn handle_rule_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(
        ..model,
        rules_create_in_flight: False,
        rules_create_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Rule Edit Handlers
// =============================================================================

/// Handle rule edit button clicked.
pub fn handle_rule_edit_clicked(
  model: Model,
  rule: Rule,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      rules_edit_id: opt.Some(rule.id),
      rules_edit_name: rule.name,
      rules_edit_goal: opt.unwrap(rule.goal, ""),
      rules_edit_resource_type: rule.resource_type,
      rules_edit_task_type_id: rule.task_type_id,
      rules_edit_to_state: rule.to_state,
      rules_edit_active: rule.active,
      rules_edit_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle rule edit name change.
pub fn handle_rule_edit_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_edit_name: name), effect.none())
}

/// Handle rule edit goal change.
pub fn handle_rule_edit_goal_changed(
  model: Model,
  goal: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_edit_goal: goal), effect.none())
}

/// Handle rule edit resource type change.
/// Resets to_state to a valid default for the new resource type (AC11).
pub fn handle_rule_edit_resource_type_changed(
  model: Model,
  resource_type: String,
) -> #(Model, Effect(Msg)) {
  let task_type_id = case resource_type {
    "task" -> model.rules_edit_task_type_id
    _ -> opt.None
  }
  // Reset to_state to first valid option for the resource type
  let to_state = case resource_type {
    "task" -> "available"
    _ -> "pendiente"
  }
  #(
    Model(
      ..model,
      rules_edit_resource_type: resource_type,
      rules_edit_task_type_id: task_type_id,
      rules_edit_to_state: to_state,
    ),
    effect.none(),
  )
}

/// Handle rule edit task type id change.
pub fn handle_rule_edit_task_type_id_changed(
  model: Model,
  task_type_id_str: String,
) -> #(Model, Effect(Msg)) {
  let task_type_id = case task_type_id_str {
    "" -> opt.None
    s ->
      case int.parse(s) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }
  }
  #(Model(..model, rules_edit_task_type_id: task_type_id), effect.none())
}

/// Handle rule edit to_state change.
pub fn handle_rule_edit_to_state_changed(
  model: Model,
  to_state: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_edit_to_state: to_state), effect.none())
}

/// Handle rule edit active change.
pub fn handle_rule_edit_active_changed(
  model: Model,
  active: Bool,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_edit_active: active), effect.none())
}

/// Handle rule edit form submission.
pub fn handle_rule_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.rules_edit_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.rules_edit_id {
        opt.Some(rule_id) -> {
          case model.rules_edit_name {
            "" -> #(
              Model(
                ..model,
                rules_edit_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.NameRequired,
                )),
              ),
              effect.none(),
            )
            name -> {
              let model =
                Model(
                  ..model,
                  rules_edit_in_flight: True,
                  rules_edit_error: opt.None,
                )
              #(
                model,
                api_workflows.update_rule(
                  rule_id,
                  name,
                  model.rules_edit_goal,
                  model.rules_edit_resource_type,
                  model.rules_edit_task_type_id,
                  model.rules_edit_to_state,
                  model.rules_edit_active,
                  RuleUpdated,
                ),
              )
            }
          }
        }
        opt.None -> #(model, effect.none())
      }
    }
  }
}

/// Handle rule edit cancelled.
pub fn handle_rule_edit_cancelled(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      rules_edit_id: opt.None,
      rules_edit_name: "",
      rules_edit_goal: "",
      rules_edit_resource_type: "task",
      rules_edit_task_type_id: opt.None,
      rules_edit_to_state: "completed",
      rules_edit_active: True,
      rules_edit_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle rule updated success.
pub fn handle_rule_updated_ok(
  model: Model,
  updated_rule: Rule,
) -> #(Model, Effect(Msg)) {
  let rules = case model.rules {
    Loaded(existing) ->
      Loaded(
        list.map(existing, fn(r) {
          case r.id == updated_rule.id {
            True -> updated_rule
            False -> r
          }
        }),
      )
    other -> other
  }
  #(
    Model(
      ..model,
      rules: rules,
      rules_edit_id: opt.None,
      rules_edit_name: "",
      rules_edit_goal: "",
      rules_edit_resource_type: "task",
      rules_edit_task_type_id: opt.None,
      rules_edit_to_state: "completed",
      rules_edit_active: True,
      rules_edit_in_flight: False,
      rules_edit_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle rule updated error.
pub fn handle_rule_updated_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(
        ..model,
        rules_edit_in_flight: False,
        rules_edit_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Rule Delete Handlers
// =============================================================================

/// Handle rule delete button clicked.
pub fn handle_rule_delete_clicked(
  model: Model,
  rule: Rule,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      rules_delete_confirm: opt.Some(rule),
      rules_delete_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle rule delete cancelled.
pub fn handle_rule_delete_cancelled(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, rules_delete_confirm: opt.None, rules_delete_error: opt.None),
    effect.none(),
  )
}

/// Handle rule delete confirmed.
pub fn handle_rule_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.rules_delete_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.rules_delete_confirm {
        opt.Some(rule) -> {
          let model =
            Model(
              ..model,
              rules_delete_in_flight: True,
              rules_delete_error: opt.None,
            )
          #(model, api_workflows.delete_rule(rule.id, RuleDeleted))
        }
        opt.None -> #(model, effect.none())
      }
    }
  }
}

/// Handle rule deleted success.
pub fn handle_rule_deleted_ok(model: Model) -> #(Model, Effect(Msg)) {
  let deleted_id = case model.rules_delete_confirm {
    opt.Some(rule) -> opt.Some(rule.id)
    opt.None -> opt.None
  }
  let rules = case model.rules, deleted_id {
    Loaded(existing), opt.Some(id) ->
      Loaded(list.filter(existing, fn(r) { r.id != id }))
    other, _ -> other
  }
  #(
    Model(
      ..model,
      rules: rules,
      rules_delete_confirm: opt.None,
      rules_delete_in_flight: False,
      rules_delete_error: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.RuleDeleted)),
    ),
    effect.none(),
  )
}

/// Handle rule deleted error.
pub fn handle_rule_deleted_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(
        ..model,
        rules_delete_in_flight: False,
        rules_delete_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Rule Templates Handlers
// =============================================================================

/// Handle rule templates fetch success.
pub fn handle_rule_templates_fetched_ok(
  model: Model,
  templates: List(RuleTemplate),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, rules_templates: Loaded(templates)), effect.none())
}

/// Handle rule templates fetch error.
pub fn handle_rule_templates_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, rules_templates: Failed(err)), effect.none())
  }
}

/// Handle rule attach template selected.
pub fn handle_rule_attach_template_selected(
  model: Model,
  template_id_str: String,
) -> #(Model, Effect(Msg)) {
  let template_id = case template_id_str {
    "" -> opt.None
    s ->
      case int.parse(s) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }
  }
  #(Model(..model, rules_attach_template_id: template_id), effect.none())
}

/// Handle rule attach template submitted.
pub fn handle_rule_attach_template_submitted(
  model: Model,
  rule_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.rules_attach_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.rules_attach_template_id {
        opt.Some(template_id) -> {
          let model =
            Model(
              ..model,
              rules_attach_in_flight: True,
              rules_attach_error: opt.None,
            )
          // Use execution_order = 0 (will be appended at end on server)
          #(
            model,
            api_workflows.attach_template(
              rule_id,
              template_id,
              0,
              RuleTemplateAttached,
            ),
          )
        }
        opt.None -> #(model, effect.none())
      }
    }
  }
}

/// Handle rule template attached success.
pub fn handle_rule_template_attached_ok(
  model: Model,
  templates: List(RuleTemplate),
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      rules_templates: Loaded(templates),
      rules_attach_template_id: opt.None,
      rules_attach_in_flight: False,
      rules_attach_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle rule template attached error.
pub fn handle_rule_template_attached_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(
        ..model,
        rules_attach_in_flight: False,
        rules_attach_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

/// Handle rule template detach clicked.
pub fn handle_rule_template_detach_clicked(
  model: Model,
  rule_id: Int,
  template_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.rules_attach_in_flight {
    True -> #(model, effect.none())
    False -> {
      let model =
        Model(
          ..model,
          rules_attach_in_flight: True,
          rules_attach_error: opt.None,
        )
      #(
        model,
        api_workflows.detach_template(
          rule_id,
          template_id,
          RuleTemplateDetached,
        ),
      )
    }
  }
}

/// Handle rule template detached success.
pub fn handle_rule_template_detached_ok(
  model: Model,
  template_id: Int,
) -> #(Model, Effect(Msg)) {
  let templates = case model.rules_templates {
    Loaded(existing) ->
      Loaded(list.filter(existing, fn(t) { t.id != template_id }))
    other -> other
  }
  #(
    Model(
      ..model,
      rules_templates: templates,
      rules_attach_in_flight: False,
      rules_attach_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle rule template detached error.
pub fn handle_rule_template_detached_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(
        ..model,
        rules_attach_in_flight: False,
        rules_attach_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Task Template Fetch Handlers
// =============================================================================

/// Handle org task templates fetch success.
pub fn handle_task_templates_org_fetched_ok(
  model: Model,
  templates: List(TaskTemplate),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, task_templates_org: Loaded(templates)), effect.none())
}

/// Handle org task templates fetch error.
pub fn handle_task_templates_org_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, task_templates_org: Failed(err)), effect.none())
  }
}

/// Handle project task templates fetch success.
pub fn handle_task_templates_project_fetched_ok(
  model: Model,
  templates: List(TaskTemplate),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, task_templates_project: Loaded(templates)), effect.none())
}

/// Handle project task templates fetch error.
pub fn handle_task_templates_project_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, task_templates_project: Failed(err)), effect.none())
  }
}

// =============================================================================
// Task Template Dialog Handlers (Component Pattern)
// =============================================================================

/// Handle opening a task template dialog (create, edit, or delete).
pub fn handle_open_task_template_dialog(
  model: Model,
  mode: TaskTemplateDialogMode,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, task_templates_dialog_mode: opt.Some(mode)), effect.none())
}

/// Handle closing any open task template dialog.
pub fn handle_close_task_template_dialog(model: Model) -> #(Model, Effect(Msg)) {
  #(Model(..model, task_templates_dialog_mode: opt.None), effect.none())
}

// =============================================================================
// Task Template Component Event Handlers
// =============================================================================

/// Handle task template created event from component.
/// Adds the new template to the list and shows a toast.
pub fn handle_task_template_crud_created(
  model: Model,
  template: TaskTemplate,
) -> #(Model, Effect(Msg)) {
  // Add to org or project list based on project_id
  let #(org, project) = case template.project_id {
    opt.Some(_) -> {
      let project = case model.task_templates_project {
        Loaded(existing) -> Loaded([template, ..existing])
        _ -> Loaded([template])
      }
      #(model.task_templates_org, project)
    }
    opt.None -> {
      let org = case model.task_templates_org {
        Loaded(existing) -> Loaded([template, ..existing])
        _ -> Loaded([template])
      }
      #(org, model.task_templates_project)
    }
  }
  #(
    Model(
      ..model,
      task_templates_org: org,
      task_templates_project: project,
      task_templates_dialog_mode: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskTemplateCreated)),
    ),
    effect.none(),
  )
}

/// Handle task template updated event from component.
/// Updates the template in the list and shows a toast.
pub fn handle_task_template_crud_updated(
  model: Model,
  updated_template: TaskTemplate,
) -> #(Model, Effect(Msg)) {
  let update_list = fn(templates: List(TaskTemplate)) {
    list.map(templates, fn(t: TaskTemplate) {
      case t.id == updated_template.id {
        True -> updated_template
        False -> t
      }
    })
  }
  let org = case model.task_templates_org {
    Loaded(existing) -> Loaded(update_list(existing))
    other -> other
  }
  let project = case model.task_templates_project {
    Loaded(existing) -> Loaded(update_list(existing))
    other -> other
  }
  #(
    Model(
      ..model,
      task_templates_org: org,
      task_templates_project: project,
      task_templates_dialog_mode: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskTemplateUpdated)),
    ),
    effect.none(),
  )
}

/// Handle task template deleted event from component.
/// Removes the template from the list and shows a toast.
pub fn handle_task_template_crud_deleted(
  model: Model,
  template_id: Int,
) -> #(Model, Effect(Msg)) {
  let filter_list = fn(templates: List(TaskTemplate)) {
    list.filter(templates, fn(t: TaskTemplate) { t.id != template_id })
  }
  let org = case model.task_templates_org {
    Loaded(existing) -> Loaded(filter_list(existing))
    other -> other
  }
  let project = case model.task_templates_project {
    Loaded(existing) -> Loaded(filter_list(existing))
    other -> other
  }
  #(
    Model(
      ..model,
      task_templates_org: org,
      task_templates_project: project,
      task_templates_dialog_mode: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskTemplateDeleted)),
    ),
    effect.none(),
  )
}

// =============================================================================
// Fetch Helpers
// =============================================================================

/// Fetch workflows for admin panel (both org and project scoped).
pub fn fetch_workflows(model: Model) -> #(Model, Effect(Msg)) {
  let org_effect = api_workflows.list_org_workflows(WorkflowsOrgFetched)
  let project_effect = case model.selected_project_id {
    opt.Some(project_id) ->
      api_workflows.list_project_workflows(project_id, WorkflowsProjectFetched)
    opt.None -> effect.none()
  }
  let model = Model(..model, workflows_org: Loading, workflows_project: Loading)
  #(model, effect.batch([org_effect, project_effect]))
}

/// Fetch task templates for admin panel (both org and project scoped).
pub fn fetch_task_templates(model: Model) -> #(Model, Effect(Msg)) {
  let org_effect = api_workflows.list_org_templates(TaskTemplatesOrgFetched)
  let project_effect = case model.selected_project_id {
    opt.Some(project_id) ->
      api_workflows.list_project_templates(
        project_id,
        TaskTemplatesProjectFetched,
      )
    opt.None -> effect.none()
  }
  let model =
    Model(..model, task_templates_org: Loading, task_templates_project: Loading)
  #(model, effect.batch([org_effect, project_effect]))
}
