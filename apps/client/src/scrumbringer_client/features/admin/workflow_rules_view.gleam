//// Admin workflow rules view.
////
//// ## Mission
////
//// Render workflow rule drill-down, attached templates, and rule dialogs.
////
//// ## Responsibilities
////
//// - Rules table for a selected workflow
//// - Rule row expansion and attached template list
//// - Attach-template modal
//// - Rule CRUD custom element wiring
////
//// ## Relations
////
//// - **features/admin/views/workflows.gleam**: Delegates selected-workflow rules here
//// - **features/admin/workflows.gleam**: Owns workflow/rule update transitions

import gleam/int
import gleam/json
import gleam/list
import gleam/option as opt
import gleam/result
import gleam/set

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  a, div, input, label, p, span, table, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import gleam/dynamic/decode

import domain/remote.{type Remote, Loaded}
import domain/task_type.{type TaskType}
import domain/workflow.{
  type Rule, type TaskTemplate, type Workflow, rule_resource_type,
  rule_task_type_id, rule_to_state_string,
}
import domain/workflow/workflow_codec

import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale, serialize}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/expand_toggle
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/modal_header
import scrumbringer_client/ui/remote as ui_remote
import scrumbringer_client/ui/section_header

// =============================================================================
// Rules Views
// =============================================================================

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    workflow_id: Int,
    workflow_name: String,
    rules: admin_rules.Model,
    workflows_org: Remote(List(Workflow)),
    workflows_project: Remote(List(Workflow)),
    task_types: Remote(List(TaskType)),
    task_templates_org: Remote(List(TaskTemplate)),
    task_templates_project: Remote(List(TaskTemplate)),
    on_back_clicked: msg,
    on_create_clicked: msg,
    on_rule_expanded: fn(Int) -> msg,
    on_edit_clicked: fn(Rule) -> msg,
    on_delete_clicked: fn(Rule) -> msg,
    on_attach_modal_opened: fn(Int) -> msg,
    on_attach_modal_closed: msg,
    on_template_detached: fn(Int, Int) -> msg,
    on_template_selected: fn(Int) -> msg,
    on_attach_submitted: msg,
    on_rule_created: fn(Rule) -> msg,
    on_rule_updated: fn(Rule) -> msg,
    on_rule_deleted: fn(Int) -> msg,
    on_rule_dialog_closed: msg,
    on_noop: msg,
  )
}

pub fn workflow_name_from_remotes(
  workflows_org: Remote(List(Workflow)),
  workflows_project: Remote(List(Workflow)),
  workflow_id: Int,
) -> String {
  find_workflow_name(workflows_org, workflow_id)
  |> opt.lazy_or(fn() { find_workflow_name(workflows_project, workflow_id) })
  |> workflow_name_or_id(workflow_id)
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view_workflow_rules(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("section"),
      attribute.attribute("data-testid", "automation-rule-builder"),
    ],
    [
      ui_button.text(
        t(config, i18n_text.BackToWorkflows),
        config.on_back_clicked,
        ui_button.Secondary,
        ui_button.ViewAction,
      )
        |> ui_button.view,
      // Section header with add button (Story 4.8: consistent icons)
      section_header.view_with_action(
        icons.Rules,
        t(config, i18n_text.RulesTitle(config.workflow_name)),
        dialog.add_button_with_locale(
          config.locale,
          i18n_text.CreateRule,
          config.on_create_clicked,
        ),
      ),
      view_rules_table(config, config.rules.rules, config.rules.rules_metrics),
      // Rule CRUD dialog component (handles create/edit/delete internally)
      view_rule_crud_dialog(config),
    ],
  )
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

fn workflow_name_or_id(name: opt.Option(String), workflow_id: Int) -> String {
  case name {
    opt.None -> "Workflow #" <> int.to_string(workflow_id)
    opt.Some(value) -> value
  }
}

