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

import gleam/dict
import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/project.{type ProjectMember, ProjectMember}
import domain/project_role.{type ProjectRole}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state.{
  type Model, type Msg, AdminModel, CapabilityMembersFetched,
  CapabilityMembersSaved, Failed, Loaded, MemberCapabilitiesFetched,
  MemberCapabilitiesSaved, MemberRoleChanged, admin_msg, update_admin,
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

pub const handle_org_settings_save_all_clicked = org_settings.handle_org_settings_save_all_clicked

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
  case model.core.selected_project_id {
    opt.Some(project_id) -> #(
      model,
      api_projects.update_member_role(project_id, user_id, new_role, fn(result) {
        admin_msg(MemberRoleChanged(result))
      }),
    )
    opt.None -> #(model, effect.none())
  }
}

/// Handle role change success - update member in list.
pub fn handle_member_role_changed_ok(
  model: Model,
  result: api_projects.RoleChangeResult,
) -> #(Model, Effect(Msg)) {
  let updated_members = case model.admin.members {
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
  let model =
    update_admin(model, fn(admin) {
      AdminModel(..admin, members: updated_members)
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.RoleUpdated,
    ))
  #(model, toast_fx)
}

/// Handle role change error.
pub fn handle_member_role_changed_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    422 -> #(
      model,
      update_helpers.toast_warning(update_helpers.i18n_t(
        model,
        i18n_text.CannotDemoteLastManager,
      )),
    )
    _ -> #(model, update_helpers.toast_error(err.message))
  }
}

// =============================================================================
// Member Capabilities Handlers (Story 4.7 AC10-14)
// =============================================================================

/// Handle opening the member capabilities dialog.
pub fn handle_member_capabilities_dialog_opened(
  model: Model,
  user_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> {
      // Check if we have cached capabilities for this user
      let selected = case
        dict.get(model.admin.member_capabilities_cache, user_id)
      {
        Ok(ids) -> ids
        Error(_) -> []
      }
      #(
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            member_capabilities_dialog_user_id: opt.Some(user_id),
            member_capabilities_loading: True,
            member_capabilities_selected: selected,
            member_capabilities_error: opt.None,
          )
        }),
        api_projects.get_member_capabilities(project_id, user_id, fn(result) {
          admin_msg(MemberCapabilitiesFetched(result))
        }),
      )
    }
    opt.None -> #(model, effect.none())
  }
}

/// Handle closing the member capabilities dialog.
pub fn handle_member_capabilities_dialog_closed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        member_capabilities_dialog_user_id: opt.None,
        member_capabilities_selected: [],
        member_capabilities_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle toggling a capability checkbox.
pub fn handle_member_capabilities_toggled(
  model: Model,
  capability_id: Int,
) -> #(Model, Effect(Msg)) {
  let selected = case
    list.contains(model.admin.member_capabilities_selected, capability_id)
  {
    True ->
      list.filter(model.admin.member_capabilities_selected, fn(id) {
        id != capability_id
      })
    False -> [capability_id, ..model.admin.member_capabilities_selected]
  }
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, member_capabilities_selected: selected)
    }),
    effect.none(),
  )
}

/// Handle save button click.
pub fn handle_member_capabilities_save_clicked(
  model: Model,
) -> #(Model, Effect(Msg)) {
  case
    model.core.selected_project_id,
    model.admin.member_capabilities_dialog_user_id
  {
    opt.Some(project_id), opt.Some(user_id) -> #(
      update_admin(model, fn(admin) {
        AdminModel(..admin, member_capabilities_saving: True)
      }),
      api_projects.set_member_capabilities(
        project_id,
        user_id,
        model.admin.member_capabilities_selected,
        fn(result) { admin_msg(MemberCapabilitiesSaved(result)) },
      ),
    )
    _, _ -> #(model, effect.none())
  }
}

