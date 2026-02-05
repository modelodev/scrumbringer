////
//// Project card for assignments view.
////

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element
import lustre/element/html.{button, div, input, option, p, select, span, text}
import lustre/event

import domain/metrics.{
  type OrgMetricsProjectOverview, OrgMetricsOverview, OrgMetricsProjectOverview,
}
import domain/project.{type Project, type ProjectMember}
import domain/project_role.{Manager, Member, to_string}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}

import scrumbringer_client/client_state
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/assignments/components/assignments_card
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/loading

pub fn view(
  model: client_state.Model,
  project: Project,
  members_state: Remote(List(ProjectMember)),
  expanded: Bool,
) -> element.Element(client_state.Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }
  let assignments = model.admin.assignments

  let no_members = case members_state {
    Loaded(members_list) ->
      case model.core.user {
        opt.Some(user) ->
          members_list == []
          || list.all(members_list, fn(member) { member.user_id == user.id })
        opt.None -> members_list == []
      }
    _ -> project.members_count == 0
  }

  let warning_badge = case no_members {
    True ->
      badge.new_unchecked(t(i18n_text.AssignmentsNoMembersBadge), badge.Warning)
      |> badge.view_inline
    False -> element.none()
  }

  let users_count = case members_state {
    Loaded(members_list) -> list.length(members_list)
    _ -> project.members_count
  }
  let users_label = t(i18n_text.AssignmentsUsersCount(users_count))
  let metrics_summary = view_project_metrics_summary(model, project.id)

  let is_inline_add = case assignments.inline_add_context {
    opt.Some(state_types.AddUserToProject(id)) -> id == project.id
    _ -> False
  }

  let inline_confirm = assignments.inline_remove_confirm

  let is_confirming = case inline_confirm {
    opt.Some(#(pid, _)) -> pid == project.id
    _ -> False
  }

  let is_expanded = expanded || is_inline_add || is_confirming
  let toggle_label = case is_expanded {
    True -> t(i18n_text.CollapseRule)
    False -> t(i18n_text.ExpandRule)
  }
  let body =
    div([], [
      case metrics_summary {
        opt.Some(summary) -> summary
        opt.None -> element.none()
      },
      case members_state {
        NotAsked | Loading ->
          loading.loading(t(i18n_text.AssignmentsLoadingMembers))

        Failed(err) -> error_notice.view(err.message)

        Loaded(members_list) ->
          case members_list == [] {
            True ->
              p([attribute.class("assignments-empty")], [
                text(t(i18n_text.NoMembersYet)),
              ])
            False ->
              div([], [
                list.map(members_list, fn(member) {
                  view_member_row(model, project.id, member, inline_confirm)
                })
                |> element.fragment,
              ])
          }
      },
      case is_inline_add {
        True -> view_inline_add(model)
        False ->
          button(
            [
              attribute.class("btn-sm"),
              event.on_click(
                client_state.admin_msg(
                  admin_messages.AssignmentsInlineAddStarted(
                    state_types.AddUserToProject(project.id),
                  ),
                ),
              ),
            ],
            [text(t(i18n_text.AddMember))],
          )
      },
    ])

  assignments_card.view(assignments_card.Config(
    title: project.name,
    icon: icons.Projects,
    badge: warning_badge,
    meta: users_label,
    expanded: is_expanded,
    toggle_label: toggle_label,
    on_toggle: client_state.admin_msg(admin_messages.AssignmentsProjectToggled(
      project.id,
    )),
    body: body,
  ))
}

fn view_project_metrics_summary(
  model: client_state.Model,
  project_id: Int,
) -> opt.Option(element.Element(client_state.Msg)) {
  case model.admin.metrics.admin_metrics_overview {
    Loaded(OrgMetricsOverview(by_project: projects, ..)) ->
      case list.find(projects, fn(p) { p.project_id == project_id }) {
        Ok(metrics) -> opt.Some(project_metrics_view(model, metrics))
        Error(_) -> opt.None
      }
    _ -> opt.None
  }
}

fn project_metrics_view(
  model: client_state.Model,
  metrics: OrgMetricsProjectOverview,
) -> element.Element(client_state.Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }
  let OrgMetricsProjectOverview(
    available_count: available_count,
    claimed_count: claimed_count,
    ongoing_count: ongoing_count,
    completed_count: completed_count,
    release_rate_percent: release_rate_percent,
    ..,
  ) = metrics

  div([attribute.class("assignments-metrics")], [
    div([attribute.class("assignments-metrics-item")], [
      text(
        t(i18n_text.AvailableCount) <> ": " <> int.to_string(available_count),
      ),
    ]),
    div([attribute.class("assignments-metrics-item")], [
      text(t(i18n_text.Claimed) <> ": " <> int.to_string(claimed_count)),
    ]),
    div([attribute.class("assignments-metrics-item")], [
      text(t(i18n_text.OngoingCount) <> ": " <> int.to_string(ongoing_count)),
    ]),
    div([attribute.class("assignments-metrics-item")], [
      text(t(i18n_text.Completed) <> ": " <> int.to_string(completed_count)),
    ]),
    div([attribute.class("assignments-metrics-item")], [
      text(
        t(i18n_text.ReleasePercent)
        <> ": "
        <> option_percent_label(release_rate_percent),
      ),
    ]),
  ])
}

fn option_percent_label(value: opt.Option(Int)) -> String {
  case value {
    opt.Some(v) -> int.to_string(v) <> "%"
    opt.None -> "-"
  }
}

