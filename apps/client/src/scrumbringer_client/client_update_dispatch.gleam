//// Dispatch helpers for client_update.
////
//// Extracted to keep client_update.gleam focused on top-level routing.

import gleam/dict
import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/card
import domain/project_role.{Member as MemberRole}

import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/update as admin_workflow
import scrumbringer_client/features/assignments/update as assignments_workflow
import scrumbringer_client/features/capabilities/update as capabilities_workflow
import scrumbringer_client/features/invites/update as invite_links_workflow
import scrumbringer_client/features/metrics/update as metrics_workflow
import scrumbringer_client/features/now_working/update as now_working_workflow
import scrumbringer_client/features/pool/update as pool_workflow
import scrumbringer_client/features/projects/update as projects_workflow
import scrumbringer_client/features/skills/update as skills_workflow
import scrumbringer_client/features/task_types/update as task_types_workflow
import scrumbringer_client/features/tasks/update as tasks_workflow
import scrumbringer_client/router
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
    client_state.ProjectsFetched(Ok(projects)) -> {
      let selected =
        update_helpers.ensure_selected_project(
          model.core.selected_project_id,
          projects,
        )
      let model =
        client_state.update_core(model, fn(core) {
          client_state.CoreModel(
            ..core,
            projects: client_state.Loaded(projects),
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

    client_state.ProjectsFetched(Error(err)) -> {
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
                client_state.MemberModel(
                  ..member,
                  member_drag: opt.None,
                  member_pool_drag: client_state.PoolDragIdle,
                )
              },
            )
          #(model, replace_url(model))
        }

        False -> #(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(..core, projects: client_state.Failed(err))
          }),
          effect.none(),
        )
      }
    }

    client_state.ProjectCreateDialogOpened ->
      projects_workflow.handle_project_create_dialog_opened(model)
    client_state.ProjectCreateDialogClosed ->
      projects_workflow.handle_project_create_dialog_closed(model)
    client_state.ProjectCreateNameChanged(name) ->
      projects_workflow.handle_project_create_name_changed(model, name)
    client_state.ProjectCreateSubmitted ->
      projects_workflow.handle_project_create_submitted(model)
    client_state.ProjectCreated(Ok(project)) ->
      projects_workflow.handle_project_created_ok(model, project)
    client_state.ProjectCreated(Error(err)) ->
      projects_workflow.handle_project_created_error(model, err)
    // Project Edit (Story 4.8 AC39)
    client_state.ProjectEditDialogOpened(project_id, project_name) ->
      projects_workflow.handle_project_edit_dialog_opened(
        model,
        project_id,
        project_name,
      )
    client_state.ProjectEditDialogClosed ->
      projects_workflow.handle_project_edit_dialog_closed(model)
    client_state.ProjectEditNameChanged(name) ->
      projects_workflow.handle_project_edit_name_changed(model, name)
    client_state.ProjectEditSubmitted ->
      projects_workflow.handle_project_edit_submitted(model)
    client_state.ProjectUpdated(Ok(project)) ->
      projects_workflow.handle_project_updated_ok(model, project)
    client_state.ProjectUpdated(Error(err)) ->
      projects_workflow.handle_project_updated_error(model, err)
    // Project Delete (Story 4.8 AC39)
    client_state.ProjectDeleteConfirmOpened(project_id, project_name) ->
      projects_workflow.handle_project_delete_confirm_opened(
        model,
        project_id,
        project_name,
      )
    client_state.ProjectDeleteConfirmClosed ->
      projects_workflow.handle_project_delete_confirm_closed(model)
    client_state.ProjectDeleteSubmitted ->
      projects_workflow.handle_project_delete_submitted(model)
    client_state.ProjectDeleted(Ok(_)) ->
      projects_workflow.handle_project_deleted_ok(model)
    client_state.ProjectDeleted(Error(err)) ->
      projects_workflow.handle_project_deleted_error(model, err)

    client_state.InviteCreateDialogOpened ->
      invite_links_workflow.handle_invite_create_dialog_opened(model)
    client_state.InviteCreateDialogClosed ->
      invite_links_workflow.handle_invite_create_dialog_closed(model)
    client_state.InviteLinkEmailChanged(value) ->
      invite_links_workflow.handle_invite_link_email_changed(model, value)
    client_state.InviteLinksFetched(Ok(links)) ->
      invite_links_workflow.handle_invite_links_fetched_ok(model, links)
    client_state.InviteLinksFetched(Error(err)) ->
      invite_links_workflow.handle_invite_links_fetched_error(model, err)
    client_state.InviteLinkCreateSubmitted ->
      invite_links_workflow.handle_invite_link_create_submitted(model)
    client_state.InviteLinkRegenerateClicked(email) ->
      invite_links_workflow.handle_invite_link_regenerate_clicked(model, email)
    client_state.InviteLinkCreated(Ok(link)) ->
      invite_links_workflow.handle_invite_link_created_ok(model, link)
    client_state.InviteLinkCreated(Error(err)) ->
      invite_links_workflow.handle_invite_link_created_error(model, err)
    client_state.InviteLinkRegenerated(Ok(link)) ->
      invite_links_workflow.handle_invite_link_regenerated_ok(model, link)
    client_state.InviteLinkRegenerated(Error(err)) ->
      invite_links_workflow.handle_invite_link_regenerated_error(model, err)
    client_state.InviteLinkCopyClicked(text) ->
      invite_links_workflow.handle_invite_link_copy_clicked(model, text)
    client_state.InviteLinkCopyFinished(ok) ->
      invite_links_workflow.handle_invite_link_copy_finished(model, ok)

    client_state.CapabilitiesFetched(Ok(capabilities)) ->
      capabilities_workflow.handle_capabilities_fetched_ok(model, capabilities)
    client_state.CapabilitiesFetched(Error(err)) ->
      capabilities_workflow.handle_capabilities_fetched_error(model, err)
    client_state.CapabilityCreateDialogOpened ->
      capabilities_workflow.handle_capability_dialog_opened(model)
    client_state.CapabilityCreateDialogClosed ->
      capabilities_workflow.handle_capability_dialog_closed(model)
    client_state.CapabilityCreateNameChanged(name) ->
      capabilities_workflow.handle_capability_create_name_changed(model, name)
    client_state.CapabilityCreateSubmitted ->
      capabilities_workflow.handle_capability_create_submitted(model)
    client_state.CapabilityCreated(Ok(capability)) ->
      capabilities_workflow.handle_capability_created_ok(model, capability)
    client_state.CapabilityCreated(Error(err)) ->
      capabilities_workflow.handle_capability_created_error(model, err)
    // Capability delete (Story 4.9 AC9)
    client_state.CapabilityDeleteDialogOpened(capability_id) ->
      capabilities_workflow.handle_capability_delete_dialog_opened(
        model,
        capability_id,
      )
    client_state.CapabilityDeleteDialogClosed ->
      capabilities_workflow.handle_capability_delete_dialog_closed(model)
    client_state.CapabilityDeleteSubmitted ->
      capabilities_workflow.handle_capability_delete_submitted(model)
    client_state.CapabilityDeleted(Ok(deleted_id)) ->
      capabilities_workflow.handle_capability_deleted_ok(model, deleted_id)
    client_state.CapabilityDeleted(Error(err)) ->
      capabilities_workflow.handle_capability_deleted_error(model, err)

    client_state.MembersFetched(Ok(members)) ->
      admin_workflow.handle_members_fetched_ok(model, members)
    client_state.MembersFetched(Error(err)) ->
      admin_workflow.handle_members_fetched_error(model, err)

    client_state.OrgUsersCacheFetched(Ok(users)) -> {
      let #(model, fx) =
        admin_workflow.handle_org_users_cache_fetched_ok(model, users)
      let #(model, assignments_fx) =
        assignments_workflow.start_user_projects_fetch(model, users)
      #(model, effect.batch([fx, assignments_fx]))
    }
    client_state.OrgUsersCacheFetched(Error(err)) ->
      admin_workflow.handle_org_users_cache_fetched_error(model, err)
    client_state.OrgSettingsUsersFetched(Ok(users)) ->
      admin_workflow.handle_org_settings_users_fetched_ok(model, users)

    client_state.OrgSettingsUsersFetched(Error(err)) ->
      admin_workflow.handle_org_settings_users_fetched_error(model, err)
    client_state.OrgSettingsRoleChanged(user_id, org_role) ->
      admin_workflow.handle_org_settings_role_changed(model, user_id, org_role)
    client_state.OrgSettingsSaved(_user_id, Ok(updated)) ->
      admin_workflow.handle_org_settings_saved_ok(model, updated)
    client_state.OrgSettingsSaved(user_id, Error(err)) ->
      admin_workflow.handle_org_settings_saved_error(model, user_id, err)
    client_state.OrgSettingsDeleteClicked(user_id) ->
      admin_workflow.handle_org_settings_delete_clicked(model, user_id)
    client_state.OrgSettingsDeleteCancelled ->
      admin_workflow.handle_org_settings_delete_cancelled(model)
    client_state.OrgSettingsDeleteConfirmed ->
      admin_workflow.handle_org_settings_delete_confirmed(model)
    client_state.OrgSettingsDeleted(Ok(_)) ->
      admin_workflow.handle_org_settings_deleted_ok(model)
    client_state.OrgSettingsDeleted(Error(err)) ->
      admin_workflow.handle_org_settings_deleted_error(model, err)

    client_state.MemberAddDialogOpened ->
      admin_workflow.handle_member_add_dialog_opened(model)
    client_state.MemberAddDialogClosed ->
      admin_workflow.handle_member_add_dialog_closed(model)
    client_state.MemberAddRoleChanged(role_string) -> {
      let role = case project_role.parse(role_string) {
        Ok(r) -> r
        Error(_) -> MemberRole
      }
      admin_workflow.handle_member_add_role_changed(model, role)
    }
    client_state.MemberAddUserSelected(user_id) ->
      admin_workflow.handle_member_add_user_selected(model, user_id)
    client_state.MemberAddSubmitted ->
      admin_workflow.handle_member_add_submitted(model)
    client_state.MemberAdded(Ok(_)) ->
      admin_workflow.handle_member_added_ok(model, refresh_section_for_test)
    client_state.MemberAdded(Error(err)) ->
      admin_workflow.handle_member_added_error(model, err)

    client_state.MemberRemoveClicked(user_id) ->
      admin_workflow.handle_member_remove_clicked(model, user_id)
    client_state.MemberRemoveCancelled ->
      admin_workflow.handle_member_remove_cancelled(model)
    client_state.MemberRemoveConfirmed ->
      admin_workflow.handle_member_remove_confirmed(model)
    client_state.MemberRemoved(Ok(_)) ->
      admin_workflow.handle_member_removed_ok(model, refresh_section_for_test)
    client_state.MemberRemoved(Error(err)) ->
      admin_workflow.handle_member_removed_error(model, err)

    client_state.MemberRoleChangeRequested(user_id, new_role) ->
      admin_workflow.handle_member_role_change_requested(
        model,
        user_id,
        new_role,
      )
    client_state.MemberRoleChanged(Ok(result)) ->
      admin_workflow.handle_member_role_changed_ok(model, result)
    client_state.MemberRoleChanged(Error(err)) ->
      admin_workflow.handle_member_role_changed_error(model, err)

    // client_state.Member capabilities dialog (Story 4.7 AC10-14)
    client_state.MemberCapabilitiesDialogOpened(user_id) ->
      admin_workflow.handle_member_capabilities_dialog_opened(model, user_id)
    client_state.MemberCapabilitiesDialogClosed ->
      admin_workflow.handle_member_capabilities_dialog_closed(model)
    client_state.MemberCapabilitiesToggled(capability_id) ->
      admin_workflow.handle_member_capabilities_toggled(model, capability_id)
    client_state.MemberCapabilitiesSaveClicked ->
      admin_workflow.handle_member_capabilities_save_clicked(model)
    client_state.MemberCapabilitiesFetched(Ok(result)) ->
      admin_workflow.handle_member_capabilities_fetched_ok(model, result)
    client_state.MemberCapabilitiesFetched(Error(err)) ->
      admin_workflow.handle_member_capabilities_fetched_error(model, err)
    client_state.MemberCapabilitiesSaved(Ok(result)) ->
      admin_workflow.handle_member_capabilities_saved_ok(model, result)
    client_state.MemberCapabilitiesSaved(Error(err)) ->
      admin_workflow.handle_member_capabilities_saved_error(model, err)

    // Capability members dialog (Story 4.7 AC16-17)
    client_state.CapabilityMembersDialogOpened(capability_id) ->
      admin_workflow.handle_capability_members_dialog_opened(
        model,
        capability_id,
      )
    client_state.CapabilityMembersDialogClosed ->
      admin_workflow.handle_capability_members_dialog_closed(model)
    client_state.CapabilityMembersToggled(user_id) ->
      admin_workflow.handle_capability_members_toggled(model, user_id)
    client_state.CapabilityMembersSaveClicked ->
      admin_workflow.handle_capability_members_save_clicked(model)
    client_state.CapabilityMembersFetched(Ok(result)) ->
      admin_workflow.handle_capability_members_fetched_ok(model, result)
    client_state.CapabilityMembersFetched(Error(err)) ->
      admin_workflow.handle_capability_members_fetched_error(model, err)
    client_state.CapabilityMembersSaved(Ok(result)) ->
      admin_workflow.handle_capability_members_saved_ok(model, result)
    client_state.CapabilityMembersSaved(Error(err)) ->
      admin_workflow.handle_capability_members_saved_error(model, err)

    client_state.OrgUsersSearchChanged(query) ->
      admin_workflow.handle_org_users_search_changed(model, query)

    client_state.OrgUsersSearchDebounced(query) ->
      admin_workflow.handle_org_users_search_debounced(model, query)
    client_state.OrgUsersSearchResults(token, Ok(users)) ->
      admin_workflow.handle_org_users_search_results_ok(model, token, users)
    client_state.OrgUsersSearchResults(token, Error(err)) ->
      admin_workflow.handle_org_users_search_results_error(model, token, err)

    client_state.AssignmentsViewModeChanged(view_mode) ->
      assignments_workflow.handle_assignments_view_mode_changed(
        model,
        view_mode,
      )
    client_state.AssignmentsSearchChanged(value) ->
      assignments_workflow.handle_assignments_search_changed(model, value)
    client_state.AssignmentsSearchDebounced(value) ->
      assignments_workflow.handle_assignments_search_debounced(model, value)
    client_state.AssignmentsProjectToggled(project_id) ->
      assignments_workflow.handle_assignments_project_toggled(model, project_id)
    client_state.AssignmentsUserToggled(user_id) ->
      assignments_workflow.handle_assignments_user_toggled(model, user_id)
    client_state.AssignmentsProjectMembersFetched(project_id, Ok(members)) ->
      assignments_workflow.handle_assignments_project_members_fetched(
        model,
        project_id,
        Ok(members),
      )
    client_state.AssignmentsProjectMembersFetched(project_id, Error(err)) ->
      assignments_workflow.handle_assignments_project_members_fetched(
        model,
        project_id,
        Error(err),
      )
    client_state.AssignmentsUserProjectsFetched(user_id, Ok(projects)) ->
      assignments_workflow.handle_assignments_user_projects_fetched(
        model,
        user_id,
        Ok(projects),
      )
    client_state.AssignmentsUserProjectsFetched(user_id, Error(err)) ->
      assignments_workflow.handle_assignments_user_projects_fetched(
        model,
        user_id,
        Error(err),
      )
    client_state.AssignmentsInlineAddStarted(context) ->
      assignments_workflow.handle_assignments_inline_add_started(model, context)
    client_state.AssignmentsInlineAddSearchChanged(value) ->
      assignments_workflow.handle_assignments_inline_add_search_changed(
        model,
        value,
      )
    client_state.AssignmentsInlineAddSelectionChanged(value) ->
      assignments_workflow.handle_assignments_inline_add_selection_changed(
        model,
        value,
      )
    client_state.AssignmentsInlineAddRoleChanged(value) ->
      assignments_workflow.handle_assignments_inline_add_role_changed(
        model,
        value,
      )
    client_state.AssignmentsInlineAddSubmitted ->
      assignments_workflow.handle_assignments_inline_add_submitted(model)
    client_state.AssignmentsInlineAddCancelled ->
      assignments_workflow.handle_assignments_inline_add_cancelled(model)
    client_state.AssignmentsProjectMemberAdded(project_id, Ok(member)) ->
      assignments_workflow.handle_assignments_project_member_added_ok(
        model,
        project_id,
        member,
      )
    client_state.AssignmentsProjectMemberAdded(_project_id, Error(err)) ->
      assignments_workflow.handle_assignments_project_member_added_error(
        model,
        err,
      )
    client_state.AssignmentsUserProjectAdded(user_id, Ok(project)) ->
      assignments_workflow.handle_assignments_user_project_added_ok(
        model,
        user_id,
        project,
      )
    client_state.AssignmentsUserProjectAdded(_user_id, Error(err)) ->
      assignments_workflow.handle_assignments_user_project_added_error(
        model,
        err,
      )
    client_state.AssignmentsRemoveClicked(project_id, user_id) ->
      assignments_workflow.handle_assignments_remove_clicked(
        model,
        project_id,
        user_id,
      )
    client_state.AssignmentsRemoveCancelled ->
      assignments_workflow.handle_assignments_remove_cancelled(model)
    client_state.AssignmentsRemoveConfirmed ->
      assignments_workflow.handle_assignments_remove_confirmed(model)
    client_state.AssignmentsRemoveCompleted(project_id, user_id, Ok(_)) ->
      assignments_workflow.handle_assignments_remove_completed_ok(
        model,
        project_id,
        user_id,
      )
    client_state.AssignmentsRemoveCompleted(_project_id, _user_id, Error(err)) ->
      assignments_workflow.handle_assignments_remove_completed_error(model, err)
    client_state.AssignmentsRoleChanged(project_id, user_id, new_role) ->
      assignments_workflow.handle_assignments_role_changed(
        model,
        project_id,
        user_id,
        new_role,
      )
    client_state.AssignmentsRoleChangeCompleted(project_id, user_id, Ok(result)) ->
      assignments_workflow.handle_assignments_role_change_completed_ok(
        model,
        project_id,
        user_id,
        result,
      )
    client_state.AssignmentsRoleChangeCompleted(project_id, user_id, Error(err)) ->
      assignments_workflow.handle_assignments_role_change_completed_error(
        model,
        project_id,
        user_id,
        err,
      )

    client_state.TaskTypesFetched(Ok(task_types)) ->
      task_types_workflow.handle_task_types_fetched_ok(model, task_types)
    client_state.TaskTypesFetched(Error(err)) ->
      task_types_workflow.handle_task_types_fetched_error(model, err)
    client_state.TaskTypeCreateDialogOpened ->
      task_types_workflow.handle_task_type_dialog_opened(model)
    client_state.TaskTypeCreateDialogClosed ->
      task_types_workflow.handle_task_type_dialog_closed(model)
    client_state.TaskTypeCreateNameChanged(name) ->
      task_types_workflow.handle_task_type_create_name_changed(model, name)
    client_state.TaskTypeCreateIconChanged(icon) ->
      task_types_workflow.handle_task_type_create_icon_changed(model, icon)
    client_state.TaskTypeCreateIconSearchChanged(search) ->
      task_types_workflow.handle_task_type_create_icon_search_changed(
        model,
        search,
      )
    client_state.TaskTypeCreateIconCategoryChanged(category) ->
      task_types_workflow.handle_task_type_create_icon_category_changed(
        model,
        category,
      )
    client_state.TaskTypeIconLoaded ->
      task_types_workflow.handle_task_type_icon_loaded(model)
    client_state.TaskTypeIconErrored ->
      task_types_workflow.handle_task_type_icon_errored(model)
    client_state.TaskTypeCreateCapabilityChanged(value) ->
      task_types_workflow.handle_task_type_create_capability_changed(
        model,
        value,
      )
    client_state.TaskTypeCreateSubmitted ->
      task_types_workflow.handle_task_type_create_submitted(model)
    client_state.TaskTypeCreated(Ok(_)) ->
      task_types_workflow.handle_task_type_created_ok(
        model,
        refresh_section_for_test,
      )
    client_state.TaskTypeCreated(Error(err)) ->
      task_types_workflow.handle_task_type_created_error(model, err)
    // Task types - dialog mode control (component pattern)
    client_state.OpenTaskTypeDialog(mode) ->
      task_types_workflow.handle_open_task_type_dialog(model, mode)
    client_state.CloseTaskTypeDialog ->
      task_types_workflow.handle_close_task_type_dialog(model)
    // Task types - component events
    client_state.TaskTypeCrudCreated(task_type) ->
      task_types_workflow.handle_task_type_crud_created(
        model,
        task_type,
        refresh_section_for_test,
      )
    client_state.TaskTypeCrudUpdated(task_type) ->
      task_types_workflow.handle_task_type_crud_updated(model, task_type)
    client_state.TaskTypeCrudDeleted(type_id) ->
      task_types_workflow.handle_task_type_crud_deleted(model, type_id)
  }
}

