////
//// Project card for assignments view.
////

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element
import lustre/element/html.{
  button, div, input, option, p, select, span, td, text, tr,
}
import lustre/event

import domain/metrics.{
  type OrgMetricsOverview, type OrgMetricsProjectOverview, OrgMetricsOverview,
  OrgMetricsProjectOverview,
}
import domain/org.{type OrgUser}
import domain/project.{type Project, type ProjectMember}
import domain/project_role.{type ProjectRole, Manager, Member, to_string}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}

import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/features/admin/member_role as project_member_role
import scrumbringer_client/features/assignments/components/metric_chip
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/expand_toggle
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/task_metric

pub type Config(msg) {
  Config(
    locale: Locale,
    assignments: assignments_state.AssignmentsModel,
    current_user_id: opt.Option(Int),
    org_users: Remote(List(OrgUser)),
    metrics: Remote(OrgMetricsOverview),
    on_project_toggled: fn(Int) -> msg,
    on_inline_add_started: fn(assignments_state.AssignmentsAddContext) -> msg,
    on_role_changed: fn(Int, Int, ProjectRole) -> msg,
    on_remove_confirmed: msg,
    on_remove_cancelled: msg,
    on_remove_clicked: fn(Int, Int) -> msg,
    on_inline_add_search_changed: fn(String) -> msg,
    on_inline_add_selection_changed: fn(String) -> msg,
    on_inline_add_role_changed: fn(ProjectRole) -> msg,
    on_inline_add_cancelled: msg,
    on_inline_add_submitted: msg,
    noop: msg,
  )
}

pub fn view_rows(
  config: Config(msg),
  project: Project,
  members_state: Remote(List(ProjectMember)),
  expanded: Bool,
) -> List(element.Element(msg)) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let assignments = config.assignments

  let no_members = case members_state {
    Loaded(members_list) ->
      case config.current_user_id {
        opt.Some(user_id) ->
          members_list == []
          || list.all(members_list, fn(member) { member.user_id == user_id })
        opt.None -> members_list == []
      }
    _ -> project.members_count == 0
  }

  let warning_badge = case no_members {
    True ->
      badge.new_unchecked(t(i18n_text.TeamNoPeopleBadge), badge.Warning)
      |> badge.view_inline
    False -> element.none()
  }

  let users_count = case members_state {
    Loaded(members_list) -> list.length(members_list)
    _ -> project.members_count
  }
  let users_label = t(i18n_text.TeamPeopleCount(users_count))
  let metrics_summary = view_project_metrics_summary(config, project.id)

  let is_inline_add = case assignments.inline_add_context {
    opt.Some(assignments_state.AddUserToProject(id)) -> id == project.id
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
        NotAsked | Loading -> loading.loading(t(i18n_text.TeamLoadingMembers))

        Failed(err) -> error_notice.view(err.message)

        Loaded(members_list) ->
          case members_list == [] {
            True ->
              p([attribute.class("assignments-empty")], [
                text(t(i18n_text.NoMembersYet)),
              ])
            False ->
              div([attribute.class("assignments-rows")], [
                list.map(members_list, fn(member) {
                  view_member_row(config, project.id, member, inline_confirm)
                })
                |> element.fragment,
              ])
          }
      },
      case is_inline_add {
        True -> view_inline_add(config)
        False ->
          ui_button.text(
            t(i18n_text.AddMember),
            config.on_inline_add_started(assignments_state.AddUserToProject(
              project.id,
            )),
            ui_button.Secondary,
            ui_button.EntityAction,
          )
          |> ui_button.view
      },
    ])

  let summary_row =
    tr([attribute.class("assignments-table-row")], [
      td([attribute.class("assignments-primary-cell")], [
        div([attribute.class("assignments-card-title")], [
          button(
            [
              attribute.class("btn-expand"),
              attribute.attribute("aria-label", toggle_label),
              attribute.attribute(
                "aria-expanded",
                attribute_value.boolean(is_expanded),
              ),
              event.on_click(config.on_project_toggled(project.id)),
            ],
            [expand_toggle.view(is_expanded)],
          ),
          div([attribute.class("assignments-card-icon")], [
            icons.nav_icon(icons.Projects, icons.Small),
          ]),
          text(project.name),
          warning_badge,
        ]),
      ]),
      td([attribute.class("assignments-meta-cell")], [text(users_label)]),
    ])

  let expansion_rows = case is_expanded {
    True -> [
      tr([attribute.class("expansion-row")], [
        td([attribute.attribute("colspan", "2")], [
          div([attribute.class("assignments-card-body expansion-content")], [
            body,
          ]),
        ]),
      ]),
    ]
    False -> []
  }

  [summary_row, ..expansion_rows]
}

