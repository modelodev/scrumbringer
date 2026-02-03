//// Admin workflows, rules, task templates, and rule metrics views.
////
//// ## Mission
////
//// Render workflow-related admin views and their dialog components.
////
//// ## Responsibilities
////
//// - Workflows list and rules drill-down
//// - Task templates management
//// - Rule metrics tab
////
//// ## Relations
////
//// - **features/admin/view.gleam**: Delegates to this module
//// - **features/admin/update.gleam**: Handles workflow-related messages
//// - **client_state.gleam**: Provides Model/Msg types

import gleam/int
import gleam/json
import gleam/list
import gleam/option as opt
import gleam/result
import gleam/set

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  a, button, div, h3, hr, input, label, p, span, table, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import gleam/dynamic/decode

import domain/project.{type Project}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task_type.{type TaskType}
import domain/workflow.{type Rule, type TaskTemplate, type Workflow, Workflow}

import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, AdminRuleMetricsDrilldownClicked,
  AdminRuleMetricsDrilldownClosed, AdminRuleMetricsExecPageChanged,
  AdminRuleMetricsFromChangedAndRefresh, AdminRuleMetricsQuickRangeClicked,
  AdminRuleMetricsToChangedAndRefresh, AdminRuleMetricsWorkflowExpanded,
  AttachTemplateModalClosed, AttachTemplateModalOpened, AttachTemplateSelected,
  AttachTemplateSubmitted, CloseRuleDialog, CloseTaskTemplateDialog,
  CloseWorkflowDialog, NoOp, OpenRuleDialog, OpenTaskTemplateDialog,
  OpenWorkflowDialog, RuleCrudCreated, RuleCrudDeleted, RuleCrudUpdated,
  RuleExpandToggled, RulesBackClicked, TaskTemplateCrudCreated,
  TaskTemplateCrudDeleted, TaskTemplateCrudUpdated, TemplateDetachClicked,
  WorkflowCrudCreated, WorkflowCrudDeleted, WorkflowCrudUpdated,
  WorkflowRulesClicked, pool_msg,
}
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/expand_toggle
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/info_callout
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/modal_header
import scrumbringer_client/ui/remote as ui_remote
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers

// =============================================================================
// Workflows Views
// =============================================================================

/// Workflows management view.
pub fn view_workflows(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  // If we're viewing rules for a specific workflow, show rules view
  case model.admin.rules_workflow_id {
    opt.Some(workflow_id) -> view_workflow_rules(model, workflow_id)
    opt.None -> view_workflows_list(model, selected_project)
  }
}

fn view_workflows_list(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  // Workflows are project-scoped, so require a project to be selected (AC22)
  case selected_project {
    opt.None ->
      div([attribute.class("section")], [
        div([attribute.class("empty")], [
          text(update_helpers.i18n_t(model, i18n_text.SelectProjectForWorkflows)),
        ]),
      ])
    opt.Some(project) ->
      div([attribute.class("section")], [
        // Section header with add button (Story 4.8: consistent icons)
        section_header.view_with_action(
          icons.Workflows,
          update_helpers.i18n_t(
            model,
            i18n_text.WorkflowsProjectTitle(project.name),
          ),
          dialog.add_button(
            model,
            i18n_text.CreateWorkflow,
            pool_msg(OpenWorkflowDialog(state_types.WorkflowDialogCreate)),
          ),
        ),
        // Story 4.9 AC21: Contextual hint with link to Templates
        view_rules_hint(model),
        // Project workflows table (AC23)
        view_workflows_table(
          model,
          model.admin.workflows_project,
          opt.Some(project),
        ),
        // Workflow CRUD dialog component (handles create, edit, delete)
        view_workflow_crud_dialog(model),
      ])
  }
}

/// Story 4.9 AC21: Contextual hint linking Rules to Templates.
fn view_rules_hint(model: Model) -> Element(Msg) {
  info_callout.view_with_content(
    opt.None,
    span([], [
      text(update_helpers.i18n_t(model, i18n_text.RulesHintTemplates)),
      a(
        [
          attribute.href("/config/templates"),
          attribute.class("info-callout-link"),
        ],
        [
          text(
            update_helpers.i18n_t(model, i18n_text.RulesHintTemplatesLink)
            <> " \u{2192}",
          ),
        ],
      ),
    ]),
  )
}

// Justification: nested case keeps dialog mode and project scoping logic colocated.

/// Render the workflow-crud-dialog Lustre component.
fn view_workflow_crud_dialog(model: Model) -> Element(Msg) {
  case model.admin.workflows_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, workflow_json, project_id_attr) = case mode {
        state_types.WorkflowDialogCreate -> #(
          "create",
          attribute.none(),
          case model.core.selected_project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
        state_types.WorkflowDialogEdit(workflow) -> #(
          "edit",
          attribute.property(
            "workflow",
            workflow_to_property_json(workflow, "edit"),
          ),
          case workflow.project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
        state_types.WorkflowDialogDelete(workflow) -> #(
          "delete",
          attribute.property(
            "workflow",
            workflow_to_property_json(workflow, "delete"),
          ),
          case workflow.project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
      }

      element.element(
        "workflow-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", locale.serialize(model.ui.locale)),
          project_id_attr,
          attribute.attribute("mode", mode_str),
          // Property for workflow data (edit/delete modes)
          workflow_json,
          // Event listeners for component events
          event.on("workflow-created", decode_workflow_created_event()),
          event.on("workflow-updated", decode_workflow_updated_event()),
          event.on("workflow-deleted", decode_workflow_deleted_event()),
          event.on("close-requested", decode_workflow_close_requested_event()),
        ],
        [],
      )
    }
  }
}

/// Convert workflow to JSON for property passing to component.
fn workflow_to_property_json(workflow: Workflow, mode: String) -> json.Json {
  json.object([
    #("id", json.int(workflow.id)),
    #("org_id", json.int(workflow.org_id)),
    #("project_id", case workflow.project_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("name", json.string(workflow.name)),
    #("description", case workflow.description {
      opt.Some(desc) -> json.string(desc)
      opt.None -> json.null()
    }),
    #("active", json.bool(workflow.active)),
    #("rule_count", json.int(workflow.rule_count)),
    #("created_by", json.int(workflow.created_by)),
    #("created_at", json.string(workflow.created_at)),
    #("_mode", json.string(mode)),
  ])
}

/// Decoder for workflow-created event.
fn decode_workflow_created_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(workflow_decoder(), fn(workflow) {
    decode.success(pool_msg(WorkflowCrudCreated(workflow)))
  })
}

/// Decoder for workflow-updated event.
fn decode_workflow_updated_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(workflow_decoder(), fn(workflow) {
    decode.success(pool_msg(WorkflowCrudUpdated(workflow)))
  })
}

/// Decoder for workflow-deleted event.
fn decode_workflow_deleted_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(
    decode.field("id", decode.int, decode.success),
    fn(id) { decode.success(pool_msg(WorkflowCrudDeleted(id))) },
  )
}

/// Decoder for Workflow from JSON (used in custom events).
fn workflow_decoder() -> decode.Decoder(Workflow) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", decode.optional(decode.int))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use active <- decode.field("active", decode.bool)
  use rule_count <- decode.field("rule_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Workflow(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    active: active,
    rule_count: rule_count,
    created_by: created_by,
    created_at: created_at,
  ))
}

