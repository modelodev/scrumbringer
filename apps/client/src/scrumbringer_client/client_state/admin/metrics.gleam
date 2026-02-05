//// Metrics admin state.

import gleam/option.{type Option}

import domain/metrics.{
  type OrgMetricsOverview, type OrgMetricsProjectTasksPayload,
  type OrgMetricsUserOverview,
}
import domain/remote.{type Remote, NotAsked}
import scrumbringer_client/api/workflows as api_workflows

/// Represents metrics admin state.
pub type Model {
  Model(
    admin_metrics_overview: Remote(OrgMetricsOverview),
    admin_metrics_project_tasks: Remote(OrgMetricsProjectTasksPayload),
    admin_metrics_project_id: Option(Int),
    admin_metrics_users: Remote(List(OrgMetricsUserOverview)),
    admin_rule_metrics: Remote(List(api_workflows.OrgWorkflowMetricsSummary)),
    admin_rule_metrics_from: String,
    admin_rule_metrics_to: String,
    admin_rule_metrics_expanded_workflow: Option(Int),
    admin_rule_metrics_workflow_details: Remote(api_workflows.WorkflowMetrics),
    admin_rule_metrics_drilldown_rule_id: Option(Int),
    admin_rule_metrics_rule_details: Remote(api_workflows.RuleMetricsDetailed),
    admin_rule_metrics_executions: Remote(api_workflows.RuleExecutionsResponse),
    admin_rule_metrics_exec_offset: Int,
  )
}

/// Provides default metrics admin state.
pub fn default_model() -> Model {
  Model(
    admin_metrics_overview: NotAsked,
    admin_metrics_project_tasks: NotAsked,
    admin_metrics_project_id: option.None,
    admin_metrics_users: NotAsked,
    admin_rule_metrics: NotAsked,
    admin_rule_metrics_from: "",
    admin_rule_metrics_to: "",
    admin_rule_metrics_expanded_workflow: option.None,
    admin_rule_metrics_workflow_details: NotAsked,
    admin_rule_metrics_drilldown_rule_id: option.None,
    admin_rule_metrics_rule_details: NotAsked,
    admin_rule_metrics_executions: NotAsked,
    admin_rule_metrics_exec_offset: 0,
  )
}
