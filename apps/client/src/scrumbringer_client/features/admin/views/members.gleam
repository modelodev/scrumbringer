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
//// - **features/admin/view.gleam**: Adapts root Model/Msg to Config

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, input, label, option, p, select, span, text}
import lustre/event

import domain/capability.{type Capability}
import domain/org.{type OrgUser}
import domain/org_role
import domain/project.{type Project, type ProjectMember, ProjectMember}
import domain/project_role.{type ProjectRole, Manager, Member}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}

import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/admin/member_role as project_member_role
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/confirm_dialog
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/search_select
import scrumbringer_client/ui/section_header
import scrumbringer_client/ui/skeleton

// =============================================================================
// Members View
// =============================================================================

pub type Config(msg) {
  Config(
    locale: Locale,
    selected_project: opt.Option(Project),
    members: admin_members.Model,
    capabilities: admin_capabilities.Model,
    current_user_id: opt.Option(Int),
    is_org_admin: Bool,
    on_add_dialog_opened: msg,
    on_add_dialog_closed: msg,
    on_org_users_search_changed: fn(String) -> msg,
    on_member_add_user_selected: fn(Int) -> msg,
    on_member_add_role_changed: fn(ProjectRole) -> msg,
    on_member_add_submitted: msg,
    on_member_remove_clicked: fn(Int) -> msg,
    on_member_remove_confirmed: msg,
    on_member_remove_cancelled: msg,
    on_member_release_all_clicked: fn(Int, Int) -> msg,
    on_member_release_all_confirmed: msg,
    on_member_release_all_cancelled: msg,
    on_member_role_change_requested: fn(Int, ProjectRole) -> msg,
    on_member_capabilities_opened: fn(Int) -> msg,
    on_member_capabilities_closed: msg,
    on_member_capabilities_toggled: fn(Int) -> msg,
    on_member_capabilities_save_clicked: msg,
    on_invalid_role: msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

/// Project members management view.
pub fn view_members(config: Config(msg)) -> Element(msg) {
  case config.selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(t(config, i18n_text.SelectProjectToManageMembers)),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        // Section header with subtitle and action (Story 4.8: consistent icons + help text)
        section_header.view_full(
          icons.Team,
          t(config, i18n_text.MembersTitle(project.name)),
          t(config, i18n_text.MembersHelp),
          dialog.add_button_with_locale(
            config.locale,
            i18n_text.AddMember,
            config.on_add_dialog_opened,
          ),
        ),
        // Members list
        case config.members.members_remove_error {
          opt.Some(err) -> error_notice.view(err)
          opt.None -> element.none()
        },
        view_members_table(
          config,
          config.members.members,
          config.members.org_users_cache,
        ),
        case config.members.members_release_confirm {
          opt.Some(target) ->
            view_release_all_dialog(config, project.name, target)
          opt.None -> element.none()
        },
        // Add member dialog
        case config.members.members_add_dialog_mode {
          dialog_mode.DialogCreate -> view_add_member_dialog(config)
          _ -> element.none()
        },
        // Remove member confirmation dialog
        case config.members.members_remove_confirm {
          opt.Some(user) ->
            view_remove_member_dialog(config, project.name, user)
          opt.None -> element.none()
        },
        // Member capabilities dialog (AC11-14, Story 4.8 AC23)
        case config.capabilities.member_capabilities_dialog_user_id {
          opt.Some(user_id) ->
            view_member_capabilities_dialog(config, user_id, project.name)
          opt.None -> element.none()
        },
      ])
  }
}

// =============================================================================
// Members Helpers
// =============================================================================