/// Decoder for close-requested event from workflow dialog.
fn decode_workflow_close_requested_event() -> decode.Decoder(Msg) {
  decode.success(pool_msg(CloseWorkflowDialog))
}

fn view_workflows_table(
  model: Model,
  workflows: Remote(List(Workflow)),
  _project: opt.Option(Project),
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  data_table.view_remote_with_forbidden(
    workflows,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoWorkflowsYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name
        data_table.column(t(i18n_text.WorkflowName), fn(w: Workflow) {
          text(w.name)
        }),
        // Active status
        data_table.column(t(i18n_text.WorkflowActive), fn(w: Workflow) {
          text(case w.active {
            True -> "✓"
            False -> "✗"
          })
        }),
        // Rules count
        data_table.column(t(i18n_text.WorkflowRules), fn(w: Workflow) {
          text(int.to_string(w.rule_count))
        }),
        // Actions
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(w: Workflow) { view_workflow_actions(model, w) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(w: Workflow) { int.to_string(w.id) }),
  )
}

fn view_workflow_actions(model: Model, w: Workflow) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  div([attribute.class("btn-group")], [
    // Rules button - navigate to rules view
    button(
      [
        attribute.class("btn-icon btn-xs"),
        attribute.attribute("title", t(i18n_text.WorkflowRules)),
        event.on_click(pool_msg(WorkflowRulesClicked(w.id))),
      ],
      [icons.nav_icon(icons.Cog, icons.Small)],
    ),
    // Edit button
    action_buttons.edit_button(
      t(i18n_text.EditWorkflow),
      pool_msg(OpenWorkflowDialog(state_types.WorkflowDialogEdit(w))),
    ),
    // Delete button
    action_buttons.delete_button(
      t(i18n_text.DeleteWorkflow),
      pool_msg(OpenWorkflowDialog(state_types.WorkflowDialogDelete(w))),
    ),
  ])
}

// =============================================================================
// Rules Views
// =============================================================================

fn view_workflow_rules(model: Model, workflow_id: Int) -> Element(Msg) {
  // Find the workflow name
  let workflow_name =
    find_workflow_name(model.admin.workflows_org, workflow_id)
    |> opt.lazy_or(fn() {
      find_workflow_name(model.admin.workflows_project, workflow_id)
    })
    |> opt.unwrap("Workflow #" <> int.to_string(workflow_id))

  div([attribute.class("section")], [
    button([event.on_click(pool_msg(RulesBackClicked))], [
      text("← Back to Workflows"),
    ]),
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Rules,
      update_helpers.i18n_t(model, i18n_text.RulesTitle(workflow_name)),
      dialog.add_button(
        model,
        i18n_text.CreateRule,
        pool_msg(OpenRuleDialog(state_types.RuleDialogCreate)),
      ),
    ),
    view_rules_table(model, model.admin.rules, model.admin.rules_metrics),
    // Rule CRUD dialog component (handles create/edit/delete internally)
    view_rule_crud_dialog(model, workflow_id),
  ])
}

fn find_workflow_name(
  workflows: Remote(List(Workflow)),
  workflow_id: Int,
) -> opt.Option(String) {
  case workflows {
    Loaded(list) ->
      list
      |> list.find(fn(w) { w.id == workflow_id })
      |> result.map(fn(w) { w.name })
      |> opt.from_result
    _ -> opt.None
  }
}

// Justification: nested case improves clarity for branching logic.
fn view_rules_table(
  model: Model,
  rules: Remote(List(Rule)),
  metrics: Remote(api_workflows.WorkflowMetrics),
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  ui_remote.view_remote(
    rules,
    loading: fn() { loading.loading(t(i18n_text.LoadingEllipsis)) },
    error: fn(err) {
      case err.status {
        403 ->
          div([attribute.class("forbidden")], [text(t(i18n_text.NotPermitted))])
        _ -> error_notice.view(err.message)
      }
    },
    loaded: fn(rs) {
      case rs {
        [] -> empty_state.simple(icons.Inbox, t(i18n_text.NoRulesYet))
        _ ->
          div([attribute.class("rules-expandable-table")], [
            table([attribute.class("table data-table")], [
              thead([], [
                tr([], [
                  th([attribute.class("col-expand")], []),
                  th([], [text(t(i18n_text.RuleName))]),
                  th([], [text(t(i18n_text.RuleResourceType))]),
                  th([], [text(t(i18n_text.RuleToState))]),
                  th([], [text(t(i18n_text.RuleActive))]),
                  th([], [text(t(i18n_text.RuleTemplates))]),
                  th([], [text(t(i18n_text.RuleMetricsApplied))]),
                  th([], [text(t(i18n_text.RuleMetricsSuppressed))]),
                  th([attribute.class("col-actions")], [
                    text(t(i18n_text.Actions)),
                  ]),
                ]),
              ]),
              keyed.tbody(
                [],
                list.flat_map(rs, fn(r) {
                  view_rule_row_expandable(
                    model,
                    r,
                    get_rule_metrics(metrics, r.id),
                  )
                }),
              ),
            ]),
            // Attach template modal
            view_attach_template_modal(model),
          ])
      }
    },
  )
}

// Justification: large function kept intact to preserve cohesive UI logic.

/// Render an expandable rule row with optional expansion for attached templates.
fn view_rule_row_expandable(
  model: Model,
  rule: Rule,
  rule_metrics: #(Int, Int),
) -> List(#(String, Element(Msg))) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }
  let is_expanded = set.contains(model.admin.rules_expanded, rule.id)
  let _expand_title = case is_expanded {
    True -> t(i18n_text.CollapseRule)
    False -> t(i18n_text.ExpandRule)
  }
  let #(applied, suppressed) = rule_metrics
  let template_count = list.length(rule.templates)

  // AC2: Whole row is clickeable (via row class + click handler)
  // AC5: aria-expanded attribute
  let row_class = case is_expanded {
    True -> "rule-row rule-row-expandable rule-row-expanded"
    False -> "rule-row rule-row-expandable"
  }

  let main_row = #(
    "rule-" <> int.to_string(rule.id),
    tr(
      [
        attribute.class(row_class),
        attribute.attribute("aria-expanded", case is_expanded {
          True -> "true"
          False -> "false"
        }),
        // AC2: Click anywhere on the row to expand/collapse
        event.on_click(pool_msg(RuleExpandToggled(rule.id))),
      ],
      [
        // Expand/collapse icon (AC1: visual indicator) - use triangles for consistency
        td([attribute.class("cell-expand")], [
          expand_toggle.view_with_class(is_expanded, "rule-expand-icon"),
        ]),
        // Name
        td([], [text(rule.name)]),
        // Resource type with task type info if applicable
        td([attribute.class("cell-resource-type")], [
          view_rule_resource_type(model, rule),
        ]),
        // To state
        td([], [text(rule.to_state)]),
        // Active status with completeness indicator (AC6-8)
        td([attribute.class("cell-status")], [
          view_rule_active_status(model, rule.active, template_count),
        ]),
        // Templates count badge
        td([attribute.class("cell-templates")], [
          case template_count {
            0 ->
              badge.new_unchecked("0", badge.Neutral)
              |> badge.view_with_class("badge-empty")
            n ->
              badge.new_unchecked(int.to_string(n), badge.Neutral)
              |> badge.view_with_class("badge-count")
          },
        ]),
        // Applied metrics
        td([attribute.class("metric-cell")], [
          span([attribute.class("metric applied")], [
            text(int.to_string(applied)),
          ]),
        ]),
        // Suppressed metrics
        td([attribute.class("metric-cell")], [
          span([attribute.class("metric suppressed")], [
            text(int.to_string(suppressed)),
          ]),
        ]),
        // Actions - use class to prevent row click via CSS/JS
        td([attribute.class("cell-actions cell-no-expand")], [
          action_buttons.edit_delete_row(
            edit_title: t(i18n_text.EditRule),
            edit_click: pool_msg(
              OpenRuleDialog(state_types.RuleDialogEdit(rule)),
            ),
            delete_title: t(i18n_text.DeleteRule),
            delete_click: pool_msg(
              OpenRuleDialog(state_types.RuleDialogDelete(rule)),
            ),
          ),
        ]),
      ],
    ),
  )

  case is_expanded {
    False -> [main_row]
    True -> [main_row, view_rule_templates_expansion(model, rule)]
  }
}

