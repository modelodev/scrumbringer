//// Automation rule list view.
////
//// ## Mission
////
//// Render engine rule drill-down, selected templates, and rule dialogs.
////
//// ## Responsibilities
////
//// - Rule list for a selected engine
//// - Rule row expansion and selected template summary
//// - Rule builder panel wiring
////
//// ## Relations
////
//// - **features/automations/engine_list.gleam**: Delegates selected-engine rules here

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/result
import gleam/set
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, form, h2, input, option, p, select, span, text}
import lustre/element/keyed
import lustre/event

import domain/remote.{type Remote, Loaded}
import domain/task_type.{type TaskType}
import domain/workflow.{
  type Rule, type TaskTemplate, type Workflow, rule_task_type_id,
}

import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/features/automations/rule_sentence
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/expand_toggle
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/remote as ui_remote

// =============================================================================
// Rules Views
// =============================================================================

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    workflow_id: Int,
    selected_rule_id: opt.Option(Int),
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
    on_rule_name_changed: fn(String) -> msg,
    on_rule_goal_changed: fn(String) -> msg,
    on_rule_subject_changed: fn(String) -> msg,
    on_rule_task_type_changed: fn(String) -> msg,
    on_rule_event_changed: fn(String) -> msg,
    on_rule_card_scope_changed: fn(String) -> msg,
    on_rule_template_search_changed: fn(String) -> msg,
    on_rule_template_changed: fn(String) -> msg,
    on_rule_active_changed: fn(Bool) -> msg,
    on_rule_submitted: msg,
    on_rule_delete_confirmed: msg,
    on_rule_panel_closed: msg,
    on_noop: msg,
  )
}

pub fn engine_name_from_remotes(
  workflows_org: Remote(List(Workflow)),
  workflows_project: Remote(List(Workflow)),
  workflow_id: Int,
) -> String {
  find_engine_name(workflows_org, workflow_id)
  |> opt.lazy_or(fn() { find_engine_name(workflows_project, workflow_id) })
  |> engine_name_or_id(workflow_id)
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
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
      view_rules_heading(config),
      view_rules_list(config, config.rules.rules, config.rules.rules_metrics),
      view_rule_builder_panel(config),
    ],
  )
}

fn view_rules_heading(config: Config(msg)) -> Element(msg) {
  div([attribute.class("automation-rules-heading")], [
    div([attribute.class("automation-rules-heading__copy")], [
      h2([], [text(t(config, i18n_text.RulesTitle(config.workflow_name)))]),
      p([], [text(t(config, i18n_text.AutomationEnginesDescription))]),
    ]),
    dialog.add_button_with_locale(
      config.locale,
      i18n_text.CreateRule,
      config.on_create_clicked,
    ),
  ])
}

fn find_engine_name(
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

fn engine_name_or_id(name: opt.Option(String), workflow_id: Int) -> String {
  case name {
    opt.None -> "Motor #" <> int.to_string(workflow_id)
    opt.Some(value) -> value
  }
}

fn view_rules_list(
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
          keyed.element(
            "div",
            [attribute.class("automation-rule-list")],
            list.map(rs, fn(r) {
              view_rule_row_expandable(
                config,
                r,
                get_rule_metrics(metrics, r.id),
              )
            }),
          )
      }
    },
  )
}

