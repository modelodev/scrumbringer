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

import scrumbringer_client/client_state.{
  type Model, type Msg, type OrgUsersSearchState, type Remote, Loaded,
  MemberAddDialogClosed, MemberAddDialogOpened, MemberAddRoleChanged,
  MemberAddSubmitted, MemberAddUserSelected, MemberCapabilitiesDialogClosed,
  MemberCapabilitiesDialogOpened, MemberCapabilitiesSaveClicked,
  MemberCapabilitiesToggled, MemberRemoveCancelled, MemberRemoveClicked,
  MemberRemoveConfirmed, MemberRoleChangeRequested, OrgUsersSearchChanged,
  OrgUsersSearchDebounced, OrgUsersSearchFailed, OrgUsersSearchIdle,
  OrgUsersSearchLoaded, OrgUsersSearchLoading, admin_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attrs
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers
import scrumbringer_client/utils/format_date

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
      div([attrs.empty()], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.SelectProjectToManageMembers,
        )),
      ])

    opt.Some(project) ->
      div([attrs.section()], [
        // Section header with subtitle and action (Story 4.8: consistent icons + help text)
        section_header.view_full(
          icons.Team,
          update_helpers.i18n_t(model, i18n_text.MembersTitle(project.name)),
          update_helpers.i18n_t(model, i18n_text.MembersHelp),
          dialog.add_button(
            model,
            i18n_text.AddMember,
            admin_msg(MemberAddDialogOpened),
          ),
        ),
        // Members list
        case model.admin.members_remove_error {
          opt.Some(err) -> error_notice.view(err)
          opt.None -> element.none()
        },
        view_members_table(
          model,
          model.admin.members,
          model.admin.org_users_cache,
        ),
        // Add member dialog
        case model.admin.members_add_dialog_open {
          True -> view_add_member_dialog(model)
          False -> element.none()
        },
        // Remove member confirmation dialog
        case model.admin.members_remove_confirm {
          opt.Some(user) -> view_remove_member_dialog(model, project.name, user)
          opt.None -> element.none()
        },
        // Member capabilities dialog (AC11-14, Story 4.8 AC23)
        case model.admin.member_capabilities_dialog_user_id {
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
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  // Check if current user is org admin (can change roles)
  let is_org_admin = case model.core.user {
    opt.Some(user) -> user.org_role == org_role.Admin
    opt.None -> False
  }

  // Helper to resolve user email from cache
  let resolve_email = fn(user_id: Int) -> String {
    case update_helpers.resolve_org_user(cache, user_id) {
      opt.Some(user) -> user.email
      opt.None -> t(i18n_text.UserNumber(user_id))
    }
  }

  // Helper to get capability count from cache
  let get_cap_count = fn(user_id: Int) -> Int {
    case dict.get(model.admin.member_capabilities_cache, user_id) {
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
        // User ID
        data_table.column(t(i18n_text.UserId), fn(m: ProjectMember) {
          text(int.to_string(m.user_id))
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
        // Created date
        data_table.column(t(i18n_text.CreatedAt), fn(m: ProjectMember) {
          text(format_date.date_only(m.created_at))
        }),
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
  div([attribute.class("actions-row")], [
    // Manage capabilities button
    button(
      [
        attribute.class("btn-icon btn-xs"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.ManageCapabilities),
        ),
        attribute.attribute("data-testid", "member-capabilities-btn"),
        event.on_click(admin_msg(MemberCapabilitiesDialogOpened(m.user_id))),
      ],
      [icons.nav_icon(icons.Cog, icons.Small)],
    ),
    // Remove button
    button(
      [
        attribute.class("btn-icon btn-xs btn-danger-icon"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.Remove),
        ),
        event.on_click(admin_msg(MemberRemoveClicked(m.user_id))),
      ],
      [icons.nav_icon(icons.Trash, icons.Small)],
    ),
  ])
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
            admin_msg(MemberRoleChangeRequested(member.user_id, new_role))
          }),
        ],
        [
          option(
            [
              attribute.value("member"),
              attribute.selected(member.role == Member),
            ],
            update_helpers.i18n_t(model, i18n_text.RoleMember),
          ),
          option(
            [
              attribute.value("manager"),
              attribute.selected(member.role == Manager),
            ],
            update_helpers.i18n_t(model, i18n_text.RoleManager),
          ),
        ],
      )
    False ->
      // Project Manager: show text only (view only)
      text(project_role.to_string(member.role))
  }
}