// Justification: nested case keeps resource type rendering readable with optional
// task type lookup and a fallback for missing types.
fn view_rule_resource_type(model: Model, rule: Rule) -> Element(Msg) {
  case rule.resource_type, rule.task_type_id {
    "task", opt.Some(type_id) ->
      case find_task_type(model, type_id) {
        opt.Some(tt) ->
          span([attribute.class("resource-type-task")], [
            text("task"),
            span([attribute.class("resource-type-separator")], [text(" · ")]),
            span([attribute.class("task-type-inline")], [
              icons.view_task_type_icon_inline(tt.icon, 14, model.ui.theme),
            ]),
            text(" " <> tt.name),
          ])
        opt.None -> text("task")
      }
    resource_type, _ -> text(resource_type)
  }
}

// Justification: nested case avoids collapsing active/template semantics into
// fragile conditionals and keeps UI intent explicit.
fn view_rule_active_status(
  model: Model,
  is_active: Bool,
  template_count: Int,
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  case is_active {
    True ->
      case template_count > 0 {
        True ->
          span([attribute.class("rule-complete-indicator")], [
            icons.nav_icon(icons.Check, icons.Small),
          ])
        False ->
          span(
            [
              attribute.class("rule-incomplete-indicator"),
              attribute.title(t(i18n_text.NoTemplatesWontCreateTasks)),
            ],
            [icons.nav_icon(icons.Warning, icons.Small)],
          )
      }
    False ->
      span([attribute.class("rule-inactive-indicator")], [
        icons.nav_icon(icons.XMark, icons.Small),
      ])
  }
}

/// Render the expansion row with attached templates.
fn view_rule_templates_expansion(
  model: Model,
  rule: Rule,
) -> #(String, Element(Msg)) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  let content =
    div([attribute.class("templates-expansion")], [
      div([attribute.class("templates-header")], [
        span([attribute.class("templates-title")], [
          text(t(i18n_text.AttachedTemplates)),
        ]),
        button(
          [
            attribute.class("btn btn-sm btn-primary"),
            // Stop propagation to prevent any parent click handlers from interfering
            event.on_click(pool_msg(AttachTemplateModalOpened(rule.id)))
              |> event.stop_propagation,
          ],
          [
            span([attribute.class("btn-icon-prefix")], [text("+")]),
            text(t(i18n_text.AttachTemplate)),
          ],
        ),
      ]),
      case rule.templates {
        // AC13: Empathetic hint for empty templates
        [] ->
          div([attribute.class("templates-empty-hint")], [
            span([attribute.class("hint-icon")], [
              icons.nav_icon(icons.Info, icons.Medium),
            ]),
            p([], [text(t(i18n_text.AttachTemplateHint))]),
          ])
        templates ->
          div(
            [attribute.class("templates-list")],
            list.map(templates, fn(tmpl) {
              view_attached_template_item(model, rule.id, tmpl)
            }),
          )
      },
    ])

  #(
    "rule-exp-" <> int.to_string(rule.id),
    tr(
      [
        attribute.class("expansion-row"),
        // Prevent clicks in expansion row from bubbling up
        event.on_click(NoOp) |> event.stop_propagation,
      ],
      [
        td([attribute.attribute("colspan", "9")], [content]),
      ],
    ),
  )
}

/// Render a single attached template item with detach button.
/// AC4: Template shows name, type icon, and priority.
fn view_attached_template_item(
  model: Model,
  rule_id: Int,
  tmpl: workflow.RuleTemplate,
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }
  let is_detaching =
    set.contains(model.admin.detaching_templates, #(rule_id, tmpl.id))

  // Find task type info for icon (if available)
  let task_type_info = find_task_type(model, tmpl.type_id)

  div([attribute.class("attached-template-row")], [
    // AC4: Template info with icon + priority
    div([attribute.class("attached-template-info")], [
      // Task type icon
      case task_type_info {
        opt.Some(tt) ->
          span([attribute.class("template-type-icon")], [
            icons.view_task_type_icon_inline(tt.icon, 16, model.ui.theme),
          ])
        opt.None -> element.none()
      },
      // Template name
      span([attribute.class("attached-template-name")], [text(tmpl.name)]),
    ]),
    // AC4: Priority badge
    div([attribute.class("attached-template-meta")], [
      badge.new_unchecked(
        t(i18n_text.PriorityShort(tmpl.priority)),
        badge.Neutral,
      )
        |> badge.view_with_class("priority-badge"),
      // Detach button using action_buttons per coding standards
      case is_detaching {
        True ->
          span([attribute.class("detaching")], [text(t(i18n_text.Detaching))])
        False ->
          action_buttons.delete_button(
            t(i18n_text.RemoveTemplate),
            pool_msg(TemplateDetachClicked(rule_id, tmpl.id)),
          )
      },
    ]),
  ])
}

// Justification: large function kept intact to preserve cohesive UI logic.

/// Render the attach template modal.
/// AC9: Modal opens on button click
/// AC10: Shows only templates from current project
/// AC11: Already attached templates excluded
/// AC12: Radio buttons for selection
/// AC14-15: Empty state with link to Templates
fn view_attach_template_modal(model: Model) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  case model.admin.attach_template_modal {
    opt.None -> element.none()
    opt.Some(rule_id) -> {
      // Get available templates (exclude already attached ones)
      let attached_ids = attached_template_ids(model, rule_id)
      let available_templates =
        available_templates_for_modal(model, attached_ids)

      div([attribute.class("modal-backdrop")], [
        div([attribute.class("modal-sm")], [
          modal_header.view_dialog(
            t(i18n_text.AttachTemplate),
            opt.None,
            pool_msg(AttachTemplateModalClosed),
          ),
          view_attach_template_modal_body(
            model,
            attached_ids,
            available_templates,
          ),
          view_attach_template_modal_footer(model),
        ]),
      ])
    }
  }
}