/// Render an expandable rule row with optional expansion for attached templates.
fn view_rule_row_expandable(
  config: Config(msg),
  rule: Rule,
  rule_metrics: #(Int, Int),
) -> #(String, Element(msg)) {
  let is_selected = config.selected_rule_id == opt.Some(rule.id)
  let is_expanded =
    set.contains(config.rules.rules_expanded, rule.id) || is_selected
  let #(applied, ignored) = rule_metrics
  let has_template = opt.is_some(rule.template)

  // AC2: Whole row is clickeable (via row class + click handler)
  // AC5: aria-expanded attribute
  let row_class =
    "rule-row rule-row-expandable"
    |> class_when(is_expanded, "rule-row-expanded")
    |> class_when(is_selected, "is-selected")

  #(
    "rule-" <> int.to_string(rule.id),
    div([attribute.class("automation-rule-item")], [
      div(
        [
          attribute.class(row_class),
          attribute.role("button"),
          attribute.attribute("tabindex", "0"),
          attribute.attribute("data-testid", "automation-rule-row"),
          attribute.attribute("data-selected", bool_to_string(is_selected)),
          attribute.attribute(
            "aria-expanded",
            attribute_value.boolean(is_expanded),
          ),
          // AC2: Click anywhere on the row to expand/collapse
          event.on_click(config.on_rule_expanded(rule.id)),
        ],
        [
          div([attribute.class("rule-row__main")], [
            div([attribute.class("rule-row__title")], [
              expand_toggle.view_with_class(is_expanded, "rule-expand-icon"),
              span([attribute.class("rule-row__name")], [text(rule.name)]),
              rule_sentence.status_badge(config.locale, rule),
            ]),
            rule_sentence.view(
              config.locale,
              rule,
              rule_task_type_name(config, rule),
            ),
            div([attribute.class("rule-row__meta")], [
              rule_meta(
                t(config, i18n_text.ProjectExecutionsEngineColumn),
                config.workflow_name,
              ),
              rule_meta(
                t(config, i18n_text.ProjectExecutionsTemplateColumn),
                case has_template {
                  True -> "1"
                  False -> "0"
                },
              ),
              rule_meta(
                t(config, i18n_text.RuleMetricsApplied),
                int.to_string(applied),
              ),
              rule_meta(
                t(config, i18n_text.RuleMetricsSuppressed),
                int.to_string(ignored),
              ),
            ]),
          ]),
          div([attribute.class("rule-row__actions cell-no-expand")], [
            action_buttons.edit_delete_row(
              edit_title: t(config, i18n_text.EditRule),
              edit_click: config.on_edit_clicked(rule),
              delete_title: t(config, i18n_text.DeleteRule),
              delete_click: config.on_delete_clicked(rule),
            ),
          ]),
        ],
      ),
      case is_expanded {
        True -> view_rule_templates_expansion(config, rule)
        False -> element.none()
      },
    ]),
  )
}

fn rule_meta(label: String, value: String) -> Element(msg) {
  span([attribute.class("rule-row__metric")], [
    span([attribute.class("rule-row__metric-label")], [text(label <> ":")]),
    span([attribute.class("rule-row__metric-value")], [text(value)]),
  ])
}

