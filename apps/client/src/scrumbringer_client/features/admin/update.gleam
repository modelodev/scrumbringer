//// Admin feature update handlers.
////
//// ## Mission
////
//// Provides unified access to admin-specific flows: org settings, project
//// members management, and org user search.
////
//// ## Responsibilities
////
//// - Re-export handlers from split modules
//// - Handle members fetch results
////
//// ## Non-responsibilities
////
//// - API calls (see `api/*.gleam`)
//// - User permissions checking (see `permissions.gleam`)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches admin messages to handlers here
//// - **org_settings.gleam**: Org settings handlers
//// - **member_add.gleam**: Member add dialog handlers
//// - **member_remove.gleam**: Member remove handlers
//// - **search.gleam**: Org users search handlers

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/project.{type ProjectMember}
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Login, Model,
}

// Re-export from split modules
import scrumbringer_client/features/admin/cards
import scrumbringer_client/features/admin/member_add
import scrumbringer_client/features/admin/member_remove
import scrumbringer_client/features/admin/org_settings
import scrumbringer_client/features/admin/rule_metrics
import scrumbringer_client/features/admin/search
import scrumbringer_client/features/admin/workflows

// =============================================================================
// Re-exports: Org Settings
// =============================================================================

pub const handle_org_users_cache_fetched_ok = org_settings.handle_org_users_cache_fetched_ok

pub const handle_org_users_cache_fetched_error = org_settings.handle_org_users_cache_fetched_error

pub const handle_org_settings_users_fetched_ok = org_settings.handle_org_settings_users_fetched_ok

pub const handle_org_settings_users_fetched_error = org_settings.handle_org_settings_users_fetched_error

pub const handle_org_settings_role_changed = org_settings.handle_org_settings_role_changed

pub const handle_org_settings_save_clicked = org_settings.handle_org_settings_save_clicked

pub const handle_org_settings_saved_ok = org_settings.handle_org_settings_saved_ok

pub const handle_org_settings_saved_error = org_settings.handle_org_settings_saved_error

// =============================================================================
// Re-exports: Member Add
// =============================================================================

pub const handle_member_add_dialog_opened = member_add.handle_member_add_dialog_opened

pub const handle_member_add_dialog_closed = member_add.handle_member_add_dialog_closed

pub const handle_member_add_role_changed = member_add.handle_member_add_role_changed

pub const handle_member_add_user_selected = member_add.handle_member_add_user_selected

pub const handle_member_add_submitted = member_add.handle_member_add_submitted

pub const handle_member_added_ok = member_add.handle_member_added_ok

pub const handle_member_added_error = member_add.handle_member_added_error

// =============================================================================
// Re-exports: Member Remove
// =============================================================================

pub const handle_member_remove_clicked = member_remove.handle_member_remove_clicked

pub const handle_member_remove_cancelled = member_remove.handle_member_remove_cancelled

pub const handle_member_remove_confirmed = member_remove.handle_member_remove_confirmed

pub const handle_member_removed_ok = member_remove.handle_member_removed_ok

pub const handle_member_removed_error = member_remove.handle_member_removed_error

// =============================================================================
// Re-exports: Search
// =============================================================================

pub const handle_org_users_search_changed = search.handle_org_users_search_changed

pub const handle_org_users_search_debounced = search.handle_org_users_search_debounced

pub const handle_org_users_search_results_ok = search.handle_org_users_search_results_ok

pub const handle_org_users_search_results_error = search.handle_org_users_search_results_error

// =============================================================================
// Members Fetched Handlers
// =============================================================================

/// Handle members fetch success.
pub fn handle_members_fetched_ok(
  model: Model,
  members: List(ProjectMember),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, members: Loaded(members)), effect.none())
}

/// Handle members fetch error.
pub fn handle_members_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> #(Model(..model, page: Login, user: opt.None), effect.none())
    False -> #(Model(..model, members: Failed(err)), effect.none())
  }
}

// =============================================================================
// Re-exports: Cards
// =============================================================================

pub const handle_cards_fetched_ok = cards.handle_cards_fetched_ok

pub const handle_cards_fetched_error = cards.handle_cards_fetched_error

pub const handle_card_create_title_changed = cards.handle_card_create_title_changed

pub const handle_card_create_description_changed = cards.handle_card_create_description_changed

pub const handle_card_create_submitted = cards.handle_card_create_submitted

pub const handle_card_created_ok = cards.handle_card_created_ok

pub const handle_card_created_error = cards.handle_card_created_error

pub const handle_card_edit_clicked = cards.handle_card_edit_clicked

pub const handle_card_edit_title_changed = cards.handle_card_edit_title_changed

pub const handle_card_edit_description_changed = cards.handle_card_edit_description_changed

pub const handle_card_edit_submitted = cards.handle_card_edit_submitted

pub const handle_card_edit_cancelled = cards.handle_card_edit_cancelled

pub const handle_card_updated_ok = cards.handle_card_updated_ok

pub const handle_card_updated_error = cards.handle_card_updated_error

pub const handle_card_delete_clicked = cards.handle_card_delete_clicked

pub const handle_card_delete_cancelled = cards.handle_card_delete_cancelled