// Justification: nested case keeps rule lookup and template extraction explicit.
fn attached_template_ids(model: Model, rule_id: Int) -> List(Int) {
  case model.admin.rules {
    Loaded(rules) ->
      case list.find(rules, fn(r) { r.id == rule_id }) {
        Ok(rule) -> list.map(rule.templates, fn(tmpl) { tmpl.id })
        Error(_) -> []
      }
    _ -> []
  }
}

fn available_templates_for_modal(
  model: Model,
  attached_ids: List(Int),
) -> List(TaskTemplate) {
  case model.admin.task_templates_org, model.admin.task_templates_project {
    Loaded(org), Loaded(proj) ->
      list.filter(list.append(org, proj), fn(tmpl) {
        !list.contains(attached_ids, tmpl.id)
      })
    Loaded(org), _ ->
      list.filter(org, fn(tmpl) { !list.contains(attached_ids, tmpl.id) })
    _, Loaded(proj) ->
      list.filter(proj, fn(tmpl) { !list.contains(attached_ids, tmpl.id) })
    _, _ -> []
  }
}

fn view_attach_template_modal_body(
  model: Model,
  attached_ids: List(Int),
  available_templates: List(TaskTemplate),
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  div([attribute.class("modal-body")], [
    case available_templates {
      [] ->
        div([attribute.class("modal-empty-state")], [
          icons.nav_icon(icons.TaskTemplates, icons.Large),
          p([], [text(t(i18n_text.NoTemplatesInProject))]),
          a(
            [
              attribute.href("/config/templates"),
              attribute.class("link-to-templates"),
            ],
            [text(t(i18n_text.CreateTemplateLink))],
          ),
        ])
      templates ->
        div([attribute.class("form")], [
          p([attribute.class("form-hint")], [
            text(t(i18n_text.AvailableTemplatesInProject)),
          ]),
          div(
            [attribute.class("radio-group template-radio-list")],
            list.map(templates, fn(tmpl) {
              view_template_radio_option(model, tmpl)
            }),
          ),
          p([attribute.class("form-hint-secondary")], [
            icons.nav_icon(icons.Info, icons.Small),
            text(
              " "
              <> t(i18n_text.AttachedTemplates)
              <> ": "
              <> int.to_string(list.length(attached_ids)),
            ),
          ]),
        ])
    },
  ])
}

fn view_attach_template_modal_footer(model: Model) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  div([attribute.class("modal-footer")], [
    button(
      [
        attribute.class("btn btn-secondary"),
        event.on_click(pool_msg(AttachTemplateModalClosed)),
      ],
      [text(t(i18n_text.Cancel))],
    ),
    // AC20: Loading state on submit button
    case model.admin.attach_template_loading {
      True ->
        button([attribute.class("btn btn-primary"), attribute.disabled(True)], [
          text(t(i18n_text.Attaching)),
        ])
      False ->
        button(
          [
            attribute.class("btn btn-primary"),
            attribute.disabled(opt.is_none(model.admin.attach_template_selected)),
            event.on_click(pool_msg(AttachTemplateSubmitted)),
          ],
          [text(t(i18n_text.Attach))],
        )
    },
  ])
}

/// Render a radio button option for template selection.
/// AC12: Radio buttons with template name, type icon, and priority.
fn view_template_radio_option(model: Model, tmpl: TaskTemplate) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }
  let is_selected = model.admin.attach_template_selected == opt.Some(tmpl.id)
  let radio_id = "template-radio-" <> int.to_string(tmpl.id)

  // Find task type info for icon
  let task_type_info = find_task_type(model, tmpl.type_id)

  div(
    [
      attribute.class(
        "radio-option"
        <> case is_selected {
          True -> " selected"
          False -> ""
        },
      ),
      // Put click handler on the whole div so clicking label works
      event.on_click(pool_msg(AttachTemplateSelected(tmpl.id))),
    ],
    [
      input([
        attribute.type_("radio"),
        attribute.name("template-selection"),
        attribute.id(radio_id),
        attribute.value(int.to_string(tmpl.id)),
        attribute.checked(is_selected),
      ]),
      label([attribute.for(radio_id), attribute.class("radio-label")], [
        // Task type icon
        case task_type_info {
          opt.Some(tt) ->
            span([attribute.class("template-type-icon")], [
              icons.view_task_type_icon_inline(tt.icon, 16, model.ui.theme),
            ])
          opt.None -> element.none()
        },
        // Template name
        span([attribute.class("template-name")], [text(tmpl.name)]),
        // Priority
        span([attribute.class("template-priority")], [
          text(t(i18n_text.PriorityShort(tmpl.priority))),
        ]),
      ]),
    ],
  )
}

fn find_task_type(model: Model, type_id: Int) -> opt.Option(TaskType) {
  case model.admin.task_types {
    Loaded(types) ->
      list.find(types, fn(tt) { tt.id == type_id }) |> opt.from_result
    _ -> opt.None
  }
}

/// Get metrics for a specific rule from the workflow metrics.
fn get_rule_metrics(
  metrics: Remote(api_workflows.WorkflowMetrics),
  rule_id: Int,
) -> #(Int, Int) {
  case metrics {
    Loaded(wm) -> rule_metrics_for_loaded(wm, rule_id)
    _ -> #(0, 0)
  }
}

// Justification: nested case isolates loaded metrics lookup from empty fallback.
fn rule_metrics_for_loaded(
  metrics: api_workflows.WorkflowMetrics,
  rule_id: Int,
) -> #(Int, Int) {
  case list.find(metrics.rules, fn(rm) { rm.rule_id == rule_id }) {
    Ok(rm) -> #(rm.applied_count, rm.suppressed_count)
    Error(_) -> #(0, 0)
  }
}

/// Renders the rule-crud-dialog component.
/// The component handles create/edit/delete internally and emits events.
fn view_rule_crud_dialog(model: Model, workflow_id: Int) -> Element(Msg) {
  // Build mode attribute based on dialog mode
  let mode_attr = case model.admin.rules_dialog_mode {
    opt.None -> "closed"
    opt.Some(state_types.RuleDialogCreate) -> "create"
    opt.Some(state_types.RuleDialogEdit(_)) -> "edit"
    opt.Some(state_types.RuleDialogDelete(_)) -> "delete"
  }

  // Build rule property for edit/delete modes (includes _mode field for component)
  let rule_prop = case model.admin.rules_dialog_mode {
    opt.Some(state_types.RuleDialogEdit(rule)) ->
      attribute.property("rule", rule_to_json(rule, "edit"))
    opt.Some(state_types.RuleDialogDelete(rule)) ->
      attribute.property("rule", rule_to_json(rule, "delete"))
    _ -> attribute.none()
  }

  // Build task types property (include icon for decoder)
  let task_types_json = case model.admin.task_types {
    Loaded(types) ->
      json.array(types, fn(tt) {
        json.object([
          #("id", json.int(tt.id)),
          #("name", json.string(tt.name)),
          #("icon", json.string(tt.icon)),
        ])
      })
    _ -> json.array([], fn(_: Nil) { json.null() })
  }

  element.element(
    "rule-crud-dialog",
    [
      attribute.attribute("locale", locale.serialize(model.ui.locale)),
      attribute.attribute("workflow-id", int.to_string(workflow_id)),
      attribute.attribute("mode", mode_attr),
      rule_prop,
      attribute.property("task-types", task_types_json),
      // Event handlers
      event.on(
        "rule-created",
        decode_rule_event(fn(rule) { pool_msg(RuleCrudCreated(rule)) }),
      ),
      event.on(
        "rule-updated",
        decode_rule_event(fn(rule) { pool_msg(RuleCrudUpdated(rule)) }),
      ),
      event.on(
        "rule-deleted",
        decode_rule_id_event(fn(rule_id) { pool_msg(RuleCrudDeleted(rule_id)) }),
      ),
      event.on("close-requested", decode_close_event(pool_msg(CloseRuleDialog))),
    ],
    [],
  )
}