fn view_members_table(
  config: Config(msg),
  members: Remote(List(ProjectMember)),
  cache: Remote(List(OrgUser)),
) -> Element(msg) {
  let tr = fn(key) { t(config, key) }

  // Helper to resolve user email from cache
  let resolve_email = fn(user_id: Int) -> String {
    case helpers_lookup.resolve_org_user(cache, user_id) {
      opt.Some(user) -> user.email
      opt.None -> tr(i18n_text.UserNumber(user_id))
    }
  }

  // Helper to get capability count from cache
  let get_cap_count = fn(user_id: Int) -> Int {
    case dict.get(config.capabilities.member_capabilities_cache, user_id) {
      Ok(ids) -> list.length(ids)
      Error(_) -> 0
    }
  }

  data_table.view_remote_with_forbidden(
    members,
    loading_msg: tr(i18n_text.LoadingEllipsis),
    empty_msg: tr(i18n_text.NoMembersYet),
    forbidden_msg: tr(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // User email
        data_table.column(tr(i18n_text.User), fn(m: ProjectMember) {
          text(resolve_email(m.user_id))
        }),
        // Role (dropdown for admins, text for others)
        data_table.column(tr(i18n_text.Role), fn(m: ProjectMember) {
          view_member_role_cell(config, m, config.is_org_admin)
        }),
        // Capabilities count (AC15)
        data_table.column_with_class(
          tr(i18n_text.Capabilities),
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
          tr(i18n_text.Claimed),
          fn(m: ProjectMember) { view_member_claimed_count(m) },
          "col-number",
          "cell-number",
        ),
        // Actions (Story 4.8 UX)
        data_table.column_with_class(
          tr(i18n_text.Actions),
          fn(m: ProjectMember) { view_member_actions(config, m) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(m: ProjectMember) { int.to_string(m.user_id) }),
  )
}

fn view_member_actions(config: Config(msg), m: ProjectMember) -> Element(msg) {
  let count = m.claimed_count
  let is_self = config.current_user_id == opt.Some(m.user_id)
  let can_release = count > 0 && is_self == False
  let is_loading =
    config.members.members_release_in_flight == opt.Some(m.user_id)

  div([attribute.class("actions-row")], [
    action_buttons.task_icon_button(
      t(config, i18n_text.ManageCapabilities),
      config.on_member_capabilities_opened(m.user_id),
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
          t(config, i18n_text.ReleaseAll),
          config.on_member_release_all_clicked(m.user_id, count),
          icons.Return,
          action_buttons.SizeXs,
          is_loading,
          "release-btn",
          opt.None,
          opt.Some("member-release-btn"),
        )
      False -> element.none()
    },
    action_buttons.delete_button_with_testid(
      t(config, i18n_text.Remove),
      config.on_member_remove_clicked(m.user_id),
      "member-remove-btn",
    ),
  ])
}

fn view_member_claimed_count(m: ProjectMember) -> Element(msg) {
  badge.new_unchecked(int.to_string(m.claimed_count), badge.Neutral)
  |> badge.view_with_class("claimed-badge")
}

/// Render role cell - dropdown for org admins, text for project managers.
fn view_member_role_cell(
  config: Config(msg),
  member: ProjectMember,
  is_org_admin: Bool,
) -> Element(msg) {
  case is_org_admin {
    True ->
      // Org Admin: show dropdown to change role
      select(
        [
          attribute.value(project_role.to_string(member.role)),
          event.on_input(fn(value) {
            case project_member_role.changed_input_value(value, member.role) {
              Ok(new_role) ->
                config.on_member_role_change_requested(member.user_id, new_role)
              Error(_) -> config.on_invalid_role
            }
          }),
        ],
        [
          option(
            [
              attribute.value("member"),
              attribute.selected(member.role == Member),
            ],
            t(config, i18n_text.RoleMember),
          ),
          option(
            [
              attribute.value("manager"),
              attribute.selected(member.role == Manager),
            ],
            t(config, i18n_text.RoleManager),
          ),
        ],
      )
    False ->
      // Project Manager: show text only (view only)
      text(project_role.to_string(member.role))
  }
}

fn view_add_member_dialog(config: Config(msg)) -> Element(msg) {
  let search_query = case config.members.org_users_search {
    admin_members.OrgUsersSearchIdle(query, _)
    | admin_members.OrgUsersSearchLoading(query, _)
    | admin_members.OrgUsersSearchLoaded(query, _, _)
    | admin_members.OrgUsersSearchFailed(query, _, _) -> query
  }

  let search_results = case config.members.org_users_search {
    admin_members.OrgUsersSearchIdle(_, _) -> NotAsked
    admin_members.OrgUsersSearchLoading(_, _) -> Loading
    admin_members.OrgUsersSearchLoaded(_, _, users) ->
      Loaded(
        list.filter(users, fn(user) {
          !is_already_project_member(config, user.id)
        }),
      )
    admin_members.OrgUsersSearchFailed(_, _, err) -> Failed(err)
  }

  let empty_label = case search_results {
    Loaded(users) if search_query != "" && users == [] ->
      t(config, i18n_text.NoResults)
    _ -> t(config, i18n_text.TypeAnEmailToSearch)
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.AddMember),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: config.on_add_dialog_closed,
    ),
    True,
    config.members.members_add_error,
    [
      search_select.view(search_select.Config(
        label: t(config, i18n_text.SearchByEmail),
        placeholder: t(config, i18n_text.EmailPlaceholderExample),
        value: search_query,
        on_change: fn(value) { config.on_org_users_search_changed(value) },
        input_attributes: [],
        results: search_results,
        render_item: fn(u: OrgUser) {
          let is_selected = case config.members.members_add_selected_user {
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
              member_select_button(config, u.id, is_selected),
            ],
          )
        },
        empty_label: empty_label,
        loading_label: t(config, i18n_text.Searching),
        error_label: fn(message) { message },
        class: "org-users-search",
      )),
      case config.members.members_add_selected_user {
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
              text(t(config, i18n_text.User) <> ": " <> user.email),
              badge.new_unchecked(t(config, i18n_text.Selected), badge.Primary)
                |> badge.view_with_class("member-selected-badge"),
            ],
          )
        opt.None -> element.none()
      },
      form_field.view(
        t(config, i18n_text.Role),
        select(
          [
            attribute.value(project_role.to_string(
              config.members.members_add_role,
            )),
            event.on_input(fn(value) {
              case project_member_role.input_value(value) {
                Ok(role) -> config.on_member_add_role_changed(role)
                Error(_) -> config.on_invalid_role
              }
            }),
          ],
          [
            option([attribute.value("member")], t(config, i18n_text.RoleMember)),
            option(
              [attribute.value("manager")],
              t(config, i18n_text.RoleManager),
            ),
          ],
        ),
      ),
    ],
    [
      dialog.cancel_button_with_locale(
        config.locale,
        config.on_add_dialog_closed,
      ),
      member_add_submit_button(config),
    ],
  )
}

