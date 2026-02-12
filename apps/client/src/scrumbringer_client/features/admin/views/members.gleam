//// Admin members management views.
////
//// ## Mission
////
//// Render project members management views and dialogs.
////
//// ## Responsibilities
////
//// - Members list and actions
//// - Add/remove member dialogs
//// - Member capabilities dialog
////
//// ## Relations
////
//// - **features/admin/view.gleam**: Delegates to this module
//// - **features/admin/update.gleam**: Handles member-related messages
//// - **client_state.gleam**: Provides Model/Msg types

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, input, label, option, p, select, span, text,
}
import lustre/event

import domain/capability.{type Capability}
import domain/org.{type OrgUser}
import domain/org_role
import domain/project.{type Project, type ProjectMember}
import domain/project_role.{Manager, Member}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}

import scrumbringer_client/client_state.{type Model, type Msg, admin_msg}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/confirm_dialog
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icon_actions
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/search_select
import scrumbringer_client/ui/section_header

// =============================================================================
// Members View
// =============================================================================

// Justification: nested case improves clarity for branching logic.
/// Project members management view.
pub fn view_members(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(helpers_i18n.i18n_t(model, i18n_text.SelectProjectToManageMembers)),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        // Section header with subtitle and action (Story 4.8: consistent icons + help text)
        section_header.view_full(
          icons.Team,
          helpers_i18n.i18n_t(model, i18n_text.MembersTitle(project.name)),
          helpers_i18n.i18n_t(model, i18n_text.MembersHelp),
          dialog.add_button(
            model,
            i18n_text.AddMember,
            admin_msg(admin_messages.MemberAddDialogOpened),
          ),
        ),
        // Members list
        case model.admin.members.members_remove_error {
          opt.Some(err) -> error_notice.view(err)
          opt.None -> element.none()
        },
        view_members_table(
          model,
          model.admin.members.members,
          model.admin.members.org_users_cache,
        ),
        case model.admin.members.members_release_confirm {
          opt.Some(target) ->
            view_release_all_dialog(model, project.name, target)
          opt.None -> element.none()
        },
        // Add member dialog
        case model.admin.members.members_add_dialog_mode {
          dialog_mode.DialogCreate -> view_add_member_dialog(model)
          _ -> element.none()
        },
        // Remove member confirmation dialog
        case model.admin.members.members_remove_confirm {
          opt.Some(user) -> view_remove_member_dialog(model, project.name, user)
          opt.None -> element.none()
        },
        // Member capabilities dialog (AC11-14, Story 4.8 AC23)
        case model.admin.capabilities.member_capabilities_dialog_user_id {
          opt.Some(user_id) ->
            view_member_capabilities_dialog(model, user_id, project.name)
          opt.None -> element.none()
        },
      ])
  }
}

// =============================================================================
// Members Helpers
// =============================================================================

fn view_members_table(
  model: Model,
  members: Remote(List(ProjectMember)),
  cache: Remote(List(OrgUser)),
) -> Element(Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }

  // Check if current user is org admin (can change roles)
  let is_org_admin = case model.core.user {
    opt.Some(user) -> user.org_role == org_role.Admin
    opt.None -> False
  }

  // Helper to resolve user email from cache
  let resolve_email = fn(user_id: Int) -> String {
    case helpers_lookup.resolve_org_user(cache, user_id) {
      opt.Some(user) -> user.email
      opt.None -> t(i18n_text.UserNumber(user_id))
    }
  }

  // Helper to get capability count from cache
  let get_cap_count = fn(user_id: Int) -> Int {
    case dict.get(model.admin.capabilities.member_capabilities_cache, user_id) {
      Ok(ids) -> list.length(ids)
      Error(_) -> 0
    }
  }

  data_table.view_remote_with_forbidden(
    members,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoMembersYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // User email
        data_table.column(t(i18n_text.User), fn(m: ProjectMember) {
          text(resolve_email(m.user_id))
        }),
        // Role (dropdown for admins, text for others)
        data_table.column(t(i18n_text.Role), fn(m: ProjectMember) {
          view_member_role_cell(model, m, is_org_admin)
        }),
        // Capabilities count (AC15)
        data_table.column_with_class(
          t(i18n_text.Capabilities),
          fn(m: ProjectMember) {
            badge.new_unchecked(
              int.to_string(get_cap_count(m.user_id)),
              badge.Neutral,
            )
            |> badge.view_with_class("count-badge")
          },
          "col-number",
          "cell-number",
        ),
        data_table.column_with_class(
          t(i18n_text.Claimed),
          fn(m: ProjectMember) { view_member_claimed_count(m) },
          "col-number",
          "cell-number",
        ),
        // Actions (Story 4.8 UX)
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(m: ProjectMember) { view_member_actions(model, m) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(m: ProjectMember) { int.to_string(m.user_id) }),
  )
}

