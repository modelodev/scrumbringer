//// Admin section views.
////
//// ## Mission
////
//// Renders admin panel views for organization and project administration.
////
//// ## Responsibilities
////
//// - Organization settings view (role management)
//// - Capabilities management view
//// - Project members management view
//// - Task types management view
////
//// ## Structure Note
////
//// Members and automation-related views live in `features/admin/views/*`.
//// This module keeps core admin views and delegates to those submodules.
////
//// ## Relations
////
//// - **client_view.gleam**: Dispatches to admin views from view_section
//// - **features/admin/update.gleam**: Handles admin-related messages
//// - **client_state.gleam**: Provides Model, Msg, Remote types

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import domain/card as domain_card
import domain/project.{type Project}
import domain/remote.{Loaded}
import domain/task as domain_task

import scrumbringer_client/client_state.{
  type Model, type Msg, NoOp, admin_msg, pool_msg,
}
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/features/admin/api_tokens_view
import scrumbringer_client/features/admin/capabilities_view
import scrumbringer_client/features/admin/cards_view
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/org_settings_view
import scrumbringer_client/features/admin/task_types_view
import scrumbringer_client/features/admin/views/members as members_view
import scrumbringer_client/features/cards/show_entry
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/utils/card_queries

import scrumbringer_client/client_state/selectors as state_selectors
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions

// =============================================================================
// =============================================================================
// Public API
// =============================================================================

/// Organization settings view - manage user roles.
pub fn view_org_settings(model: Model) -> Element(Msg) {
  org_settings_view.view(org_settings_config(model))
}

/// API token management view.
pub fn view_api_tokens(model: Model) -> Element(Msg) {
  api_tokens_view.view(api_tokens_config(model))
}

fn api_tokens_config(model: Model) -> api_tokens_view.Config(Msg) {
  api_tokens_view.Config(
    locale: model.ui.locale,
    model: model.admin.api_tokens,
    projects: state_selectors.active_projects(model),
    on_token_create_opened: admin_msg(admin_messages.ApiTokenCreateDialogOpened),
    on_token_create_closed: admin_msg(admin_messages.ApiTokenCreateDialogClosed),
    on_token_name_changed: fn(value) {
      admin_msg(admin_messages.ApiTokenNameChanged(value))
    },
    on_token_integration_changed: fn(value) {
      admin_msg(admin_messages.ApiTokenIntegrationChanged(value))
    },
    on_token_project_changed: fn(value) {
      admin_msg(admin_messages.ApiTokenProjectChanged(value))
    },
    on_token_scope_toggled: fn(scope) {
      admin_msg(admin_messages.ApiTokenScopeToggled(scope))
    },
    on_token_expires_at_changed: fn(value) {
      admin_msg(admin_messages.ApiTokenExpiresAtChanged(value))
    },
    on_token_create_submitted: admin_msg(admin_messages.ApiTokenCreateSubmitted),
    on_token_secret_dismissed: admin_msg(
      admin_messages.ApiTokenCreatedSecretDismissed,
    ),
    on_token_secret_copy_clicked: fn(secret) {
      admin_msg(admin_messages.ApiTokenCreatedSecretCopyClicked(secret))
    },
    on_token_rename_clicked: fn(id, name) {
      admin_msg(admin_messages.ApiTokenRenameClicked(id, name))
    },
    on_token_rename_cancelled: admin_msg(admin_messages.ApiTokenRenameCancelled),
    on_token_rename_name_changed: fn(value) {
      admin_msg(admin_messages.ApiTokenRenameNameChanged(value))
    },
    on_token_rename_submitted: admin_msg(admin_messages.ApiTokenRenameSubmitted),
    on_token_revoke_clicked: fn(id) {
      admin_msg(admin_messages.ApiTokenRevokeClicked(id))
    },
    on_token_revoke_cancelled: admin_msg(admin_messages.ApiTokenRevokeCancelled),
    on_token_revoke_confirmed: admin_msg(admin_messages.ApiTokenRevokeConfirmed),
    on_integration_deactivate_clicked: fn(id) {
      admin_msg(admin_messages.IntegrationDeactivateClicked(id))
    },
    on_integration_deactivate_cancelled: admin_msg(
      admin_messages.IntegrationDeactivateCancelled,
    ),
    on_integration_deactivate_confirmed: admin_msg(
      admin_messages.IntegrationDeactivateConfirmed,
    ),
  )
}

