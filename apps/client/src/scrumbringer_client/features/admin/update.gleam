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

import lustre/effect

import domain/api_error.{type ApiError}
import domain/project.{type ProjectMember, ProjectMember}
import domain/project_role.{type ProjectRole, Member as MemberRole, parse}
import domain/remote.{Failed, Loaded}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/assignments/update as assignments_workflow
import scrumbringer_client/features/capabilities/update as capabilities_workflow
import scrumbringer_client/features/invites/update as invite_links_workflow
import scrumbringer_client/features/projects/update as projects_workflow
import scrumbringer_client/features/task_types/update as task_types_workflow
import scrumbringer_client/i18n/text as i18n_text

// Re-export from split modules
import scrumbringer_client/features/admin/cards
import scrumbringer_client/features/admin/member_add
import scrumbringer_client/features/admin/member_release_all
import scrumbringer_client/features/admin/member_remove
import scrumbringer_client/features/admin/org_settings
import scrumbringer_client/features/admin/rule_metrics
import scrumbringer_client/features/admin/search
import scrumbringer_client/features/admin/workflows
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/selection as helpers_selection
import scrumbringer_client/helpers/toast as helpers_toast

// =============================================================================
// Re-exports: Org Settings
// =============================================================================

pub const handle_org_users_cache_fetched_ok = org_settings.handle_org_users_cache_fetched_ok

pub const handle_org_users_cache_fetched_error = org_settings.handle_org_users_cache_fetched_error

pub const handle_org_settings_users_fetched_ok = org_settings.handle_org_settings_users_fetched_ok

pub const handle_org_settings_users_fetched_error = org_settings.handle_org_settings_users_fetched_error

pub const handle_org_settings_role_changed = org_settings.handle_org_settings_role_changed

pub const handle_org_settings_saved_ok = org_settings.handle_org_settings_saved_ok

pub const handle_org_settings_saved_error = org_settings.handle_org_settings_saved_error

pub const handle_org_settings_delete_clicked = org_settings.handle_org_settings_delete_clicked

pub const handle_org_settings_delete_cancelled = org_settings.handle_org_settings_delete_cancelled

pub const handle_org_settings_delete_confirmed = org_settings.handle_org_settings_delete_confirmed

pub const handle_org_settings_deleted_ok = org_settings.handle_org_settings_deleted_ok

pub const handle_org_settings_deleted_error = org_settings.handle_org_settings_deleted_error

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
// Re-exports: Member Release All
// =============================================================================

pub const handle_member_release_all_clicked = member_release_all.handle_member_release_all_clicked

pub const handle_member_release_all_cancelled = member_release_all.handle_member_release_all_cancelled

pub const handle_member_release_all_confirmed = member_release_all.handle_member_release_all_confirmed

pub const handle_member_release_all_ok = member_release_all.handle_member_release_all_ok

pub const handle_member_release_all_error = member_release_all.handle_member_release_all_error

// =============================================================================
// Member Role Change Handlers
// =============================================================================

/// Handle role change request - call the API.
pub fn handle_member_role_change_requested(
  model: client_state.Model,
  user_id: Int,
  new_role: ProjectRole,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> #(
      model,
      api_projects.update_member_role(project_id, user_id, new_role, fn(result) {
        client_state.admin_msg(admin_messages.MemberRoleChanged(result))
      }),
    )
    opt.None -> #(model, effect.none())
  }
}

/// Handle role change success - update member in list.
pub fn handle_member_role_changed_ok(
  model: client_state.Model,
  result: api_projects.RoleChangeResult,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let updated_members = case model.admin.members.members {
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
    client_state.update_admin(model, fn(admin) {
      update_members(admin, fn(members_state) {
        admin_members.Model(..members_state, members: updated_members)
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.RoleUpdated,
    ))
  #(model, toast_fx)
}

/// Handle role change error.
pub fn handle_member_role_changed_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    case err.status {
      422 -> #(
        model,
        helpers_toast.toast_warning(helpers_i18n.i18n_t(
          model,
          i18n_text.CannotDemoteLastManager,
        )),
      )
      _ -> #(model, helpers_toast.toast_error(err.message))
    }
  })
}

// =============================================================================
// Member Capabilities Handlers (Story 4.7 AC10-14)
// =============================================================================