fn view_member_row(
  model: client_state.Model,
  project_id: Int,
  member: ProjectMember,
  inline_confirm: opt.Option(#(Int, Int)),
) -> element.Element(client_state.Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }
  let email = case
    helpers_lookup.resolve_org_user(
      model.admin.members.org_users_cache,
      member.user_id,
    )
  {
    opt.Some(user) -> user.email
    opt.None -> t(i18n_text.UserNumber(member.user_id))
  }

  let is_confirming = case inline_confirm {
    opt.Some(#(pid, uid)) -> pid == project_id && uid == member.user_id
    _ -> False
  }

  let is_role_in_flight = case model.admin.assignments.role_change_in_flight {
    opt.Some(#(pid, uid)) -> pid == project_id && uid == member.user_id
    _ -> False
  }

  div([attribute.class("assignments-row")], [
    div([attribute.class("assignments-row-title")], [text(email)]),
    select(
      [
        attribute.value(to_string(member.role)),
        attribute.disabled(is_role_in_flight),
        event.on_input(fn(value) {
          let new_role = case value {
            "manager" -> Manager
            _ -> Member
          }
          client_state.admin_msg(admin_messages.AssignmentsRoleChanged(
            project_id,
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
          t(i18n_text.RoleMember),
        ),
        option(
          [
            attribute.value("manager"),
            attribute.selected(member.role == Manager),
          ],
          t(i18n_text.RoleManager),
        ),
      ],
    ),
    case is_confirming {
      True ->
        div([attribute.class("assignments-row-actions")], [
          button(
            [
              attribute.class("btn-xs btn-danger"),
              event.on_click(client_state.admin_msg(
                admin_messages.AssignmentsRemoveConfirmed,
              )),
            ],
            [text(t(i18n_text.Remove))],
          ),
          button(
            [
              attribute.class("btn-xs"),
              event.on_click(client_state.admin_msg(
                admin_messages.AssignmentsRemoveCancelled,
              )),
            ],
            [text(t(i18n_text.Cancel))],
          ),
        ])
      False ->
        button(
          [
            attribute.class("btn-icon btn-xs btn-danger"),
            attribute.attribute("title", t(i18n_text.Remove)),
            attribute.attribute("aria-label", t(i18n_text.Remove)),
            event.on_click(
              client_state.admin_msg(admin_messages.AssignmentsRemoveClicked(
                project_id,
                member.user_id,
              )),
            ),
          ],
          [icons.nav_icon(icons.Trash, icons.Small)],
        )
    },
  ])
}

fn view_inline_add(
  model: client_state.Model,
) -> element.Element(client_state.Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }
  let assignments = model.admin.assignments
  let search = assignments.inline_add_search
  let selected = assignments.inline_add_selection
  let is_disabled = assignments.inline_add_in_flight

  let options = case model.admin.members.org_users_cache {
    Loaded(users) ->
      users
      |> list.filter(fn(user) {
        let term = string.lowercase(string.trim(search))
        case term == "" {
          True -> True
          False -> string.contains(string.lowercase(user.email), term)
        }
      })
      |> list.map(fn(user) {
        option([attribute.value(int.to_string(user.id))], user.email)
      })
    _ -> []
  }

  div([attribute.class("assignments-inline-add")], [
    div([attribute.class("assignments-inline-add-row")], [
      span([attribute.class("assignments-inline-add-label")], [
        text(t(i18n_text.AddMember)),
      ]),
      input([
        attribute.type_("text"),
        attribute.value(search),
        attribute.placeholder(t(i18n_text.SearchByEmail)),
        event.on_input(fn(value) {
          client_state.admin_msg(
            admin_messages.AssignmentsInlineAddSearchChanged(value),
          )
        }),
      ]),
      select(
        [
          attribute.value(case selected {
            opt.Some(id) -> int.to_string(id)
            opt.None -> ""
          }),
          event.on_input(fn(value) {
            client_state.admin_msg(
              admin_messages.AssignmentsInlineAddSelectionChanged(value),
            )
          }),
        ],
        [
          option(
            [attribute.value(""), attribute.selected(selected == opt.None)],
            t(i18n_text.Select),
          ),
          ..options
        ],
      ),
      select(
        [
          attribute.value(to_string(assignments.inline_add_role)),
          event.on_input(fn(value) {
            client_state.admin_msg(
              admin_messages.AssignmentsInlineAddRoleChanged(value),
            )
          }),
        ],
        [
          option([attribute.value("member")], t(i18n_text.RoleMember)),
          option([attribute.value("manager")], t(i18n_text.RoleManager)),
        ],
      ),
      div([attribute.class("assignments-inline-add-actions")], [
        button(
          [
            attribute.class("btn-xs"),
            attribute.disabled(is_disabled),
            event.on_click(client_state.admin_msg(
              admin_messages.AssignmentsInlineAddCancelled,
            )),
          ],
          [text(t(i18n_text.Cancel))],
        ),
        button(
          [
            attribute.class("btn-xs btn-primary"),
            attribute.disabled(is_disabled || selected == opt.None),
            event.on_click(client_state.admin_msg(
              admin_messages.AssignmentsInlineAddSubmitted,
            )),
          ],
          [
            text(case is_disabled {
              True -> t(i18n_text.Working)
              False -> t(i18n_text.Add)
            }),
          ],
        ),
      ]),
    ]),
  ])
}