fn org_settings_config(model: Model) -> org_settings_view.Config(Msg) {
  org_settings_view.Config(
    locale: model.ui.locale,
    model: model.admin.members,
    current_user_id: model.core.user |> opt.map(fn(user) { user.id }),
    on_role_changed: fn(user_id, role) {
      admin_msg(admin_messages.OrgSettingsRoleChanged(user_id, role))
    },
    on_invalid_role: NoOp,
    on_delete_clicked: fn(user_id) {
      admin_msg(admin_messages.OrgSettingsDeleteClicked(user_id))
    },
    on_delete_cancelled: admin_msg(admin_messages.OrgSettingsDeleteCancelled),
    on_delete_confirmed: admin_msg(admin_messages.OrgSettingsDeleteConfirmed),
  )
}

/// Capabilities management view.
pub fn view_capabilities(model: Model) -> Element(Msg) {
  capabilities_view.view(capabilities_config(model))
}

fn capabilities_config(model: Model) -> capabilities_view.Config(Msg) {
  let project_name = case state_selectors.selected_project(model) {
    opt.Some(project) -> project.name
    opt.None -> ""
  }

  capabilities_view.Config(
    locale: model.ui.locale,
    capabilities: model.admin.capabilities,
    members: model.admin.members,
    selected_project_name: project_name,
    on_create_opened: admin_msg(admin_messages.CapabilityCreateDialogOpened),
    on_create_closed: admin_msg(admin_messages.CapabilityCreateDialogClosed),
    on_create_name_changed: fn(value) {
      admin_msg(admin_messages.CapabilityCreateNameChanged(value))
    },
    on_create_submitted: admin_msg(admin_messages.CapabilityCreateSubmitted),
    on_edit_opened: fn(id, name) {
      admin_msg(admin_messages.CapabilityEditDialogOpened(id, name))
    },
    on_edit_closed: admin_msg(admin_messages.CapabilityEditDialogClosed),
    on_edit_name_changed: fn(value) {
      admin_msg(admin_messages.CapabilityEditNameChanged(value))
    },
    on_edit_submitted: admin_msg(admin_messages.CapabilityEditSubmitted),
    on_delete_opened: fn(id) {
      admin_msg(admin_messages.CapabilityDeleteDialogOpened(id))
    },
    on_delete_closed: admin_msg(admin_messages.CapabilityDeleteDialogClosed),
    on_delete_submitted: admin_msg(admin_messages.CapabilityDeleteSubmitted),
    on_members_opened: fn(id) {
      admin_msg(admin_messages.CapabilityMembersDialogOpened(id))
    },
    on_members_closed: admin_msg(admin_messages.CapabilityMembersDialogClosed),
    on_member_toggled: fn(id) {
      admin_msg(admin_messages.CapabilityMembersToggled(id))
    },
    on_members_save_clicked: admin_msg(
      admin_messages.CapabilityMembersSaveClicked,
    ),
  )
}

/// Project members management view.
pub fn view_members(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  members_view.view_members(members_config(model, selected_project))
}