fn view_member_actions(model: Model, m: ProjectMember) -> Element(Msg) {
  let count = m.claimed_count
  let is_self = case model.core.user {
    opt.Some(user) -> user.id == m.user_id
    opt.None -> False
  }
  let can_release = count > 0 && is_self == False
  let is_loading =
    model.admin.members.members_release_in_flight == opt.Some(m.user_id)

  div([attribute.class("actions-row")], [
    action_buttons.task_icon_button(
      helpers_i18n.i18n_t(model, i18n_text.ManageCapabilities),
      admin_msg(admin_messages.MemberCapabilitiesDialogOpened(m.user_id)),
      icons.Cog,
      action_buttons.SizeXs,
      False,
      "",
      opt.None,
      opt.Some("member-capabilities-btn"),
    ),
    case can_release {
      True ->
        action_buttons.task_icon_button(
          helpers_i18n.i18n_t(model, i18n_text.ReleaseAll),
          admin_msg(admin_messages.MemberReleaseAllClicked(m.user_id, count)),
          icons.Return,
          action_buttons.SizeXs,
          is_loading,
          "release-btn",
          opt.None,
          opt.Some("member-release-btn"),
        )
      False -> element.none()
    },
    icon_actions.delete_with_testid(
      helpers_i18n.i18n_t(model, i18n_text.Remove),
      admin_msg(admin_messages.MemberRemoveClicked(m.user_id)),
      "member-remove-btn",
    ),
  ])
}

fn view_member_claimed_count(m: ProjectMember) -> Element(Msg) {
  badge.new_unchecked(int.to_string(m.claimed_count), badge.Neutral)
  |> badge.view_with_class("claimed-badge")
}

/// Render role cell - dropdown for org admins, text for project managers.
fn view_member_role_cell(
  model: Model,
  member: ProjectMember,
  is_org_admin: Bool,
) -> Element(Msg) {
  case is_org_admin {
    True ->
      // Org Admin: show dropdown to change role
      select(
        [
          attribute.value(project_role.to_string(member.role)),
          event.on_input(fn(value) {
            let new_role = case value {
              "manager" -> Manager
              _ -> Member
            }
            admin_msg(admin_messages.MemberRoleChangeRequested(
              member.user_id,
              new_role,
            ))
          }),
        ],
        [
          option(
            [
              attribute.value("member"),
              attribute.selected(member.role == Member),
            ],
            helpers_i18n.i18n_t(model, i18n_text.RoleMember),
          ),
          option(
            [
              attribute.value("manager"),
              attribute.selected(member.role == Manager),
            ],
            helpers_i18n.i18n_t(model, i18n_text.RoleManager),
          ),
        ],
      )
    False ->
      // Project Manager: show text only (view only)
      text(project_role.to_string(member.role))
  }
}

