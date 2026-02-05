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
import gleam/set

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow,
}
import scrumbringer_client/client_state.{
  type Model, type Msg, type TaskTemplateDialogMode, type WorkflowDialogMode,
  admin_msg, pool_msg, update_admin,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/i18n/text as i18n_text

import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/toast as helpers_toast

// =============================================================================
// Workflow Fetch Handlers
// =============================================================================

/// Handle project workflows fetch success.
pub fn handle_workflows_project_fetched_ok(
  model: Model,
  workflows: List(Workflow),
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_workflows(admin, fn(workflows_state) {
        admin_workflows.Model(
          ..workflows_state,
          workflows_project: Loaded(workflows),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle project workflows fetch error.
pub fn handle_workflows_project_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_workflows(admin, fn(workflows_state) {
          admin_workflows.Model(
            ..workflows_state,
            workflows_project: Failed(err),
          )
        })
      }),
      effect.none(),
    )
  })
}

// =============================================================================
// Workflow Dialog Handlers (Component Pattern)
// =============================================================================

/// Handle opening a workflow dialog (create, edit, or delete).
pub fn handle_open_workflow_dialog(
  model: Model,
  mode: WorkflowDialogMode,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_workflows(admin, fn(workflows_state) {
        admin_workflows.Model(
          ..workflows_state,
          workflows_dialog_mode: opt.Some(mode),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle closing any open workflow dialog.
pub fn handle_close_workflow_dialog(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_workflows(admin, fn(workflows_state) {
        admin_workflows.Model(
          ..workflows_state,
          workflows_dialog_mode: opt.None,
        )
      })
    }),
    effect.none(),
  )
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
      let project = case model.admin.workflows.workflows_project {
        Loaded(existing) -> Loaded([workflow, ..existing])
        _ -> Loaded([workflow])
      }
      #(model.admin.workflows.workflows_org, project)
    }
    opt.None -> {
      let org = case model.admin.workflows.workflows_org {
        Loaded(existing) -> Loaded([workflow, ..existing])
        _ -> Loaded([workflow])
      }
      #(org, model.admin.workflows.workflows_project)
    }
  }
  let model =
    update_admin(model, fn(admin) {
      update_workflows(admin, fn(_workflows_state) {
        admin_workflows.Model(
          workflows_org: org,
          workflows_project: project,
          workflows_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.WorkflowCreated,
    ))
  #(model, toast_fx)
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
  let org = case model.admin.workflows.workflows_org {
    Loaded(existing) -> Loaded(update_list(existing))
    other -> other
  }
  let project = case model.admin.workflows.workflows_project {
    Loaded(existing) -> Loaded(update_list(existing))
    other -> other
  }
  let model =
    update_admin(model, fn(admin) {
      update_workflows(admin, fn(_workflows_state) {
        admin_workflows.Model(
          workflows_org: org,
          workflows_project: project,
          workflows_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.WorkflowUpdated,
    ))
  #(model, toast_fx)
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
  let org = case model.admin.workflows.workflows_org {
    Loaded(existing) -> Loaded(filter_list(existing))
    other -> other
  }
  let project = case model.admin.workflows.workflows_project {
    Loaded(existing) -> Loaded(filter_list(existing))
    other -> other
  }
  let model =
    update_admin(model, fn(admin) {
      update_workflows(admin, fn(_workflows_state) {
        admin_workflows.Model(
          workflows_org: org,
          workflows_project: project,
          workflows_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.WorkflowDeleted,
    ))
  #(model, toast_fx)
}

/// Handle workflow rules clicked (navigate to rules view).
pub fn handle_workflow_rules_clicked(
  model: Model,
  workflow_id: Int,
) -> #(Model, Effect(Msg)) {
  let model =
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules_workflow_id: opt.Some(workflow_id),
          rules: Loading,
          rules_metrics: Loading,
        )
      })
    })

  let task_types_effect = case model.core.selected_project_id {
    opt.Some(project_id) ->
      api_tasks.list_task_types(project_id, fn(result) {
        admin_msg(admin_messages.TaskTypesFetched(result))
      })
    opt.None -> effect.none()
  }

  #(
    model,
    effect.batch([
      api_workflows.list_rules(workflow_id, fn(result) {
        pool_msg(pool_messages.RulesFetched(result))
      }),
      api_workflows.get_workflow_metrics(workflow_id, fn(result) {
        pool_msg(pool_messages.RuleMetricsFetched(result))
      }),
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
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(..rules_state, rules: Loaded(rules))
      })
    }),
    effect.none(),
  )
}

