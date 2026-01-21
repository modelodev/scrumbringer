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

import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/project.{type ProjectMember, ProjectMember}
import domain/project_role.{type ProjectRole}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Login, MemberRoleChanged, Model,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// Re-export from split modules
import scrumbringer_client/features/admin/cards
import scrumbringer_client/features/admin/member_add
import scrumbringer_client/features/admin/member_remove
import scrumbringer_client/features/admin/org_settings
import scrumbringer_client/features/admin/rule_metrics
import scrumbringer_client/features/admin/search
import scrumbringer_client/features/admin/user_projects
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
// Member Role Change Handlers
// =============================================================================

/// Handle role change request - call the API.
pub fn handle_member_role_change_requested(
  model: Model,
  user_id: Int,
  new_role: ProjectRole,
) -> #(Model, Effect(Msg)) {
  case model.selected_project_id {
    opt.Some(project_id) -> #(
      model,
      api_projects.update_member_role(
        project_id,
        user_id,
        new_role,
        MemberRoleChanged,
      ),
    )
    opt.None -> #(model, effect.none())
  }
}

/// Handle role change success - update member in list.
pub fn handle_member_role_changed_ok(
  model: Model,
  result: api_projects.RoleChangeResult,
) -> #(Model, Effect(Msg)) {
  let updated_members = case model.members {
    Loaded(members) ->
      Loaded(
        list.map(members, fn(m) {
          case m.user_id == result.user_id {
            True -> ProjectMember(..m, role: result.role)
            False -> m
          }
        }),
      )
    other -> other
  }
  #(
    Model(
      ..model,
      members: updated_members,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.RoleUpdated)),
    ),
    effect.none(),
  )
}

/// Handle role change error.
pub fn handle_member_role_changed_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    422 -> #(
      Model(
        ..model,
        toast: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.CannotDemoteLastManager,
        )),
      ),
      effect.none(),
    )
    _ -> #(
      Model(..model, toast: opt.Some(err.message)),
      effect.none(),
    )
  }
}

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
// Re-exports: Cards (component pattern - minimal handlers)
// =============================================================================

pub const handle_cards_fetched_ok = cards.handle_cards_fetched_ok

pub const handle_cards_fetched_error = cards.handle_cards_fetched_error

pub const handle_open_card_dialog = cards.handle_open_card_dialog

pub const handle_close_card_dialog = cards.handle_close_card_dialog

pub const handle_card_crud_created = cards.handle_card_crud_created

pub const handle_card_crud_updated = cards.handle_card_crud_updated

pub const handle_card_crud_deleted = cards.handle_card_crud_deleted

pub const fetch_cards_for_project = cards.fetch_cards_for_project

// =============================================================================
// Re-exports: Workflows
// =============================================================================

pub const handle_workflows_project_fetched_ok = workflows.handle_workflows_project_fetched_ok

pub const handle_workflows_project_fetched_error = workflows.handle_workflows_project_fetched_error

pub const handle_open_workflow_dialog = workflows.handle_open_workflow_dialog

pub const handle_close_workflow_dialog = workflows.handle_close_workflow_dialog

pub const handle_workflow_crud_created = workflows.handle_workflow_crud_created

pub const handle_workflow_crud_updated = workflows.handle_workflow_crud_updated

pub const handle_workflow_crud_deleted = workflows.handle_workflow_crud_deleted

pub const handle_workflow_rules_clicked = workflows.handle_workflow_rules_clicked

// =============================================================================
// Re-exports: Rules
// =============================================================================

pub const handle_rules_fetched_ok = workflows.handle_rules_fetched_ok

pub const handle_rules_fetched_error = workflows.handle_rules_fetched_error

pub const handle_rule_metrics_fetched_ok = workflows.handle_rule_metrics_fetched_ok

pub const handle_rule_metrics_fetched_error = workflows.handle_rule_metrics_fetched_error

pub const handle_rules_back_clicked = workflows.handle_rules_back_clicked

// Rule Component Event Handlers

pub const handle_open_rule_dialog = workflows.handle_open_rule_dialog

pub const handle_close_rule_dialog = workflows.handle_close_rule_dialog

pub const handle_rule_crud_created = workflows.handle_rule_crud_created

pub const handle_rule_crud_updated = workflows.handle_rule_crud_updated

pub const handle_rule_crud_deleted = workflows.handle_rule_crud_deleted

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

pub const handle_task_templates_project_fetched_ok = workflows.handle_task_templates_project_fetched_ok

pub const handle_task_templates_project_fetched_error = workflows.handle_task_templates_project_fetched_error

// Task Template Component Event Handlers

pub const handle_open_task_template_dialog = workflows.handle_open_task_template_dialog

pub const handle_close_task_template_dialog = workflows.handle_close_task_template_dialog

pub const handle_task_template_crud_created = workflows.handle_task_template_crud_created

pub const handle_task_template_crud_updated = workflows.handle_task_template_crud_updated

pub const handle_task_template_crud_deleted = workflows.handle_task_template_crud_deleted

// =============================================================================
// Fetch Helpers
// =============================================================================

pub const fetch_workflows = workflows.fetch_workflows

pub const fetch_task_templates = workflows.fetch_task_templates

// =============================================================================
// Re-exports: Rule Metrics Tab
// =============================================================================

pub const handle_rule_metrics_tab_init = rule_metrics.init_tab

pub const handle_rule_metrics_tab_from_changed = rule_metrics.handle_from_changed

pub const handle_rule_metrics_tab_to_changed = rule_metrics.handle_to_changed

pub const handle_rule_metrics_tab_refresh_clicked = rule_metrics.handle_refresh_clicked

pub const handle_rule_metrics_tab_quick_range_clicked = rule_metrics.handle_quick_range_clicked

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

// =============================================================================
// Re-exports: User Projects
// =============================================================================

pub const handle_user_projects_dialog_opened = user_projects.handle_user_projects_dialog_opened

pub const handle_user_projects_dialog_closed = user_projects.handle_user_projects_dialog_closed

pub const handle_user_projects_fetched_ok = user_projects.handle_user_projects_fetched_ok

pub const handle_user_projects_fetched_error = user_projects.handle_user_projects_fetched_error

pub const handle_user_projects_add_project_changed = user_projects.handle_user_projects_add_project_changed

pub const handle_user_projects_add_submitted = user_projects.handle_user_projects_add_submitted

pub const handle_user_project_added_ok = user_projects.handle_user_project_added_ok

pub const handle_user_project_added_error = user_projects.handle_user_project_added_error

pub const handle_user_project_remove_clicked = user_projects.handle_user_project_remove_clicked

pub const handle_user_project_removed_ok = user_projects.handle_user_project_removed_ok

pub const handle_user_project_removed_error = user_projects.handle_user_project_removed_error