fn members_config(
  model: Model,
  selected_project: opt.Option(Project),
) -> members_view.Config(Msg) {
  let current_user_id = model.core.user |> opt.map(fn(user) { user.id })
  let is_org_admin = case model.core.user {
    opt.Some(user) -> permissions.is_org_admin(user.org_role)
    opt.None -> False
  }

  members_view.Config(
    locale: model.ui.locale,
    selected_project: selected_project,
    members: model.admin.members,
    capabilities: model.admin.capabilities,
    current_user_id: current_user_id,
    is_org_admin: is_org_admin,
    on_add_dialog_opened: admin_msg(admin_messages.MemberAddDialogOpened),
    on_add_dialog_closed: admin_msg(admin_messages.MemberAddDialogClosed),
    on_org_users_search_changed: fn(value) {
      admin_msg(admin_messages.OrgUsersSearchDebounced(value))
    },
    on_member_add_user_selected: fn(id) {
      admin_msg(admin_messages.MemberAddUserSelected(id))
    },
    on_member_add_role_changed: fn(role) {
      admin_msg(admin_messages.MemberAddRoleChanged(role))
    },
    on_member_add_submitted: admin_msg(admin_messages.MemberAddSubmitted),
    on_member_remove_clicked: fn(id) {
      admin_msg(admin_messages.MemberRemoveClicked(id))
    },
    on_member_remove_confirmed: admin_msg(admin_messages.MemberRemoveConfirmed),
    on_member_remove_cancelled: admin_msg(admin_messages.MemberRemoveCancelled),
    on_member_release_all_clicked: fn(id, count) {
      admin_msg(admin_messages.MemberReleaseAllClicked(id, count))
    },
    on_member_release_all_confirmed: admin_msg(
      admin_messages.MemberReleaseAllConfirmed,
    ),
    on_member_release_all_cancelled: admin_msg(
      admin_messages.MemberReleaseAllCancelled,
    ),
    on_member_role_change_requested: fn(id, role) {
      admin_msg(admin_messages.MemberRoleChangeRequested(id, role))
    },
    on_member_capabilities_opened: fn(id) {
      admin_msg(admin_messages.MemberCapabilitiesDialogOpened(id))
    },
    on_member_capabilities_closed: admin_msg(
      admin_messages.MemberCapabilitiesDialogClosed,
    ),
    on_member_capabilities_toggled: fn(id) {
      admin_msg(admin_messages.MemberCapabilitiesToggled(id))
    },
    on_member_capabilities_save_clicked: admin_msg(
      admin_messages.MemberCapabilitiesSaveClicked,
    ),
    on_invalid_role: NoOp,
  )
}

/// Task types management view.
pub fn view_task_types(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(i18n.t(model.ui.locale, i18n_text.SelectProjectToManageTaskTypes)),
      ])

    opt.Some(project) -> task_types_view.view(task_types_config(model, project))
  }
}

fn task_types_config(
  model: Model,
  project: Project,
) -> task_types_view.Config(Msg) {
  task_types_view.Config(
    locale: model.ui.locale,
    theme: model.ui.theme,
    project_id: project.id,
    project_name: project.name,
    model: model.admin.task_types,
    capabilities: model.admin.capabilities.capabilities,
    on_create_opened: admin_msg(admin_messages.OpenTaskTypeDialog(
      admin_task_types.TaskTypeDialogCreate,
    )),
    on_edit_opened: fn(task_type) {
      admin_msg(
        admin_messages.OpenTaskTypeDialog(admin_task_types.TaskTypeDialogEdit(
          task_type,
        )),
      )
    },
    on_delete_opened: fn(task_type) {
      admin_msg(
        admin_messages.OpenTaskTypeDialog(admin_task_types.TaskTypeDialogDelete(
          task_type,
        )),
      )
    },
    on_dialog_closed: admin_msg(admin_messages.CloseTaskTypeDialog),
    on_crud_created: fn(task_type) {
      admin_msg(admin_messages.TaskTypeCrudCreated(task_type))
    },
    on_crud_updated: fn(task_type) {
      admin_msg(admin_messages.TaskTypeCrudUpdated(task_type))
    },
    on_crud_deleted: fn(id) {
      admin_msg(admin_messages.TaskTypeCrudDeleted(id))
    },
  )
}

// =============================================================================
// Cards Views
// =============================================================================