/// Handle rules fetch error.
pub fn handle_rules_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_rules(admin, fn(rules_state) {
          admin_rules.Model(..rules_state, rules: Failed(err))
        })
      }),
      effect.none(),
    )
  })
}

/// Handle rule metrics fetch success.
pub fn handle_rule_metrics_fetched_ok(
  model: Model,
  metrics: api_workflows.WorkflowMetrics,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(..rules_state, rules_metrics: Loaded(metrics))
      })
    }),
    effect.none(),
  )
}

/// Handle rule metrics fetch error.
pub fn handle_rule_metrics_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_rules(admin, fn(rules_state) {
          admin_rules.Model(..rules_state, rules_metrics: Failed(err))
        })
      }),
      effect.none(),
    )
  })
}

/// Handle rules back clicked (return to workflows view).
pub fn handle_rules_back_clicked(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules_workflow_id: opt.None,
          rules: NotAsked,
          rules_metrics: NotAsked,
        )
      })
    }),
    effect.none(),
  )
}

// =============================================================================
// Rule Dialog Handlers (Component Pattern)
// =============================================================================

/// Handle opening a rule dialog (create, edit, or delete).
pub fn handle_open_rule_dialog(
  model: Model,
  mode: client_state.RuleDialogMode,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules_dialog_mode: opt.Some(mode),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle closing any open rule dialog.
pub fn handle_close_rule_dialog(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules_dialog_mode: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

// =============================================================================
// Rule Component Event Handlers
// =============================================================================

/// Handle rule created event from component.
/// Adds the new rule to the list and shows a toast.
pub fn handle_rule_crud_created(
  model: Model,
  rule: Rule,
) -> #(Model, Effect(Msg)) {
  let rules = case model.admin.rules.rules {
    Loaded(existing) -> Loaded([rule, ..existing])
    _ -> Loaded([rule])
  }
  let model =
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules: rules,
          rules_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.RuleCreated,
    ))
  #(model, toast_fx)
}

/// Handle rule updated event from component.
/// Updates the rule in the list and shows a toast.
pub fn handle_rule_crud_updated(
  model: Model,
  updated_rule: Rule,
) -> #(Model, Effect(Msg)) {
  let rules = case model.admin.rules.rules {
    Loaded(existing) ->
      Loaded(
        list.map(existing, fn(r: Rule) {
          case r.id == updated_rule.id {
            True -> updated_rule
            False -> r
          }
        }),
      )
    other -> other
  }
  let model =
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules: rules,
          rules_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.RuleUpdated,
    ))
  #(model, toast_fx)
}

/// Handle rule deleted event from component.
/// Removes the rule from the list and shows a toast.
pub fn handle_rule_crud_deleted(
  model: Model,
  rule_id: Int,
) -> #(Model, Effect(Msg)) {
  let rules = case model.admin.rules.rules {
    Loaded(existing) ->
      Loaded(list.filter(existing, fn(r: Rule) { r.id != rule_id }))
    other -> other
  }
  let model =
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules: rules,
          rules_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.RuleDeleted,
    ))
  #(model, toast_fx)
}

// =============================================================================
// Rule Templates Handlers
// =============================================================================