fn view_add_member_dialog(model: Model) -> Element(Msg) {
  let search_query = case model.admin.members.org_users_search {
    state_types.OrgUsersSearchIdle(query, _)
    | state_types.OrgUsersSearchLoading(query, _)
    | state_types.OrgUsersSearchLoaded(query, _, _)
    | state_types.OrgUsersSearchFailed(query, _, _) -> query
  }

  let search_results = case model.admin.members.org_users_search {
    state_types.OrgUsersSearchIdle(_, _) -> NotAsked
    state_types.OrgUsersSearchLoading(_, _) -> Loading
    state_types.OrgUsersSearchLoaded(_, _, users) -> Loaded(users)
    state_types.OrgUsersSearchFailed(_, _, err) -> Failed(err)
  }

  let empty_label = case model.admin.members.org_users_search {
    state_types.OrgUsersSearchLoaded(query, _, users)
      if query != "" && users == []
    -> helpers_i18n.i18n_t(model, i18n_text.NoResults)
    _ -> helpers_i18n.i18n_t(model, i18n_text.TypeAnEmailToSearch)
  }

  dialog.view(
    dialog.DialogConfig(
      title: helpers_i18n.i18n_t(model, i18n_text.AddMember),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: admin_msg(admin_messages.MemberAddDialogClosed),
    ),
    True,
    model.admin.members.members_add_error,
    [
      search_select.view(search_select.Config(
        label: helpers_i18n.i18n_t(model, i18n_text.SearchByEmail),
        placeholder: helpers_i18n.i18n_t(
          model,
          i18n_text.EmailPlaceholderExample,
        ),
        value: search_query,
        on_change: fn(value) {
          admin_msg(admin_messages.OrgUsersSearchDebounced(value))
        },
        input_attributes: [],
        results: search_results,
        render_item: fn(u: OrgUser) {
          let is_selected = case model.admin.members.members_add_selected_user {
            opt.Some(user) -> user.id == u.id
            opt.None -> False
          }

          div(
            [
              attribute.class(
                "search-select-item"
                <> case is_selected {
                  True -> " selected"
                  False -> ""
                },
              ),
            ],
            [
              div([attribute.class("search-select-main")], [
                span([attribute.class("search-select-primary")], [text(u.email)]),
                badge.new_unchecked(
                  org_role.to_string(u.org_role),
                  badge.Neutral,
                )
                  |> badge.view_with_class("search-select-role"),
              ]),
              button(
                [
                  attribute.class(case is_selected {
                    True -> "btn btn-primary btn-xs"
                    False -> "btn btn-secondary btn-xs"
                  }),
                  attribute.disabled(is_selected),
                  event.on_click(
                    admin_msg(admin_messages.MemberAddUserSelected(u.id)),
                  ),
                ],
                [
                  text(
                    helpers_i18n.i18n_t(model, case is_selected {
                      True -> i18n_text.Selected
                      False -> i18n_text.Select
                    }),
                  ),
                ],
              ),
            ],
          )
        },
        empty_label: empty_label,
        loading_label: helpers_i18n.i18n_t(model, i18n_text.Searching),
        error_label: fn(message) { message },
        class: "org-users-search",
      )),
      case model.admin.members.members_add_selected_user {
        opt.Some(user) ->
          div(
            [
              attribute.class("field-hint icon-row member-selected-hint"),
              attribute.attribute("data-testid", "member-add-selected-user"),
            ],
            [
              span([attribute.class("member-selected-hint-icon")], [
                icons.nav_icon(icons.CheckCircle, icons.Small),
              ]),
              text(
                helpers_i18n.i18n_t(model, i18n_text.User) <> ": " <> user.email,
              ),
              badge.new_unchecked(
                helpers_i18n.i18n_t(model, i18n_text.Selected),
                badge.Primary,
              )
                |> badge.view_with_class("member-selected-badge"),
            ],
          )
        opt.None -> element.none()
      },
      form_field.view(
        helpers_i18n.i18n_t(model, i18n_text.Role),
        select(
          [
            attribute.value(project_role.to_string(
              model.admin.members.members_add_role,
            )),
            event.on_input(fn(value) {
              admin_msg(admin_messages.MemberAddRoleChanged(value))
            }),
          ],
          [
            option(
              [attribute.value("member")],
              helpers_i18n.i18n_t(model, i18n_text.RoleMember),
            ),
            option(
              [attribute.value("manager")],
              helpers_i18n.i18n_t(model, i18n_text.RoleManager),
            ),
          ],
        ),
      ),
    ],
    [
      dialog.cancel_button(
        model,
        admin_msg(admin_messages.MemberAddDialogClosed),
      ),
      button(
        [
          event.on_click(admin_msg(admin_messages.MemberAddSubmitted)),
          attribute.disabled(
            model.admin.members.members_add_in_flight
            || model.admin.members.members_add_selected_user == opt.None,
          ),
          attribute.class(case model.admin.members.members_add_in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case model.admin.members.members_add_in_flight {
            True -> helpers_i18n.i18n_t(model, i18n_text.Working)
            False -> helpers_i18n.i18n_t(model, i18n_text.AddMember)
          }),
        ],
      ),
    ],
  )
}

fn view_remove_member_dialog(
  model: Model,
  project_name: String,
  user: OrgUser,
) -> Element(Msg) {
  confirm_dialog.view(
    confirm_dialog.ConfirmConfig(
      title: helpers_i18n.i18n_t(model, i18n_text.RemoveMemberTitle),
      body: [
        p([], [
          text(helpers_i18n.i18n_t(
            model,
            i18n_text.RemoveMemberConfirm(user.email, project_name),
          )),
        ]),
      ],
      confirm_label: case model.admin.members.members_remove_in_flight {
        True -> helpers_i18n.i18n_t(model, i18n_text.Removing)
        False -> helpers_i18n.i18n_t(model, i18n_text.Remove)
      },
      cancel_label: helpers_i18n.i18n_t(model, i18n_text.Cancel),
      on_confirm: admin_msg(admin_messages.MemberRemoveConfirmed),
      on_cancel: admin_msg(admin_messages.MemberRemoveCancelled),
      is_open: True,
      is_loading: model.admin.members.members_remove_in_flight,
      error: model.admin.members.members_remove_error,
      confirm_class: case model.admin.members.members_remove_in_flight {
        True -> "btn-danger btn-loading"
        False -> "btn-danger"
      },
    ),
  )
}