fn member_select_button(
  config: Config(msg),
  user_id: Int,
  is_selected: Bool,
) -> Element(msg) {
  ui_button.text(
    t(config, case is_selected {
      True -> i18n_text.Selected
      False -> i18n_text.Select
    }),
    config.on_member_add_user_selected(user_id),
    case is_selected {
      True -> ui_button.Primary
      False -> ui_button.Secondary
    },
    ui_button.EntityAction,
  )
  |> ui_button.with_size(ui_button.ExtraSmall)
  |> ui_button.with_disabled(is_selected)
  |> ui_button.view
}

fn member_add_submit_button(config: Config(msg)) -> Element(msg) {
  let is_in_flight = config.members.members_add_in_flight
  let disabled =
    is_in_flight || config.members.members_add_selected_user == opt.None

  let button =
    ui_button.text(
      case is_in_flight {
        True -> t(config, i18n_text.Working)
        False -> t(config, i18n_text.AddMember)
      },
      config.on_member_add_submitted,
      ui_button.Primary,
      ui_button.EntityAction,
    )
    |> ui_button.with_disabled(disabled)

  case is_in_flight {
    True -> ui_button.with_class(button, "btn-loading")
    False -> button
  }
  |> ui_button.view
}

fn is_already_project_member(config: Config(msg), user_id: Int) -> Bool {
  case config.members.members {
    Loaded(members) ->
      list.any(members, fn(member) {
        let ProjectMember(user_id: member_user_id, ..) = member
        member_user_id == user_id
      })
    _ -> False
  }
}