fn class_when(base: String, condition: Bool, class_name: String) -> String {
  case condition {
    True -> base <> " " <> class_name
    False -> base
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn rule_task_type_name(config: Config(msg), rule: Rule) -> opt.Option(String) {
  case rule_task_type_id(rule) {
    opt.Some(type_id) ->
      find_task_type(config, type_id)
      |> opt.map(fn(task_type) { task_type.name })
    opt.None -> opt.None
  }
}

/// Render the expansion row with the rule's selected template.
fn view_rule_templates_expansion(
  config: Config(msg),
  rule: Rule,
) -> Element(msg) {
  div(
    [
      attribute.class("templates-expansion"),
      // Prevent clicks in expansion row from bubbling up
      event.on_click(config.on_noop) |> event.stop_propagation,
    ],
    [
      div([attribute.class("templates-header")], [
        span([attribute.class("templates-title")], [
          text(t(config, i18n_text.AttachedTemplates)),
        ]),
      ]),
      case rule.template {
        opt.None ->
          div([attribute.class("templates-empty-hint")], [
            span([attribute.class("hint-icon")], [
              icons.nav_icon(icons.Info, icons.Medium),
            ]),
            p([], [text(t(config, i18n_text.AttachTemplateHint))]),
          ])
        opt.Some(template) ->
          div([attribute.class("templates-list")], [
            view_attached_template_item(config, template),
          ])
      },
    ],
  )
}

/// Render the selected template item.
fn view_attached_template_item(
  config: Config(msg),
  tmpl: workflow.RuleTemplate,
) -> Element(msg) {
  let task_type_info = find_task_type(config, tmpl.type_id)

  div([attribute.class("attached-template-row")], [
    div([attribute.class("attached-template-info")], [
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
    ]),
  ])
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

fn view_rule_builder_panel(config: Config(msg)) -> Element(msg) {
  case config.rules.rules_dialog_mode {
    opt.None -> element.none()
    opt.Some(admin_rules.RuleDialogDelete(rule)) ->
      view_rule_delete_panel(config, rule)
    opt.Some(admin_rules.RuleDialogCreate) ->
      view_rule_form_panel(
        config,
        t(config, i18n_text.RuleBuilderNewRule),
        t(config, i18n_text.CreateRule),
      )
    opt.Some(admin_rules.RuleDialogEdit(_rule)) ->
      view_rule_form_panel(
        config,
        t(config, i18n_text.RuleBuilderEditRule),
        t(config, i18n_text.RuleBuilderSaveRule),
      )
  }
}

fn view_rule_form_panel(
  config: Config(msg),
  title: String,
  submit_label: String,
) -> Element(msg) {
  let form_disabled =
    config.rules.rule_form_submitting || !rule_form_is_valid(config)

  div(
    [
      attribute.class("automation-rule-panel"),
      attribute.role("region"),
      attribute.attribute("aria-label", title),
      attribute.attribute("data-testid", "automation-rule-builder"),
    ],
    [
      div([attribute.class("automation-rule-panel-header")], [
        h2([], [text(title)]),
        ui_button.text(
          t(config, i18n_text.Cancel),
          config.on_rule_panel_closed,
          ui_button.Secondary,
          ui_button.EntityAction,
        )
          |> ui_button.view,
      ]),
      form(
        [
          attribute.class("form automation-rule-form"),
          event.on_submit(fn(_) {
            case form_disabled {
              True -> config.on_noop
              False -> config.on_rule_submitted
            }
          }),
        ],
        [
          form_field.view_required(
            t(config, i18n_text.RuleName),
            input([
              attribute.type_("text"),
              attribute.value(config.rules.rule_form_name),
              event.on_input(config.on_rule_name_changed),
            ]),
          ),
          form_field.view(
            t(config, i18n_text.RuleGoal),
            input([
              attribute.type_("text"),
              attribute.value(config.rules.rule_form_goal),
              event.on_input(config.on_rule_goal_changed),
            ]),
          ),
          div([attribute.class("rule-builder-when")], [
            form_field.view(
              t(config, i18n_text.RuleBuilderWhen),
              view_rule_subject_select(config),
            ),
            case config.rules.rule_form_subject {
              "task" -> view_rule_task_type_select(config)
              _ -> element.none()
            },
            form_field.view(
              t(config, i18n_text.RuleBuilderEvent),
              view_rule_event_select(config),
            ),
          ]),
          case config.rules.rule_form_subject {
            "card" -> view_rule_card_scope_select(config)
            _ -> element.none()
          },
          form_field.view_required(
            t(config, i18n_text.RuleBuilderCreateTaskFrom),
            view_rule_template_picker(config),
          ),
          form_field.view_checkbox(
            t(config, i18n_text.RuleActive),
            input([
              attribute.type_("checkbox"),
              attribute.checked(config.rules.rule_form_active),
              event.on_check(config.on_rule_active_changed),
            ]),
          ),
          view_rule_preview(config),
          view_rule_form_error(config),
          div([attribute.class("automation-rule-panel-actions")], [
            ui_button.submit(
              submit_label,
              ui_button.Primary,
              ui_button.EntityAction,
            )
            |> ui_button.with_disabled(form_disabled)
            |> ui_button.view,
          ]),
        ],
      ),
    ],
  )
}

fn view_rule_card_scope_select(config: Config(msg)) -> Element(msg) {
  form_field.view(
    t(config, i18n_text.RuleBuilderCardLevel),
    input([
      attribute.type_("number"),
      attribute.attribute("min", "1"),
      attribute.value(config.rules.rule_form_card_scope),
      event.on_input(config.on_rule_card_scope_changed),
      attribute.attribute(
        "aria-label",
        t(config, i18n_text.RuleBuilderCardScope),
      ),
      attribute.placeholder(t(config, i18n_text.RuleBuilderAnyCard)),
    ]),
  )
}

fn view_rule_template_picker(config: Config(msg)) -> Element(msg) {
  let templates = filtered_templates_for_rule_builder(config)

  div([attribute.class("rule-template-picker")], [
    input([
      attribute.type_("search"),
      attribute.value(config.rules.rule_form_template_search),
      attribute.placeholder(t(config, i18n_text.RuleTemplateSearchPlaceholder)),
      attribute.attribute(
        "aria-label",
        t(config, i18n_text.RuleTemplateSearchPlaceholder),
      ),
      attribute.attribute("data-testid", "automation-template-search"),
      event.on_input(config.on_rule_template_search_changed),
    ]),
    select(
      [
        attribute.value(config.rules.rule_form_template_id),
        event.on_input(config.on_rule_template_changed),
        event.on_change(config.on_rule_template_changed),
        attribute.attribute(
          "aria-label",
          t(config, i18n_text.RuleBuilderTaskTemplate),
        ),
        attribute.attribute("data-testid", "automation-template-picker"),
      ],
      [
        option(
          [
            attribute.value(""),
            attribute.selected(config.rules.rule_form_template_id == ""),
          ],
          t(config, i18n_text.RuleBuilderChooseTemplate),
        ),
        ..task_template_options(config, templates)
      ],
    ),
    case templates {
      [] ->
        p([attribute.class("rule-template-picker__empty")], [
          text(t(config, i18n_text.RuleTemplateNoSearchResults)),
        ])
      _ -> element.none()
    },
    view_selected_template_preview(config),
  ])
}

fn task_template_options(
  config: Config(msg),
  templates: List(TaskTemplate),
) -> List(Element(msg)) {
  templates
  |> list.map(fn(tmpl) {
    let value = int.to_string(tmpl.id)
    option(
      [
        attribute.value(value),
        attribute.selected(config.rules.rule_form_template_id == value),
      ],
      tmpl.name,
    )
  })
}

fn filtered_templates_for_rule_builder(
  config: Config(msg),
) -> List(TaskTemplate) {
  let query = string.trim(config.rules.rule_form_template_search)
  case query {
    "" -> available_templates_for_rule_builder(config)
    _ ->
      available_templates_for_rule_builder(config)
      |> list.filter(fn(tmpl) { task_template_matches_query(tmpl, query) })
  }
}

fn task_template_matches_query(tmpl: TaskTemplate, query: String) -> Bool {
  string.contains(tmpl.name, query)
  || string.contains(tmpl.type_name, query)
  || string.contains(int.to_string(tmpl.priority), query)
}

fn view_selected_template_preview(config: Config(msg)) -> Element(msg) {
  case selected_rule_template(config) {
    opt.None -> element.none()
    opt.Some(tmpl) ->
      div([attribute.class("rule-template-picker__preview")], [
        span([attribute.class("rule-template-picker__preview-title")], [
          text(tmpl.name),
        ]),
        span([attribute.class("rule-template-picker__preview-meta")], [
          text(
            tmpl.type_name
            <> " - "
            <> t(config, i18n_text.PriorityShort(tmpl.priority)),
          ),
        ]),
        case tmpl.description {
          opt.Some(description) ->
            p([attribute.class("rule-template-picker__preview-description")], [
              text(description),
            ])
          opt.None -> element.none()
        },
      ])
  }
}

fn available_templates_for_rule_builder(
  config: Config(msg),
) -> List(TaskTemplate) {
  loaded_task_templates(config.task_templates_project)
  |> list.append(loaded_task_templates(config.task_templates_org))
}

fn loaded_task_templates(
  templates: Remote(List(TaskTemplate)),
) -> List(TaskTemplate) {
  case templates {
    Loaded(values) -> values
    _ -> []
  }
}

fn view_rule_subject_select(config: Config(msg)) -> Element(msg) {
  select(
    [
      attribute.value(config.rules.rule_form_subject),
      event.on_input(config.on_rule_subject_changed),
      event.on_change(config.on_rule_subject_changed),
      attribute.attribute("aria-label", t(config, i18n_text.RuleBuilderSubject)),
    ],
    [
      option(
        [
          attribute.value("task"),
          attribute.selected(config.rules.rule_form_subject == "task"),
        ],
        t(config, i18n_text.RuleBuilderTask),
      ),
      option(
        [
          attribute.value("card"),
          attribute.selected(config.rules.rule_form_subject == "card"),
        ],
        t(config, i18n_text.RuleBuilderCard),
      ),
    ],
  )
}

fn view_rule_task_type_select(config: Config(msg)) -> Element(msg) {
  form_field.view(
    t(config, i18n_text.RuleTaskType),
    select(
      [
        attribute.value(config.rules.rule_form_task_type_id),
        event.on_input(config.on_rule_task_type_changed),
        event.on_change(config.on_rule_task_type_changed),
        attribute.attribute("aria-label", t(config, i18n_text.RuleTaskType)),
      ],
      [
        option(
          [
            attribute.value(""),
            attribute.selected(config.rules.rule_form_task_type_id == ""),
          ],
          t(config, i18n_text.RuleBuilderAnyTaskType),
        ),
        ..task_type_options(config)
      ],
    ),
  )
}

fn task_type_options(config: Config(msg)) -> List(Element(msg)) {
  case config.task_types {
    Loaded(types) ->
      list.map(types, fn(task_type) {
        let value = int.to_string(task_type.id)
        option(
          [
            attribute.value(value),
            attribute.selected(config.rules.rule_form_task_type_id == value),
          ],
          task_type.name,
        )
      })
    _ -> []
  }
}

fn view_rule_event_select(config: Config(msg)) -> Element(msg) {
  let options = case config.rules.rule_form_subject {
    "card" -> [
      #("card_activated", t(config, i18n_text.RuleBuilderCardActivatedEvent)),
      #("card_closed", t(config, i18n_text.RuleBuilderCardClosedEvent)),
    ]
    _ -> [
      #("task_created", t(config, i18n_text.RuleBuilderTaskCreatedEvent)),
      #("task_completed", t(config, i18n_text.RuleBuilderTaskCompletedEvent)),
      #("task_claimed", t(config, i18n_text.RuleBuilderTaskClaimedEvent)),
      #("task_released", t(config, i18n_text.RuleBuilderTaskReleasedEvent)),
    ]
  }

  select(
    [
      attribute.value(config.rules.rule_form_event),
      event.on_input(config.on_rule_event_changed),
      event.on_change(config.on_rule_event_changed),
      attribute.attribute("aria-label", t(config, i18n_text.RuleBuilderEvent)),
    ],
    list.map(options, fn(item) {
      let #(value, label) = item
      option(
        [
          attribute.value(value),
          attribute.selected(config.rules.rule_form_event == value),
        ],
        label,
      )
    }),
  )
}

fn view_rule_preview(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("rule-builder-preview"),
      attribute.attribute("aria-live", "polite"),
    ],
    [
      span([attribute.class("preview-label")], [
        text(t(config, i18n_text.RuleBuilderPreview)),
      ]),
      p([], [text(rule_preview_sentence(config))]),
      p([attribute.class("hint")], [text(rule_template_preview(config))]),
    ],
  )
}

fn rule_preview_sentence(config: Config(msg)) -> String {
  case config.rules.rule_form_event {
    "task_created" ->
      "When "
      <> task_subject_label(config)
      <> " is created, work is created in the Pool."
    "task_claimed" ->
      "When "
      <> task_subject_label(config)
      <> " is claimed, work is created in the Pool."
    "task_released" ->
      "When "
      <> task_subject_label(config)
      <> " is released, work is created in the Pool."
    "task_completed" ->
      "When "
      <> task_subject_label(config)
      <> " is completed, work is created in the Pool."
    "card_activated" ->
      "When "
      <> card_scope_label(config)
      <> " is activated, work is created in the Pool."
    "card_closed" ->
      "When "
      <> card_scope_label(config)
      <> " is closed, work is created in the Pool."
    _ -> "This rule uses a target that requires review before it can run."
  }
}

fn card_scope_label(config: Config(msg)) -> String {
  case string.trim(config.rules.rule_form_card_scope) {
    "" -> "any card"
    value -> "a card at level " <> value
  }
}

fn task_subject_label(config: Config(msg)) -> String {
  case config.rules.rule_form_task_type_id {
    "" -> "any task"
    value ->
      case int.parse(value) {
        Ok(type_id) ->
          case find_task_type(config, type_id) {
            opt.Some(task_type) -> "a " <> task_type.name <> " task"
            opt.None -> "a selected task type"
          }
        Error(_) -> "a selected task type"
      }
  }
}

fn rule_template_preview(config: Config(msg)) -> String {
  case selected_rule_template(config) {
    opt.Some(template) ->
      "It will create \"" <> template.name <> "\" as available work."
    opt.None -> "Choose one template before saving this rule."
  }
}

fn selected_rule_template(config: Config(msg)) -> opt.Option(TaskTemplate) {
  case int.parse(config.rules.rule_form_template_id) {
    Ok(template_id) ->
      available_templates_for_rule_builder(config)
      |> list.find(fn(tmpl) { tmpl.id == template_id })
      |> opt.from_result
    Error(_) -> opt.None
  }
}

fn view_rule_form_error(config: Config(msg)) -> Element(msg) {
  case config.rules.rule_form_error {
    opt.Some(message) ->
      div([attribute.class("field-error"), attribute.role("alert")], [
        text(message),
      ])
    opt.None -> element.none()
  }
}

fn rule_form_is_valid(config: Config(msg)) -> Bool {
  string.trim(config.rules.rule_form_name) != ""
  && config.rules.rule_form_event != "unsupported"
  && config.rules.rule_form_template_id != ""
  && rule_card_scope_is_valid(config)
}

fn rule_card_scope_is_valid(config: Config(msg)) -> Bool {
  case
    config.rules.rule_form_subject,
    string.trim(config.rules.rule_form_card_scope)
  {
    "card", "" -> True
    "card", value ->
      case int.parse(value) {
        Ok(depth) -> depth > 0
        Error(_) -> False
      }
    _, _ -> True
  }
}

fn view_rule_delete_panel(config: Config(msg), rule: Rule) -> Element(msg) {
  div(
    [
      attribute.class("automation-rule-panel automation-rule-panel-danger"),
      attribute.role("region"),
      attribute.attribute("aria-label", t(config, i18n_text.DeleteRule)),
      attribute.attribute("data-testid", "automation-rule-builder"),
    ],
    [
      div([attribute.class("automation-rule-panel-header")], [
        h2([], [text(t(config, i18n_text.DeleteRule))]),
        ui_button.text(
          t(config, i18n_text.Cancel),
          config.on_rule_panel_closed,
          ui_button.Secondary,
          ui_button.EntityAction,
        )
          |> ui_button.view,
      ]),
      p([], [text(t(config, i18n_text.RuleDeleteConfirm(rule.name)))]),
      view_rule_form_error(config),
      div([attribute.class("automation-rule-panel-actions")], [
        ui_button.text(
          t(config, i18n_text.DeleteRule),
          config.on_rule_delete_confirmed,
          ui_button.Danger,
          ui_button.EntityAction,
        )
        |> ui_button.with_disabled(config.rules.rule_form_submitting)
        |> ui_button.view,
      ]),
    ],
  )
}
