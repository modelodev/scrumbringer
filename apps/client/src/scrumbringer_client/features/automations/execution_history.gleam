//// Automation execution history view.
////
//// ## Mission
////
//// Render the executions mode, engine expansion metrics, and drilldown modal.
////
//// ## Responsibilities
////
//// - Date range controls for automation executions
//// - Engine/rule execution tables
//// - Rule execution drilldown modal

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, h3, hr, input, span, table, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/expand_toggle
import scrumbringer_client/ui/filter_bar
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/info_callout
import scrumbringer_client/ui/modal_close_button
import scrumbringer_client/ui/skeleton

// =============================================================================
// Automation Execution History Views
// =============================================================================

pub type QuickRange(msg) {
  QuickRange(label: String, from: String, to: String, on_clicked: msg)
}

pub type Config(msg) {
  Config(
    locale: Locale,
    model: admin_metrics.Model,
    selected_execution_id: opt.Option(Int),
    quick_ranges: List(QuickRange(msg)),
    on_from_changed: fn(String) -> msg,
    on_to_changed: fn(String) -> msg,
    on_workflow_expanded: fn(Int) -> msg,
    on_drilldown_clicked: fn(Int) -> msg,
    on_drilldown_closed: msg,
    on_exec_page_changed: fn(Int) -> msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

/// Automation execution history view.
pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("automation-executions-mode")], [
    div([attribute.class("automation-executions-description")], [
      text(t(config, i18n_text.RuleMetricsDescription)),
    ]),
    view_execution_filters(config),
    view_execution_results(config),
  ])
}

fn view_execution_filters(config: Config(msg)) -> Element(msg) {
  let is_loading = case config.model.admin_rule_metrics {
    Loading -> True
    _ -> False
  }

  filter_bar.new([
    form_field.view(
      t(config, i18n_text.RuleMetricsFrom),
      input([
        attribute.type_("date"),
        attribute.value(config.model.admin_rule_metrics_from),
        event.on_input(config.on_from_changed),
        attribute.attribute("aria-label", t(config, i18n_text.RuleMetricsFrom)),
      ]),
    ),
    form_field.view(
      t(config, i18n_text.RuleMetricsTo),
      input([
        attribute.type_("date"),
        attribute.value(config.model.admin_rule_metrics_to),
        event.on_input(config.on_to_changed),
        attribute.attribute("aria-label", t(config, i18n_text.RuleMetricsTo)),
      ]),
    ),
  ])
  |> filter_bar.with_actions(list.append(
    [
      span([attribute.class("quick-ranges-label")], [
        text(t(config, i18n_text.RuleMetricsQuickRange)),
      ]),
    ],
    list.append(
      list.map(config.quick_ranges, fn(range) {
        view_quick_range_button(config, range)
      }),
      [
        case is_loading {
          True ->
            div([attribute.class("field loading-indicator")], [
              span([attribute.class("btn-spinner")], []),
              text(" " <> t(config, i18n_text.LoadingEllipsis)),
            ])
          False -> element.none()
        },
      ],
    ),
  ))
  |> filter_bar.with_class("automation-executions-filters")
  |> filter_bar.with_testid("automation-executions-filter-bar")
  |> filter_bar.view
}

/// Quick range button helper with active state.
fn view_quick_range_button(
  config: Config(msg),
  range: QuickRange(msg),
) -> Element(msg) {
  // Check if this range is currently active
  let is_active =
    config.model.admin_rule_metrics_from == range.from
    && config.model.admin_rule_metrics_to == range.to

  let class = case is_active {
    True -> "btn-chip btn-chip-active"
    False -> "btn-chip"
  }

  button(
    [
      attribute.class(class),
      event.on_click(range.on_clicked),
      attribute.attribute("aria-pressed", attribute_value.boolean(is_active)),
    ],
    [text(range.label)],
  )
}