/// Convert a Rule to JSON for property passing to component.
/// Includes _mode field to indicate edit or delete operation.
fn rule_to_json(rule: Rule, mode: String) -> json.Json {
  json.object([
    #("id", json.int(rule.id)),
    #("workflow_id", json.int(rule.workflow_id)),
    #("name", json.string(rule.name)),
    #("goal", json.nullable(rule.goal, json.string)),
    #("resource_type", json.string(rule.resource_type)),
    #("task_type_id", json.nullable(rule.task_type_id, json.int)),
    #("to_state", json.string(rule.to_state)),
    #("active", json.bool(rule.active)),
    #("created_at", json.string(rule.created_at)),
    #("_mode", json.string(mode)),
  ])
}

/// Decode rule event from component custom event.
/// Story 4.10: Added templates field (defaults to empty list from component events).
fn decode_rule_event(to_msg: fn(Rule) -> Msg) -> decode.Decoder(Msg) {
  decode.at(["detail"], {
    use id <- decode.field("id", decode.int)
    use workflow_id <- decode.field("workflow_id", decode.int)
    use name <- decode.field("name", decode.string)
    use goal <- decode.field("goal", decode.optional(decode.string))
    use resource_type <- decode.field("resource_type", decode.string)
    use task_type_id <- decode.field(
      "task_type_id",
      decode.optional(decode.int),
    )
    use to_state <- decode.field("to_state", decode.string)
    use active <- decode.field("active", decode.bool)
    use created_at <- decode.field("created_at", decode.string)
    decode.success(
      to_msg(
        workflow.Rule(
          id: id,
          workflow_id: workflow_id,
          name: name,
          goal: goal,
          resource_type: resource_type,
          task_type_id: task_type_id,
          to_state: to_state,
          active: active,
          created_at: created_at,
          templates: [],
        ),
      ),
    )
  })
}

/// Decode rule ID from delete event.
fn decode_rule_id_event(to_msg: fn(Int) -> Msg) -> decode.Decoder(Msg) {
  decode.at(["detail", "rule_id"], decode.int)
  |> decode.map(to_msg)
}

/// Decode close event (no payload).
fn decode_close_event(msg: Msg) -> decode.Decoder(Msg) {
  decode.success(msg)
}

// =============================================================================
// Task Templates Views
// =============================================================================

/// Task templates management view (project-scoped only).
pub fn view_task_templates(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  // Get title with project name
  let title = case selected_project {
    opt.Some(project) ->
      update_helpers.i18n_t(
        model,
        i18n_text.TaskTemplatesProjectTitle(project.name),
      )
    opt.None -> update_helpers.i18n_t(model, i18n_text.TaskTemplatesTitle)
  }

  div([attribute.class("section")], [
    // Section header with action button
    section_header.view_with_action(
      icons.TaskTemplates,
      title,
      dialog.add_button(
        model,
        i18n_text.CreateTaskTemplate,
        pool_msg(OpenTaskTemplateDialog(state_types.TaskTemplateDialogCreate)),
      ),
    ),
    // Story 4.9: Unified hint with rules link and variables info
    view_templates_hint(model),
    // Templates table (project-scoped)
    view_task_templates_table(model, model.admin.task_templates_project),
    // Task template CRUD dialog component
    view_task_template_crud_dialog(model),
  ])
}

/// Story 4.9: Unified hint with rules link and variables documentation.
fn view_templates_hint(model: Model) -> Element(Msg) {
  info_callout.view_with_content(
    opt.None,
    div([], [
      span([], [
        text(update_helpers.i18n_t(model, i18n_text.TemplatesHintRules)),
        a(
          [
            attribute.href("/config/workflows"),
            attribute.class("info-callout-link"),
          ],
          [
            text(
              update_helpers.i18n_t(model, i18n_text.TemplatesHintRulesLink)
              <> " \u{2192}",
            ),
          ],
        ),
      ]),
      div([attribute.class("info-callout-variables")], [
        text(update_helpers.i18n_t(model, i18n_text.TaskTemplateVariablesHelp)),
      ]),
    ]),
  )
}

// Justification: nested case keeps dialog mode and project scoping logic colocated.

/// Render the task-template-crud-dialog Lustre component.
fn view_task_template_crud_dialog(model: Model) -> Element(Msg) {
  case model.admin.task_templates_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, template_json, project_id_attr) = case mode {
        state_types.TaskTemplateDialogCreate -> #(
          "create",
          attribute.none(),
          case model.core.selected_project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
        state_types.TaskTemplateDialogEdit(template) -> #(
          "edit",
          attribute.property(
            "template",
            task_template_to_property_json(template, "edit"),
          ),
          case template.project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
        state_types.TaskTemplateDialogDelete(template) -> #(
          "delete",
          attribute.property(
            "template",
            task_template_to_property_json(template, "delete"),
          ),
          case template.project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
      }

      element.element(
        "task-template-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", locale.serialize(model.ui.locale)),
          project_id_attr,
          attribute.attribute("mode", mode_str),
          // Property for template data (edit/delete modes)
          template_json,
          // Property for task types list
          attribute.property(
            "task-types",
            task_types_to_property_json(model.admin.task_types),
          ),
          // Event listeners for component events
          event.on(
            "task-template-created",
            decode_task_template_created_event(),
          ),
          event.on(
            "task-template-updated",
            decode_task_template_updated_event(),
          ),
          event.on(
            "task-template-deleted",
            decode_task_template_deleted_event(),
          ),
          event.on(
            "close-requested",
            decode_task_template_close_requested_event(),
          ),
        ],
        [],
      )
    }
  }
}

/// Convert task template to JSON for property passing to component.
fn task_template_to_property_json(
  template: TaskTemplate,
  mode: String,
) -> json.Json {
  json.object([
    #("id", json.int(template.id)),
    #("org_id", json.int(template.org_id)),
    #("project_id", case template.project_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("name", json.string(template.name)),
    #("description", case template.description {
      opt.Some(desc) -> json.string(desc)
      opt.None -> json.null()
    }),
    #("type_id", json.int(template.type_id)),
    #("type_name", json.string(template.type_name)),
    #("priority", json.int(template.priority)),
    #("created_by", json.int(template.created_by)),
    #("created_at", json.string(template.created_at)),
    #("_mode", json.string(mode)),
  ])
}

/// Convert task types to JSON for property passing to component.
fn task_types_to_property_json(task_types: Remote(List(TaskType))) -> json.Json {
  case task_types {
    Loaded(types) ->
      json.array(types, fn(tt: TaskType) {
        json.object([
          #("id", json.int(tt.id)),
          #("name", json.string(tt.name)),
          #("icon", json.string(tt.icon)),
        ])
      })
    _ -> json.array([], fn(_) { json.null() })
  }
}