/// Handle rule templates fetch success.
pub fn handle_rule_templates_fetched_ok(
  model: Model,
  templates: List(RuleTemplate),
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules_templates: Loaded(templates),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle rule templates fetch error.
pub fn handle_rule_templates_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_rules(admin, fn(rules_state) {
          admin_rules.Model(
            ..rules_state,
            rules_templates: Failed(err),
          )
        })
      }),
      effect.none(),
    )
  })
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
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules_attach_template_id: template_id,
        )
      })
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle rule attach template submitted.
pub fn handle_rule_attach_template_submitted(
  model: Model,
  rule_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.admin.rules.rules_attach_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.admin.rules.rules_attach_template_id {
        opt.Some(template_id) -> {
          let model =
            update_admin(model, fn(admin) {
              update_rules(admin, fn(rules_state) {
                admin_rules.Model(
                  ..rules_state,
                  rules_attach_in_flight: True,
                  rules_attach_error: opt.None,
                )
              })
            })
          // Use execution_order = 0 (will be appended at end on server)
          #(
            model,
            api_workflows.attach_template(rule_id, template_id, 0, fn(result) {
              pool_msg(pool_messages.RuleTemplateAttached(result))
            }),
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
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules_templates: Loaded(templates),
          rules_attach_template_id: opt.None,
          rules_attach_in_flight: False,
          rules_attach_error: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle rule template attached error.
pub fn handle_rule_template_attached_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_rules(admin, fn(rules_state) {
          admin_rules.Model(
            ..rules_state,
            rules_attach_in_flight: False,
            rules_attach_error: opt.Some(err.message),
          )
        })
      }),
      effect.none(),
    )
  })
}

/// Handle rule template detach clicked.
pub fn handle_rule_template_detach_clicked(
  model: Model,
  rule_id: Int,
  template_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.admin.rules.rules_attach_in_flight {
    True -> #(model, effect.none())
    False -> {
      let model =
        update_admin(model, fn(admin) {
          update_rules(admin, fn(rules_state) {
            admin_rules.Model(
              ..rules_state,
              rules_attach_in_flight: True,
              rules_attach_error: opt.None,
            )
          })
        })
      #(
        model,
        api_workflows.detach_template(rule_id, template_id, fn(result) {
          pool_msg(pool_messages.RuleTemplateDetached(result))
        }),
      )
    }
  }
}

/// Handle rule template detached success.
pub fn handle_rule_template_detached_ok(
  model: Model,
  template_id: Int,
) -> #(Model, Effect(Msg)) {
  let templates = case model.admin.rules.rules_templates {
    Loaded(existing) ->
      Loaded(list.filter(existing, fn(t) { t.id != template_id }))
    other -> other
  }
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules_templates: templates,
          rules_attach_in_flight: False,
          rules_attach_error: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle rule template detached error.
pub fn handle_rule_template_detached_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_rules(admin, fn(rules_state) {
          admin_rules.Model(
            ..rules_state,
            rules_attach_in_flight: False,
            rules_attach_error: opt.Some(err.message),
          )
        })
      }),
      effect.none(),
    )
  })
}

// =============================================================================
// Story 4.10: Rule Template Attachment UI Handlers
// =============================================================================

/// Toggle rule expansion to show/hide attached templates.
pub fn handle_rule_expand_toggled(
  model: Model,
  rule_id: Int,
) -> #(Model, Effect(Msg)) {
  let expanded = case set.contains(model.admin.rules.rules_expanded, rule_id) {
    True -> set.delete(model.admin.rules.rules_expanded, rule_id)
    False -> set.insert(model.admin.rules.rules_expanded, rule_id)
  }
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules_expanded: expanded,
        )
      })
    }),
    effect.none(),
  )
}

