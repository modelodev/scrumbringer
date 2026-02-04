//// Admin-specific client state model.

import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/set

import domain/capability.{type Capability}
import domain/card.{type Card, type CardState}
import domain/metrics.{
  type OrgMetricsOverview, type OrgMetricsProjectTasksPayload,
  type OrgMetricsUserOverview,
}
import domain/org.{type InviteLink, type OrgUser}
import domain/project.{type ProjectMember}
import domain/project_role.{type ProjectRole}
import domain/remote.{type Remote}
import domain/task_type.{type TaskType}
import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow,
}

import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/client_state/types as state_types

/// Represents AdminModel.
pub type AdminModel {
  AdminModel(
    invite_links: Remote(List(InviteLink)),
    invite_link_dialog: state_types.DialogState(state_types.InviteLinkForm),
    invite_link_last: Option(InviteLink),
    invite_link_copy_status: Option(String),
    projects_dialog: state_types.DialogState(state_types.ProjectDialogForm),
    capabilities: Remote(List(Capability)),
    capabilities_create_dialog_open: Bool,
    capabilities_create_name: String,
    capabilities_create_in_flight: Bool,
    capabilities_create_error: Option(String),
    capability_delete_dialog_id: Option(Int),
    capability_delete_in_flight: Bool,
    capability_delete_error: Option(String),
    members: Remote(List(ProjectMember)),
    members_project_id: Option(Int),
    org_users_cache: Remote(List(OrgUser)),
    org_settings_users: Remote(List(OrgUser)),
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
    org_settings_save_in_flight: Bool,
    org_settings_error: Option(String),
    org_settings_error_user_id: Option(Int),
    org_settings_delete_confirm: Option(OrgUser),
    org_settings_delete_in_flight: Bool,
    org_settings_delete_error: Option(String),
    members_add_dialog_open: Bool,
    members_add_selected_user: Option(OrgUser),
    members_add_role: ProjectRole,
    members_add_in_flight: Bool,
    members_add_error: Option(String),
    members_remove_confirm: Option(OrgUser),
    members_remove_in_flight: Bool,
    members_remove_error: Option(String),
    members_release_confirm: Option(state_types.ReleaseAllTarget),
    members_release_in_flight: Option(Int),
    members_release_error: Option(String),
    member_capabilities_dialog_user_id: Option(Int),
    member_capabilities_loading: Bool,
    member_capabilities_saving: Bool,
    member_capabilities_cache: Dict(Int, List(Int)),
    member_capabilities_selected: List(Int),
    member_capabilities_error: Option(String),
    capability_members_dialog_capability_id: Option(Int),
    capability_members_loading: Bool,
    capability_members_saving: Bool,
    capability_members_cache: Dict(Int, List(Int)),
    capability_members_selected: List(Int),
    capability_members_error: Option(String),
    org_users_search: state_types.OrgUsersSearchState,
    task_types: Remote(List(TaskType)),
    task_types_project_id: Option(Int),
    task_types_dialog_mode: Option(state_types.TaskTypeDialogMode),
    task_types_create_dialog_open: Bool,
    task_types_create_name: String,
    task_types_create_icon: String,
    task_types_create_icon_search: String,
    task_types_create_icon_category: String,
    task_types_create_capability_id: Option(String),
    task_types_create_in_flight: Bool,
    task_types_create_error: Option(String),
    task_types_icon_preview: state_types.IconPreview,
    cards: Remote(List(Card)),
    cards_project_id: Option(Int),
    cards_dialog_mode: Option(state_types.CardDialogMode),
    cards_show_empty: Bool,
    cards_show_completed: Bool,
    cards_state_filter: Option(CardState),
    cards_search: String,
    workflows_org: Remote(List(Workflow)),
    workflows_project: Remote(List(Workflow)),
    workflows_dialog_mode: Option(state_types.WorkflowDialogMode),
    rules_workflow_id: Option(Int),
    rules: Remote(List(Rule)),
    rules_dialog_mode: Option(state_types.RuleDialogMode),
    rules_templates: Remote(List(RuleTemplate)),
    rules_attach_template_id: Option(Int),
    rules_attach_in_flight: Bool,
    rules_attach_error: Option(String),
    rules_expanded: set.Set(Int),
    attach_template_modal: Option(Int),
    attach_template_selected: Option(Int),
    attach_template_loading: Bool,
    detaching_templates: set.Set(#(Int, Int)),
    rules_metrics: Remote(api_workflows.WorkflowMetrics),
    task_templates_org: Remote(List(TaskTemplate)),
    task_templates_project: Remote(List(TaskTemplate)),
    task_templates_dialog_mode: Option(state_types.TaskTemplateDialogMode),
    assignments: state_types.AssignmentsModel,
  )
}
