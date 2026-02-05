//// Dispatch helpers for client_update.
////
//// Extracted to keep client_update.gleam focused on top-level routing.

import gleam/dict
import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/card
import domain/project_role.{Member as MemberRole}
import domain/remote.{Failed, Loaded}

import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/update as admin_workflow
import scrumbringer_client/features/assignments/update as assignments_workflow
import scrumbringer_client/features/capabilities/update as capabilities_workflow
import scrumbringer_client/features/invites/update as invite_links_workflow
import scrumbringer_client/features/metrics/update as metrics_workflow
import scrumbringer_client/features/now_working/update as now_working_workflow
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/update as pool_workflow
import scrumbringer_client/features/projects/update as projects_workflow
import scrumbringer_client/features/skills/update as skills_workflow
import scrumbringer_client/features/task_types/update as task_types_workflow
import scrumbringer_client/features/tasks/update as tasks_workflow
import scrumbringer_client/router
import scrumbringer_client/state/normalized_store
import scrumbringer_client/update_helpers

/// Represents AdminContext.
pub type AdminContext(msg) {
  AdminContext(
    member_refresh: fn(client_state.Model) -> #(client_state.Model, Effect(msg)),
    refresh_section_for_test: fn(client_state.Model) ->
      #(client_state.Model, Effect(msg)),
    hydrate_model: fn(client_state.Model) -> #(client_state.Model, Effect(msg)),
    replace_url: fn(client_state.Model) -> Effect(msg),
  )
}

/// Represents PoolContext.
pub type PoolContext(msg) {
  PoolContext(
    member_refresh: fn(client_state.Model) -> #(client_state.Model, Effect(msg)),
  )
}