fn view_release_all_dialog(
  model: Model,
  project_name: String,
  target: state_types.ReleaseAllTarget,
) -> Element(Msg) {
  let state_types.ReleaseAllTarget(user: user, claimed_count: claimed_count) =
    target
  let _ = project_name

  confirm_dialog.view(
    confirm_dialog.ConfirmConfig(
      title: helpers_i18n.i18n_t(model, i18n_text.ReleaseAllConfirmTitle),
      body: [
        p([], [
          text(helpers_i18n.i18n_t(
            model,
            i18n_text.ReleaseAllConfirmBody(claimed_count, user.email),
          )),
        ]),
      ],
      confirm_label: helpers_i18n.i18n_t(model, i18n_text.Release),
      cancel_label: helpers_i18n.i18n_t(model, i18n_text.Cancel),
      on_confirm: admin_msg(admin_messages.MemberReleaseAllConfirmed),
      on_cancel: admin_msg(admin_messages.MemberReleaseAllCancelled),
      is_open: True,
      is_loading: model.admin.members.members_release_in_flight
        == opt.Some(user.id),
      error: model.admin.members.members_release_error,
      confirm_class: case model.admin.members.members_release_in_flight {
        opt.Some(_) -> "btn-primary btn-loading"
        opt.None -> "btn-primary"
      },
    ),
  )
}

// Justification: large function kept intact to preserve cohesive UI logic.

/// Member capabilities dialog (AC11-14).
/// Shows checkboxes for all project capabilities, allowing assignment.
fn view_member_capabilities_dialog(
  model: Model,
  user_id: Int,
  project_name: String,
) -> Element(Msg) {
  // Get user email for display
  let user_email = case
    helpers_lookup.resolve_org_user(
      model.admin.members.org_users_cache,
      user_id,
    )
  {
    opt.Some(user) -> user.email
    opt.None -> helpers_i18n.i18n_t(model, i18n_text.UserNumber(user_id))
  }

  // Get all capabilities for the project
  let capabilities = case model.admin.capabilities.capabilities {
    Loaded(caps) -> caps
    _ -> []
  }

  dialog.view(
    dialog.DialogConfig(
      title: helpers_i18n.i18n_t(
        model,
        i18n_text.CapabilitiesForUser(user_email, project_name),
      ),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: admin_msg(admin_messages.MemberCapabilitiesDialogClosed),
    ),
    True,
    model.admin.capabilities.member_capabilities_error,
    [
      case model.admin.capabilities.member_capabilities_loading {
        True ->
          div([attribute.class("loading")], [
            text(helpers_i18n.i18n_t(model, i18n_text.LoadingEllipsis)),
          ])
        False ->
          // Capabilities checkbox list (AC12)
          case capabilities {
            [] ->
              div([attribute.class("empty")], [
                text(helpers_i18n.i18n_t(model, i18n_text.NoCapabilitiesDefined)),
              ])
            _ ->
              div(
                [
                  attribute.class("capabilities-checklist"),
                  attribute.attribute("data-testid", "capabilities-checklist"),
                ],
                list.map(capabilities, fn(cap: Capability) {
                  let is_selected =
                    list.contains(
                      model.admin.capabilities.member_capabilities_selected,
                      cap.id,
                    )
                  label(
                    [
                      attribute.class("checkbox-label"),
                      attribute.attribute(
                        "data-capability-id",
                        int.to_string(cap.id),
                      ),
                    ],
                    [
                      input([
                        attribute.type_("checkbox"),
                        attribute.checked(is_selected),
                        event.on_check(fn(_) {
                          admin_msg(admin_messages.MemberCapabilitiesToggled(
                            cap.id,
                          ))
                        }),
                      ]),
                      span([attribute.class("capability-name")], [
                        text(cap.name),
                      ]),
                    ],
                  )
                }),
              )
          }
      },
    ],
    [
      dialog.cancel_button(
        model,
        admin_msg(admin_messages.MemberCapabilitiesDialogClosed),
      ),
      button(
        [
          event.on_click(admin_msg(admin_messages.MemberCapabilitiesSaveClicked)),
          attribute.disabled(
            model.admin.capabilities.member_capabilities_saving
            || model.admin.capabilities.member_capabilities_loading,
          ),
          attribute.class(
            case model.admin.capabilities.member_capabilities_saving {
              True -> "btn-primary btn-loading"
              False -> "btn-primary"
            },
          ),
        ],
        [
          text(case model.admin.capabilities.member_capabilities_saving {
            True -> helpers_i18n.i18n_t(model, i18n_text.Saving)
            False -> helpers_i18n.i18n_t(model, i18n_text.Save)
          }),
        ],
      ),
    ],
  )
}
