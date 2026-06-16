////
//// User card for assignments view.
////

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element
import lustre/element/html.{button, div, option, p, select, td, text, tr}
import lustre/event

import domain/metrics.{type OrgMetricsUserOverview, OrgMetricsUserOverview}
import domain/org.{type OrgUser}
import domain/project.{type Project}
import domain/project_role.{type ProjectRole, Manager, Member, to_string}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}

import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/features/admin/member_role as project_member_role
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

pub type Config(msg) {
  Config(
    locale: Locale,
    assignments: assignments_state.AssignmentsModel,
    all_projects: Remote(List(Project)),
    metrics: Remote(List(OrgMetricsUserOverview)),
    on_user_toggled: fn(Int) -> msg,
    on_inline_add_started: fn(assignments_state.AssignmentsAddContext) -> msg,
    on_role_changed: fn(Int, Int, ProjectRole) -> msg,
    on_remove_confirmed: msg,
    on_remove_cancelled: msg,
    on_remove_clicked: fn(Int, Int) -> msg,
    on_inline_add_selection_changed: fn(String) -> msg,
    on_inline_add_role_changed: fn(ProjectRole) -> msg,
    on_inline_add_cancelled: msg,
    on_inline_add_submitted: msg,
    noop: msg,
  )
}

pub fn view_rows(
  config: Config(msg),
  user: OrgUser,
  projects_state: Remote(List(Project)),
  expanded: Bool,
) -> List(element.Element(msg)) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let assignments = config.assignments

  let projects = case projects_state {
    Loaded(projects_list) -> projects_list
    _ -> []
  }

  let no_projects = case projects_state {
    Loaded(projects_list) -> projects_list == []
    _ -> False
  }

  let warning_badge = case no_projects {
    True ->
      badge.new_unchecked(t(i18n_text.TeamNoProjectsBadge), badge.Warning)
      |> badge.view_inline
    False -> element.none()
  }

  let projects_count = case projects_state {
    Loaded(projects_list) -> list.length(projects_list)
    _ -> list.length(projects)
  }
  let projects_label = t(i18n_text.TeamProjectsCount(projects_count))
  let metrics_summary = view_user_metrics_summary(config, user.id)

  let is_inline_add = case assignments.inline_add_context {
    opt.Some(assignments_state.AddProjectToUser(id)) -> id == user.id
    _ -> False
  }

  let inline_confirm = assignments.inline_remove_confirm

  let is_confirming = case inline_confirm {
    opt.Some(#(uid, _)) -> uid == user.id
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
      case projects_state {
        NotAsked | Loading -> loading.loading(t(i18n_text.TeamLoadingProjects))

        Failed(err) -> error_notice.view(err.message)

        Loaded(projects_list) ->
          case projects_list == [] {
            True ->
              p([attribute.class("assignments-empty")], [
                text(t(i18n_text.UserProjectsEmpty)),
              ])
            False ->
              div([attribute.class("assignments-rows")], [
                list.map(projects_list, fn(project) {
                  view_project_row(config, user.id, project, inline_confirm)
                })
                |> element.fragment,
              ])
          }
      },
      case is_inline_add {
        True -> view_inline_add(config, projects)
        False ->
          ui_button.text(
            t(i18n_text.UserProjectsAdd),
            config.on_inline_add_started(assignments_state.AddProjectToUser(
              user.id,
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
              event.on_click(config.on_user_toggled(user.id)),
            ],
            [expand_toggle.view(is_expanded)],
          ),
          div([attribute.class("assignments-card-icon")], [
            icons.nav_icon(icons.Team, icons.Small),
          ]),
          text(user.email),
          warning_badge,
        ]),
      ]),
      td([attribute.class("assignments-meta-cell")], [text(projects_label)]),
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