/// Handle capabilities fetch success.
pub fn handle_member_capabilities_fetched_ok(
  model: Model,
  result: api_projects.MemberCapabilities,
) -> #(Model, Effect(Msg)) {
  // Update cache and selected list
  let cache =
    dict.insert(
      model.admin.member_capabilities_cache,
      result.user_id,
      result.capability_ids,
    )
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        member_capabilities_loading: False,
        member_capabilities_cache: cache,
        member_capabilities_selected: result.capability_ids,
      )
    }),
    effect.none(),
  )
}

/// Handle capabilities fetch error.
pub fn handle_member_capabilities_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          member_capabilities_loading: False,
          member_capabilities_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  }
}

/// Handle capabilities save success.
pub fn handle_member_capabilities_saved_ok(
  model: Model,
  result: api_projects.MemberCapabilities,
) -> #(Model, Effect(Msg)) {
  // Update cache and close dialog
  let cache =
    dict.insert(
      model.admin.member_capabilities_cache,
      result.user_id,
      result.capability_ids,
    )
  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        member_capabilities_saving: False,
        member_capabilities_cache: cache,
        member_capabilities_dialog_user_id: opt.None,
        member_capabilities_selected: [],
      )
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.SkillsSaved,
    ))
  #(model, toast_fx)
}

/// Handle capabilities save error.
pub fn handle_member_capabilities_saved_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          member_capabilities_saving: False,
          member_capabilities_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Capability Members Handlers (Story 4.7 AC16-17)
// =============================================================================

/// Handle opening the capability members dialog.
pub fn handle_capability_members_dialog_opened(
  model: Model,
  capability_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> {
      // Check if we have cached members for this capability
      let selected = case
        dict.get(model.admin.capability_members_cache, capability_id)
      {
        Ok(ids) -> ids
        Error(_) -> []
      }
      #(
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            capability_members_dialog_capability_id: opt.Some(capability_id),
            capability_members_loading: True,
            capability_members_selected: selected,
            capability_members_error: opt.None,
          )
        }),
        api_projects.get_capability_members(
          project_id,
          capability_id,
          fn(result) { admin_msg(CapabilityMembersFetched(result)) },
        ),
      )
    }
    opt.None -> #(model, effect.none())
  }
}

/// Handle closing the capability members dialog.
pub fn handle_capability_members_dialog_closed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        capability_members_dialog_capability_id: opt.None,
        capability_members_selected: [],
        capability_members_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle toggling a member checkbox.
pub fn handle_capability_members_toggled(
  model: Model,
  user_id: Int,
) -> #(Model, Effect(Msg)) {
  let selected = case
    list.contains(model.admin.capability_members_selected, user_id)
  {
    True ->
      list.filter(model.admin.capability_members_selected, fn(id) {
        id != user_id
      })
    False -> [user_id, ..model.admin.capability_members_selected]
  }
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, capability_members_selected: selected)
    }),
    effect.none(),
  )
}

/// Handle save button click.
pub fn handle_capability_members_save_clicked(
  model: Model,
) -> #(Model, Effect(Msg)) {
  case
    model.core.selected_project_id,
    model.admin.capability_members_dialog_capability_id
  {
    opt.Some(project_id), opt.Some(capability_id) -> #(
      update_admin(model, fn(admin) {
        AdminModel(..admin, capability_members_saving: True)
      }),
      api_projects.set_capability_members(
        project_id,
        capability_id,
        model.admin.capability_members_selected,
        fn(result) { admin_msg(CapabilityMembersSaved(result)) },
      ),
    )
    _, _ -> #(model, effect.none())
  }
}

/// Handle capability members fetch success.
pub fn handle_capability_members_fetched_ok(
  model: Model,
  result: api_projects.CapabilityMembers,
) -> #(Model, Effect(Msg)) {
  let cache =
    dict.insert(
      model.admin.capability_members_cache,
      result.capability_id,
      result.user_ids,
    )
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        capability_members_loading: False,
        capability_members_cache: cache,
        capability_members_selected: result.user_ids,
      )
    }),
    effect.none(),
  )
}