/// Handle opening the member capabilities dialog.
pub fn handle_member_capabilities_dialog_opened(
  model: client_state.Model,
  user_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> {
      // Check if we have cached capabilities for this user
      let selected = case
        dict.get(model.admin.capabilities.member_capabilities_cache, user_id)
      {
        Ok(ids) -> ids
        Error(_) -> []
      }
      #(
        client_state.update_admin(model, fn(admin) {
          update_capabilities(admin, fn(capabilities_state) {
            admin_capabilities.Model(
              ..capabilities_state,
              member_capabilities_dialog_user_id: opt.Some(user_id),
              member_capabilities_loading: True,
              member_capabilities_selected: selected,
              member_capabilities_error: opt.None,
            )
          })
        }),
        api_projects.get_member_capabilities(project_id, user_id, fn(result) {
          client_state.admin_msg(admin_messages.MemberCapabilitiesFetched(
            result,
          ))
        }),
      )
    }
    opt.None -> #(model, effect.none())
  }
}

/// Handle closing the member capabilities dialog.
pub fn handle_member_capabilities_dialog_closed(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    client_state.update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          member_capabilities_dialog_user_id: opt.None,
          member_capabilities_selected: [],
          member_capabilities_error: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle toggling a capability checkbox.
pub fn handle_member_capabilities_toggled(
  model: client_state.Model,
  capability_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let selected = case
    list.contains(
      model.admin.capabilities.member_capabilities_selected,
      capability_id,
    )
  {
    True ->
      list.filter(model.admin.capabilities.member_capabilities_selected, fn(id) {
        id != capability_id
      })
    False -> [
      capability_id,
      ..model.admin.capabilities.member_capabilities_selected
    ]
  }
  #(
    client_state.update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          member_capabilities_selected: selected,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle save button click.
pub fn handle_member_capabilities_save_clicked(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    model.core.selected_project_id,
    model.admin.capabilities.member_capabilities_dialog_user_id
  {
    opt.Some(project_id), opt.Some(user_id) -> #(
      client_state.update_admin(model, fn(admin) {
        update_capabilities(admin, fn(capabilities_state) {
          admin_capabilities.Model(
            ..capabilities_state,
            member_capabilities_saving: True,
          )
        })
      }),
      api_projects.set_member_capabilities(
        project_id,
        user_id,
        model.admin.capabilities.member_capabilities_selected,
        fn(result) {
          client_state.admin_msg(admin_messages.MemberCapabilitiesSaved(result))
        },
      ),
    )
    _, _ -> #(model, effect.none())
  }
}

/// Handle capabilities fetch success.
pub fn handle_member_capabilities_fetched_ok(
  model: client_state.Model,
  result: api_projects.MemberCapabilities,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  // Update cache and selected list
  let cache =
    dict.insert(
      model.admin.capabilities.member_capabilities_cache,
      result.user_id,
      result.capability_ids,
    )
  #(
    client_state.update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          member_capabilities_loading: False,
          member_capabilities_cache: cache,
          member_capabilities_selected: result.capability_ids,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle capabilities fetch error.
pub fn handle_member_capabilities_fetched_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_capabilities(admin, fn(capabilities_state) {
          admin_capabilities.Model(
            ..capabilities_state,
            member_capabilities_loading: False,
            member_capabilities_error: opt.Some(err.message),
          )
        })
      }),
      effect.none(),
    )
  })
}

/// Handle capabilities save success.
pub fn handle_member_capabilities_saved_ok(
  model: client_state.Model,
  result: api_projects.MemberCapabilities,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  // Update cache and close dialog
  let cache =
    dict.insert(
      model.admin.capabilities.member_capabilities_cache,
      result.user_id,
      result.capability_ids,
    )
  let model =
    client_state.update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          member_capabilities_saving: False,
          member_capabilities_cache: cache,
          member_capabilities_dialog_user_id: opt.None,
          member_capabilities_selected: [],
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.SkillsSaved,
    ))
  #(model, toast_fx)
}

/// Handle capabilities save error.
pub fn handle_member_capabilities_saved_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_capabilities(admin, fn(capabilities_state) {
          admin_capabilities.Model(
            ..capabilities_state,
            member_capabilities_saving: False,
            member_capabilities_error: opt.Some(err.message),
          )
        })
      }),
      effect.none(),
    )
  })
}

// =============================================================================
// Capability Members Handlers (Story 4.7 AC16-17)
// =============================================================================

/// Handle opening the capability members dialog.
pub fn handle_capability_members_dialog_opened(
  model: client_state.Model,
  capability_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> {
      // Check if we have cached members for this capability
      let selected = case
        dict.get(
          model.admin.capabilities.capability_members_cache,
          capability_id,
        )
      {
        Ok(ids) -> ids
        Error(_) -> []
      }
      #(
        client_state.update_admin(model, fn(admin) {
          update_capabilities(admin, fn(capabilities_state) {
            admin_capabilities.Model(
              ..capabilities_state,
              capability_members_dialog_capability_id: opt.Some(capability_id),
              capability_members_loading: True,
              capability_members_selected: selected,
              capability_members_error: opt.None,
            )
          })
        }),
        api_projects.get_capability_members(
          project_id,
          capability_id,
          fn(result) {
            client_state.admin_msg(admin_messages.CapabilityMembersFetched(
              result,
            ))
          },
        ),
      )
    }
    opt.None -> #(model, effect.none())
  }
}