/// Handles admin.
///
/// Example:
///   handle_admin(...)
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn handle_admin(
  model: client_state.Model,
  inner: client_state.AdminMsg,
  ctx: AdminContext(client_state.Msg),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let AdminContext(
    member_refresh: member_refresh,
    refresh_section_for_test: refresh_section_for_test,
    hydrate_model: hydrate_model,
    replace_url: replace_url,
  ) = ctx

  case inner {
    admin_messages.ProjectsFetched(Ok(projects)) -> {
      let selected =
        update_helpers.ensure_selected_project(
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

      let model = update_helpers.ensure_default_section(model)

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
                member_state.MemberModel(
                  ..member,
                  member_drag: state_types.DragIdle,
                  member_pool_drag: state_types.PoolDragIdle,
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
      admin_workflow.handle_members_fetched_ok(model, members)
    admin_messages.MembersFetched(Error(err)) ->
      admin_workflow.handle_members_fetched_error(model, err)

    admin_messages.OrgUsersCacheFetched(Ok(users)) -> {
      let #(model, fx) =
        admin_workflow.handle_org_users_cache_fetched_ok(model, users)
      let #(model, assignments_fx) =
        assignments_workflow.start_user_projects_fetch(model, users)
      #(model, effect.batch([fx, assignments_fx]))
    }
    admin_messages.OrgUsersCacheFetched(Error(err)) ->
      admin_workflow.handle_org_users_cache_fetched_error(model, err)
    admin_messages.OrgSettingsUsersFetched(Ok(users)) ->
      admin_workflow.handle_org_settings_users_fetched_ok(model, users)

    admin_messages.OrgSettingsUsersFetched(Error(err)) ->
      admin_workflow.handle_org_settings_users_fetched_error(model, err)
    admin_messages.OrgSettingsRoleChanged(user_id, org_role) ->
      admin_workflow.handle_org_settings_role_changed(model, user_id, org_role)
    admin_messages.OrgSettingsSaved(_user_id, Ok(updated)) ->
      admin_workflow.handle_org_settings_saved_ok(model, updated)
    admin_messages.OrgSettingsSaved(user_id, Error(err)) ->
      admin_workflow.handle_org_settings_saved_error(model, user_id, err)
    admin_messages.OrgSettingsDeleteClicked(user_id) ->
      admin_workflow.handle_org_settings_delete_clicked(model, user_id)
    admin_messages.OrgSettingsDeleteCancelled ->
      admin_workflow.handle_org_settings_delete_cancelled(model)
    admin_messages.OrgSettingsDeleteConfirmed ->
      admin_workflow.handle_org_settings_delete_confirmed(model)
    admin_messages.OrgSettingsDeleted(Ok(_)) ->
      admin_workflow.handle_org_settings_deleted_ok(model)
    admin_messages.OrgSettingsDeleted(Error(err)) ->
      admin_workflow.handle_org_settings_deleted_error(model, err)

    admin_messages.MemberAddDialogOpened ->
      admin_workflow.handle_member_add_dialog_opened(model)
    admin_messages.MemberAddDialogClosed ->
      admin_workflow.handle_member_add_dialog_closed(model)
    admin_messages.MemberAddRoleChanged(role_string) -> {
      let role = case project_role.parse(role_string) {
        Ok(r) -> r
        Error(_) -> MemberRole
      }
      admin_workflow.handle_member_add_role_changed(model, role)
    }
    admin_messages.MemberAddUserSelected(user_id) ->
      admin_workflow.handle_member_add_user_selected(model, user_id)
    admin_messages.MemberAddSubmitted ->
      admin_workflow.handle_member_add_submitted(model)
    admin_messages.MemberAdded(Ok(_)) ->
      admin_workflow.handle_member_added_ok(model, refresh_section_for_test)
    admin_messages.MemberAdded(Error(err)) ->
      admin_workflow.handle_member_added_error(model, err)

    admin_messages.MemberRemoveClicked(user_id) ->
      admin_workflow.handle_member_remove_clicked(model, user_id)
    admin_messages.MemberRemoveCancelled ->
      admin_workflow.handle_member_remove_cancelled(model)
    admin_messages.MemberRemoveConfirmed ->
      admin_workflow.handle_member_remove_confirmed(model)
    admin_messages.MemberRemoved(Ok(_)) ->
      admin_workflow.handle_member_removed_ok(model, refresh_section_for_test)
    admin_messages.MemberRemoved(Error(err)) ->
      admin_workflow.handle_member_removed_error(model, err)

    admin_messages.MemberReleaseAllClicked(user_id, claimed_count) ->
      admin_workflow.handle_member_release_all_clicked(
        model,
        user_id,
        claimed_count,
      )
    admin_messages.MemberReleaseAllCancelled ->
      admin_workflow.handle_member_release_all_cancelled(model)
    admin_messages.MemberReleaseAllConfirmed ->
      admin_workflow.handle_member_release_all_confirmed(model)
    admin_messages.MemberReleaseAllResult(Ok(result)) ->
      admin_workflow.handle_member_release_all_ok(model, result)
    admin_messages.MemberReleaseAllResult(Error(err)) ->
      admin_workflow.handle_member_release_all_error(model, err)

    admin_messages.MemberRoleChangeRequested(user_id, new_role) ->
      admin_workflow.handle_member_role_change_requested(
        model,
        user_id,
        new_role,
      )
    admin_messages.MemberRoleChanged(Ok(result)) ->
      admin_workflow.handle_member_role_changed_ok(model, result)
    admin_messages.MemberRoleChanged(Error(err)) ->
      admin_workflow.handle_member_role_changed_error(model, err)

    // client_state.Member capabilities dialog (Story 4.7 AC10-14)
    admin_messages.MemberCapabilitiesDialogOpened(user_id) ->
      admin_workflow.handle_member_capabilities_dialog_opened(model, user_id)
    admin_messages.MemberCapabilitiesDialogClosed ->
      admin_workflow.handle_member_capabilities_dialog_closed(model)
    admin_messages.MemberCapabilitiesToggled(capability_id) ->
      admin_workflow.handle_member_capabilities_toggled(model, capability_id)
    admin_messages.MemberCapabilitiesSaveClicked ->
      admin_workflow.handle_member_capabilities_save_clicked(model)
    admin_messages.MemberCapabilitiesFetched(Ok(result)) ->
      admin_workflow.handle_member_capabilities_fetched_ok(model, result)
    admin_messages.MemberCapabilitiesFetched(Error(err)) ->
      admin_workflow.handle_member_capabilities_fetched_error(model, err)
    admin_messages.MemberCapabilitiesSaved(Ok(result)) ->
      admin_workflow.handle_member_capabilities_saved_ok(model, result)
    admin_messages.MemberCapabilitiesSaved(Error(err)) ->
      admin_workflow.handle_member_capabilities_saved_error(model, err)

    // Capability members dialog (Story 4.7 AC16-17)
    admin_messages.CapabilityMembersDialogOpened(capability_id) ->
      admin_workflow.handle_capability_members_dialog_opened(
        model,
        capability_id,
      )
    admin_messages.CapabilityMembersDialogClosed ->
      admin_workflow.handle_capability_members_dialog_closed(model)
    admin_messages.CapabilityMembersToggled(user_id) ->
      admin_workflow.handle_capability_members_toggled(model, user_id)
    admin_messages.CapabilityMembersSaveClicked ->
      admin_workflow.handle_capability_members_save_clicked(model)
    admin_messages.CapabilityMembersFetched(Ok(result)) ->
      admin_workflow.handle_capability_members_fetched_ok(model, result)
    admin_messages.CapabilityMembersFetched(Error(err)) ->
      admin_workflow.handle_capability_members_fetched_error(model, err)
    admin_messages.CapabilityMembersSaved(Ok(result)) ->
      admin_workflow.handle_capability_members_saved_ok(model, result)
    admin_messages.CapabilityMembersSaved(Error(err)) ->
      admin_workflow.handle_capability_members_saved_error(model, err)

    admin_messages.OrgUsersSearchChanged(query) ->
      admin_workflow.handle_org_users_search_changed(model, query)

    admin_messages.OrgUsersSearchDebounced(query) ->
      admin_workflow.handle_org_users_search_debounced(model, query)
    admin_messages.OrgUsersSearchResults(token, Ok(users)) ->
      admin_workflow.handle_org_users_search_results_ok(model, token, users)
    admin_messages.OrgUsersSearchResults(token, Error(err)) ->
      admin_workflow.handle_org_users_search_results_error(model, token, err)

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

fn clear_card_new_notes(
  model: client_state.Model,
  card_id: Int,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    case admin.cards {
      Loaded(cards) ->
        admin_state.AdminModel(
          ..admin,
          cards: Loaded(
            list.map(cards, fn(card_item) {
              case card_item.id == card_id {
                True -> card.Card(..card_item, has_new_notes: False)
                False -> card_item
              }
            }),
          ),
        )
      _ -> admin
    }
  })
}

/// Handles pool.
///
/// Example:
///   handle_pool(...)
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn handle_pool(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  ctx: PoolContext(client_state.Msg),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let PoolContext(member_refresh: member_refresh) = ctx

  case inner {
    pool_messages.MemberPoolMyTasksRectFetched(left, top, width, height) ->
      pool_workflow.handle_pool_my_tasks_rect_fetched(
        model,
        left,
        top,
        width,
        height,
      )
    pool_messages.MemberPoolDragToClaimArmed(armed) ->
      pool_workflow.handle_pool_drag_to_claim_armed(model, armed)
    pool_messages.MemberPoolStatusChanged(v) ->
      pool_workflow.handle_pool_status_changed(model, v, member_refresh)
    pool_messages.MemberPoolTypeChanged(v) ->
      pool_workflow.handle_pool_type_changed(model, v, member_refresh)
    pool_messages.MemberPoolCapabilityChanged(v) ->
      pool_workflow.handle_pool_capability_changed(model, v, member_refresh)

    pool_messages.MemberToggleMyCapabilitiesQuick ->
      pool_workflow.handle_toggle_my_capabilities_quick(model)
    pool_messages.MemberPoolFiltersToggled ->
      pool_workflow.handle_pool_filters_toggled(model)
    pool_messages.MemberClearFilters ->
      pool_workflow.handle_clear_filters(model, member_refresh)
    pool_messages.MemberPoolViewModeSet(mode) ->
      pool_workflow.handle_pool_view_mode_set(model, mode)
    pool_messages.MemberPoolTouchStarted(task_id, client_x, client_y) ->
      pool_workflow.handle_pool_touch_started(
        model,
        task_id,
        client_x,
        client_y,
      )
    pool_messages.MemberPoolTouchEnded(task_id) ->
      pool_workflow.handle_pool_touch_ended(model, task_id)
    pool_messages.MemberPoolLongPressCheck(task_id) ->
      pool_workflow.handle_pool_long_press_check(model, task_id)
    pool_messages.MemberTaskHoverOpened(task_id) ->
      pool_workflow.handle_task_hover_opened(model, task_id)
    pool_messages.MemberTaskHoverNotesFetched(task_id, result) ->
      pool_workflow.handle_task_hover_notes_fetched(model, task_id, result)
    pool_messages.MemberListHideCompletedToggled -> #(
      client_state.update_member(model, fn(member) {
        member_state.MemberModel(
          ..member,
          member_list_hide_completed: !model.member.member_list_hide_completed,
        )
      }),
      effect.none(),
    )
    // Story 4.8 UX: Collapse/expand card groups in Lista view
    pool_messages.MemberListCardToggled(card_id) -> {
      let current =
        dict.get(model.member.member_list_expanded_cards, card_id)
        |> opt.from_result
        |> opt.unwrap(True)
      let new_cards =
        dict.insert(model.member.member_list_expanded_cards, card_id, !current)
      #(
        client_state.update_member(model, fn(member) {
          member_state.MemberModel(
            ..member,
            member_list_expanded_cards: new_cards,
          )
        }),
        effect.none(),
      )
    }
    client_state.ViewModeChanged(mode) -> {
      let new_model =
        client_state.update_member(model, fn(member) {
          member_state.MemberModel(..member, view_mode: mode)
        })
      let route =
        router.Member(
          model.member.member_section,
          model.core.selected_project_id,
          opt.Some(mode),
        )
      #(new_model, router.replace(route))
    }
    client_state.GlobalKeyDown(event) ->
      pool_workflow.handle_global_keydown(model, event)

    pool_messages.MemberPoolSearchChanged(v) ->
      pool_workflow.handle_pool_search_changed(model, v)
    pool_messages.MemberPoolSearchDebounced(v) ->
      pool_workflow.handle_pool_search_debounced(model, v, member_refresh)

    pool_messages.MemberProjectTasksFetched(project_id, Ok(tasks)) -> {
      let tasks_by_project =
        dict.insert(model.member.member_tasks_by_project, project_id, tasks)
      let pending = model.member.member_tasks_pending - 1

      let model =
        client_state.update_member(model, fn(member) {
          member_state.MemberModel(
            ..member,
            member_tasks_by_project: tasks_by_project,
            member_tasks_pending: pending,
          )
        })

      case pending <= 0 {
        True -> #(
          client_state.update_member(model, fn(member) {
            member_state.MemberModel(
              ..member,
              member_tasks: Loaded(update_helpers.flatten_tasks(
                tasks_by_project,
              )),
            )
          }),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    pool_messages.MemberProjectTasksFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(
          client_state.update_member(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: client_state.Login,
                user: opt.None,
              )
            }),
            fn(member) {
              member_state.MemberModel(
                ..member,
                member_drag: state_types.DragIdle,
                member_pool_drag: state_types.PoolDragIdle,
              )
            },
          ),
          effect.none(),
        )
        _ -> #(
          client_state.update_member(model, fn(member) {
            member_state.MemberModel(
              ..member,
              member_tasks: Failed(err),
              member_tasks_pending: 0,
            )
          }),
          effect.none(),
        )
      }
    }

    pool_messages.MemberTaskTypesFetched(project_id, Ok(task_types)) -> {
      let task_types_by_project =
        dict.insert(
          model.member.member_task_types_by_project,
          project_id,
          task_types,
        )
      let pending = model.member.member_task_types_pending - 1

      let model =
        client_state.update_member(model, fn(member) {
          member_state.MemberModel(
            ..member,
            member_task_types_by_project: task_types_by_project,
            member_task_types_pending: pending,
          )
        })

      case pending <= 0 {
        True -> #(
          client_state.update_member(model, fn(member) {
            member_state.MemberModel(
              ..member,
              member_task_types: Loaded(update_helpers.flatten_task_types(
                task_types_by_project,
              )),
            )
          }),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    pool_messages.MemberTaskTypesFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(
          client_state.update_member(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: client_state.Login,
                user: opt.None,
              )
            }),
            fn(member) {
              member_state.MemberModel(
                ..member,
                member_drag: state_types.DragIdle,
                member_pool_drag: state_types.PoolDragIdle,
              )
            },
          ),
          effect.none(),
        )
        _ -> #(
          client_state.update_member(model, fn(member) {
            member_state.MemberModel(
              ..member,
              member_task_types: Failed(err),
              member_task_types_pending: 0,
            )
          }),
          effect.none(),
        )
      }
    }

    pool_messages.MemberCanvasRectFetched(left, top) ->
      pool_workflow.handle_canvas_rect_fetched(model, left, top)
    pool_messages.MemberDragStarted(task_id, client_x, client_y) ->
      pool_workflow.handle_drag_started(model, task_id, client_x, client_y)
    pool_messages.MemberDragOffsetResolved(task_id, offset_x, offset_y) ->
      pool_workflow.handle_drag_offset_resolved(
        model,
        task_id,
        offset_x,
        offset_y,
      )
    pool_messages.MemberDragMoved(client_x, client_y) ->
      pool_workflow.handle_drag_moved(model, client_x, client_y)
    pool_messages.MemberDragEnded -> pool_workflow.handle_drag_ended(model)

    pool_messages.MemberCreateDialogOpened ->
      tasks_workflow.handle_create_dialog_opened(model)
    pool_messages.MemberCreateDialogOpenedWithCard(card_id) ->
      tasks_workflow.handle_create_dialog_opened_with_card(model, card_id)
    pool_messages.MemberCreateDialogClosed ->
      tasks_workflow.handle_create_dialog_closed(model)
    pool_messages.MemberCreateTitleChanged(v) ->
      tasks_workflow.handle_create_title_changed(model, v)
    pool_messages.MemberCreateDescriptionChanged(v) ->
      tasks_workflow.handle_create_description_changed(model, v)
    pool_messages.MemberCreatePriorityChanged(v) ->
      tasks_workflow.handle_create_priority_changed(model, v)
    pool_messages.MemberCreateTypeIdChanged(v) ->
      tasks_workflow.handle_create_type_id_changed(model, v)
    pool_messages.MemberCreateCardIdChanged(v) ->
      tasks_workflow.handle_create_card_id_changed(model, v)

    pool_messages.MemberCreateSubmitted ->
      tasks_workflow.handle_create_submitted(model, member_refresh)

    pool_messages.MemberTaskCreated(Ok(_)) ->
      tasks_workflow.handle_task_created_ok(model, member_refresh)
    pool_messages.MemberTaskCreated(Error(err)) ->
      tasks_workflow.handle_task_created_error(model, err)

    pool_messages.MemberClaimClicked(task_id, version) ->
      tasks_workflow.handle_claim_clicked(model, task_id, version)
    pool_messages.MemberReleaseClicked(task_id, version) ->
      tasks_workflow.handle_release_clicked(model, task_id, version)
    pool_messages.MemberCompleteClicked(task_id, version) ->
      tasks_workflow.handle_complete_clicked(model, task_id, version)

    pool_messages.MemberBlockedClaimCancelled ->
      tasks_workflow.handle_blocked_claim_cancelled(model)
    pool_messages.MemberBlockedClaimConfirmed ->
      tasks_workflow.handle_blocked_claim_confirmed(model)

    pool_messages.MemberTaskClaimed(Ok(_)) ->
      tasks_workflow.handle_task_claimed_ok(model, member_refresh)
    pool_messages.MemberTaskReleased(Ok(_)) ->
      tasks_workflow.handle_task_released_ok(model, member_refresh)
    pool_messages.MemberTaskCompleted(Ok(_)) ->
      tasks_workflow.handle_task_completed_ok(model, member_refresh)

    pool_messages.MemberTaskClaimed(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    pool_messages.MemberTaskReleased(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    pool_messages.MemberTaskCompleted(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)

    pool_messages.MemberNowWorkingStartClicked(task_id) ->
      now_working_workflow.handle_start_clicked(model, task_id)
    pool_messages.MemberNowWorkingPauseClicked ->
      now_working_workflow.handle_pause_clicked(model)

    // Work sessions (multi-session) - delegate to workflow
    pool_messages.MemberWorkSessionsFetched(Ok(payload)) ->
      now_working_workflow.handle_sessions_fetched_ok(model, payload)
    pool_messages.MemberWorkSessionsFetched(Error(err)) ->
      now_working_workflow.handle_sessions_fetched_error(model, err)

    pool_messages.MemberWorkSessionStarted(Ok(payload)) ->
      now_working_workflow.handle_session_started_ok(model, payload)
    pool_messages.MemberWorkSessionStarted(Error(err)) ->
      now_working_workflow.handle_session_started_error(model, err)

    pool_messages.MemberWorkSessionPaused(Ok(payload)) ->
      now_working_workflow.handle_session_paused_ok(model, payload)
    pool_messages.MemberWorkSessionPaused(Error(err)) ->
      now_working_workflow.handle_session_paused_error(model, err)

    pool_messages.MemberWorkSessionHeartbeated(Ok(payload)) ->
      now_working_workflow.handle_session_heartbeated_ok(model, payload)
    pool_messages.MemberWorkSessionHeartbeated(Error(err)) ->
      now_working_workflow.handle_session_heartbeated_error(model, err)

    pool_messages.MemberMetricsFetched(Ok(metrics)) ->
      metrics_workflow.handle_member_metrics_fetched_ok(model, metrics)
    pool_messages.MemberMetricsFetched(Error(err)) ->
      metrics_workflow.handle_member_metrics_fetched_error(model, err)

    pool_messages.AdminMetricsOverviewFetched(Ok(overview)) ->
      metrics_workflow.handle_admin_overview_fetched_ok(model, overview)
    pool_messages.AdminMetricsOverviewFetched(Error(err)) ->
      metrics_workflow.handle_admin_overview_fetched_error(model, err)

    pool_messages.AdminMetricsProjectTasksFetched(Ok(payload)) ->
      metrics_workflow.handle_admin_project_tasks_fetched_ok(model, payload)
    pool_messages.AdminMetricsProjectTasksFetched(Error(err)) ->
      metrics_workflow.handle_admin_project_tasks_fetched_error(model, err)

    pool_messages.AdminMetricsUsersFetched(Ok(users)) ->
      metrics_workflow.handle_admin_users_fetched_ok(model, users)
    pool_messages.AdminMetricsUsersFetched(Error(err)) ->
      metrics_workflow.handle_admin_users_fetched_error(model, err)

    // Rule metrics tab
    pool_messages.AdminRuleMetricsFetched(Ok(metrics)) ->
      admin_workflow.handle_rule_metrics_tab_fetched_ok(model, metrics)
    pool_messages.AdminRuleMetricsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_tab_fetched_error(model, err)
    pool_messages.AdminRuleMetricsFromChanged(from) ->
      admin_workflow.handle_rule_metrics_tab_from_changed(model, from)
    pool_messages.AdminRuleMetricsToChanged(to) ->
      admin_workflow.handle_rule_metrics_tab_to_changed(model, to)
    pool_messages.AdminRuleMetricsFromChangedAndRefresh(from) ->
      admin_workflow.handle_rule_metrics_tab_from_changed_and_refresh(
        model,
        from,
      )
    pool_messages.AdminRuleMetricsToChangedAndRefresh(to) ->
      admin_workflow.handle_rule_metrics_tab_to_changed_and_refresh(model, to)
    pool_messages.AdminRuleMetricsRefreshClicked ->
      admin_workflow.handle_rule_metrics_tab_refresh_clicked(model)
    pool_messages.AdminRuleMetricsQuickRangeClicked(from, to) ->
      admin_workflow.handle_rule_metrics_tab_quick_range_clicked(
        model,
        from,
        to,
      )
    // Rule metrics drill-down
    pool_messages.AdminRuleMetricsWorkflowExpanded(workflow_id) ->
      admin_workflow.handle_rule_metrics_workflow_expanded(model, workflow_id)
    pool_messages.AdminRuleMetricsWorkflowDetailsFetched(Ok(details)) ->
      admin_workflow.handle_rule_metrics_workflow_details_fetched_ok(
        model,
        details,
      )
    pool_messages.AdminRuleMetricsWorkflowDetailsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_workflow_details_fetched_error(
        model,
        err,
      )
    pool_messages.AdminRuleMetricsDrilldownClicked(rule_id) ->
      admin_workflow.handle_rule_metrics_drilldown_clicked(model, rule_id)
    pool_messages.AdminRuleMetricsDrilldownClosed ->
      admin_workflow.handle_rule_metrics_drilldown_closed(model)
    pool_messages.AdminRuleMetricsRuleDetailsFetched(Ok(details)) ->
      admin_workflow.handle_rule_metrics_rule_details_fetched_ok(model, details)
    pool_messages.AdminRuleMetricsRuleDetailsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_rule_details_fetched_error(model, err)
    pool_messages.AdminRuleMetricsExecutionsFetched(Ok(response)) ->
      admin_workflow.handle_rule_metrics_executions_fetched_ok(model, response)
    pool_messages.AdminRuleMetricsExecutionsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_executions_fetched_error(model, err)
    pool_messages.AdminRuleMetricsExecPageChanged(offset) ->
      admin_workflow.handle_rule_metrics_exec_page_changed(model, offset)

    client_state.NowWorkingTicked -> now_working_workflow.handle_ticked(model)

    pool_messages.MemberMyCapabilityIdsFetched(Ok(ids)) ->
      skills_workflow.handle_my_capability_ids_fetched_ok(model, ids)
    pool_messages.MemberMyCapabilityIdsFetched(Error(err)) ->
      skills_workflow.handle_my_capability_ids_fetched_error(model, err)

    pool_messages.MemberProjectCapabilitiesFetched(Ok(capabilities)) ->
      client_state.update_member(model, fn(member) {
        member_state.MemberModel(
          ..member,
          member_capabilities: Loaded(capabilities),
        )
      })
      |> fn(next) { #(next, effect.none()) }
    pool_messages.MemberProjectCapabilitiesFetched(Error(err)) ->
      client_state.update_member(model, fn(member) {
        member_state.MemberModel(..member, member_capabilities: Failed(err))
      })
      |> fn(next) { #(next, effect.none()) }

    pool_messages.MemberToggleCapability(id) ->
      skills_workflow.handle_toggle_capability(model, id)
    pool_messages.MemberSaveCapabilitiesClicked ->
      skills_workflow.handle_save_capabilities_clicked(model)

    pool_messages.MemberMyCapabilityIdsSaved(Ok(ids)) ->
      skills_workflow.handle_save_capabilities_ok(model, ids)
    pool_messages.MemberMyCapabilityIdsSaved(Error(err)) ->
      skills_workflow.handle_save_capabilities_error(model, err)

    pool_messages.MemberPositionsFetched(Ok(positions)) ->
      pool_workflow.handle_positions_fetched_ok(model, positions)
    pool_messages.MemberPositionsFetched(Error(err)) ->
      pool_workflow.handle_positions_fetched_error(model, err)

    pool_messages.MemberPositionEditOpened(task_id) ->
      pool_workflow.handle_position_edit_opened(model, task_id)
    pool_messages.MemberPositionEditClosed ->
      pool_workflow.handle_position_edit_closed(model)
    pool_messages.MemberPositionEditXChanged(v) ->
      pool_workflow.handle_position_edit_x_changed(model, v)
    pool_messages.MemberPositionEditYChanged(v) ->
      pool_workflow.handle_position_edit_y_changed(model, v)
    pool_messages.MemberPositionEditSubmitted ->
      pool_workflow.handle_position_edit_submitted(model)

    pool_messages.MemberPositionSaved(Ok(pos)) ->
      pool_workflow.handle_position_saved_ok(model, pos)
    pool_messages.MemberPositionSaved(Error(err)) ->
      pool_workflow.handle_position_saved_error(model, err)

    pool_messages.MemberTaskDetailsOpened(task_id) ->
      tasks_workflow.handle_task_details_opened(model, task_id)
    pool_messages.MemberTaskDetailsClosed ->
      tasks_workflow.handle_task_details_closed(model)

    pool_messages.MemberTaskDetailTabClicked(tab) ->
      tasks_workflow.handle_task_detail_tab_clicked(model, tab)

    pool_messages.MemberDependenciesFetched(Ok(deps)) ->
      tasks_workflow.handle_dependencies_fetched_ok(model, deps)
    pool_messages.MemberDependenciesFetched(Error(err)) ->
      tasks_workflow.handle_dependencies_fetched_error(model, err)

    pool_messages.MemberDependencyDialogOpened ->
      tasks_workflow.handle_dependency_dialog_opened(model)
    pool_messages.MemberDependencyDialogClosed ->
      tasks_workflow.handle_dependency_dialog_closed(model)
    pool_messages.MemberDependencySearchChanged(value) ->
      tasks_workflow.handle_dependency_search_changed(model, value)
    pool_messages.MemberDependencyCandidatesFetched(Ok(tasks)) ->
      tasks_workflow.handle_dependency_candidates_fetched_ok(model, tasks)
    pool_messages.MemberDependencyCandidatesFetched(Error(err)) ->
      tasks_workflow.handle_dependency_candidates_fetched_error(model, err)
    pool_messages.MemberDependencySelected(task_id) ->
      tasks_workflow.handle_dependency_selected(model, task_id)
    pool_messages.MemberDependencyAddSubmitted ->
      tasks_workflow.handle_dependency_add_submitted(model)
    pool_messages.MemberDependencyAdded(Ok(dep)) ->
      tasks_workflow.handle_dependency_added_ok(model, dep)
    pool_messages.MemberDependencyAdded(Error(err)) ->
      tasks_workflow.handle_dependency_added_error(model, err)
    pool_messages.MemberDependencyRemoveClicked(depends_on_task_id) ->
      tasks_workflow.handle_dependency_remove_clicked(model, depends_on_task_id)
    pool_messages.MemberDependencyRemoved(depends_on_task_id, Ok(_)) ->
      tasks_workflow.handle_dependency_removed_ok(model, depends_on_task_id)
    pool_messages.MemberDependencyRemoved(_depends_on_task_id, Error(err)) ->
      tasks_workflow.handle_dependency_removed_error(model, err)

    pool_messages.MemberNotesFetched(Ok(notes)) ->
      tasks_workflow.handle_notes_fetched_ok(model, notes)
    pool_messages.MemberNotesFetched(Error(err)) ->
      tasks_workflow.handle_notes_fetched_error(model, err)

    pool_messages.MemberNoteContentChanged(v) ->
      tasks_workflow.handle_note_content_changed(model, v)
    pool_messages.MemberNoteDialogOpened ->
      tasks_workflow.handle_note_dialog_opened(model)
    pool_messages.MemberNoteDialogClosed ->
      tasks_workflow.handle_note_dialog_closed(model)
    pool_messages.MemberNoteSubmitted ->
      tasks_workflow.handle_note_submitted(model)

    pool_messages.MemberNoteAdded(Ok(note)) ->
      tasks_workflow.handle_note_added_ok(model, note)
    pool_messages.MemberNoteAdded(Error(err)) ->
      tasks_workflow.handle_note_added_error(model, err)

    // Cards (Fichas) handlers - list loading and dialog mode
    pool_messages.CardsFetched(Ok(cards)) ->
      admin_workflow.handle_cards_fetched_ok(model, cards)
    pool_messages.CardsFetched(Error(err)) ->
      admin_workflow.handle_cards_fetched_error(model, err)

    pool_messages.MemberProjectCardsFetched(project_id, Ok(cards)) -> {
      let next_store =
        normalized_store.upsert(
          model.member.member_cards_store,
          project_id,
          cards,
          fn(card_item) {
            let card.Card(id: id, ..) = card_item
            id
          },
        )
        |> normalized_store.decrement_pending

      let next_cards = case normalized_store.is_ready(next_store) {
        True -> Loaded(normalized_store.to_list(next_store))
        False -> model.member.member_cards
      }

      client_state.update_member(model, fn(member) {
        member_state.MemberModel(
          ..member,
          member_cards_store: next_store,
          member_cards: next_cards,
        )
      })
      |> fn(next) { #(next, effect.none()) }
    }
    pool_messages.MemberProjectCardsFetched(_project_id, Error(err)) -> {
      let next_store =
        model.member.member_cards_store
        |> normalized_store.decrement_pending

      let next_cards = case model.member.member_cards {
        Loaded(_) -> model.member.member_cards
        _ -> Failed(err)
      }

      client_state.update_member(model, fn(member) {
        member_state.MemberModel(
          ..member,
          member_cards_store: next_store,
          member_cards: next_cards,
        )
      })
      |> fn(next) { #(next, effect.none()) }
    }
    pool_messages.OpenCardDialog(mode) ->
      admin_workflow.handle_open_card_dialog(model, mode)
    client_state.CloseCardDialog ->
      admin_workflow.handle_close_card_dialog(model)
    // Cards (Fichas) - component events
    client_state.CardCrudCreated(card) ->
      admin_workflow.handle_card_crud_created(model, card)
    client_state.CardCrudUpdated(card) ->
      admin_workflow.handle_card_crud_updated(model, card)
    client_state.CardCrudDeleted(card_id) ->
      admin_workflow.handle_card_crud_deleted(model, card_id)
    // Cards - filter changes (Story 4.9 AC7-8, UX improvements)
    client_state.CardsShowEmptyToggled -> #(
      client_state.update_admin(model, fn(admin) {
        admin_state.AdminModel(
          ..admin,
          cards_show_empty: !model.admin.cards_show_empty,
        )
      }),
      effect.none(),
    )
    client_state.CardsShowCompletedToggled -> #(
      client_state.update_admin(model, fn(admin) {
        admin_state.AdminModel(
          ..admin,
          cards_show_completed: !model.admin.cards_show_completed,
        )
      }),
      effect.none(),
    )
    client_state.CardsStateFilterChanged(state_str) -> {
      let filter = case state_str {
        "" -> opt.None
        "pendiente" -> opt.Some(card.Pendiente)
        "en_curso" -> opt.Some(card.EnCurso)
        "cerrada" -> opt.Some(card.Cerrada)
        _ -> opt.None
      }
      #(
        client_state.update_admin(model, fn(admin) {
          admin_state.AdminModel(..admin, cards_state_filter: filter)
        }),
        effect.none(),
      )
    }
    client_state.CardsSearchChanged(query) -> #(
      client_state.update_admin(model, fn(admin) {
        admin_state.AdminModel(..admin, cards_search: query)
      }),
      effect.none(),
    )

    // Card detail (member view) handlers - component manages internal state
    pool_messages.OpenCardDetail(card_id) -> {
      let model =
        client_state.update_member(model, fn(member) {
          member_state.MemberModel(
            ..member,
            card_detail_open: opt.Some(card_id),
          )
        })
        |> clear_card_new_notes(card_id)

      let fx = api_cards.mark_card_view(card_id, fn(_res) { client_state.NoOp })

      #(model, fx)
    }
    pool_messages.CloseCardDetail -> #(
      client_state.update_member(model, fn(member) {
        member_state.MemberModel(..member, card_detail_open: opt.None)
      }),
      effect.none(),
    )

    // Workflows handlers
    pool_messages.WorkflowsProjectFetched(Ok(workflows)) ->
      admin_workflow.handle_workflows_project_fetched_ok(model, workflows)
    pool_messages.WorkflowsProjectFetched(Error(err)) ->
      admin_workflow.handle_workflows_project_fetched_error(model, err)
    // Workflow dialog control (component pattern)
    pool_messages.OpenWorkflowDialog(mode) ->
      admin_workflow.handle_open_workflow_dialog(model, mode)
    client_state.CloseWorkflowDialog ->
      admin_workflow.handle_close_workflow_dialog(model)
    // Workflow component events
    client_state.WorkflowCrudCreated(workflow) ->
      admin_workflow.handle_workflow_crud_created(model, workflow)
    client_state.WorkflowCrudUpdated(workflow) ->
      admin_workflow.handle_workflow_crud_updated(model, workflow)
    client_state.WorkflowCrudDeleted(workflow_id) ->
      admin_workflow.handle_workflow_crud_deleted(model, workflow_id)

    client_state.WorkflowRulesClicked(workflow_id) ->
      admin_workflow.handle_workflow_rules_clicked(model, workflow_id)

    // Rules handlers
    pool_messages.RulesFetched(Ok(rules)) ->
      admin_workflow.handle_rules_fetched_ok(model, rules)
    pool_messages.RulesFetched(Error(err)) ->
      admin_workflow.handle_rules_fetched_error(model, err)
    client_state.RulesBackClicked ->
      admin_workflow.handle_rules_back_clicked(model)
    pool_messages.RuleMetricsFetched(Ok(metrics)) ->
      admin_workflow.handle_rule_metrics_fetched_ok(model, metrics)
    pool_messages.RuleMetricsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_fetched_error(model, err)

    // Rules - dialog mode control (component pattern)
    client_state.OpenRuleDialog(mode) ->
      admin_workflow.handle_open_rule_dialog(model, mode)
    client_state.CloseRuleDialog ->
      admin_workflow.handle_close_rule_dialog(model)

    // Rules - component events (rule-crud-dialog emits these)
    client_state.RuleCrudCreated(rule) ->
      admin_workflow.handle_rule_crud_created(model, rule)
    client_state.RuleCrudUpdated(rule) ->
      admin_workflow.handle_rule_crud_updated(model, rule)
    client_state.RuleCrudDeleted(rule_id) ->
      admin_workflow.handle_rule_crud_deleted(model, rule_id)

    // Rule templates handlers
    pool_messages.RuleTemplatesClicked(_rule_id) -> #(model, effect.none())
    pool_messages.RuleTemplatesFetched(Ok(templates)) ->
      admin_workflow.handle_rule_templates_fetched_ok(model, templates)
    pool_messages.RuleTemplatesFetched(Error(err)) ->
      admin_workflow.handle_rule_templates_fetched_error(model, err)
    client_state.RuleAttachTemplateSelected(template_id) ->
      admin_workflow.handle_rule_attach_template_selected(model, template_id)
    client_state.RuleAttachTemplateSubmitted -> #(model, effect.none())
    client_state.RuleTemplateAttached(Ok(templates)) ->
      admin_workflow.handle_rule_template_attached_ok(model, templates)
    client_state.RuleTemplateAttached(Error(err)) ->
      admin_workflow.handle_rule_template_attached_error(model, err)
    client_state.RuleTemplateDetachClicked(_template_id) -> #(
      model,
      effect.none(),
    )
    client_state.RuleTemplateDetached(Ok(_)) -> #(model, effect.none())
    client_state.RuleTemplateDetached(Error(err)) ->
      admin_workflow.handle_rule_template_detached_error(model, err)

    // Story 4.10: Rule template attachment UI handlers
    client_state.RuleExpandToggled(rule_id) ->
      admin_workflow.handle_rule_expand_toggled(model, rule_id)
    client_state.AttachTemplateModalOpened(rule_id) ->
      admin_workflow.handle_attach_template_modal_opened(model, rule_id)
    client_state.AttachTemplateModalClosed ->
      admin_workflow.handle_attach_template_modal_closed(model)
    client_state.AttachTemplateSelected(template_id) ->
      admin_workflow.handle_attach_template_selected(model, template_id)
    client_state.AttachTemplateSubmitted ->
      admin_workflow.handle_attach_template_submitted(model)
    client_state.AttachTemplateSucceeded(rule_id, templates) ->
      admin_workflow.handle_attach_template_succeeded(model, rule_id, templates)
    client_state.AttachTemplateFailed(err) ->
      admin_workflow.handle_attach_template_failed(model, err)
    client_state.TemplateDetachClicked(rule_id, template_id) ->
      admin_workflow.handle_template_detach_clicked(model, rule_id, template_id)
    client_state.TemplateDetachSucceeded(rule_id, template_id) ->
      admin_workflow.handle_template_detach_succeeded(
        model,
        rule_id,
        template_id,
      )
    client_state.TemplateDetachFailed(rule_id, template_id, err) ->
      admin_workflow.handle_template_detach_failed(
        model,
        rule_id,
        template_id,
        err,
      )

    // Task templates handlers
    pool_messages.TaskTemplatesProjectFetched(Ok(templates)) ->
      admin_workflow.handle_task_templates_project_fetched_ok(model, templates)
    pool_messages.TaskTemplatesProjectFetched(Error(err)) ->
      admin_workflow.handle_task_templates_project_fetched_error(model, err)

    // Task templates - dialog mode control (component pattern)
    client_state.OpenTaskTemplateDialog(mode) ->
      admin_workflow.handle_open_task_template_dialog(model, mode)
    client_state.CloseTaskTemplateDialog ->
      admin_workflow.handle_close_task_template_dialog(model)

    // Task templates - component events
    client_state.TaskTemplateCrudCreated(template) ->
      admin_workflow.handle_task_template_crud_created(model, template)
    client_state.TaskTemplateCrudUpdated(template) ->
      admin_workflow.handle_task_template_crud_updated(model, template)
    client_state.TaskTemplateCrudDeleted(template_id) ->
      admin_workflow.handle_task_template_crud_deleted(model, template_id)
  }
}