/// Handle capability members fetch error.
pub fn handle_capability_members_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          capability_members_loading: False,
          capability_members_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  }
}

/// Handle capability members save success.
pub fn handle_capability_members_saved_ok(
  model: Model,
  result: api_projects.CapabilityMembers,
) -> #(Model, Effect(Msg)) {
  let cache =
    dict.insert(
      model.admin.capability_members_cache,
      result.capability_id,
      result.user_ids,
    )
  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        capability_members_saving: False,
        capability_members_cache: cache,
        capability_members_dialog_capability_id: opt.None,
        capability_members_selected: [],
      )
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.MembersSaved,
    ))
  #(model, toast_fx)
}

/// Handle capability members save error.
pub fn handle_capability_members_saved_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          capability_members_saving: False,
          capability_members_error: opt.Some(err.message),
        )
      }),
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
/// Also preloads capability data for all members to show counts immediately.
pub fn handle_members_fetched_ok(
  model: Model,
  members: List(ProjectMember),
) -> #(Model, Effect(Msg)) {
  // Preload capabilities for all members (AC15 optimization)
  let preload_fx = case model.core.selected_project_id {
    opt.Some(project_id) ->
      members
      |> list.map(fn(m) {
        api_projects.get_member_capabilities(project_id, m.user_id, fn(result) {
          admin_msg(MemberCapabilitiesFetched(result))
        })
      })
      |> effect.batch
    opt.None -> effect.none()
  }

  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, members: Loaded(members))
    }),
    preload_fx,
  )
}

/// Handle members fetch error.
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn handle_members_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> update_helpers.reset_to_login(model)
    False -> #(
      update_admin(model, fn(admin) {
        AdminModel(..admin, members: Failed(err))
      }),
      effect.none(),
    )
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

// Story 4.10: Rule Template Attachment UI Handlers
pub const handle_rule_expand_toggled = workflows.handle_rule_expand_toggled

pub const handle_attach_template_modal_opened = workflows.handle_attach_template_modal_opened

pub const handle_attach_template_modal_closed = workflows.handle_attach_template_modal_closed

pub const handle_attach_template_selected = workflows.handle_attach_template_selected

pub const handle_attach_template_submitted = workflows.handle_attach_template_submitted

pub const handle_attach_template_succeeded = workflows.handle_attach_template_succeeded

pub const handle_attach_template_failed = workflows.handle_attach_template_failed

pub const handle_template_detach_clicked = workflows.handle_template_detach_clicked

pub const handle_template_detach_succeeded = workflows.handle_template_detach_succeeded

pub const handle_template_detach_failed = workflows.handle_template_detach_failed

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

pub const handle_rule_metrics_tab_from_changed_and_refresh = rule_metrics.handle_from_changed_and_refresh

pub const handle_rule_metrics_tab_to_changed_and_refresh = rule_metrics.handle_to_changed_and_refresh

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

pub const handle_user_projects_add_role_changed = user_projects.handle_user_projects_add_role_changed

pub const handle_user_projects_add_submitted = user_projects.handle_user_projects_add_submitted

pub const handle_user_project_added_ok = user_projects.handle_user_project_added_ok

pub const handle_user_project_added_error = user_projects.handle_user_project_added_error

pub const handle_user_project_remove_clicked = user_projects.handle_user_project_remove_clicked

pub const handle_user_project_removed_ok = user_projects.handle_user_project_removed_ok

pub const handle_user_project_removed_error = user_projects.handle_user_project_removed_error

pub const handle_user_project_role_change_requested = user_projects.handle_user_project_role_change_requested

pub const handle_user_project_role_changed_ok = user_projects.handle_user_project_role_changed_ok

pub const handle_user_project_role_changed_error = user_projects.handle_user_project_role_changed_error