fn view_remove_member_dialog(
  config: Config(msg),
  project_name: String,
  user: OrgUser,
) -> Element(msg) {
  confirm_dialog.view(confirm_dialog.ConfirmConfig(
    title: t(config, i18n_text.RemoveMemberTitle),
    body: [
      p([], [
        text(t(config, i18n_text.RemoveMemberConfirm(user.email, project_name))),
      ]),
    ],
    confirm_label: case config.members.members_remove_in_flight {
      True -> t(config, i18n_text.Removing)
      False -> t(config, i18n_text.Remove)
    },
    cancel_label: t(config, i18n_text.Cancel),
    on_confirm: config.on_member_remove_confirmed,
    on_cancel: config.on_member_remove_cancelled,
    is_open: True,
    is_loading: config.members.members_remove_in_flight,
    error: config.members.members_remove_error,
    confirm_intent: ui_button.Danger,
  ))
}

fn view_release_all_dialog(
  config: Config(msg),
  project_name: String,
  target: admin_members.ReleaseAllTarget,
) -> Element(msg) {
  let admin_members.ReleaseAllTarget(user: user, claimed_count: claimed_count) =
    target
  let _ = project_name

  confirm_dialog.view(confirm_dialog.ConfirmConfig(
    title: t(config, i18n_text.ReleaseAllConfirmTitle),
    body: [
      p([], [
        text(t(
          config,
          i18n_text.ReleaseAllConfirmBody(claimed_count, user.email),
        )),
      ]),
    ],
    confirm_label: t(config, i18n_text.Release),
    cancel_label: t(config, i18n_text.Cancel),
    on_confirm: config.on_member_release_all_confirmed,
    on_cancel: config.on_member_release_all_cancelled,
    is_open: True,
    is_loading: config.members.members_release_in_flight == opt.Some(user.id),
    error: config.members.members_release_error,
    confirm_intent: ui_button.Primary,
  ))
}

/// Member capabilities dialog (AC11-14).
/// Shows checkboxes for all project capabilities, allowing assignment.
fn view_member_capabilities_dialog(
  config: Config(msg),
  user_id: Int,
  project_name: String,
) -> Element(msg) {
  // Get user email for display
  let user_email = case
    helpers_lookup.resolve_org_user(config.members.org_users_cache, user_id)
  {
    opt.Some(user) -> user.email
    opt.None -> t(config, i18n_text.UserNumber(user_id))
  }

  // Get all capabilities for the project
  let capabilities = case config.capabilities.capabilities {
    Loaded(caps) -> caps
    _ -> []
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.CapabilitiesForUser(user_email, project_name)),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: config.on_member_capabilities_closed,
    ),
    True,
    config.capabilities.member_capabilities_error,
    [
      case config.capabilities.member_capabilities_loading {
        True -> skeleton.skeleton_list(4)
        False ->
          // Capabilities checkbox list (AC12)
          case capabilities {
            [] ->
              div([attribute.class("empty")], [
                text(t(config, i18n_text.NoCapabilitiesDefined)),
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
                      config.capabilities.member_capabilities_selected,
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
                          config.on_member_capabilities_toggled(cap.id)
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
      dialog.cancel_button_with_locale(
        config.locale,
        config.on_member_capabilities_closed,
      ),
      member_capabilities_save_button(config),
    ],
  )
}

fn member_capabilities_save_button(config: Config(msg)) -> Element(msg) {
  let is_saving = config.capabilities.member_capabilities_saving
  let button =
    ui_button.text(
      case is_saving {
        True -> t(config, i18n_text.Saving)
        False -> t(config, i18n_text.Save)
      },
      config.on_member_capabilities_save_clicked,
      ui_button.Primary,
      ui_button.EntityAction,
    )
    |> ui_button.with_disabled(
      is_saving || config.capabilities.member_capabilities_loading,
    )

  case is_saving {
    True -> ui_button.with_class(button, "btn-loading")
    False -> button
  }
  |> ui_button.view
}