/// Open the attach template modal for a specific rule.
/// Also fetches templates if not already loaded.
pub fn handle_attach_template_modal_opened(
  model: Model,
  rule_id: Int,
) -> #(Model, Effect(Msg)) {
  // Check if we need to fetch templates
  let fetch_effect = case
    model.admin.task_templates.task_templates_project,
    model.core.selected_project_id
  {
    // Already loaded or loading - no need to fetch
    Loaded(_), _ -> effect.none()
    Loading, _ -> effect.none()
    // Need to fetch templates for the project
    _, opt.Some(project_id) ->
      api_workflows.list_project_templates(project_id, fn(result) {
        pool_msg(pool_messages.TaskTemplatesProjectFetched(result))
      })
    // No project selected - can't fetch
    _, opt.None -> effect.none()
  }

  let task_templates_project = case
    model.admin.task_templates.task_templates_project,
    model.core.selected_project_id
  {
    Loaded(_), _ -> model.admin.task_templates.task_templates_project
    Loading, _ -> model.admin.task_templates.task_templates_project
    _, opt.Some(_) -> Loading
    _, opt.None -> model.admin.task_templates.task_templates_project
  }

  let new_model =
    update_admin(model, fn(admin) {
      let rules =
        admin_rules.Model(
          ..admin.rules,
          attach_template_modal: opt.Some(rule_id),
          attach_template_selected: opt.None,
          attach_template_loading: False,
        )

      let task_templates =
        admin_task_templates.Model(
          ..admin.task_templates,
          task_templates_project: task_templates_project,
        )

      admin_state.AdminModel(..admin, rules: rules, task_templates: task_templates)
    })

  #(new_model, fetch_effect)
}

/// Close the attach template modal.
pub fn handle_attach_template_modal_closed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          attach_template_modal: opt.None,
          attach_template_selected: opt.None,
          attach_template_loading: False,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle template selection in the attach modal.
pub fn handle_attach_template_selected(
  model: Model,
  template_id: Int,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          attach_template_selected: opt.Some(template_id),
        )
      })
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle submit of template attachment.
pub fn handle_attach_template_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.rules.attach_template_modal, model.admin.rules.attach_template_selected {
    opt.Some(rule_id), opt.Some(template_id) -> {
      // Calculate execution_order based on current templates
      let order = case model.admin.rules.rules {
        Loaded(rules) -> {
          case list.find(rules, fn(r) { r.id == rule_id }) {
            Ok(rule) -> list.length(rule.templates) + 1
            Error(_) -> 1
          }
        }
        _ -> 1
      }
      #(
        update_admin(model, fn(admin) {
          update_rules(admin, fn(rules_state) {
            admin_rules.Model(
              ..rules_state,
              attach_template_loading: True,
            )
          })
        }),
        api_workflows.attach_template(rule_id, template_id, order, fn(result) {
          case result {
            Ok(templates) ->
              pool_msg(pool_messages.AttachTemplateSucceeded(rule_id, templates))
            Error(err) -> pool_msg(pool_messages.AttachTemplateFailed(err))
          }
        }),
      )
    }
    _, _ -> #(model, effect.none())
  }
}

/// Handle successful template attachment.
/// AC18: Toast "Plantilla asociada" after success.
pub fn handle_attach_template_succeeded(
  model: Model,
  rule_id: Int,
  templates: List(RuleTemplate),
) -> #(Model, Effect(Msg)) {
  // Update the rule's templates in the rules list
  let updated_rules = case model.admin.rules.rules {
    Loaded(rules) -> {
      Loaded(
        list.map(rules, fn(r) {
          case r.id == rule_id {
            True -> workflow.Rule(..r, templates: templates)
            False -> r
          }
        }),
      )
    }
    other -> other
  }
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules: updated_rules,
          attach_template_modal: opt.None,
          attach_template_selected: opt.None,
          attach_template_loading: False,
        )
      })
    }),
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TemplateAttached,
    )),
  )
}