/// Handle closing the capability members dialog.
pub fn handle_capability_members_dialog_closed(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    client_state.update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capability_members_dialog_capability_id: opt.None,
          capability_members_selected: [],
          capability_members_error: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle toggling a member checkbox.
pub fn handle_capability_members_toggled(
  model: client_state.Model,
  user_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let selected = case
    list.contains(model.admin.capabilities.capability_members_selected, user_id)
  {
    True ->
      list.filter(model.admin.capabilities.capability_members_selected, fn(id) {
        id != user_id
      })
    False -> [user_id, ..model.admin.capabilities.capability_members_selected]
  }
  #(
    client_state.update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capability_members_selected: selected,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle save button click.
pub fn handle_capability_members_save_clicked(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    model.core.selected_project_id,
    model.admin.capabilities.capability_members_dialog_capability_id
  {
    opt.Some(project_id), opt.Some(capability_id) -> #(
      client_state.update_admin(model, fn(admin) {
        update_capabilities(admin, fn(capabilities_state) {
          admin_capabilities.Model(
            ..capabilities_state,
            capability_members_saving: True,
          )
        })
      }),
      api_projects.set_capability_members(
        project_id,
        capability_id,
        model.admin.capabilities.capability_members_selected,
        fn(result) {
          client_state.admin_msg(admin_messages.CapabilityMembersSaved(result))
        },
      ),
    )
    _, _ -> #(model, effect.none())
  }
}

/// Handle capability members fetch success.
pub fn handle_capability_members_fetched_ok(
  model: client_state.Model,
  result: api_projects.CapabilityMembers,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let cache =
    dict.insert(
      model.admin.capabilities.capability_members_cache,
      result.capability_id,
      result.user_ids,
    )
  #(
    client_state.update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capability_members_loading: False,
          capability_members_cache: cache,
          capability_members_selected: result.user_ids,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle capability members fetch error.
pub fn handle_capability_members_fetched_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_capabilities(admin, fn(capabilities_state) {
          admin_capabilities.Model(
            ..capabilities_state,
            capability_members_loading: False,
            capability_members_error: opt.Some(err.message),
          )
        })
      }),
      effect.none(),
    )
  })
}

/// Handle capability members save success.
pub fn handle_capability_members_saved_ok(
  model: client_state.Model,
  result: api_projects.CapabilityMembers,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let cache =
    dict.insert(
      model.admin.capabilities.capability_members_cache,
      result.capability_id,
      result.user_ids,
    )
  let model =
    client_state.update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capability_members_saving: False,
          capability_members_cache: cache,
          capability_members_dialog_capability_id: opt.None,
          capability_members_selected: [],
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.MembersSaved,
    ))
  #(model, toast_fx)
}

/// Handle capability members save error.
pub fn handle_capability_members_saved_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_capabilities(admin, fn(capabilities_state) {
          admin_capabilities.Model(
            ..capabilities_state,
            capability_members_saving: False,
            capability_members_error: opt.Some(err.message),
          )
        })
      }),
      effect.none(),
    )
  })
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
  model: client_state.Model,
  members: List(ProjectMember),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  // Preload capabilities for all members (AC15 optimization)
  let preload_fx = case model.core.selected_project_id {
    opt.Some(project_id) ->
      members
      |> list.map(fn(m) {
        api_projects.get_member_capabilities(project_id, m.user_id, fn(result) {
          client_state.admin_msg(admin_messages.MemberCapabilitiesFetched(
            result,
          ))
        })
      })
      |> effect.batch
    opt.None -> effect.none()
  }

  #(
    client_state.update_admin(model, fn(admin) {
      update_members(admin, fn(members_state) {
        admin_members.Model(..members_state, members: Loaded(members))
      })
    }),
    preload_fx,
  )
}

/// Handle members fetch error.
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn handle_members_fetched_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_members(admin, fn(members_state) {
          admin_members.Model(..members_state, members: Failed(err))
        })
      }),
      effect.none(),
    )
  })
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
// Dispatch
// =============================================================================