/// Decoder for task-template-created event.
fn decode_task_template_created_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(task_template_decoder(), fn(template) {
    decode.success(pool_msg(TaskTemplateCrudCreated(template)))
  })
}

/// Decoder for task-template-updated event.
fn decode_task_template_updated_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(task_template_decoder(), fn(template) {
    decode.success(pool_msg(TaskTemplateCrudUpdated(template)))
  })
}

/// Decoder for task-template-deleted event.
fn decode_task_template_deleted_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(
    decode.field("id", decode.int, decode.success),
    fn(id) { decode.success(pool_msg(TaskTemplateCrudDeleted(id))) },
  )
}

/// Decoder for close-requested event from task template component.
fn decode_task_template_close_requested_event() -> decode.Decoder(Msg) {
  decode.success(pool_msg(CloseTaskTemplateDialog))
}

/// Decoder for TaskTemplate from JSON (used in custom events).
/// Story 4.9 AC20: Added rules_count field.
fn task_template_decoder() -> decode.Decoder(TaskTemplate) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", decode.optional(decode.int))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use type_id <- decode.field("type_id", decode.int)
  use type_name <- decode.field("type_name", decode.string)
  use priority <- decode.field("priority", decode.int)
  use _created_by <- decode.field("created_by", decode.int)
  use _created_at <- decode.field("created_at", decode.string)
  use rules_count <- decode.optional_field("rules_count", 0, decode.int)
  decode.success(workflow.TaskTemplate(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    type_id: type_id,
    type_name: type_name,
    priority: priority,
    created_by: 0,
    created_at: "",
    rules_count: rules_count,
  ))
}

fn view_task_templates_table(
  model: Model,
  templates: Remote(List(TaskTemplate)),
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  data_table.view_remote_with_forbidden(
    templates,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoTaskTemplatesYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name column
        data_table.column(t(i18n_text.TaskTemplateName), fn(tmpl: TaskTemplate) {
          text(tmpl.name)
        }),
        // Type column (task type)
        data_table.column(t(i18n_text.TaskTemplateType), fn(tmpl: TaskTemplate) {
          text(tmpl.type_name)
        }),
        // Priority column
        data_table.column_with_class(
          t(i18n_text.TaskTemplatePriority),
          fn(tmpl: TaskTemplate) {
            badge.new_unchecked(int.to_string(tmpl.priority), badge.Neutral)
            |> badge.view_with_class("priority-badge")
          },
          "col-number",
          "cell-number",
        ),
        // Actions column with icon buttons
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(tmpl: TaskTemplate) {
            action_buttons.edit_delete_row_with_testid(
              edit_title: t(i18n_text.EditTaskTemplate),
              edit_click: pool_msg(
                OpenTaskTemplateDialog(state_types.TaskTemplateDialogEdit(tmpl)),
              ),
              edit_testid: "template-edit-btn",
              delete_title: t(i18n_text.Delete),
              delete_click: pool_msg(
                OpenTaskTemplateDialog(state_types.TaskTemplateDialogDelete(
                  tmpl,
                )),
              ),
              delete_testid: "template-delete-btn",
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(tmpl) { int.to_string(tmpl.id) }),
  )
}

// =============================================================================
// Rule Metrics Tab Views
// =============================================================================

/// Rule metrics tab view.
pub fn view_rule_metrics(model: Model) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }
  let is_loading = case model.admin.admin_rule_metrics {
    Loading -> True
    _ -> False
  }

  div([attribute.class("section")], [
    // Header with icon (Story 4.8: consistent icons via section_header)
    section_header.view(icons.Metrics, t(i18n_text.RuleMetricsTitle)),
    // Description tooltip
    div([attribute.class("section-description")], [
      icons.nav_icon(icons.Info, icons.Small),
      text(" " <> t(i18n_text.RuleMetricsDescription)),
    ]),
    // Card wrapper
    div([attribute.class("admin-card")], [
      // Quick range buttons with active state
      div([attribute.class("quick-ranges")], [
        span([attribute.class("quick-ranges-label")], [
          text(t(i18n_text.RuleMetricsQuickRange)),
        ]),
        view_quick_range_button(model, t(i18n_text.RuleMetrics7Days), 7),
        view_quick_range_button(model, t(i18n_text.RuleMetrics30Days), 30),
        view_quick_range_button(model, t(i18n_text.RuleMetrics90Days), 90),
      ]),
      // Date range inputs - auto-refresh on change
      div([attribute.class("filters-row")], [
        form_field.view(
          t(i18n_text.RuleMetricsFrom),
          input([
            attribute.type_("date"),
            attribute.value(model.admin.admin_rule_metrics_from),
            // Auto-refresh on date change
            event.on_input(fn(value) {
              pool_msg(AdminRuleMetricsFromChangedAndRefresh(value))
            }),
            attribute.attribute("aria-label", t(i18n_text.RuleMetricsFrom)),
          ]),
        ),
        form_field.view(
          t(i18n_text.RuleMetricsTo),
          input([
            attribute.type_("date"),
            attribute.value(model.admin.admin_rule_metrics_to),
            // Auto-refresh on date change
            event.on_input(fn(value) {
              pool_msg(AdminRuleMetricsToChangedAndRefresh(value))
            }),
            attribute.attribute("aria-label", t(i18n_text.RuleMetricsTo)),
          ]),
        ),
        // Loading indicator (replaces manual refresh button)
        case is_loading {
          True ->
            div([attribute.class("field loading-indicator")], [
              span([attribute.class("btn-spinner")], []),
              text(" " <> t(i18n_text.LoadingEllipsis)),
            ])
          False -> element.none()
        },
      ]),
    ]),
    // Results
    view_rule_metrics_results(model),
  ])
}

/// Quick range button helper with active state.
fn view_quick_range_button(
  model: Model,
  label: String,
  days: Int,
) -> Element(Msg) {
  let today = client_ffi.date_today()
  let from = client_ffi.date_days_ago(days)

  // Check if this range is currently active
  let is_active =
    model.admin.admin_rule_metrics_from == from
    && model.admin.admin_rule_metrics_to == today

  let class = case is_active {
    True -> "btn-chip btn-chip-active"
    False -> "btn-chip"
  }

  button(
    [
      attribute.class(class),
      event.on_click(pool_msg(AdminRuleMetricsQuickRangeClicked(from, today))),
      attribute.attribute("aria-pressed", case is_active {
        True -> "true"
        False -> "false"
      }),
    ],
    [text(label)],
  )
}

/// Results section with improved empty state (T5).
fn view_rule_metrics_results(model: Model) -> Element(Msg) {
  case model.admin.admin_rule_metrics {
    NotAsked ->
      empty_state.simple(
        icons.Lightbulb,
        "Selecciona un rango de fechas o usa los botones de rango rápido para ver las métricas de tus automatizaciones.",
      )

    Loading -> loading.loading("Cargando métricas...")

    Failed(err) -> error_notice.view(err.message)

    Loaded(workflows) -> view_rule_metrics_loaded(model, workflows)
  }
}