/// Handle failed template attachment.
/// AC22: Error toast if operation fails.
pub fn handle_attach_template_failed(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_rules(admin, fn(rules_state) {
          admin_rules.Model(
            ..rules_state,
            attach_template_loading: False,
            rules_attach_error: opt.Some(err.message),
          )
        })
      }),
      helpers_toast.toast_error(err.message),
    )
  })
}

/// Handle template detach click.
pub fn handle_template_detach_clicked(
  model: Model,
  rule_id: Int,
  template_id: Int,
) -> #(Model, Effect(Msg)) {
  let detaching =
    set.insert(model.admin.rules.detaching_templates, #(rule_id, template_id))
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          detaching_templates: detaching,
        )
      })
    }),
    api_workflows.detach_template(rule_id, template_id, fn(result) {
      case result {
        Ok(_) ->
          pool_msg(pool_messages.TemplateDetachSucceeded(rule_id, template_id))
        Error(err) ->
          pool_msg(pool_messages.TemplateDetachFailed(rule_id, template_id, err))
      }
    }),
  )
}

/// Handle successful template detachment.
/// AC19: Toast "Plantilla desasociada" after success.
pub fn handle_template_detach_succeeded(
  model: Model,
  rule_id: Int,
  template_id: Int,
) -> #(Model, Effect(Msg)) {
  let detaching =
    set.delete(model.admin.rules.detaching_templates, #(rule_id, template_id))
  // Remove template from rule's templates list
  let updated_rules = case model.admin.rules.rules {
    Loaded(rules) -> {
      Loaded(
        list.map(rules, fn(r) {
          case r.id == rule_id {
            True ->
              workflow.Rule(
                ..r,
                templates: list.filter(r.templates, fn(t) {
                  t.id != template_id
                }),
              )
            False -> r
          }
        }),
      )
    }
    other -> other
  }
  #(
    update_admin(model, fn(admin) {
      update_rules(admin, fn(rules_state) {
        admin_rules.Model(
          ..rules_state,
          rules: updated_rules,
          detaching_templates: detaching,
        )
      })
    }),
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TemplateDetached,
    )),
  )
}

/// Handle failed template detachment.
/// AC22: Error toast if operation fails.
pub fn handle_template_detach_failed(
  model: Model,
  rule_id: Int,
  template_id: Int,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  let detaching =
    set.delete(model.admin.rules.detaching_templates, #(rule_id, template_id))
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_rules(admin, fn(rules_state) {
          admin_rules.Model(
            ..rules_state,
            detaching_templates: detaching,
            rules_attach_error: opt.Some(err.message),
          )
        })
      }),
      helpers_toast.toast_error(err.message),
    )
  })
}

// =============================================================================
// Task Template Fetch Handlers
// =============================================================================

/// Handle project task templates fetch success.
pub fn handle_task_templates_project_fetched_ok(
  model: Model,
  templates: List(TaskTemplate),
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_templates(admin, fn(task_templates_state) {
        admin_task_templates.Model(
          ..task_templates_state,
          task_templates_project: Loaded(templates),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle project task templates fetch error.
pub fn handle_task_templates_project_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_task_templates(admin, fn(task_templates_state) {
          admin_task_templates.Model(
            ..task_templates_state,
            task_templates_project: Failed(err),
          )
        })
      }),
      effect.none(),
    )
  })
}

// =============================================================================
// Task Template Dialog Handlers (Component Pattern)
// =============================================================================