/// Results section with improved empty state (T5).
fn view_execution_results(config: Config(msg)) -> Element(msg) {
  case config.model.admin_rule_metrics {
    NotAsked -> info_callout.simple(t(config, i18n_text.RuleMetricsHelp))

    Loading -> skeleton.skeleton_table(3)

    Failed(err) -> error_notice.view(err.message)

    Loaded(workflows) -> view_execution_history_loaded(config, workflows)
  }
}

fn view_execution_history_loaded(
  config: Config(msg),
  workflows: List(api_rule_metrics.OrgWorkflowMetricsSummary),
) -> Element(msg) {
  case workflows {
    [] ->
      empty_state.simple("inbox", t(config, i18n_text.RuleMetricsNoExecutions))
    _ ->
      div([attribute.class("automation-executions-results")], [
        view_execution_summary_table(config, config.model.admin_rule_metrics),
      ])
  }
}

fn view_execution_summary_table(
  config: Config(msg),
  metrics: Remote(List(api_rule_metrics.OrgWorkflowMetricsSummary)),
) -> Element(msg) {
  case metrics {
    NotAsked ->
      div([attribute.class("empty")], [
        text(t(config, i18n_text.RuleMetricsSelectRange)),
      ])

    Loading -> skeleton.skeleton_table(3)

    Failed(err) -> error_notice.view(err.message)

    Loaded(workflows) -> view_execution_summary_table_loaded(config, workflows)
  }
}

fn view_execution_summary_table_loaded(
  config: Config(msg),
  workflows: List(api_rule_metrics.OrgWorkflowMetricsSummary),
) -> Element(msg) {
  case workflows {
    [] ->
      div([attribute.class("empty")], [
        text(t(config, i18n_text.RuleMetricsNoData)),
      ])
    _ ->
      element.fragment([
        table([attribute.class("table")], [
          thead([], [
            tr([], [
              th([], []),
              th([], [
                text(t(config, i18n_text.WorkflowName)),
              ]),
              th([], [
                text(t(config, i18n_text.RuleMetricsRuleCount)),
              ]),
              th([], [
                text(t(config, i18n_text.RuleMetricsEvaluated)),
              ]),
              th([], [
                text(t(config, i18n_text.RuleMetricsApplied)),
              ]),
              th([], [
                text(t(config, i18n_text.RuleMetricsSuppressed)),
              ]),
            ]),
          ]),
          keyed.tbody(
            [],
            list.flat_map(workflows, fn(w) { view_workflow_row(config, w) }),
          ),
        ]),
        // Drill-down modal
        view_rule_drilldown_modal(config),
      ])
  }
}