/// Cards management view.
pub fn view_cards(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(i18n.t(model.ui.locale, i18n_text.SelectProjectToManageCards)),
      ])

    opt.Some(project) ->
      cards_view.view(cards_config(
        model,
        project.id,
        project.name,
        view_card_show(model, project),
      ))
  }
}

/// Render the card-crud-dialog Lustre component.
/// Made public for use in client_view.gleam (Story 4.8 UX: global dialog rendering)
pub fn view_card_crud_dialog(model: Model, project_id: Int) -> Element(Msg) {
  cards_view.view_crud_dialog(cards_config(
    model,
    project_id,
    "",
    element.none(),
  ))
}

fn cards_config(
  model: Model,
  project_id: Int,
  project_name: String,
  detail_modal: Element(Msg),
) -> cards_view.Config(Msg) {
  cards_view.Config(
    locale: model.ui.locale,
    project_id: project_id,
    project_name: project_name,
    model: model.admin.cards,
    detail_modal: detail_modal,
    on_create_opened: pool_msg(
      pool_messages.OpenCardDialog(admin_cards.CardDialogCreate(opt.None)),
    ),
    on_search_changed: fn(value) {
      pool_msg(pool_messages.CardsSearchChanged(value))
    },
    on_state_filter_changed: fn(value) {
      pool_msg(pool_messages.CardsStateFilterChanged(value))
    },
    on_show_empty_toggled: pool_msg(pool_messages.CardsShowEmptyToggled),
    on_show_closed_toggled: pool_msg(pool_messages.CardsShowClosedToggled),
    on_detail_opened: fn(id) { pool_msg(pool_messages.OpenCardShow(id)) },
    on_task_create_opened: fn(id) {
      pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(id))
    },
    on_edit_opened: fn(id) {
      pool_msg(pool_messages.OpenCardDialog(admin_cards.CardDialogEdit(id)))
    },
    on_delete_opened: fn(id) {
      pool_msg(pool_messages.OpenCardDialog(admin_cards.CardDialogDelete(id)))
    },
    on_dialog_closed: pool_msg(pool_messages.CloseCardDialog),
    on_card_created: fn(card) { pool_msg(pool_messages.CardCrudCreated(card)) },
    on_card_updated: fn(card) { pool_msg(pool_messages.CardCrudUpdated(card)) },
    on_card_deleted: fn(id) { pool_msg(pool_messages.CardCrudDeleted(id)) },
  )
}

// =============================================================================
// Card Show (Config Cards)
// =============================================================================

fn view_card_show(model: Model, project: Project) -> Element(Msg) {
  let is_org_admin = case model.core.user {
    opt.Some(user) -> permissions.is_org_admin(user.org_role)
    opt.None -> False
  }

  show_entry.view(
    show_entry.Config(
      model: model.member.card_show_model,
      card: selected_show_card(model),
      cards: admin_cards_list(model),
      tasks: selected_show_card_tasks(model),
      locale: model.ui.locale,
      current_user_id: model.core.user |> opt.map(fn(user) { user.id }),
      can_manage_notes: is_org_admin || permissions.is_project_manager(project),
      can_manage_structure: is_org_admin
        || permissions.is_project_manager(project),
      can_execute_work: True,
      on_card_show_msg: fn(msg) { pool_msg(pool_messages.CardShowMsg(msg)) },
    ),
  )
}

fn admin_cards_list(model: Model) -> List(domain_card.Card) {
  case model.admin.cards.cards {
    Loaded(cards) -> cards
    _ -> []
  }
}

fn selected_show_card(model: Model) -> opt.Option(domain_card.Card) {
  case model.member.card_show_open {
    opt.Some(card_id) ->
      card_queries.find_card(
        model.member.pool.member_cards_store,
        model.admin.cards.cards,
        card_id,
      )
    opt.None -> opt.None
  }
}

fn selected_show_card_tasks(model: Model) -> List(domain_task.Task) {
  case model.member.card_show_open {
    opt.Some(card_id) ->
      show_entry.tasks_for_card(model.member.pool.member_tasks, card_id)
    opt.None -> []
  }
}