fn view_rule_metrics_loaded(
  model: Model,
  workflows: List(api_workflows.OrgWorkflowMetricsSummary),
) -> Element(Msg) {
  case workflows {
    [] ->
      empty_state.simple(
        icons.Inbox,
        "No se encontraron ejecuciones de automatizaciones en el rango seleccionado.",
      )
    _ ->
      div([attribute.class("admin-card")], [
        div([attribute.class("admin-card-header")], [
          span([], [icons.nav_icon(icons.ClipboardDoc, icons.Small)]),
          text(" Resultados"),
        ]),
        view_rule_metrics_table(model, model.admin.admin_rule_metrics),
      ])
  }
}

fn view_rule_metrics_table(
  model: Model,
  metrics: Remote(List(api_workflows.OrgWorkflowMetricsSummary)),
) -> Element(Msg) {
  case metrics {
    NotAsked ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.RuleMetricsSelectRange)),
      ])

    Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) -> error_notice.view(err.message)

    Loaded(workflows) -> view_rule_metrics_table_loaded(model, workflows)
  }
}

fn view_rule_metrics_table_loaded(
  model: Model,
  workflows: List(api_workflows.OrgWorkflowMetricsSummary),
) -> Element(Msg) {
  case workflows {
    [] ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.RuleMetricsNoData)),
      ])
    _ ->
      element.fragment([
        table([attribute.class("table")], [
          thead([], [
            tr([], [
              th([], []),
              th([], [
                text(update_helpers.i18n_t(model, i18n_text.WorkflowName)),
              ]),
              th([], [
                text(update_helpers.i18n_t(
                  model,
                  i18n_text.RuleMetricsRuleCount,
                )),
              ]),
              th([], [
                text(update_helpers.i18n_t(
                  model,
                  i18n_text.RuleMetricsEvaluated,
                )),
              ]),
              th([], [
                text(update_helpers.i18n_t(model, i18n_text.RuleMetricsApplied)),
              ]),
              th([], [
                text(update_helpers.i18n_t(
                  model,
                  i18n_text.RuleMetricsSuppressed,
                )),
              ]),
            ]),
          ]),
          keyed.tbody(
            [],
            list.flat_map(workflows, fn(w) { view_workflow_row(model, w) }),
          ),
        ]),
        // Drill-down modal
        view_rule_drilldown_modal(model),
      ])
  }
}

/// Render a workflow row with optional expansion for per-rule metrics.
fn view_workflow_row(
  model: Model,
  w: api_workflows.OrgWorkflowMetricsSummary,
) -> List(#(String, Element(Msg))) {
  let is_expanded =
    model.admin.admin_rule_metrics_expanded_workflow == opt.Some(w.workflow_id)
  let main_row = #(
    "wf-" <> int.to_string(w.workflow_id),
    tr(
      [
        attribute.class("workflow-row clickable"),
        event.on_click(
          pool_msg(AdminRuleMetricsWorkflowExpanded(w.workflow_id)),
        ),
      ],
      [
        td([attribute.class("expand-col")], [expand_toggle.view(is_expanded)]),
        td([], [text(w.workflow_name)]),
        td([], [text(int.to_string(w.rule_count))]),
        td([], [text(int.to_string(w.evaluated_count))]),
        td([attribute.class("metric-cell")], [
          span([attribute.class("metric applied")], [
            text(int.to_string(w.applied_count)),
          ]),
        ]),
        td([attribute.class("metric-cell")], [
          span([attribute.class("metric suppressed")], [
            text(int.to_string(w.suppressed_count)),
          ]),
        ]),
      ],
    ),
  )

  case is_expanded {
    False -> [main_row]
    True -> [main_row, view_workflow_rules_expansion(model, w.workflow_id)]
  }
}

/// Render the expansion row with per-rule metrics.
fn view_workflow_rules_expansion(
  model: Model,
  _workflow_id: Int,
) -> #(String, Element(Msg)) {
  let content =
    view_workflow_rules_expansion_content(
      model,
      model.admin.admin_rule_metrics_workflow_details,
    )

  #(
    "expansion",
    tr([attribute.class("expansion-row")], [
      td([attribute.attribute("colspan", "6")], [
        div([attribute.class("expansion-content")], [content]),
      ]),
    ]),
  )
}

fn view_workflow_rules_expansion_content(
  model: Model,
  details: Remote(api_workflows.WorkflowMetrics),
) -> Element(Msg) {
  case details {
    NotAsked | Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])
    Failed(err) -> error_notice.view(err.message)
    Loaded(loaded) -> view_workflow_rules_expansion_loaded(model, loaded)
  }
}

fn view_workflow_rules_expansion_loaded(
  model: Model,
  details: api_workflows.WorkflowMetrics,
) -> Element(Msg) {
  case details.rules {
    [] ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.RuleMetricsNoRules)),
      ])
    rules ->
      table([attribute.class("table nested-table")], [
        thead([], [
          tr([], [
            th([], [text(update_helpers.i18n_t(model, i18n_text.RuleName))]),
            th([], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsEvaluated)),
            ]),
            th([], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsApplied)),
            ]),
            th([], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsSuppressed)),
            ]),
            th([], []),
          ]),
        ]),
        keyed.tbody(
          [],
          list.map(rules, fn(r) { view_workflow_rule_metrics_row(model, r) }),
        ),
      ])
  }
}

fn view_workflow_rule_metrics_row(
  model: Model,
  rule_metrics: api_workflows.RuleMetricsSummary,
) -> #(String, Element(Msg)) {
  #(
    "rule-" <> int.to_string(rule_metrics.rule_id),
    tr([], [
      td([], [text(rule_metrics.rule_name)]),
      td([], [text(int.to_string(rule_metrics.evaluated_count))]),
      td([attribute.class("metric-cell")], [
        span([attribute.class("metric applied")], [
          text(int.to_string(rule_metrics.applied_count)),
        ]),
      ]),
      td([attribute.class("metric-cell")], [
        span([attribute.class("metric suppressed")], [
          text(int.to_string(rule_metrics.suppressed_count)),
        ]),
      ]),
      td([], [
        button(
          [
            attribute.class("btn-small"),
            event.on_click(
              pool_msg(AdminRuleMetricsDrilldownClicked(rule_metrics.rule_id)),
            ),
          ],
          [text(update_helpers.i18n_t(model, i18n_text.ViewDetails))],
        ),
      ]),
    ]),
  )
}

/// Render the drill-down modal for rule details and executions.
fn view_rule_drilldown_modal(model: Model) -> Element(Msg) {
  case model.admin.admin_rule_metrics_drilldown_rule_id {
    opt.None -> element.none()
    opt.Some(_rule_id) ->
      div([attribute.class("modal drilldown-modal")], [
        div([attribute.class("modal-content")], [
          div([attribute.class("modal-header")], [
            h3([], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsDrilldown)),
            ]),
            button(
              [
                attribute.class("btn-close"),
                event.on_click(pool_msg(AdminRuleMetricsDrilldownClosed)),
              ],
              [text("X")],
            ),
          ]),
          div([attribute.class("modal-body")], [
            view_drilldown_details(model),
            hr([]),
            view_drilldown_executions(model),
          ]),
        ]),
      ])
  }
}