/// Render a workflow row with optional expansion for per-rule metrics.
fn view_workflow_row(
  config: Config(msg),
  w: api_rule_metrics.OrgWorkflowMetricsSummary,
) -> List(#(String, Element(msg))) {
  let is_expanded =
    config.model.admin_rule_metrics_expanded_workflow == opt.Some(w.workflow_id)
  let main_row = #(
    "wf-" <> int.to_string(w.workflow_id),
    tr(
      [
        attribute.class("workflow-row clickable"),
        event.on_click(config.on_workflow_expanded(w.workflow_id)),
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
    True -> [main_row, view_engine_rules_expansion(config, w.workflow_id)]
  }
}

/// Render the expansion row with per-rule metrics.
fn view_engine_rules_expansion(
  config: Config(msg),
  _workflow_id: Int,
) -> #(String, Element(msg)) {
  let content =
    view_engine_rules_expansion_content(
      config,
      config.model.admin_rule_metrics_workflow_details,
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

fn view_engine_rules_expansion_content(
  config: Config(msg),
  details: Remote(api_rule_metrics.WorkflowMetrics),
) -> Element(msg) {
  case details {
    NotAsked | Loading -> skeleton.skeleton_list(2)
    Failed(err) -> error_notice.view(err.message)
    Loaded(loaded) -> view_engine_rules_expansion_loaded(config, loaded)
  }
}

fn view_engine_rules_expansion_loaded(
  config: Config(msg),
  details: api_rule_metrics.WorkflowMetrics,
) -> Element(msg) {
  case details.rules {
    [] ->
      div([attribute.class("empty")], [
        text(t(config, i18n_text.RuleMetricsNoRules)),
      ])
    rules ->
      table([attribute.class("table nested-table")], [
        thead([], [
          tr([], [
            th([], [text(t(config, i18n_text.RuleName))]),
            th([], [
              text(t(config, i18n_text.RuleMetricsEvaluated)),
            ]),
            th([], [
              text(t(config, i18n_text.RuleMetricsApplied)),
            ]),
            th([], [
              text(t(config, i18n_text.RuleMetricsSuppressed)),
            ]),
            th([], []),
          ]),
        ]),
        keyed.tbody(
          [],
          list.map(rules, fn(r) { view_workflow_rule_metrics_row(config, r) }),
        ),
      ])
  }
}

fn view_workflow_rule_metrics_row(
  config: Config(msg),
  rule_metrics: api_rule_metrics.RuleMetricsSummary,
) -> #(String, Element(msg)) {
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
        ui_button.text(
          t(config, i18n_text.ViewDetails),
          config.on_drilldown_clicked(rule_metrics.rule_id),
          ui_button.Secondary,
          ui_button.EntityAction,
        )
        |> ui_button.with_size(ui_button.ExtraSmall)
        |> ui_button.view,
      ]),
    ]),
  )
}

/// Render the drill-down modal for rule details and executions.
fn view_rule_drilldown_modal(config: Config(msg)) -> Element(msg) {
  case config.model.admin_rule_metrics_drilldown_rule_id {
    opt.None -> element.none()
    opt.Some(_rule_id) ->
      div([attribute.class("modal drilldown-modal")], [
        div([attribute.class("modal-content")], [
          div([attribute.class("modal-header")], [
            h3([], [
              text(t(config, i18n_text.RuleMetricsDrilldown)),
            ]),
            modal_close_button.view_with_label_and_class(
              t(config, i18n_text.Close),
              "btn-close",
              config.on_drilldown_closed,
            ),
          ]),
          div([attribute.class("modal-body")], [
            view_drilldown_details(config),
            hr([]),
            view_drilldown_executions(config),
          ]),
        ]),
      ])
  }
}