pub const handle_card_delete_confirmed = cards.handle_card_delete_confirmed

pub const handle_card_deleted_ok = cards.handle_card_deleted_ok

pub const handle_card_deleted_error = cards.handle_card_deleted_error

pub const fetch_cards_for_project = cards.fetch_cards_for_project

// =============================================================================
// Re-exports: Workflows
// =============================================================================

pub const handle_workflows_org_fetched_ok = workflows.handle_workflows_org_fetched_ok

pub const handle_workflows_org_fetched_error = workflows.handle_workflows_org_fetched_error

pub const handle_workflows_project_fetched_ok = workflows.handle_workflows_project_fetched_ok

pub const handle_workflows_project_fetched_error = workflows.handle_workflows_project_fetched_error

pub const handle_workflow_create_name_changed = workflows.handle_workflow_create_name_changed

pub const handle_workflow_create_description_changed = workflows.handle_workflow_create_description_changed

pub const handle_workflow_create_active_changed = workflows.handle_workflow_create_active_changed

pub const handle_workflow_create_submitted = workflows.handle_workflow_create_submitted

pub const handle_workflow_created_ok = workflows.handle_workflow_created_ok

pub const handle_workflow_created_error = workflows.handle_workflow_created_error

pub const handle_workflow_edit_clicked = workflows.handle_workflow_edit_clicked

pub const handle_workflow_edit_name_changed = workflows.handle_workflow_edit_name_changed

pub const handle_workflow_edit_description_changed = workflows.handle_workflow_edit_description_changed

pub const handle_workflow_edit_active_changed = workflows.handle_workflow_edit_active_changed

pub const handle_workflow_edit_submitted = workflows.handle_workflow_edit_submitted

pub const handle_workflow_edit_cancelled = workflows.handle_workflow_edit_cancelled

pub const handle_workflow_updated_ok = workflows.handle_workflow_updated_ok

pub const handle_workflow_updated_error = workflows.handle_workflow_updated_error

pub const handle_workflow_delete_clicked = workflows.handle_workflow_delete_clicked

pub const handle_workflow_delete_cancelled = workflows.handle_workflow_delete_cancelled

pub const handle_workflow_delete_confirmed = workflows.handle_workflow_delete_confirmed

pub const handle_workflow_deleted_ok = workflows.handle_workflow_deleted_ok

pub const handle_workflow_deleted_error = workflows.handle_workflow_deleted_error

pub const handle_workflow_rules_clicked = workflows.handle_workflow_rules_clicked

// =============================================================================
// Re-exports: Rules
// =============================================================================

pub const handle_rules_fetched_ok = workflows.handle_rules_fetched_ok

pub const handle_rules_fetched_error = workflows.handle_rules_fetched_error

pub const handle_rule_metrics_fetched_ok = workflows.handle_rule_metrics_fetched_ok

pub const handle_rule_metrics_fetched_error = workflows.handle_rule_metrics_fetched_error

pub const handle_rules_back_clicked = workflows.handle_rules_back_clicked

pub const handle_rule_create_name_changed = workflows.handle_rule_create_name_changed

pub const handle_rule_create_goal_changed = workflows.handle_rule_create_goal_changed

pub const handle_rule_create_resource_type_changed = workflows.handle_rule_create_resource_type_changed

pub const handle_rule_create_task_type_id_changed = workflows.handle_rule_create_task_type_id_changed

pub const handle_rule_create_to_state_changed = workflows.handle_rule_create_to_state_changed

pub const handle_rule_create_active_changed = workflows.handle_rule_create_active_changed

pub const handle_rule_create_submitted = workflows.handle_rule_create_submitted

pub const handle_rule_created_ok = workflows.handle_rule_created_ok

pub const handle_rule_created_error = workflows.handle_rule_created_error

pub const handle_rule_edit_clicked = workflows.handle_rule_edit_clicked

pub const handle_rule_edit_name_changed = workflows.handle_rule_edit_name_changed

pub const handle_rule_edit_goal_changed = workflows.handle_rule_edit_goal_changed

pub const handle_rule_edit_resource_type_changed = workflows.handle_rule_edit_resource_type_changed

pub const handle_rule_edit_task_type_id_changed = workflows.handle_rule_edit_task_type_id_changed

pub const handle_rule_edit_to_state_changed = workflows.handle_rule_edit_to_state_changed

pub const handle_rule_edit_active_changed = workflows.handle_rule_edit_active_changed

pub const handle_rule_edit_submitted = workflows.handle_rule_edit_submitted

pub const handle_rule_edit_cancelled = workflows.handle_rule_edit_cancelled

pub const handle_rule_updated_ok = workflows.handle_rule_updated_ok

pub const handle_rule_updated_error = workflows.handle_rule_updated_error

pub const handle_rule_delete_clicked = workflows.handle_rule_delete_clicked

pub const handle_rule_delete_cancelled = workflows.handle_rule_delete_cancelled

pub const handle_rule_delete_confirmed = workflows.handle_rule_delete_confirmed

pub const handle_rule_deleted_ok = workflows.handle_rule_deleted_ok