fn view_rules_table(
  config: Config(msg),
  rules: Remote(List(Rule)),
  metrics: Remote(api_rule_metrics.WorkflowMetrics),
) -> Element(msg) {
  ui_remote.view_remote(
    rules,
    loading: fn() { loading.loading(t(config, i18n_text.LoadingEllipsis)) },
    error: fn(err) {
      case err.status {
        403 ->
          div([attribute.class("forbidden")], [
            text(t(config, i18n_text.NotPermitted)),
          ])
        _ -> error_notice.view(err.message)
      }
    },
    loaded: fn(rs) {
      case rs {
        [] -> empty_state.simple("inbox", t(config, i18n_text.NoRulesYet))
        _ ->
          div([attribute.class("rules-expandable-table")], [
            table([attribute.class("table data-table")], [
              thead([], [
                tr([], [
                  th([attribute.class("col-expand")], []),
                  th([], [text(t(config, i18n_text.RuleName))]),
                  th([], [text(t(config, i18n_text.RuleResourceType))]),
                  th([], [text(t(config, i18n_text.RuleToState))]),
                  th([], [text(t(config, i18n_text.RuleActive))]),
                  th([], [text(t(config, i18n_text.RuleTemplates))]),
                  th([], [text(t(config, i18n_text.RuleMetricsApplied))]),
                  th([], [text(t(config, i18n_text.RuleMetricsSuppressed))]),
                  th([attribute.class("col-actions")], [
                    text(t(config, i18n_text.Actions)),
                  ]),
                ]),
              ]),
              keyed.tbody(
                [],
                list.flat_map(rs, fn(r) {
                  view_rule_row_expandable(
                    config,
                    r,
                    get_rule_metrics(metrics, r.id),
                  )
                }),
              ),
            ]),
            // Attach template modal
            view_attach_template_modal(config),
          ])
      }
    },
  )
}

/// Render an expandable rule row with optional expansion for attached templates.
fn view_rule_row_expandable(
  config: Config(msg),
  rule: Rule,
  rule_metrics: #(Int, Int),
) -> List(#(String, Element(msg))) {
  let is_expanded = set.contains(config.rules.rules_expanded, rule.id)
  let _expand_title = case is_expanded {
    True -> t(config, i18n_text.CollapseRule)
    False -> t(config, i18n_text.ExpandRule)
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
        attribute.attribute("data-testid", "automation-rule-row"),
        attribute.attribute(
          "aria-expanded",
          attribute_value.boolean(is_expanded),
        ),
        // AC2: Click anywhere on the row to expand/collapse
        event.on_click(config.on_rule_expanded(rule.id)),
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
          view_rule_resource_type(config, rule),
        ]),
        // To state
        td([], [text(rule_to_state_string(rule))]),
        // Active status with completeness indicator (AC6-8)
        td([attribute.class("cell-status")], [
          view_rule_active_status(config, rule.active, template_count),
        ]),
        // Templates count badge
        td([attribute.class("cell-templates")], [
          case template_count {
            0 ->
              badge.new_unchecked("0", badge.Neutral)
              |> badge.view_with_class("table-badge table-badge-empty")
            n ->
              badge.new_unchecked(int.to_string(n), badge.Neutral)
              |> badge.view_with_class("table-badge table-badge-count")
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
            edit_title: t(config, i18n_text.EditRule),
            edit_click: config.on_edit_clicked(rule),
            delete_title: t(config, i18n_text.DeleteRule),
            delete_click: config.on_delete_clicked(rule),
          ),
        ]),
      ],
    ),
  )

  case is_expanded {
    False -> [main_row]
    True -> [main_row, view_rule_templates_expansion(config, rule)]
  }
}

// Justification: nested case keeps resource type rendering readable with optional
// task type lookup and a fallback for missing types.
fn view_rule_resource_type(config: Config(msg), rule: Rule) -> Element(msg) {
  let task_label = t(config, i18n_text.ResourceTypeTask)
  case rule_resource_type(rule), rule_task_type_id(rule) {
    "task", opt.Some(type_id) ->
      case find_task_type(config, type_id) {
        opt.Some(tt) ->
          span([attribute.class("resource-type-task")], [
            text(task_label),
            span([attribute.class("resource-type-separator")], [text(" · ")]),
            span([attribute.class("task-type-inline")], [
              icons.view_task_type_icon_inline(tt.icon, 14, config.theme),
            ]),
            text(" " <> tt.name),
          ])
        opt.None -> text(task_label)
      }
    resource_type, _ -> text(resource_type)
  }
}