/// Render the suppression breakdown in the drill-down modal.
fn view_drilldown_details(model: Model) -> Element(Msg) {
  case model.admin.admin_rule_metrics_rule_details {
    NotAsked | Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) -> error_notice.view(err.message)

    Loaded(details) ->
      div([attribute.class("drilldown-details")], [
        h3([], [text(details.rule_name)]),
        div([attribute.class("metrics-summary")], [
          div([attribute.class("metric-box")], [
            span([attribute.class("metric-label")], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsEvaluated)),
            ]),
            span([attribute.class("metric-value")], [
              text(int.to_string(details.evaluated_count)),
            ]),
          ]),
          div([attribute.class("metric-box applied")], [
            span([attribute.class("metric-label")], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsApplied)),
            ]),
            span([attribute.class("metric-value")], [
              text(int.to_string(details.applied_count)),
            ]),
          ]),
          div([attribute.class("metric-box suppressed")], [
            span([attribute.class("metric-label")], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsSuppressed)),
            ]),
            span([attribute.class("metric-value")], [
              text(int.to_string(details.suppressed_count)),
            ]),
          ]),
        ]),
        // Suppression breakdown
        h3([], [
          text(update_helpers.i18n_t(model, i18n_text.SuppressionBreakdown)),
        ]),
        div([attribute.class("suppression-breakdown")], [
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(update_helpers.i18n_t(model, i18n_text.SuppressionIdempotent)),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(details.suppression_breakdown.idempotent)),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(update_helpers.i18n_t(
                model,
                i18n_text.SuppressionNotUserTriggered,
              )),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(
                details.suppression_breakdown.not_user_triggered,
              )),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(update_helpers.i18n_t(
                model,
                i18n_text.SuppressionNotMatching,
              )),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(details.suppression_breakdown.not_matching)),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(update_helpers.i18n_t(model, i18n_text.SuppressionInactive)),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(details.suppression_breakdown.inactive)),
            ]),
          ]),
        ]),
      ])
  }
}

/// Render the executions list in the drill-down modal.
fn view_drilldown_executions(model: Model) -> Element(Msg) {
  case model.admin.admin_rule_metrics_executions {
    NotAsked | Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) -> error_notice.view(err.message)

    Loaded(response) -> view_drilldown_executions_loaded(model, response)
  }
}

fn view_drilldown_executions_loaded(
  model: Model,
  response: api_workflows.RuleExecutionsResponse,
) -> Element(Msg) {
  let origin_cell: fn(api_workflows.RuleExecution) -> Element(Msg) = fn(exec) {
    let api_workflows.RuleExecution(_, origin_type, origin_id, _, _, _, _, _) =
      exec
    text(origin_type <> " #" <> int.to_string(origin_id))
  }
  let outcome_cell: fn(api_workflows.RuleExecution) -> Element(Msg) = fn(exec) {
    let api_workflows.RuleExecution(_, _, _, outcome, _, _, _, _) = exec
    span([attribute.class(outcome_class_for(outcome))], [
      text(outcome_text_for(model, exec)),
    ])
  }
  let user_cell: fn(api_workflows.RuleExecution) -> Element(Msg) = fn(exec) {
    let api_workflows.RuleExecution(_, _, _, _, _, _, user_email, _) = exec
    text(display_user_email(user_email))
  }
  let timestamp_cell: fn(api_workflows.RuleExecution) -> Element(Msg) = fn(exec) {
    let api_workflows.RuleExecution(_, _, _, _, _, _, _, created_at) = exec
    text(created_at)
  }
  let key_fn: fn(api_workflows.RuleExecution) -> String = fn(exec) {
    let api_workflows.RuleExecution(id, _, _, _, _, _, _, _) = exec
    int.to_string(id)
  }

  div([attribute.class("drilldown-executions")], [
    h3([], [
      text(update_helpers.i18n_t(model, i18n_text.RecentExecutions)),
    ]),
    case response.executions {
      [] ->
        div([attribute.class("empty")], [
          text(update_helpers.i18n_t(model, i18n_text.NoExecutions)),
        ])
      executions ->
        element.fragment([
          data_table.new()
            |> data_table.with_class("executions-table")
            |> data_table.with_columns([
              data_table.column(
                update_helpers.i18n_t(model, i18n_text.Origin),
                origin_cell,
              ),
              data_table.column(
                update_helpers.i18n_t(model, i18n_text.Outcome),
                outcome_cell,
              ),
              data_table.column(
                update_helpers.i18n_t(model, i18n_text.User),
                user_cell,
              ),
              data_table.column(
                update_helpers.i18n_t(model, i18n_text.Timestamp),
                timestamp_cell,
              ),
            ])
            |> data_table.with_rows(executions, key_fn)
            |> data_table.view(),
          // Pagination
          view_executions_pagination(model, response.pagination),
        ])
    },
  ])
}

fn outcome_class_for(outcome: String) -> String {
  case outcome {
    "applied" -> "outcome-applied"
    "suppressed" -> "outcome-suppressed"
    _ -> ""
  }
}

fn outcome_text_for(model: Model, exec: api_workflows.RuleExecution) -> String {
  case exec.outcome {
    "applied" -> update_helpers.i18n_t(model, i18n_text.OutcomeApplied)
    "suppressed" ->
      update_helpers.i18n_t(model, i18n_text.OutcomeSuppressed)
      <> suppression_reason_suffix(exec.suppression_reason)
    _ -> exec.outcome
  }
}

fn suppression_reason_suffix(reason: String) -> String {
  case reason {
    "" -> ""
    _ -> " (" <> reason <> ")"
  }
}

fn display_user_email(user_email: String) -> String {
  case user_email {
    "" -> "-"
    _ -> user_email
  }
}

/// Render pagination controls for executions.
fn view_executions_pagination(
  _model: Model,
  pagination: api_workflows.Pagination,
) -> Element(Msg) {
  let current_page = pagination.offset / pagination.limit + 1
  let total_pages =
    { pagination.total + pagination.limit - 1 } / pagination.limit

  case total_pages <= 1 {
    True -> element.none()
    False ->
      div([attribute.class("pagination")], [
        button(
          [
            attribute.class("btn-small"),
            attribute.disabled(pagination.offset == 0),
            event.on_click(pool_msg(AdminRuleMetricsExecPageChanged(0))),
          ],
          [text("<<")],
        ),
        button(
          [
            attribute.class("btn-small"),
            attribute.disabled(pagination.offset == 0),
            event.on_click(
              pool_msg(
                AdminRuleMetricsExecPageChanged(int.max(
                  0,
                  pagination.offset - pagination.limit,
                )),
              ),
            ),
          ],
          [text("<")],
        ),
        span([attribute.class("page-info")], [
          text(
            int.to_string(current_page) <> " / " <> int.to_string(total_pages),
          ),
        ]),
        button(
          [
            attribute.class("btn-small"),
            attribute.disabled(
              pagination.offset + pagination.limit >= pagination.total,
            ),
            event.on_click(
              pool_msg(AdminRuleMetricsExecPageChanged(
                pagination.offset + pagination.limit,
              )),
            ),
          ],
          [text(">")],
        ),
        button(
          [
            attribute.class("btn-small"),
            attribute.disabled(
              pagination.offset + pagination.limit >= pagination.total,
            ),
            event.on_click(
              pool_msg(AdminRuleMetricsExecPageChanged(
                { total_pages - 1 } * pagination.limit,
              )),
            ),
          ],
          [text(">>")],
        ),
      ])
  }
}