fn view_user_metrics_summary(
  config: Config(msg),
  user_id: Int,
) -> opt.Option(element.Element(msg)) {
  case config.metrics {
    Loaded(users) ->
      case list.find(users, fn(user) { user.user_id == user_id }) {
        Ok(metrics) -> opt.Some(user_metrics_view(config.locale, metrics))
        Error(_) -> opt.None
      }
    _ -> opt.None
  }
}

fn user_metrics_view(
  locale: Locale,
  metrics: OrgMetricsUserOverview,
) -> element.Element(msg) {
  let t = fn(key) { i18n.t(locale, key) }
  let OrgMetricsUserOverview(
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
    ongoing_count: ongoing_count,
    last_claim_at: last_claim_at,
    ..,
  ) = metrics

  div([attribute.class("assignments-metrics")], [
    div([attribute.class("assignments-metrics-item")], [
      text(t(i18n_text.Claimed) <> ": " <> int.to_string(claimed_count)),
    ]),
    div([attribute.class("assignments-metrics-item")], [
      text(t(i18n_text.Released) <> ": " <> int.to_string(released_count)),
    ]),
    div([attribute.class("assignments-metrics-item")], [
      text(t(i18n_text.Completed) <> ": " <> int.to_string(completed_count)),
    ]),
    div([attribute.class("assignments-metrics-item")], [
      text(t(i18n_text.OngoingCount) <> ": " <> int.to_string(ongoing_count)),
    ]),
    div([attribute.class("assignments-metrics-item")], [
      text(t(i18n_text.LastClaim) <> ": " <> option_string_label(last_claim_at)),
    ]),
  ])
}

fn option_string_label(value: opt.Option(String)) -> String {
  case value {
    opt.Some(v) -> v
    opt.None -> "-"
  }
}

fn view_project_row(
  config: Config(msg),
  user_id: Int,
  project: Project,
  inline_confirm: opt.Option(#(Int, Int)),
) -> element.Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let is_confirming = case inline_confirm {
    opt.Some(#(pid, uid)) -> pid == project.id && uid == user_id
    _ -> False
  }

  let is_role_in_flight = case config.assignments.role_change_in_flight {
    opt.Some(#(pid, uid)) -> pid == project.id && uid == user_id
    _ -> False
  }

  let remove_label = t(i18n_text.Remove) <> ": " <> project.name

  div([attribute.class("assignments-row")], [
    div([attribute.class("assignments-row-title")], [text(project.name)]),
    select(
      [
        attribute.value(to_string(project.my_role)),
        attribute.disabled(is_role_in_flight),
        event.on_input(fn(value) {
          case project_member_role.changed_input_value(value, project.my_role) {
            Ok(new_role) ->
              config.on_role_changed(project.id, user_id, new_role)
            Error(_) -> config.noop
          }
        }),
      ],
      [
        option(
          [
            attribute.value("member"),
            attribute.selected(project.my_role == Member),
          ],
          t(i18n_text.RoleMember),
        ),
        option(
          [
            attribute.value("manager"),
            attribute.selected(project.my_role == Manager),
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
          config.on_remove_clicked(project.id, user_id),
        )
    },
  ])
}

fn view_inline_add(
  config: Config(msg),
  assigned_projects: List(Project),
) -> element.Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let assignments = config.assignments
  let selected = assignments.inline_add_selection
  let is_disabled = assignments.inline_add_in_flight

  let assigned_ids = list.map(assigned_projects, fn(project) { project.id })
  let options = case config.all_projects {
    Loaded(projects) ->
      projects
      |> list.filter(fn(project) { !list.contains(assigned_ids, project.id) })
      |> list.map(fn(project) {
        option([attribute.value(int.to_string(project.id))], project.name)
      })
    _ -> []
  }

  div([attribute.class("assignments-inline-add")], [
    div([attribute.class("assignments-inline-add-row")], [
      div([attribute.class("assignments-inline-add-label")], [
        text(t(i18n_text.UserProjectsAdd)),
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
            t(i18n_text.SelectProject),
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