fn view_project_metrics_summary(
  config: Config(msg),
  project_id: Int,
) -> opt.Option(element.Element(msg)) {
  case config.metrics {
    Loaded(OrgMetricsOverview(by_project: projects, ..)) ->
      case list.find(projects, fn(p) { p.project_id == project_id }) {
        Ok(metrics) -> opt.Some(project_metrics_view(config.locale, metrics))
        Error(_) -> opt.None
      }
    _ -> opt.None
  }
}

fn project_metrics_view(
  locale: Locale,
  metrics: OrgMetricsProjectOverview,
) -> element.Element(msg) {
  let t = fn(key) { i18n.t(locale, key) }
  let OrgMetricsProjectOverview(
    available_count: available_count,
    claimed_count: claimed_count,
    ongoing_count: ongoing_count,
    closed_count: closed_count,
    release_rate_percent: release_rate_percent,
    ..,
  ) = metrics

  div([attribute.class("assignments-metrics")], [
    metric_chip.task_metric(locale, task_metric.Available, available_count),
    metric_chip.task_metric(locale, task_metric.Claimed, claimed_count),
    metric_chip.task_metric(locale, task_metric.Ongoing, ongoing_count),
    metric_chip.task_metric(locale, task_metric.Closed, closed_count),
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
  config: Config(msg),
  project_id: Int,
  member: ProjectMember,
  inline_confirm: opt.Option(#(Int, Int)),
) -> element.Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let email = case
    helpers_lookup.resolve_org_user(config.org_users, member.user_id)
  {
    opt.Some(user) -> user.email
    opt.None -> t(i18n_text.UserNumber(member.user_id))
  }

  let is_confirming = case inline_confirm {
    opt.Some(#(pid, uid)) -> pid == project_id && uid == member.user_id
    _ -> False
  }

  let is_role_in_flight = case config.assignments.role_change_in_flight {
    opt.Some(#(pid, uid)) -> pid == project_id && uid == member.user_id
    _ -> False
  }

  let remove_label = t(i18n_text.Remove) <> ": " <> email

  div([attribute.class("assignments-row")], [
    div([attribute.class("assignments-row-title")], [text(email)]),
    select(
      [
        attribute.value(to_string(member.role)),
        attribute.disabled(is_role_in_flight),
        event.on_input(fn(value) {
          case project_member_role.changed_input_value(value, member.role) {
            Ok(new_role) ->
              config.on_role_changed(project_id, member.user_id, new_role)
            Error(_) -> config.noop
          }
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
          ui_button.text(
            t(i18n_text.Remove),
            config.on_remove_confirmed,
            ui_button.Danger,
            ui_button.EntityAction,
          )
            |> ui_button.with_size(ui_button.ExtraSmall)
            |> ui_button.with_accessible_label(remove_label)
            |> ui_button.view,
          ui_button.text(
            t(i18n_text.Cancel),
            config.on_remove_cancelled,
            ui_button.Secondary,
            ui_button.EntityAction,
          )
            |> ui_button.with_size(ui_button.ExtraSmall)
            |> ui_button.view,
        ])
      False ->
        action_buttons.delete_button(
          remove_label,
          config.on_remove_clicked(project_id, member.user_id),
        )
    },
  ])
}

fn view_inline_add(config: Config(msg)) -> element.Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let assignments = config.assignments
  let search = assignments.inline_add_search
  let selected = assignments.inline_add_selection
  let is_disabled = assignments.inline_add_in_flight

  let options = case config.org_users {
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
        event.on_input(fn(value) { config.on_inline_add_search_changed(value) }),
      ]),
      select(
        [
          attribute.value(case selected {
            opt.Some(id) -> int.to_string(id)
            opt.None -> ""
          }),
          event.on_input(fn(value) {
            config.on_inline_add_selection_changed(value)
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
            case project_member_role.input_value(value) {
              Ok(role) -> config.on_inline_add_role_changed(role)
              Error(_) -> config.noop
            }
          }),
        ],
        [
          option([attribute.value("member")], t(i18n_text.RoleMember)),
          option([attribute.value("manager")], t(i18n_text.RoleManager)),
        ],
      ),
      div([attribute.class("assignments-inline-add-actions")], [
        ui_button.text(
          t(i18n_text.Cancel),
          config.on_inline_add_cancelled,
          ui_button.Secondary,
          ui_button.EntityAction,
        )
          |> ui_button.with_size(ui_button.ExtraSmall)
          |> ui_button.with_disabled(is_disabled)
          |> ui_button.view,
        ui_button.text(
          case is_disabled {
            True -> t(i18n_text.Working)
            False -> t(i18n_text.Add)
          },
          config.on_inline_add_submitted,
          ui_button.Primary,
          ui_button.EntityAction,
        )
          |> ui_button.with_size(ui_button.ExtraSmall)
          |> ui_button.with_disabled(is_disabled || selected == opt.None)
          |> ui_button.view,
      ]),
    ]),
  ])
}