fn view_add_member_dialog(model: Model) -> Element(Msg) {
  let search_query = case model.admin.org_users_search {
    OrgUsersSearchIdle(query, _)
    | OrgUsersSearchLoading(query, _)
    | OrgUsersSearchLoaded(query, _, _)
    | OrgUsersSearchFailed(query, _, _) -> query
  }

  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.AddMember),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: admin_msg(MemberAddDialogClosed),
    ),
    True,
    model.admin.members_add_error,
    [
      form_field.view(
        update_helpers.i18n_t(model, i18n_text.SearchByEmail),
        input([
          attribute.type_("text"),
          attribute.value(search_query),
          event.on_input(fn(value) { admin_msg(OrgUsersSearchChanged(value)) }),
          event.debounce(
            event.on_input(fn(value) {
              admin_msg(OrgUsersSearchDebounced(value))
            }),
            350,
          ),
          attribute.placeholder(update_helpers.i18n_t(
            model,
            i18n_text.EmailPlaceholderExample,
          )),
        ]),
      ),
      view_org_users_search_results(model, model.admin.org_users_search),
      form_field.view(
        update_helpers.i18n_t(model, i18n_text.Role),
        select(
          [
            attribute.value(project_role.to_string(model.admin.members_add_role)),
            event.on_input(fn(value) { admin_msg(MemberAddRoleChanged(value)) }),
          ],
          [
            option(
              [attribute.value("member")],
              update_helpers.i18n_t(model, i18n_text.RoleMember),
            ),
            option(
              [attribute.value("manager")],
              update_helpers.i18n_t(model, i18n_text.RoleManager),
            ),
          ],
        ),
      ),
    ],
    [
      dialog.cancel_button(model, admin_msg(MemberAddDialogClosed)),
      button(
        [
          event.on_click(admin_msg(MemberAddSubmitted)),
          attribute.disabled(
            model.admin.members_add_in_flight
            || model.admin.members_add_selected_user == opt.None,
          ),
          attribute.class(case model.admin.members_add_in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case model.admin.members_add_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Working)
            False -> update_helpers.i18n_t(model, i18n_text.AddMember)
          }),
        ],
      ),
    ],
  )
}

// Justification: nested case improves clarity for branching logic.
fn view_org_users_search_results(
  model: Model,
  results: OrgUsersSearchState,
) -> Element(Msg) {
  case results {
    OrgUsersSearchIdle(_query, _) ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.TypeAnEmailToSearch)),
      ])

    OrgUsersSearchLoading(_query, _) ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.Searching)),
      ])

    OrgUsersSearchFailed(_query, _token, err) ->
      case err.status == 403 {
        True ->
          div(
            [
              attribute.class("not-permitted"),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))],
          )
        False -> error_notice.view(err.message)
      }

    OrgUsersSearchLoaded(_query, _token, users) ->
      case users {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoResults)),
          ])

        _ ->
          data_table.new()
          |> data_table.with_columns([
            data_table.column(
              update_helpers.i18n_t(model, i18n_text.EmailLabel),
              fn(u: OrgUser) { text(u.email) },
            ),
            data_table.column(
              update_helpers.i18n_t(model, i18n_text.OrgRole),
              fn(u: OrgUser) { text(u.org_role) },
            ),
            data_table.column(
              update_helpers.i18n_t(model, i18n_text.Created),
              fn(u: OrgUser) { text(u.created_at) },
            ),
            data_table.column(
              update_helpers.i18n_t(model, i18n_text.Select),
              fn(u: OrgUser) {
                button(
                  [event.on_click(admin_msg(MemberAddUserSelected(u.id)))],
                  [text(update_helpers.i18n_t(model, i18n_text.Select))],
                )
              },
            ),
          ])
          |> data_table.with_rows(users, fn(u) { int.to_string(u.id) })
          |> data_table.view()
      }
  }
}

fn view_remove_member_dialog(
  model: Model,
  project_name: String,
  user: OrgUser,
) -> Element(Msg) {
  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.RemoveMemberTitle),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: admin_msg(MemberRemoveCancelled),
    ),
    True,
    model.admin.members_remove_error,
    [
      p([], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.RemoveMemberConfirm(user.email, project_name),
        )),
      ]),
    ],
    [
      dialog.cancel_button(model, admin_msg(MemberRemoveCancelled)),
      button(
        [
          event.on_click(admin_msg(MemberRemoveConfirmed)),
          attribute.disabled(model.admin.members_remove_in_flight),
          attribute.class(case model.admin.members_remove_in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case model.admin.members_remove_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Removing)
            False -> update_helpers.i18n_t(model, i18n_text.Remove)
          }),
        ],
      ),
    ],
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
    update_helpers.resolve_org_user(model.admin.org_users_cache, user_id)
  {
    opt.Some(user) -> user.email
    opt.None -> update_helpers.i18n_t(model, i18n_text.UserNumber(user_id))
  }

  // Get all capabilities for the project
  let capabilities = case model.admin.capabilities {
    Loaded(caps) -> caps
    _ -> []
  }

  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(
        model,
        i18n_text.CapabilitiesForUser(user_email, project_name),
      ),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: admin_msg(MemberCapabilitiesDialogClosed),
    ),
    True,
    model.admin.member_capabilities_error,
    [
      case model.admin.member_capabilities_loading {
        True ->
          div([attribute.class("loading")], [
            text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
          ])
        False ->
          // Capabilities checkbox list (AC12)
          case capabilities {
            [] ->
              div([attribute.class("empty")], [
                text(update_helpers.i18n_t(
                  model,
                  i18n_text.NoCapabilitiesDefined,
                )),
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
                      model.admin.member_capabilities_selected,
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
                          admin_msg(MemberCapabilitiesToggled(cap.id))
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
      dialog.cancel_button(model, admin_msg(MemberCapabilitiesDialogClosed)),
      button(
        [
          event.on_click(admin_msg(MemberCapabilitiesSaveClicked)),
          attribute.disabled(
            model.admin.member_capabilities_saving
            || model.admin.member_capabilities_loading,
          ),
          attribute.class(case model.admin.member_capabilities_saving {
            True -> "btn-primary btn-loading"
            False -> "btn-primary"
          }),
        ],
        [
          text(case model.admin.member_capabilities_saving {
            True -> update_helpers.i18n_t(model, i18n_text.Saving)
            False -> update_helpers.i18n_t(model, i18n_text.Save)
          }),
        ],
      ),
    ],
  )
}