// Justification: nested case avoids collapsing active/template semantics into
// fragile conditionals and keeps UI intent explicit.
fn view_rule_active_status(
  config: Config(msg),
  is_active: Bool,
  template_count: Int,
) -> Element(msg) {
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
              attribute.title(t(config, i18n_text.NoTemplatesWontCreateTasks)),
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
  config: Config(msg),
  rule: Rule,
) -> #(String, Element(msg)) {
  let content =
    div([attribute.class("templates-expansion")], [
      div([attribute.class("templates-header")], [
        span([attribute.class("templates-title")], [
          text(t(config, i18n_text.AttachedTemplates)),
        ]),
        ui_button.icon_text(
          t(config, i18n_text.AttachTemplate),
          config.on_attach_modal_opened(rule.id),
          icons.Plus,
          ui_button.Primary,
          ui_button.EntityAction,
        )
          // Stop propagation to prevent any parent click handlers from interfering
          |> ui_button.with_stop_propagation
          |> ui_button.view,
      ]),
      case rule.templates {
        // AC13: Empathetic hint for empty templates
        [] ->
          div([attribute.class("templates-empty-hint")], [
            span([attribute.class("hint-icon")], [
              icons.nav_icon(icons.Info, icons.Medium),
            ]),
            p([], [text(t(config, i18n_text.AttachTemplateHint))]),
          ])
        templates ->
          div(
            [attribute.class("templates-list")],
            list.map(templates, fn(tmpl) {
              view_attached_template_item(config, rule.id, tmpl)
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
        event.on_click(config.on_noop) |> event.stop_propagation,
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
  config: Config(msg),
  rule_id: Int,
  tmpl: workflow.RuleTemplate,
) -> Element(msg) {
  let is_detaching =
    set.contains(config.rules.detaching_templates, #(rule_id, tmpl.id))

  // Find task type info for icon (if available)
  let task_type_info = find_task_type(config, tmpl.type_id)

  div([attribute.class("attached-template-row")], [
    // AC4: Template info with icon + priority
    div([attribute.class("attached-template-info")], [
      // Task type icon
      case task_type_info {
        opt.Some(tt) ->
          span([attribute.class("template-type-icon")], [
            icons.view_task_type_icon_inline(tt.icon, 16, config.theme),
          ])
        opt.None -> element.none()
      },
      // Template name
      span([attribute.class("attached-template-name")], [text(tmpl.name)]),
    ]),
    // AC4: Priority badge
    div([attribute.class("attached-template-meta")], [
      badge.new_unchecked(
        t(config, i18n_text.PriorityShort(tmpl.priority)),
        badge.Neutral,
      )
        |> badge.view_with_class("priority-badge"),
      // Detach button using action_buttons per coding standards
      case is_detaching {
        True ->
          span([attribute.class("detaching")], [
            text(t(config, i18n_text.Detaching)),
          ])
        False ->
          action_buttons.delete_button(
            t(config, i18n_text.RemoveTemplate),
            config.on_template_detached(rule_id, tmpl.id),
          )
      },
    ]),
  ])
}

/// Render the attach template modal.
/// AC9: Modal opens on button click
/// AC10: Shows only templates from current project
/// AC11: Already attached templates excluded
/// AC12: Radio buttons for selection
/// AC14-15: Empty state with link to Templates
fn view_attach_template_modal(config: Config(msg)) -> Element(msg) {
  case config.rules.attach_template_modal {
    opt.None -> element.none()
    opt.Some(rule_id) -> {
      // Get available templates (exclude already attached ones)
      let attached_ids = attached_template_ids(config, rule_id)
      let available_templates =
        available_templates_for_modal(config, attached_ids)

      div([attribute.class("modal-backdrop")], [
        div([attribute.class("modal-sm")], [
          modal_header.view_dialog_with_close_label(
            t(config, i18n_text.AttachTemplate),
            opt.None,
            config.on_attach_modal_closed,
            t(config, i18n_text.Close),
          ),
          view_attach_template_modal_body(
            config,
            attached_ids,
            available_templates,
          ),
          view_attach_template_modal_footer(config),
        ]),
      ])
    }
  }
}

// Justification: nested case keeps rule lookup and template extraction explicit.
fn attached_template_ids(config: Config(msg), rule_id: Int) -> List(Int) {
  case config.rules.rules {
    Loaded(rules) ->
      case list.find(rules, fn(r) { r.id == rule_id }) {
        Ok(rule) -> list.map(rule.templates, fn(tmpl) { tmpl.id })
        Error(_) -> []
      }
    _ -> []
  }
}

fn available_templates_for_modal(
  config: Config(msg),
  attached_ids: List(Int),
) -> List(TaskTemplate) {
  case config.task_templates_org, config.task_templates_project {
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
  config: Config(msg),
  attached_ids: List(Int),
  available_templates: List(TaskTemplate),
) -> Element(msg) {
  div([attribute.class("modal-body")], [
    case available_templates {
      [] ->
        div([attribute.class("modal-empty-state")], [
          icons.nav_icon(icons.TaskTemplates, icons.Large),
          p([], [text(t(config, i18n_text.NoTemplatesInProject))]),
          a(
            [
              attribute.href("/config/templates"),
              attribute.class("link-to-templates"),
            ],
            [text(t(config, i18n_text.CreateTemplateLink))],
          ),
        ])
      templates ->
        div([attribute.class("form")], [
          p([attribute.class("form-hint")], [
            text(t(config, i18n_text.AvailableTemplatesInProject)),
          ]),
          div(
            [
              attribute.class("radio-group template-radio-list"),
              attribute.attribute("data-testid", "automation-template-picker"),
            ],
            list.map(templates, fn(tmpl) {
              view_template_radio_option(config, tmpl)
            }),
          ),
          p([attribute.class("form-hint-secondary")], [
            icons.nav_icon(icons.Info, icons.Small),
            text(
              " "
              <> t(config, i18n_text.AttachedTemplates)
              <> ": "
              <> int.to_string(list.length(attached_ids)),
            ),
          ]),
        ])
    },
  ])
}

fn view_attach_template_modal_footer(config: Config(msg)) -> Element(msg) {
  div([attribute.class("modal-footer")], [
    ui_button.text(
      t(config, i18n_text.Cancel),
      config.on_attach_modal_closed,
      ui_button.Secondary,
      ui_button.EntityAction,
    )
      |> ui_button.view,
    view_attach_template_submit_button(config),
  ])
}

fn view_attach_template_submit_button(config: Config(msg)) -> Element(msg) {
  let label = case config.rules.attach_template_loading {
    True -> t(config, i18n_text.Attaching)
    False -> t(config, i18n_text.Attach)
  }

  let button =
    ui_button.text(
      label,
      config.on_attach_submitted,
      ui_button.Primary,
      ui_button.EntityAction,
    )
    |> ui_button.with_disabled(
      config.rules.attach_template_loading
      || opt.is_none(config.rules.attach_template_selected),
    )

  case config.rules.attach_template_loading {
    True -> button |> ui_button.with_class("btn-loading") |> ui_button.view
    False -> button |> ui_button.view
  }
}

/// Render a radio button option for template selection.
/// AC12: Radio buttons with template name, type icon, and priority.
fn view_template_radio_option(
  config: Config(msg),
  tmpl: TaskTemplate,
) -> Element(msg) {
  let is_selected = config.rules.attach_template_selected == opt.Some(tmpl.id)
  let radio_id = "template-radio-" <> int.to_string(tmpl.id)

  // Find task type info for icon
  let task_type_info = find_task_type(config, tmpl.type_id)

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
      event.on_click(config.on_template_selected(tmpl.id)),
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
              icons.view_task_type_icon_inline(tt.icon, 16, config.theme),
            ])
          opt.None -> element.none()
        },
        // Template name
        span([attribute.class("template-name")], [text(tmpl.name)]),
        // Priority
        span([attribute.class("template-priority")], [
          text(t(config, i18n_text.PriorityShort(tmpl.priority))),
        ]),
      ]),
    ],
  )
}