fn clear_card_new_notes(
  model: client_state.Model,
  card_id: Int,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    case admin.cards {
      client_state.Loaded(cards) ->
        client_state.AdminModel(
          ..admin,
          cards: client_state.Loaded(
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
    client_state.MemberPoolMyTasksRectFetched(left, top, width, height) ->
      pool_workflow.handle_pool_my_tasks_rect_fetched(
        model,
        left,
        top,
        width,
        height,
      )
    client_state.MemberPoolDragToClaimArmed(armed) ->
      pool_workflow.handle_pool_drag_to_claim_armed(model, armed)
    client_state.MemberPoolStatusChanged(v) ->
      pool_workflow.handle_pool_status_changed(model, v, member_refresh)
    client_state.MemberPoolTypeChanged(v) ->
      pool_workflow.handle_pool_type_changed(model, v, member_refresh)
    client_state.MemberPoolCapabilityChanged(v) ->
      pool_workflow.handle_pool_capability_changed(model, v, member_refresh)

    client_state.MemberToggleMyCapabilitiesQuick ->
      pool_workflow.handle_toggle_my_capabilities_quick(model)
    client_state.MemberPoolFiltersToggled ->
      pool_workflow.handle_pool_filters_toggled(model)
    client_state.MemberClearFilters ->
      pool_workflow.handle_clear_filters(model, member_refresh)
    client_state.MemberPoolViewModeSet(mode) ->
      pool_workflow.handle_pool_view_mode_set(model, mode)
    client_state.MemberListHideCompletedToggled -> #(
      client_state.update_member(model, fn(member) {
        client_state.MemberModel(
          ..member,
          member_list_hide_completed: !model.member.member_list_hide_completed,
        )
      }),
      effect.none(),
    )
    // Story 4.8 UX: Collapse/expand card groups in Lista view
    client_state.MemberListCardToggled(card_id) -> {
      let current =
        dict.get(model.member.member_list_expanded_cards, card_id)
        |> opt.from_result
        |> opt.unwrap(True)
      let new_cards =
        dict.insert(model.member.member_list_expanded_cards, card_id, !current)
      #(
        client_state.update_member(model, fn(member) {
          client_state.MemberModel(
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
          client_state.MemberModel(..member, view_mode: mode)
        })
      let route =
        router.Member(
          model.member.member_section,
          model.core.selected_project_id,
          opt.Some(mode),
        )
      #(new_model, router.replace(route))
    }
    client_state.MemberPanelToggled -> #(
      client_state.update_member(model, fn(member) {
        client_state.MemberModel(
          ..member,
          member_panel_expanded: !model.member.member_panel_expanded,
        )
      }),
      effect.none(),
    )
    client_state.MobileLeftDrawerToggled -> #(
      client_state.update_ui(model, fn(ui) {
        client_state.UiModel(
          ..ui,
          mobile_drawer: client_state.toggle_left_drawer(model.ui.mobile_drawer),
        )
      }),
      effect.none(),
    )
    client_state.MobileRightDrawerToggled -> #(
      client_state.update_ui(model, fn(ui) {
        client_state.UiModel(
          ..ui,
          mobile_drawer: client_state.toggle_right_drawer(
            model.ui.mobile_drawer,
          ),
        )
      }),
      effect.none(),
    )
    client_state.MobileDrawersClosed -> #(
      client_state.update_ui(model, fn(ui) {
        client_state.UiModel(
          ..ui,
          mobile_drawer: client_state.close_drawers(model.ui.mobile_drawer),
        )
      }),
      effect.none(),
    )
    client_state.SidebarConfigToggled -> {
      let next_state =
        client_state.toggle_sidebar_config(model.ui.sidebar_collapse)
      #(
        client_state.update_ui(model, fn(ui) {
          client_state.UiModel(..ui, sidebar_collapse: next_state)
        }),
        app_effects.save_sidebar_state(next_state),
      )
    }
    client_state.SidebarOrgToggled -> {
      let next_state =
        client_state.toggle_sidebar_org(model.ui.sidebar_collapse)
      #(
        client_state.update_ui(model, fn(ui) {
          client_state.UiModel(..ui, sidebar_collapse: next_state)
        }),
        app_effects.save_sidebar_state(next_state),
      )
    }
    // Story 4.8 UX: Preferences popup toggle
    client_state.PreferencesPopupToggled -> #(
      client_state.update_ui(model, fn(ui) {
        client_state.UiModel(
          ..ui,
          preferences_popup_open: !model.ui.preferences_popup_open,
        )
      }),
      effect.none(),
    )
    client_state.GlobalKeyDown(event) ->
      pool_workflow.handle_global_keydown(model, event)

    client_state.MemberPoolSearchChanged(v) ->
      pool_workflow.handle_pool_search_changed(model, v)
    client_state.MemberPoolSearchDebounced(v) ->
      pool_workflow.handle_pool_search_debounced(model, v, member_refresh)

    client_state.MemberProjectTasksFetched(project_id, Ok(tasks)) -> {
      let tasks_by_project =
        dict.insert(model.member.member_tasks_by_project, project_id, tasks)
      let pending = model.member.member_tasks_pending - 1

      let model =
        client_state.update_member(model, fn(member) {
          client_state.MemberModel(
            ..member,
            member_tasks_by_project: tasks_by_project,
            member_tasks_pending: pending,
          )
        })

      case pending <= 0 {
        True -> #(
          client_state.update_member(model, fn(member) {
            client_state.MemberModel(
              ..member,
              member_tasks: client_state.Loaded(update_helpers.flatten_tasks(
                tasks_by_project,
              )),
            )
          }),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    client_state.MemberProjectTasksFetched(_project_id, Error(err)) -> {
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
              client_state.MemberModel(
                ..member,
                member_drag: opt.None,
                member_pool_drag: client_state.PoolDragIdle,
              )
            },
          ),
          effect.none(),
        )
        _ -> #(
          client_state.update_member(model, fn(member) {
            client_state.MemberModel(
              ..member,
              member_tasks: client_state.Failed(err),
              member_tasks_pending: 0,
            )
          }),
          effect.none(),
        )
      }
    }

    client_state.MemberTaskTypesFetched(project_id, Ok(task_types)) -> {
      let task_types_by_project =
        dict.insert(
          model.member.member_task_types_by_project,
          project_id,
          task_types,
        )
      let pending = model.member.member_task_types_pending - 1

      let model =
        client_state.update_member(model, fn(member) {
          client_state.MemberModel(
            ..member,
            member_task_types_by_project: task_types_by_project,
            member_task_types_pending: pending,
          )
        })

      case pending <= 0 {
        True -> #(
          client_state.update_member(model, fn(member) {
            client_state.MemberModel(
              ..member,
              member_task_types: client_state.Loaded(
                update_helpers.flatten_task_types(task_types_by_project),
              ),
            )
          }),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    client_state.MemberTaskTypesFetched(_project_id, Error(err)) -> {
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
              client_state.MemberModel(
                ..member,
                member_drag: opt.None,
                member_pool_drag: client_state.PoolDragIdle,
              )
            },
          ),
          effect.none(),
        )
        _ -> #(
          client_state.update_member(model, fn(member) {
            client_state.MemberModel(
              ..member,
              member_task_types: client_state.Failed(err),
              member_task_types_pending: 0,
            )
          }),
          effect.none(),
        )
      }
    }

    client_state.MemberCanvasRectFetched(left, top) ->
      pool_workflow.handle_canvas_rect_fetched(model, left, top)
    client_state.MemberDragStarted(task_id, offset_x, offset_y) ->
      pool_workflow.handle_drag_started(model, task_id, offset_x, offset_y)
    client_state.MemberDragMoved(client_x, client_y) ->
      pool_workflow.handle_drag_moved(model, client_x, client_y)
    client_state.MemberDragEnded -> pool_workflow.handle_drag_ended(model)

    client_state.MemberCreateDialogOpened ->
      tasks_workflow.handle_create_dialog_opened(model)
    client_state.MemberCreateDialogOpenedWithCard(card_id) ->
      tasks_workflow.handle_create_dialog_opened_with_card(model, card_id)
    client_state.MemberCreateDialogClosed ->
      tasks_workflow.handle_create_dialog_closed(model)
    client_state.MemberCreateTitleChanged(v) ->
      tasks_workflow.handle_create_title_changed(model, v)
    client_state.MemberCreateDescriptionChanged(v) ->
      tasks_workflow.handle_create_description_changed(model, v)
    client_state.MemberCreatePriorityChanged(v) ->
      tasks_workflow.handle_create_priority_changed(model, v)
    client_state.MemberCreateTypeIdChanged(v) ->
      tasks_workflow.handle_create_type_id_changed(model, v)
    client_state.MemberCreateCardIdChanged(v) ->
      tasks_workflow.handle_create_card_id_changed(model, v)

    client_state.MemberCreateSubmitted ->
      tasks_workflow.handle_create_submitted(model, member_refresh)

    client_state.MemberTaskCreated(Ok(_)) ->
      tasks_workflow.handle_task_created_ok(model, member_refresh)
    client_state.MemberTaskCreated(Error(err)) ->
      tasks_workflow.handle_task_created_error(model, err)

    client_state.MemberClaimClicked(task_id, version) ->
      tasks_workflow.handle_claim_clicked(model, task_id, version)
    client_state.MemberReleaseClicked(task_id, version) ->
      tasks_workflow.handle_release_clicked(model, task_id, version)
    client_state.MemberCompleteClicked(task_id, version) ->
      tasks_workflow.handle_complete_clicked(model, task_id, version)

    client_state.MemberTaskClaimed(Ok(_)) ->
      tasks_workflow.handle_task_claimed_ok(model, member_refresh)
    client_state.MemberTaskReleased(Ok(_)) ->
      tasks_workflow.handle_task_released_ok(model, member_refresh)
    client_state.MemberTaskCompleted(Ok(_)) ->
      tasks_workflow.handle_task_completed_ok(model, member_refresh)

    client_state.MemberTaskClaimed(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    client_state.MemberTaskReleased(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    client_state.MemberTaskCompleted(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)

    client_state.MemberNowWorkingStartClicked(task_id) ->
      now_working_workflow.handle_start_clicked(model, task_id)
    client_state.MemberNowWorkingPauseClicked ->
      now_working_workflow.handle_pause_clicked(model)

    // Work sessions (multi-session) - delegate to workflow
    client_state.MemberWorkSessionsFetched(Ok(payload)) ->
      now_working_workflow.handle_sessions_fetched_ok(model, payload)
    client_state.MemberWorkSessionsFetched(Error(err)) ->
      now_working_workflow.handle_sessions_fetched_error(model, err)

    client_state.MemberWorkSessionStarted(Ok(payload)) ->
      now_working_workflow.handle_session_started_ok(model, payload)
    client_state.MemberWorkSessionStarted(Error(err)) ->
      now_working_workflow.handle_session_started_error(model, err)

    client_state.MemberWorkSessionPaused(Ok(payload)) ->
      now_working_workflow.handle_session_paused_ok(model, payload)
    client_state.MemberWorkSessionPaused(Error(err)) ->
      now_working_workflow.handle_session_paused_error(model, err)

    client_state.MemberWorkSessionHeartbeated(Ok(payload)) ->
      now_working_workflow.handle_session_heartbeated_ok(model, payload)
    client_state.MemberWorkSessionHeartbeated(Error(err)) ->
      now_working_workflow.handle_session_heartbeated_error(model, err)

    client_state.MemberMetricsFetched(Ok(metrics)) ->
      metrics_workflow.handle_member_metrics_fetched_ok(model, metrics)
    client_state.MemberMetricsFetched(Error(err)) ->
      metrics_workflow.handle_member_metrics_fetched_error(model, err)

    client_state.AdminMetricsOverviewFetched(Ok(overview)) ->
      metrics_workflow.handle_admin_overview_fetched_ok(model, overview)
    client_state.AdminMetricsOverviewFetched(Error(err)) ->
      metrics_workflow.handle_admin_overview_fetched_error(model, err)

    client_state.AdminMetricsProjectTasksFetched(Ok(payload)) ->
      metrics_workflow.handle_admin_project_tasks_fetched_ok(model, payload)
    client_state.AdminMetricsProjectTasksFetched(Error(err)) ->
      metrics_workflow.handle_admin_project_tasks_fetched_error(model, err)

    // Rule metrics tab
    client_state.AdminRuleMetricsFetched(Ok(metrics)) ->
      admin_workflow.handle_rule_metrics_tab_fetched_ok(model, metrics)
    client_state.AdminRuleMetricsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_tab_fetched_error(model, err)
    client_state.AdminRuleMetricsFromChanged(from) ->
      admin_workflow.handle_rule_metrics_tab_from_changed(model, from)
    client_state.AdminRuleMetricsToChanged(to) ->
      admin_workflow.handle_rule_metrics_tab_to_changed(model, to)
    client_state.AdminRuleMetricsFromChangedAndRefresh(from) ->
      admin_workflow.handle_rule_metrics_tab_from_changed_and_refresh(
        model,
        from,
      )
    client_state.AdminRuleMetricsToChangedAndRefresh(to) ->
      admin_workflow.handle_rule_metrics_tab_to_changed_and_refresh(model, to)
    client_state.AdminRuleMetricsRefreshClicked ->
      admin_workflow.handle_rule_metrics_tab_refresh_clicked(model)
    client_state.AdminRuleMetricsQuickRangeClicked(from, to) ->
      admin_workflow.handle_rule_metrics_tab_quick_range_clicked(
        model,
        from,
        to,
      )
    // Rule metrics drill-down
    client_state.AdminRuleMetricsWorkflowExpanded(workflow_id) ->
      admin_workflow.handle_rule_metrics_workflow_expanded(model, workflow_id)
    client_state.AdminRuleMetricsWorkflowDetailsFetched(Ok(details)) ->
      admin_workflow.handle_rule_metrics_workflow_details_fetched_ok(
        model,
        details,
      )
    client_state.AdminRuleMetricsWorkflowDetailsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_workflow_details_fetched_error(
        model,
        err,
      )
    client_state.AdminRuleMetricsDrilldownClicked(rule_id) ->
      admin_workflow.handle_rule_metrics_drilldown_clicked(model, rule_id)
    client_state.AdminRuleMetricsDrilldownClosed ->
      admin_workflow.handle_rule_metrics_drilldown_closed(model)
    client_state.AdminRuleMetricsRuleDetailsFetched(Ok(details)) ->
      admin_workflow.handle_rule_metrics_rule_details_fetched_ok(model, details)
    client_state.AdminRuleMetricsRuleDetailsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_rule_details_fetched_error(model, err)
    client_state.AdminRuleMetricsExecutionsFetched(Ok(response)) ->
      admin_workflow.handle_rule_metrics_executions_fetched_ok(model, response)
    client_state.AdminRuleMetricsExecutionsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_executions_fetched_error(model, err)
    client_state.AdminRuleMetricsExecPageChanged(offset) ->
      admin_workflow.handle_rule_metrics_exec_page_changed(model, offset)

    client_state.NowWorkingTicked -> now_working_workflow.handle_ticked(model)

    client_state.MemberMyCapabilityIdsFetched(Ok(ids)) ->
      skills_workflow.handle_my_capability_ids_fetched_ok(model, ids)
    client_state.MemberMyCapabilityIdsFetched(Error(err)) ->
      skills_workflow.handle_my_capability_ids_fetched_error(model, err)

    client_state.MemberToggleCapability(id) ->
      skills_workflow.handle_toggle_capability(model, id)
    client_state.MemberSaveCapabilitiesClicked ->
      skills_workflow.handle_save_capabilities_clicked(model)

    client_state.MemberMyCapabilityIdsSaved(Ok(ids)) ->
      skills_workflow.handle_save_capabilities_ok(model, ids)
    client_state.MemberMyCapabilityIdsSaved(Error(err)) ->
      skills_workflow.handle_save_capabilities_error(model, err)

    client_state.MemberPositionsFetched(Ok(positions)) ->
      pool_workflow.handle_positions_fetched_ok(model, positions)
    client_state.MemberPositionsFetched(Error(err)) ->
      pool_workflow.handle_positions_fetched_error(model, err)

    client_state.MemberPositionEditOpened(task_id) ->
      pool_workflow.handle_position_edit_opened(model, task_id)
    client_state.MemberPositionEditClosed ->
      pool_workflow.handle_position_edit_closed(model)
    client_state.MemberPositionEditXChanged(v) ->
      pool_workflow.handle_position_edit_x_changed(model, v)
    client_state.MemberPositionEditYChanged(v) ->
      pool_workflow.handle_position_edit_y_changed(model, v)
    client_state.MemberPositionEditSubmitted ->
      pool_workflow.handle_position_edit_submitted(model)

    client_state.MemberPositionSaved(Ok(pos)) ->
      pool_workflow.handle_position_saved_ok(model, pos)
    client_state.MemberPositionSaved(Error(err)) ->
      pool_workflow.handle_position_saved_error(model, err)

    client_state.MemberTaskDetailsOpened(task_id) ->
      tasks_workflow.handle_task_details_opened(model, task_id)
    client_state.MemberTaskDetailsClosed ->
      tasks_workflow.handle_task_details_closed(model)

    client_state.MemberNotesFetched(Ok(notes)) ->
      tasks_workflow.handle_notes_fetched_ok(model, notes)
    client_state.MemberNotesFetched(Error(err)) ->
      tasks_workflow.handle_notes_fetched_error(model, err)

    client_state.MemberNoteContentChanged(v) ->
      tasks_workflow.handle_note_content_changed(model, v)
    client_state.MemberNoteSubmitted ->
      tasks_workflow.handle_note_submitted(model)

    client_state.MemberNoteAdded(Ok(note)) ->
      tasks_workflow.handle_note_added_ok(model, note)
    client_state.MemberNoteAdded(Error(err)) ->
      tasks_workflow.handle_note_added_error(model, err)

    // Cards (Fichas) handlers - list loading and dialog mode
    client_state.CardsFetched(Ok(cards)) ->
      admin_workflow.handle_cards_fetched_ok(model, cards)
    client_state.CardsFetched(Error(err)) ->
      admin_workflow.handle_cards_fetched_error(model, err)
    client_state.OpenCardDialog(mode) ->
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
        client_state.AdminModel(
          ..admin,
          cards_show_empty: !model.admin.cards_show_empty,
        )
      }),
      effect.none(),
    )
    client_state.CardsShowCompletedToggled -> #(
      client_state.update_admin(model, fn(admin) {
        client_state.AdminModel(
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
          client_state.AdminModel(..admin, cards_state_filter: filter)
        }),
        effect.none(),
      )
    }
    client_state.CardsSearchChanged(query) -> #(
      client_state.update_admin(model, fn(admin) {
        client_state.AdminModel(..admin, cards_search: query)
      }),
      effect.none(),
    )

    // Card detail (member view) handlers - component manages internal state
    client_state.OpenCardDetail(card_id) -> {
      let model =
        client_state.update_member(model, fn(member) {
          client_state.MemberModel(
            ..member,
            card_detail_open: opt.Some(card_id),
          )
        })
        |> clear_card_new_notes(card_id)

      let fx = api_cards.mark_card_view(card_id, fn(_res) { client_state.NoOp })

      #(model, fx)
    }
    client_state.CloseCardDetail -> #(
      client_state.update_member(model, fn(member) {
        client_state.MemberModel(..member, card_detail_open: opt.None)
      }),
      effect.none(),
    )

    // Workflows handlers
    client_state.WorkflowsProjectFetched(Ok(workflows)) ->
      admin_workflow.handle_workflows_project_fetched_ok(model, workflows)
    client_state.WorkflowsProjectFetched(Error(err)) ->
      admin_workflow.handle_workflows_project_fetched_error(model, err)
    // Workflow dialog control (component pattern)
    client_state.OpenWorkflowDialog(mode) ->
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
    client_state.RulesFetched(Ok(rules)) ->
      admin_workflow.handle_rules_fetched_ok(model, rules)
    client_state.RulesFetched(Error(err)) ->
      admin_workflow.handle_rules_fetched_error(model, err)
    client_state.RulesBackClicked ->
      admin_workflow.handle_rules_back_clicked(model)
    client_state.RuleMetricsFetched(Ok(metrics)) ->
      admin_workflow.handle_rule_metrics_fetched_ok(model, metrics)
    client_state.RuleMetricsFetched(Error(err)) ->
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
    client_state.RuleTemplatesClicked(_rule_id) -> #(model, effect.none())
    client_state.RuleTemplatesFetched(Ok(templates)) ->
      admin_workflow.handle_rule_templates_fetched_ok(model, templates)
    client_state.RuleTemplatesFetched(Error(err)) ->
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
    client_state.TaskTemplatesProjectFetched(Ok(templates)) ->
      admin_workflow.handle_task_templates_project_fetched_ok(model, templates)
    client_state.TaskTemplatesProjectFetched(Error(err)) ->
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