/// Provides admin update context.
pub type Context {
  Context(
    member_refresh: fn(client_state.Model) ->
      #(client_state.Model, effect.Effect(client_state.Msg)),
    refresh_section_for_test: fn(client_state.Model) ->
      #(client_state.Model, effect.Effect(client_state.Msg)),
    hydrate_model: fn(client_state.Model) ->
      #(client_state.Model, effect.Effect(client_state.Msg)),
    replace_url: fn(client_state.Model) -> effect.Effect(client_state.Msg),
  )
}

/// Dispatch admin messages to feature handlers.
///
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn update(
  model: client_state.Model,
  inner: admin_messages.Msg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let Context(
    member_refresh: member_refresh,
    refresh_section_for_test: refresh_section_for_test,
    hydrate_model: hydrate_model,
    replace_url: replace_url,
  ) = ctx

  case inner {
    admin_messages.ProjectsFetched(Ok(projects)) -> {
      let selected =
        helpers_selection.ensure_selected_project(
          model.core.selected_project_id,
          projects,
        )
      let model =
        client_state.update_core(model, fn(core) {
          client_state.CoreModel(
            ..core,
            projects: Loaded(projects),
            selected_project_id: selected,
          )
        })

      let model = helpers_selection.ensure_default_section(model)

      case model.core.page {
        client_state.Member -> {
          let #(model, fx) = member_refresh(model)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([fx, hyd_fx, replace_url(model)]))
        }

        client_state.Admin -> {
          let #(model, fx) = refresh_section_for_test(model)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([fx, hyd_fx, replace_url(model)]))
        }

        _ -> {
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([hyd_fx, replace_url(model)]))
        }
      }
    }

    admin_messages.ProjectsFetched(Error(err)) -> {
      case err.status == 401 {
        True -> {
          let model =
            client_state.update_member(
              client_state.update_core(model, fn(core) {
                client_state.CoreModel(
                  ..core,
                  page: client_state.Login,
                  user: opt.None,
                )
              }),
              fn(member) {
                let pool = member.pool
                member_state.MemberModel(
                  ..member,
                  pool: member_pool.Model(
                    ..pool,
                    member_drag: state_types.DragIdle,
                    member_pool_drag: state_types.PoolDragIdle,
                  ),
                )
              },
            )
          #(model, replace_url(model))
        }

        False -> #(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(..core, projects: Failed(err))
          }),
          effect.none(),
        )
      }
    }

    admin_messages.ProjectCreateDialogOpened ->
      projects_workflow.handle_project_create_dialog_opened(model)
    admin_messages.ProjectCreateDialogClosed ->
      projects_workflow.handle_project_create_dialog_closed(model)
    admin_messages.ProjectCreateNameChanged(name) ->
      projects_workflow.handle_project_create_name_changed(model, name)
    admin_messages.ProjectCreateSubmitted ->
      projects_workflow.handle_project_create_submitted(model)
    admin_messages.ProjectCreated(Ok(project)) ->
      projects_workflow.handle_project_created_ok(model, project)
    admin_messages.ProjectCreated(Error(err)) ->
      projects_workflow.handle_project_created_error(model, err)
    // Project Edit (Story 4.8 AC39)
    admin_messages.ProjectEditDialogOpened(project_id, project_name) ->
      projects_workflow.handle_project_edit_dialog_opened(
        model,
        project_id,
        project_name,
      )
    admin_messages.ProjectEditDialogClosed ->
      projects_workflow.handle_project_edit_dialog_closed(model)
    admin_messages.ProjectEditNameChanged(name) ->
      projects_workflow.handle_project_edit_name_changed(model, name)
    admin_messages.ProjectEditSubmitted ->
      projects_workflow.handle_project_edit_submitted(model)
    admin_messages.ProjectUpdated(Ok(project)) ->
      projects_workflow.handle_project_updated_ok(model, project)
    admin_messages.ProjectUpdated(Error(err)) ->
      projects_workflow.handle_project_updated_error(model, err)
    // Project Delete (Story 4.8 AC39)
    admin_messages.ProjectDeleteConfirmOpened(project_id, project_name) ->
      projects_workflow.handle_project_delete_confirm_opened(
        model,
        project_id,
        project_name,
      )
    admin_messages.ProjectDeleteConfirmClosed ->
      projects_workflow.handle_project_delete_confirm_closed(model)
    admin_messages.ProjectDeleteSubmitted ->
      projects_workflow.handle_project_delete_submitted(model)
    admin_messages.ProjectDeleted(Ok(_)) ->
      projects_workflow.handle_project_deleted_ok(model)
    admin_messages.ProjectDeleted(Error(err)) ->
      projects_workflow.handle_project_deleted_error(model, err)

    admin_messages.InviteCreateDialogOpened ->
      invite_links_workflow.handle_invite_create_dialog_opened(model)
    admin_messages.InviteCreateDialogClosed ->
      invite_links_workflow.handle_invite_create_dialog_closed(model)
    admin_messages.InviteLinkEmailChanged(value) ->
      invite_links_workflow.handle_invite_link_email_changed(model, value)
    admin_messages.InviteLinksFetched(Ok(links)) ->
      invite_links_workflow.handle_invite_links_fetched_ok(model, links)
    admin_messages.InviteLinksFetched(Error(err)) ->
      invite_links_workflow.handle_invite_links_fetched_error(model, err)
    admin_messages.InviteLinkCreateSubmitted ->
      invite_links_workflow.handle_invite_link_create_submitted(model)
    admin_messages.InviteLinkRegenerateClicked(email) ->
      invite_links_workflow.handle_invite_link_regenerate_clicked(model, email)
    admin_messages.InviteLinkCreated(Ok(link)) ->
      invite_links_workflow.handle_invite_link_created_ok(model, link)
    admin_messages.InviteLinkCreated(Error(err)) ->
      invite_links_workflow.handle_invite_link_created_error(model, err)
    admin_messages.InviteLinkRegenerated(Ok(link)) ->
      invite_links_workflow.handle_invite_link_regenerated_ok(model, link)
    admin_messages.InviteLinkRegenerated(Error(err)) ->
      invite_links_workflow.handle_invite_link_regenerated_error(model, err)
    admin_messages.InviteLinkCopyClicked(text) ->
      invite_links_workflow.handle_invite_link_copy_clicked(model, text)
    admin_messages.InviteLinkCopyFinished(ok) ->
      invite_links_workflow.handle_invite_link_copy_finished(model, ok)

    admin_messages.CapabilitiesFetched(Ok(capabilities)) ->
      capabilities_workflow.handle_capabilities_fetched_ok(model, capabilities)
    admin_messages.CapabilitiesFetched(Error(err)) ->
      capabilities_workflow.handle_capabilities_fetched_error(model, err)
    admin_messages.CapabilityCreateDialogOpened ->
      capabilities_workflow.handle_capability_dialog_opened(model)
    admin_messages.CapabilityCreateDialogClosed ->
      capabilities_workflow.handle_capability_dialog_closed(model)
    admin_messages.CapabilityCreateNameChanged(name) ->
      capabilities_workflow.handle_capability_create_name_changed(model, name)
    admin_messages.CapabilityCreateSubmitted ->
      capabilities_workflow.handle_capability_create_submitted(model)
    admin_messages.CapabilityCreated(Ok(capability)) ->
      capabilities_workflow.handle_capability_created_ok(model, capability)
    admin_messages.CapabilityCreated(Error(err)) ->
      capabilities_workflow.handle_capability_created_error(model, err)
    // Capability delete (Story 4.9 AC9)
    admin_messages.CapabilityDeleteDialogOpened(capability_id) ->
      capabilities_workflow.handle_capability_delete_dialog_opened(
        model,
        capability_id,
      )
    admin_messages.CapabilityDeleteDialogClosed ->
      capabilities_workflow.handle_capability_delete_dialog_closed(model)
    admin_messages.CapabilityDeleteSubmitted ->
      capabilities_workflow.handle_capability_delete_submitted(model)
    admin_messages.CapabilityDeleted(Ok(deleted_id)) ->
      capabilities_workflow.handle_capability_deleted_ok(model, deleted_id)
    admin_messages.CapabilityDeleted(Error(err)) ->
      capabilities_workflow.handle_capability_deleted_error(model, err)

    admin_messages.MembersFetched(Ok(members)) ->
      handle_members_fetched_ok(model, members)
    admin_messages.MembersFetched(Error(err)) ->
      handle_members_fetched_error(model, err)

    admin_messages.OrgUsersCacheFetched(Ok(users)) -> {
      let #(model, fx) = handle_org_users_cache_fetched_ok(model, users)
      let #(model, assignments_fx) =
        assignments_workflow.start_user_projects_fetch(model, users)
      #(model, effect.batch([fx, assignments_fx]))
    }
    admin_messages.OrgUsersCacheFetched(Error(err)) ->
      handle_org_users_cache_fetched_error(model, err)
    admin_messages.OrgSettingsUsersFetched(Ok(users)) ->
      handle_org_settings_users_fetched_ok(model, users)

    admin_messages.OrgSettingsUsersFetched(Error(err)) ->
      handle_org_settings_users_fetched_error(model, err)
    admin_messages.OrgSettingsRoleChanged(user_id, org_role) ->
      handle_org_settings_role_changed(model, user_id, org_role)
    admin_messages.OrgSettingsSaved(_user_id, Ok(updated)) ->
      handle_org_settings_saved_ok(model, updated)
    admin_messages.OrgSettingsSaved(user_id, Error(err)) ->
      handle_org_settings_saved_error(model, user_id, err)
    admin_messages.OrgSettingsDeleteClicked(user_id) ->
      handle_org_settings_delete_clicked(model, user_id)
    admin_messages.OrgSettingsDeleteCancelled ->
      handle_org_settings_delete_cancelled(model)
    admin_messages.OrgSettingsDeleteConfirmed ->
      handle_org_settings_delete_confirmed(model)
    admin_messages.OrgSettingsDeleted(Ok(_)) ->
      handle_org_settings_deleted_ok(model)
    admin_messages.OrgSettingsDeleted(Error(err)) ->
      handle_org_settings_deleted_error(model, err)

    admin_messages.MemberAddDialogOpened ->
      handle_member_add_dialog_opened(model)
    admin_messages.MemberAddDialogClosed ->
      handle_member_add_dialog_closed(model)
    admin_messages.MemberAddRoleChanged(role_string) -> {
      let role = case parse(role_string) {
        Ok(r) -> r
        Error(_) -> MemberRole
      }
      handle_member_add_role_changed(model, role)
    }
    admin_messages.MemberAddUserSelected(user_id) ->
      handle_member_add_user_selected(model, user_id)
    admin_messages.MemberAddSubmitted -> handle_member_add_submitted(model)
    admin_messages.MemberAdded(Ok(_)) ->
      handle_member_added_ok(model, refresh_section_for_test)
    admin_messages.MemberAdded(Error(err)) ->
      handle_member_added_error(model, err)

    admin_messages.MemberRemoveClicked(user_id) ->
      handle_member_remove_clicked(model, user_id)
    admin_messages.MemberRemoveCancelled ->
      handle_member_remove_cancelled(model)
    admin_messages.MemberRemoveConfirmed ->
      handle_member_remove_confirmed(model)
    admin_messages.MemberRemoved(Ok(_)) ->
      handle_member_removed_ok(model, refresh_section_for_test)
    admin_messages.MemberRemoved(Error(err)) ->
      handle_member_removed_error(model, err)

    admin_messages.MemberReleaseAllClicked(user_id, claimed_count) ->
      handle_member_release_all_clicked(model, user_id, claimed_count)
    admin_messages.MemberReleaseAllCancelled ->
      handle_member_release_all_cancelled(model)
    admin_messages.MemberReleaseAllConfirmed ->
      handle_member_release_all_confirmed(model)
    admin_messages.MemberReleaseAllResult(Ok(result)) ->
      handle_member_release_all_ok(model, result)
    admin_messages.MemberReleaseAllResult(Error(err)) ->
      handle_member_release_all_error(model, err)

    admin_messages.MemberRoleChangeRequested(user_id, new_role) ->
      handle_member_role_change_requested(model, user_id, new_role)
    admin_messages.MemberRoleChanged(Ok(result)) ->
      handle_member_role_changed_ok(model, result)
    admin_messages.MemberRoleChanged(Error(err)) ->
      handle_member_role_changed_error(model, err)

    // client_state.Member capabilities dialog (Story 4.7 AC10-14)
    admin_messages.MemberCapabilitiesDialogOpened(user_id) ->
      handle_member_capabilities_dialog_opened(model, user_id)
    admin_messages.MemberCapabilitiesDialogClosed ->
      handle_member_capabilities_dialog_closed(model)
    admin_messages.MemberCapabilitiesToggled(capability_id) ->
      handle_member_capabilities_toggled(model, capability_id)
    admin_messages.MemberCapabilitiesSaveClicked ->
      handle_member_capabilities_save_clicked(model)
    admin_messages.MemberCapabilitiesFetched(Ok(result)) ->
      handle_member_capabilities_fetched_ok(model, result)
    admin_messages.MemberCapabilitiesFetched(Error(err)) ->
      handle_member_capabilities_fetched_error(model, err)
    admin_messages.MemberCapabilitiesSaved(Ok(result)) ->
      handle_member_capabilities_saved_ok(model, result)
    admin_messages.MemberCapabilitiesSaved(Error(err)) ->
      handle_member_capabilities_saved_error(model, err)

    // Capability members dialog (Story 4.7 AC16-17)
    admin_messages.CapabilityMembersDialogOpened(capability_id) ->
      handle_capability_members_dialog_opened(model, capability_id)
    admin_messages.CapabilityMembersDialogClosed ->
      handle_capability_members_dialog_closed(model)
    admin_messages.CapabilityMembersToggled(user_id) ->
      handle_capability_members_toggled(model, user_id)
    admin_messages.CapabilityMembersSaveClicked ->
      handle_capability_members_save_clicked(model)
    admin_messages.CapabilityMembersFetched(Ok(result)) ->
      handle_capability_members_fetched_ok(model, result)
    admin_messages.CapabilityMembersFetched(Error(err)) ->
      handle_capability_members_fetched_error(model, err)
    admin_messages.CapabilityMembersSaved(Ok(result)) ->
      handle_capability_members_saved_ok(model, result)
    admin_messages.CapabilityMembersSaved(Error(err)) ->
      handle_capability_members_saved_error(model, err)

    admin_messages.OrgUsersSearchChanged(query) ->
      handle_org_users_search_changed(model, query)

    admin_messages.OrgUsersSearchDebounced(query) ->
      handle_org_users_search_debounced(model, query)
    admin_messages.OrgUsersSearchResults(token, Ok(users)) ->
      handle_org_users_search_results_ok(model, token, users)
    admin_messages.OrgUsersSearchResults(token, Error(err)) ->
      handle_org_users_search_results_error(model, token, err)

    admin_messages.AssignmentsViewModeChanged(view_mode) ->
      assignments_workflow.handle_assignments_view_mode_changed(
        model,
        view_mode,
      )
    admin_messages.AssignmentsSearchChanged(value) ->
      assignments_workflow.handle_assignments_search_changed(model, value)
    admin_messages.AssignmentsSearchDebounced(value) ->
      assignments_workflow.handle_assignments_search_debounced(model, value)
    admin_messages.AssignmentsProjectToggled(project_id) ->
      assignments_workflow.handle_assignments_project_toggled(model, project_id)
    admin_messages.AssignmentsUserToggled(user_id) ->
      assignments_workflow.handle_assignments_user_toggled(model, user_id)
    admin_messages.AssignmentsProjectMembersFetched(project_id, Ok(members)) ->
      assignments_workflow.handle_assignments_project_members_fetched(
        model,
        project_id,
        Ok(members),
      )
    admin_messages.AssignmentsProjectMembersFetched(project_id, Error(err)) ->
      assignments_workflow.handle_assignments_project_members_fetched(
        model,
        project_id,
        Error(err),
      )
    admin_messages.AssignmentsUserProjectsFetched(user_id, Ok(projects)) ->
      assignments_workflow.handle_assignments_user_projects_fetched(
        model,
        user_id,
        Ok(projects),
      )
    admin_messages.AssignmentsUserProjectsFetched(user_id, Error(err)) ->
      assignments_workflow.handle_assignments_user_projects_fetched(
        model,
        user_id,
        Error(err),
      )
    admin_messages.AssignmentsInlineAddStarted(context) ->
      assignments_workflow.handle_assignments_inline_add_started(model, context)
    admin_messages.AssignmentsInlineAddSearchChanged(value) ->
      assignments_workflow.handle_assignments_inline_add_search_changed(
        model,
        value,
      )
    admin_messages.AssignmentsInlineAddSelectionChanged(value) ->
      assignments_workflow.handle_assignments_inline_add_selection_changed(
        model,
        value,
      )
    admin_messages.AssignmentsInlineAddRoleChanged(value) ->
      assignments_workflow.handle_assignments_inline_add_role_changed(
        model,
        value,
      )
    admin_messages.AssignmentsInlineAddSubmitted ->
      assignments_workflow.handle_assignments_inline_add_submitted(model)
    admin_messages.AssignmentsInlineAddCancelled ->
      assignments_workflow.handle_assignments_inline_add_cancelled(model)
    admin_messages.AssignmentsProjectMemberAdded(project_id, Ok(member)) ->
      assignments_workflow.handle_assignments_project_member_added_ok(
        model,
        project_id,
        member,
      )
    admin_messages.AssignmentsProjectMemberAdded(_project_id, Error(err)) ->
      assignments_workflow.handle_assignments_project_member_added_error(
        model,
        err,
      )
    admin_messages.AssignmentsUserProjectAdded(user_id, Ok(project)) ->
      assignments_workflow.handle_assignments_user_project_added_ok(
        model,
        user_id,
        project,
      )
    admin_messages.AssignmentsUserProjectAdded(_user_id, Error(err)) ->
      assignments_workflow.handle_assignments_user_project_added_error(
        model,
        err,
      )
    admin_messages.AssignmentsRemoveClicked(project_id, user_id) ->
      assignments_workflow.handle_assignments_remove_clicked(
        model,
        project_id,
        user_id,
      )
    admin_messages.AssignmentsRemoveCancelled ->
      assignments_workflow.handle_assignments_remove_cancelled(model)
    admin_messages.AssignmentsRemoveConfirmed ->
      assignments_workflow.handle_assignments_remove_confirmed(model)
    admin_messages.AssignmentsRemoveCompleted(project_id, user_id, Ok(_)) ->
      assignments_workflow.handle_assignments_remove_completed_ok(
        model,
        project_id,
        user_id,
      )
    admin_messages.AssignmentsRemoveCompleted(_project_id, _user_id, Error(err)) ->
      assignments_workflow.handle_assignments_remove_completed_error(model, err)
    admin_messages.AssignmentsRoleChanged(project_id, user_id, new_role) ->
      assignments_workflow.handle_assignments_role_changed(
        model,
        project_id,
        user_id,
        new_role,
      )
    admin_messages.AssignmentsRoleChangeCompleted(
      project_id,
      user_id,
      Ok(result),
    ) ->
      assignments_workflow.handle_assignments_role_change_completed_ok(
        model,
        project_id,
        user_id,
        result,
      )
    admin_messages.AssignmentsRoleChangeCompleted(
      project_id,
      user_id,
      Error(err),
    ) ->
      assignments_workflow.handle_assignments_role_change_completed_error(
        model,
        project_id,
        user_id,
        err,
      )

    admin_messages.TaskTypesFetched(Ok(task_types)) ->
      task_types_workflow.handle_task_types_fetched_ok(model, task_types)
    admin_messages.TaskTypesFetched(Error(err)) ->
      task_types_workflow.handle_task_types_fetched_error(model, err)
    admin_messages.TaskTypeCreateDialogOpened ->
      task_types_workflow.handle_task_type_dialog_opened(model)
    admin_messages.TaskTypeCreateDialogClosed ->
      task_types_workflow.handle_task_type_dialog_closed(model)
    admin_messages.TaskTypeCreateNameChanged(name) ->
      task_types_workflow.handle_task_type_create_name_changed(model, name)
    admin_messages.TaskTypeCreateIconChanged(icon) ->
      task_types_workflow.handle_task_type_create_icon_changed(model, icon)
    admin_messages.TaskTypeCreateIconSearchChanged(search) ->
      task_types_workflow.handle_task_type_create_icon_search_changed(
        model,
        search,
      )
    admin_messages.TaskTypeCreateIconCategoryChanged(category) ->
      task_types_workflow.handle_task_type_create_icon_category_changed(
        model,
        category,
      )
    admin_messages.TaskTypeIconLoaded ->
      task_types_workflow.handle_task_type_icon_loaded(model)
    admin_messages.TaskTypeIconErrored ->
      task_types_workflow.handle_task_type_icon_errored(model)
    admin_messages.TaskTypeCreateCapabilityChanged(value) ->
      task_types_workflow.handle_task_type_create_capability_changed(
        model,
        value,
      )
    admin_messages.TaskTypeCreateSubmitted ->
      task_types_workflow.handle_task_type_create_submitted(model)
    admin_messages.TaskTypeCreated(Ok(_)) ->
      task_types_workflow.handle_task_type_created_ok(
        model,
        refresh_section_for_test,
      )
    admin_messages.TaskTypeCreated(Error(err)) ->
      task_types_workflow.handle_task_type_created_error(model, err)
    // Task types - dialog mode control (component pattern)
    admin_messages.OpenTaskTypeDialog(mode) ->
      task_types_workflow.handle_open_task_type_dialog(model, mode)
    admin_messages.CloseTaskTypeDialog ->
      task_types_workflow.handle_close_task_type_dialog(model)
    // Task types - component events
    admin_messages.TaskTypeCrudCreated(task_type) ->
      task_types_workflow.handle_task_type_crud_created(
        model,
        task_type,
        refresh_section_for_test,
      )
    admin_messages.TaskTypeCrudUpdated(task_type) ->
      task_types_workflow.handle_task_type_crud_updated(model, task_type)
    admin_messages.TaskTypeCrudDeleted(type_id) ->
      task_types_workflow.handle_task_type_crud_deleted(model, type_id)
  }
}

fn update_members(
  admin: admin_state.AdminModel,
  f: fn(admin_members.Model) -> admin_members.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, members: f(admin.members))
}

fn update_capabilities(
  admin: admin_state.AdminModel,
  f: fn(admin_capabilities.Model) -> admin_capabilities.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, capabilities: f(admin.capabilities))
}