/// Handle opening a task template dialog (create, edit, or delete).
pub fn handle_open_task_template_dialog(
  model: Model,
  mode: TaskTemplateDialogMode,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_templates(admin, fn(task_templates_state) {
        admin_task_templates.Model(
          ..task_templates_state,
          task_templates_dialog_mode: opt.Some(mode),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle closing any open task template dialog.
pub fn handle_close_task_template_dialog(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_templates(admin, fn(task_templates_state) {
        admin_task_templates.Model(
          ..task_templates_state,
          task_templates_dialog_mode: opt.None,
        )
      })
    }),
    effect.none(),
  )
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
      let project = case model.admin.task_templates.task_templates_project {
        Loaded(existing) -> Loaded([template, ..existing])
        _ -> Loaded([template])
      }
      #(model.admin.task_templates.task_templates_org, project)
    }
    opt.None -> {
      let org = case model.admin.task_templates.task_templates_org {
        Loaded(existing) -> Loaded([template, ..existing])
        _ -> Loaded([template])
      }
      #(org, model.admin.task_templates.task_templates_project)
    }
  }
  let model =
    update_admin(model, fn(admin) {
      update_task_templates(admin, fn(_task_templates_state) {
        admin_task_templates.Model(
          task_templates_org: org,
          task_templates_project: project,
          task_templates_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TaskTemplateCreated,
    ))
  #(model, toast_fx)
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
  let org = case model.admin.task_templates.task_templates_org {
    Loaded(existing) -> Loaded(update_list(existing))
    other -> other
  }
  let project = case model.admin.task_templates.task_templates_project {
    Loaded(existing) -> Loaded(update_list(existing))
    other -> other
  }
  let model =
    update_admin(model, fn(admin) {
      update_task_templates(admin, fn(_task_templates_state) {
        admin_task_templates.Model(
          task_templates_org: org,
          task_templates_project: project,
          task_templates_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TaskTemplateUpdated,
    ))
  #(model, toast_fx)
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
  let org = case model.admin.task_templates.task_templates_org {
    Loaded(existing) -> Loaded(filter_list(existing))
    other -> other
  }
  let project = case model.admin.task_templates.task_templates_project {
    Loaded(existing) -> Loaded(filter_list(existing))
    other -> other
  }
  let model =
    update_admin(model, fn(admin) {
      update_task_templates(admin, fn(_task_templates_state) {
        admin_task_templates.Model(
          task_templates_org: org,
          task_templates_project: project,
          task_templates_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TaskTemplateDeleted,
    ))
  #(model, toast_fx)
}

// =============================================================================
// Fetch Helpers
// =============================================================================

/// Fetch workflows for admin panel (project-scoped only).
pub fn fetch_workflows(model: Model) -> #(Model, Effect(Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> {
      let fetch_effect =
        api_workflows.list_project_workflows(project_id, fn(result) {
          pool_msg(pool_messages.WorkflowsProjectFetched(result))
        })
      let model =
        update_admin(model, fn(admin) {
          update_workflows(admin, fn(workflows_state) {
            admin_workflows.Model(
              ..workflows_state,
              workflows_project: Loading,
            )
          })
        })
      #(model, fetch_effect)
    }
    opt.None -> #(model, effect.none())
  }
}

/// Fetch task templates for admin panel (project-scoped only).
pub fn fetch_task_templates(model: Model) -> #(Model, Effect(Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> {
      let fetch_effect =
        api_workflows.list_project_templates(project_id, fn(result) {
          pool_msg(pool_messages.TaskTemplatesProjectFetched(result))
        })
      let model =
        update_admin(model, fn(admin) {
          update_task_templates(admin, fn(task_templates_state) {
            admin_task_templates.Model(
              ..task_templates_state,
              task_templates_project: Loading,
            )
          })
        })
      #(model, fetch_effect)
    }
    opt.None -> #(model, effect.none())
  }
}

fn update_workflows(
  admin: admin_state.AdminModel,
  f: fn(admin_workflows.Model) -> admin_workflows.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, workflows: f(admin.workflows))
}

fn update_rules(
  admin: admin_state.AdminModel,
  f: fn(admin_rules.Model) -> admin_rules.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, rules: f(admin.rules))
}

fn update_task_templates(
  admin: admin_state.AdminModel,
  f: fn(admin_task_templates.Model) -> admin_task_templates.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, task_templates: f(admin.task_templates))
}