fn find_task_type(config: Config(msg), type_id: Int) -> opt.Option(TaskType) {
  case config.task_types {
    Loaded(types) ->
      list.find(types, fn(tt) { tt.id == type_id }) |> opt.from_result
    _ -> opt.None
  }
}

/// Get metrics for a specific rule from the workflow metrics.
fn get_rule_metrics(
  metrics: Remote(api_rule_metrics.WorkflowMetrics),
  rule_id: Int,
) -> #(Int, Int) {
  case metrics {
    Loaded(wm) -> rule_metrics_for_loaded(wm, rule_id)
    _ -> #(0, 0)
  }
}

// Justification: nested case isolates loaded metrics lookup from empty fallback.
fn rule_metrics_for_loaded(
  metrics: api_rule_metrics.WorkflowMetrics,
  rule_id: Int,
) -> #(Int, Int) {
  case list.find(metrics.rules, fn(rm) { rm.rule_id == rule_id }) {
    Ok(rm) -> #(rm.applied_count, rm.suppressed_count)
    Error(_) -> #(0, 0)
  }
}

/// Renders the rule-crud-dialog component.
/// The component handles create/edit/delete internally and emits events.
fn view_rule_crud_dialog(config: Config(msg)) -> Element(msg) {
  // Build mode attribute based on dialog mode
  let mode_attr = case config.rules.rules_dialog_mode {
    opt.None -> "closed"
    opt.Some(admin_rules.RuleDialogCreate) -> "create"
    opt.Some(admin_rules.RuleDialogEdit(_)) -> "edit"
    opt.Some(admin_rules.RuleDialogDelete(_)) -> "delete"
  }

  // Build rule property for edit/delete modes (includes _mode field for component)
  let rule_prop = case config.rules.rules_dialog_mode {
    opt.Some(admin_rules.RuleDialogEdit(rule)) ->
      attribute.property("rule", rule_to_json(rule, "edit"))
    opt.Some(admin_rules.RuleDialogDelete(rule)) ->
      attribute.property("rule", rule_to_json(rule, "delete"))
    _ -> attribute.none()
  }

  // Build task types property (include icon for decoder)
  let task_types_json = case config.task_types {
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
      attribute.attribute("locale", serialize(config.locale)),
      attribute.attribute("workflow-id", int.to_string(config.workflow_id)),
      attribute.attribute("mode", mode_attr),
      rule_prop,
      attribute.property("task-types", task_types_json),
      // Event handlers
      event.on(
        "rule-created",
        decode_rule_event(fn(rule) { config.on_rule_created(rule) }),
      ),
      event.on(
        "rule-updated",
        decode_rule_event(fn(rule) { config.on_rule_updated(rule) }),
      ),
      event.on(
        "rule-deleted",
        decode_rule_id_event(fn(rule_id) { config.on_rule_deleted(rule_id) }),
      ),
      event.on(
        "close-requested",
        decode_close_event(config.on_rule_dialog_closed),
      ),
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
    #("resource_type", json.string(rule_resource_type(rule))),
    #("task_type_id", json.nullable(rule_task_type_id(rule), json.int)),
    #("to_state", json.string(rule_to_state_string(rule))),
    #("active", json.bool(rule.active)),
    #("created_at", json.string(rule.created_at)),
    #("_mode", json.string(mode)),
  ])
}

/// Decode rule event from component custom event.
/// Story 4.10: Added templates field (defaults to empty list from component events).
fn decode_rule_event(to_msg: fn(Rule) -> msg) -> decode.Decoder(msg) {
  event_decoders.custom_detail(workflow_codec.rule_decoder(), fn(rule) {
    decode.success(to_msg(rule))
  })
}

/// Decode rule ID from delete event.
fn decode_rule_id_event(to_msg: fn(Int) -> msg) -> decode.Decoder(msg) {
  decode.at(["detail", "rule_id"], decode.int)
  |> decode.map(to_msg)
}

/// Decode close event (no payload).
fn decode_close_event(msg: msg) -> decode.Decoder(msg) {
  decode.success(msg)
}