pub const handle_rule_deleted_error = workflows.handle_rule_deleted_error

// =============================================================================
// Re-exports: Rule Templates
// =============================================================================

pub const handle_rule_templates_fetched_ok = workflows.handle_rule_templates_fetched_ok

pub const handle_rule_templates_fetched_error = workflows.handle_rule_templates_fetched_error

pub const handle_rule_attach_template_selected = workflows.handle_rule_attach_template_selected

pub const handle_rule_attach_template_submitted = workflows.handle_rule_attach_template_submitted

pub const handle_rule_template_attached_ok = workflows.handle_rule_template_attached_ok

pub const handle_rule_template_attached_error = workflows.handle_rule_template_attached_error

pub const handle_rule_template_detach_clicked = workflows.handle_rule_template_detach_clicked

pub const handle_rule_template_detached_ok = workflows.handle_rule_template_detached_ok

pub const handle_rule_template_detached_error = workflows.handle_rule_template_detached_error

// =============================================================================
// Re-exports: Task Templates
// =============================================================================

pub const handle_task_templates_org_fetched_ok = workflows.handle_task_templates_org_fetched_ok

pub const handle_task_templates_org_fetched_error = workflows.handle_task_templates_org_fetched_error

pub const handle_task_templates_project_fetched_ok = workflows.handle_task_templates_project_fetched_ok

pub const handle_task_templates_project_fetched_error = workflows.handle_task_templates_project_fetched_error

pub const handle_task_template_create_name_changed = workflows.handle_task_template_create_name_changed

pub const handle_task_template_create_description_changed = workflows.handle_task_template_create_description_changed

pub const handle_task_template_create_type_id_changed = workflows.handle_task_template_create_type_id_changed

pub const handle_task_template_create_priority_changed = workflows.handle_task_template_create_priority_changed

pub const handle_task_template_create_submitted = workflows.handle_task_template_create_submitted

pub const handle_task_template_created_ok = workflows.handle_task_template_created_ok

pub const handle_task_template_created_error = workflows.handle_task_template_created_error

pub const handle_task_template_edit_clicked = workflows.handle_task_template_edit_clicked

pub const handle_task_template_edit_name_changed = workflows.handle_task_template_edit_name_changed

pub const handle_task_template_edit_description_changed = workflows.handle_task_template_edit_description_changed

pub const handle_task_template_edit_type_id_changed = workflows.handle_task_template_edit_type_id_changed

pub const handle_task_template_edit_priority_changed = workflows.handle_task_template_edit_priority_changed

pub const handle_task_template_edit_submitted = workflows.handle_task_template_edit_submitted

pub const handle_task_template_edit_cancelled = workflows.handle_task_template_edit_cancelled

pub const handle_task_template_updated_ok = workflows.handle_task_template_updated_ok

pub const handle_task_template_updated_error = workflows.handle_task_template_updated_error

pub const handle_task_template_delete_clicked = workflows.handle_task_template_delete_clicked

pub const handle_task_template_delete_cancelled = workflows.handle_task_template_delete_cancelled

pub const handle_task_template_delete_confirmed = workflows.handle_task_template_delete_confirmed

pub const handle_task_template_deleted_ok = workflows.handle_task_template_deleted_ok

pub const handle_task_template_deleted_error = workflows.handle_task_template_deleted_error

// =============================================================================
// Fetch Helpers
// =============================================================================

pub const fetch_workflows = workflows.fetch_workflows

pub const fetch_task_templates = workflows.fetch_task_templates

// =============================================================================
// Re-exports: Rule Metrics Tab
// =============================================================================

pub const handle_rule_metrics_tab_from_changed = rule_metrics.handle_from_changed

pub const handle_rule_metrics_tab_to_changed = rule_metrics.handle_to_changed

pub const handle_rule_metrics_tab_refresh_clicked = rule_metrics.handle_refresh_clicked

pub const handle_rule_metrics_tab_fetched_ok = rule_metrics.handle_fetched_ok

pub const handle_rule_metrics_tab_fetched_error = rule_metrics.handle_fetched_error

// Rule metrics drill-down
pub const handle_rule_metrics_workflow_expanded = rule_metrics.handle_workflow_expanded

pub const handle_rule_metrics_workflow_details_fetched_ok = rule_metrics.handle_workflow_details_fetched_ok

pub const handle_rule_metrics_workflow_details_fetched_error = rule_metrics.handle_workflow_details_fetched_error

pub const handle_rule_metrics_drilldown_clicked = rule_metrics.handle_drilldown_clicked

pub const handle_rule_metrics_drilldown_closed = rule_metrics.handle_drilldown_closed

pub const handle_rule_metrics_rule_details_fetched_ok = rule_metrics.handle_rule_details_fetched_ok

pub const handle_rule_metrics_rule_details_fetched_error = rule_metrics.handle_rule_details_fetched_error

pub const handle_rule_metrics_executions_fetched_ok = rule_metrics.handle_executions_fetched_ok

pub const handle_rule_metrics_executions_fetched_error = rule_metrics.handle_executions_fetched_error

pub const handle_rule_metrics_exec_page_changed = rule_metrics.handle_exec_page_changed