/// Render the suppression breakdown in the drill-down modal.
fn view_drilldown_details(config: Config(msg)) -> Element(msg) {
  case config.model.admin_rule_metrics_rule_details {
    NotAsked | Loading -> skeleton.skeleton_list(3)

    Failed(err) -> error_notice.view(err.message)

    Loaded(details) ->
      div([attribute.class("drilldown-details")], [
        h3([], [text(details.rule_name)]),
        div([attribute.class("metrics-summary")], [
          div([attribute.class("metric-box")], [
            span([attribute.class("metric-label")], [
              text(t(config, i18n_text.RuleMetricsEvaluated)),
            ]),
            span([attribute.class("metric-value")], [
              text(int.to_string(details.evaluated_count)),
            ]),
          ]),
          div([attribute.class("metric-box applied")], [
            span([attribute.class("metric-label")], [
              text(t(config, i18n_text.RuleMetricsApplied)),
            ]),
            span([attribute.class("metric-value")], [
              text(int.to_string(details.applied_count)),
            ]),
          ]),
          div([attribute.class("metric-box suppressed")], [
            span([attribute.class("metric-label")], [
              text(t(config, i18n_text.RuleMetricsSuppressed)),
            ]),
            span([attribute.class("metric-value")], [
              text(int.to_string(details.suppressed_count)),
            ]),
          ]),
        ]),
        // Suppression breakdown
        h3([], [
          text(t(config, i18n_text.SuppressionBreakdown)),
        ]),
        div([attribute.class("suppression-breakdown")], [
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(t(config, i18n_text.SuppressionIdempotent)),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(details.suppression_breakdown.idempotent)),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(t(config, i18n_text.SuppressionNotUserTriggered)),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(
                details.suppression_breakdown.not_user_triggered,
              )),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(t(config, i18n_text.SuppressionNotMatching)),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(details.suppression_breakdown.not_matching)),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(t(config, i18n_text.SuppressionInactive)),
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
fn view_drilldown_executions(config: Config(msg)) -> Element(msg) {
  case config.model.admin_rule_metrics_executions {
    NotAsked | Loading -> skeleton.skeleton_list(3)

    Failed(err) -> error_notice.view(err.message)

    Loaded(response) -> view_drilldown_executions_loaded(config, response)
  }
}

fn view_drilldown_executions_loaded(
  config: Config(msg),
  response: api_rule_metrics.RuleExecutionsResponse,
) -> Element(msg) {
  let business_executions =
    list.filter(response.executions, is_business_execution)

  let origin_cell: fn(api_rule_metrics.RuleExecution) -> Element(msg) = fn(
    exec: api_rule_metrics.RuleExecution,
  ) {
    text(execution_target_label(exec.task_id, exec.card_id))
  }
  let outcome_cell: fn(api_rule_metrics.RuleExecution) -> Element(msg) = fn(
    exec: api_rule_metrics.RuleExecution,
  ) {
    span([attribute.class(outcome_class_for(exec.outcome))], [
      text(outcome_text_for(config, exec)),
    ])
  }
  let user_cell: fn(api_rule_metrics.RuleExecution) -> Element(msg) = fn(
    exec: api_rule_metrics.RuleExecution,
  ) {
    text(display_user_email(exec.user_email))
  }
  let timestamp_cell: fn(api_rule_metrics.RuleExecution) -> Element(msg) = fn(
    exec: api_rule_metrics.RuleExecution,
  ) {
    text(exec.created_at)
  }
  let created_task_cell: fn(api_rule_metrics.RuleExecution) -> Element(msg) = fn(
    exec: api_rule_metrics.RuleExecution,
  ) {
    text(option_id_label(exec.created_task_id, "task #"))
  }
  let template_cell: fn(api_rule_metrics.RuleExecution) -> Element(msg) = fn(
    exec: api_rule_metrics.RuleExecution,
  ) {
    text(execution_template_label(exec.template_id, exec.template_version))
  }
  let key_fn: fn(api_rule_metrics.RuleExecution) -> String = fn(
    exec: api_rule_metrics.RuleExecution,
  ) {
    int.to_string(exec.id)
  }

  div([attribute.class("drilldown-executions")], [
    h3([], [
      text(t(config, i18n_text.RecentExecutions)),
    ]),
    case business_executions {
      [] ->
        div([attribute.class("empty")], [
          text(t(config, i18n_text.NoExecutions)),
        ])
      executions ->
        element.fragment([
          data_table.new()
            |> data_table.with_class("executions-table")
            |> data_table.with_columns([
              data_table.column(t(config, i18n_text.Origin), origin_cell),
              data_table.column(t(config, i18n_text.Outcome), outcome_cell),
              data_table.column("Created task", created_task_cell),
              data_table.column("Template", template_cell),
              data_table.column(t(config, i18n_text.User), user_cell),
              data_table.column(t(config, i18n_text.Timestamp), timestamp_cell),
            ])
            |> data_table.with_rows(executions, key_fn)
            |> data_table.with_row_attrs(fn(exec) {
              let is_selected =
                config.selected_execution_id == opt.Some(exec.id)
              [
                attribute.attribute("data-testid", "automation-execution-row"),
                attribute.attribute(
                  "data-selected",
                  bool_to_string(is_selected),
                ),
                attribute.class(row_class(
                  "automation-execution-row",
                  is_selected,
                )),
              ]
            })
            |> data_table.view(),
          // Pagination
          view_executions_pagination(config, response.pagination),
        ])
    },
  ])
}

fn row_class(base: String, is_selected: Bool) -> String {
  case is_selected {
    True -> base <> " is-selected"
    False -> base
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn is_business_execution(exec: api_rule_metrics.RuleExecution) -> Bool {
  api_rule_metrics.execution_outcome_is_created(exec.outcome)
}

fn execution_template_label(
  template_id: opt.Option(Int),
  template_version: opt.Option(Int),
) -> String {
  case template_id, template_version {
    opt.Some(id), opt.Some(version) ->
      "#" <> int.to_string(id) <> " v" <> int.to_string(version)
    opt.Some(id), _ -> "#" <> int.to_string(id)
    _, _ -> "-"
  }
}

fn option_id_label(value: opt.Option(Int), prefix: String) -> String {
  case value {
    opt.Some(id) -> prefix <> int.to_string(id)
    opt.None -> "-"
  }
}

fn execution_target_label(
  task_id: opt.Option(Int),
  card_id: opt.Option(Int),
) -> String {
  case task_id, card_id {
    opt.Some(id), _ -> "task #" <> int.to_string(id)
    _, opt.Some(id) -> "card #" <> int.to_string(id)
    _, _ -> "-"
  }
}

fn outcome_class_for(outcome: api_rule_metrics.RuleExecutionOutcome) -> String {
  case outcome {
    api_rule_metrics.CreatedExecution -> "outcome-applied"
    api_rule_metrics.IgnoredExecution(_) -> "outcome-suppressed"
    api_rule_metrics.UnknownExecution(_) -> ""
  }
}

fn outcome_text_for(
  config: Config(msg),
  exec: api_rule_metrics.RuleExecution,
) -> String {
  case exec.outcome {
    api_rule_metrics.CreatedExecution -> t(config, i18n_text.OutcomeApplied)
    api_rule_metrics.IgnoredExecution(reason) ->
      t(config, i18n_text.OutcomeSuppressed)
      <> suppression_reason_suffix(reason)
    api_rule_metrics.UnknownExecution(raw) -> raw
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
  config: Config(msg),
  pagination: api_rule_metrics.Pagination,
) -> Element(msg) {
  let current_page = pagination.offset / pagination.limit + 1
  let total_pages =
    { pagination.total + pagination.limit - 1 } / pagination.limit

  case total_pages <= 1 {
    True -> element.none()
    False ->
      div([attribute.class("pagination")], [
        pagination_button(
          label: "<<",
          accessible_label: t(config, i18n_text.FirstPage),
          disabled: pagination.offset == 0,
          on_click: config.on_exec_page_changed(0),
        ),
        pagination_button(
          label: "<",
          accessible_label: t(config, i18n_text.PreviousPage),
          disabled: pagination.offset == 0,
          on_click: config.on_exec_page_changed(int.max(
            0,
            pagination.offset - pagination.limit,
          )),
        ),
        span([attribute.class("page-info")], [
          text(
            int.to_string(current_page) <> " / " <> int.to_string(total_pages),
          ),
        ]),
        pagination_button(
          label: ">",
          accessible_label: t(config, i18n_text.NextPage),
          disabled: pagination.offset + pagination.limit >= pagination.total,
          on_click: config.on_exec_page_changed(
            pagination.offset + pagination.limit,
          ),
        ),
        pagination_button(
          label: ">>",
          accessible_label: t(config, i18n_text.LastPage),
          disabled: pagination.offset + pagination.limit >= pagination.total,
          on_click: config.on_exec_page_changed(
            { total_pages - 1 } * pagination.limit,
          ),
        ),
      ])
  }
}

fn pagination_button(
  label label: String,
  accessible_label accessible_label: String,
  disabled disabled: Bool,
  on_click on_click: msg,
) -> Element(msg) {
  ui_button.text(label, on_click, ui_button.Secondary, ui_button.EntityAction)
  |> ui_button.with_size(ui_button.ExtraSmall)
  |> ui_button.with_disabled(disabled)
  |> ui_button.with_accessible_label(accessible_label)
  |> ui_button.view
}
