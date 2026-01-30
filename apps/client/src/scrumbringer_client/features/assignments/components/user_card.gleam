////
//// User card for assignments view.
////

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element
import lustre/element/html.{button, div, option, p, select, span, text}
import lustre/event

import domain/org.{type OrgUser}
import domain/project.{type Project}
import domain/project_role.{Manager, Member, to_string}

import scrumbringer_client/client_state
import scrumbringer_client/features/assignments/components/assignments_card
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/status_block
import scrumbringer_client/update_helpers

pub fn view(
  model: client_state.Model,
  user: OrgUser,
  projects_state: client_state.Remote(List(Project)),
  expanded: Bool,
) -> element.Element(client_state.Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }
  let assignments = model.admin.assignments

  let projects = case projects_state {
    client_state.Loaded(projects_list) -> projects_list
    _ -> []
  }

  let no_projects = case projects_state {
    client_state.Loaded(projects_list) -> projects_list == []
    _ -> False
  }

  let warning_badge = case no_projects {
    True ->
      badge.new_unchecked(
        t(i18n_text.AssignmentsNoProjectsBadge),
        badge.Warning,
      )
      |> badge.view_inline
    False -> element.none()
  }

  let projects_count = case projects_state {
    client_state.Loaded(projects_list) -> list.length(projects_list)
    _ -> list.length(projects)
  }
  let projects_label = t(i18n_text.AssignmentsProjectsCount(projects_count))

  let is_inline_add = case assignments.inline_add_context {
    opt.Some(client_state.AddProjectToUser(id)) -> id == user.id
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
      case projects_state {
        client_state.NotAsked | client_state.Loading ->
          loading.loading(t(i18n_text.AssignmentsLoadingProjects))

        client_state.Failed(err) -> status_block.error_text(err.message)

        client_state.Loaded(projects_list) ->
          case projects_list == [] {
            True ->
              p([attribute.class("assignments-empty")], [
                text(t(i18n_text.UserProjectsEmpty)),
              ])
            False ->
              div([], [
                list.map(projects_list, fn(project) {
                  view_project_row(model, user.id, project, inline_confirm)
                })
                |> element.fragment,
              ])
          }
      },
      case is_inline_add {
        True -> view_inline_add(model, user.id, projects)
        False ->
          button(
            [
              attribute.class("btn-sm"),
              event.on_click(
                client_state.admin_msg(
                  client_state.AssignmentsInlineAddStarted(
                    client_state.AddProjectToUser(user.id),
                  ),
                ),
              ),
            ],
            [text(t(i18n_text.UserProjectsAdd))],
          )
      },
    ])

  assignments_card.view(assignments_card.Config(
    title: user.email,
    icon: icons.Team,
    badge: warning_badge,
    meta: projects_label,
    expanded: is_expanded,
    toggle_label: toggle_label,
    on_toggle: client_state.admin_msg(client_state.AssignmentsUserToggled(
      user.id,
    )),
    body: body,
  ))
}

fn view_project_row(
  model: client_state.Model,
  user_id: Int,
  project: Project,
  inline_confirm: opt.Option(#(Int, Int)),
) -> element.Element(client_state.Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }
  let is_confirming = case inline_confirm {
    opt.Some(#(pid, uid)) -> pid == project.id && uid == user_id
    _ -> False
  }

  let is_role_in_flight = case model.admin.assignments.role_change_in_flight {
    opt.Some(#(pid, uid)) -> pid == project.id && uid == user_id
    _ -> False
  }

  div([attribute.class("assignments-row")], [
    div([attribute.class("assignments-row-title")], [text(project.name)]),
    select(
      [
        attribute.value(to_string(project.my_role)),
        attribute.disabled(is_role_in_flight),
        event.on_input(fn(value) {
          let new_role = case value {
            "manager" -> Manager
            _ -> Member
          }
          client_state.admin_msg(client_state.AssignmentsRoleChanged(
            project.id,
            user_id,
            new_role,
          ))
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
          button(
            [
              attribute.class("btn-xs btn-danger"),
              event.on_click(client_state.admin_msg(
                client_state.AssignmentsRemoveConfirmed,
              )),
            ],
            [text(t(i18n_text.Remove))],
          ),
          button(
            [
              attribute.class("btn-xs"),
              event.on_click(client_state.admin_msg(
                client_state.AssignmentsRemoveCancelled,
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
              client_state.admin_msg(client_state.AssignmentsRemoveClicked(
                project.id,
                user_id,
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
  _user_id: Int,
  assigned_projects: List(Project),
) -> element.Element(client_state.Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }
  let assignments = model.admin.assignments
  let selected = assignments.inline_add_selection
  let is_disabled = assignments.inline_add_in_flight

  let assigned_ids = list.map(assigned_projects, fn(project) { project.id })
  let options = case model.core.projects {
    client_state.Loaded(projects) ->
      projects
      |> list.filter(fn(project) { !list.contains(assigned_ids, project.id) })
      |> list.map(fn(project) {
        option([attribute.value(int.to_string(project.id))], project.name)
      })
    _ -> []
  }

  div([attribute.class("assignments-inline-add")], [
    div([attribute.class("assignments-inline-add-row")], [
      span([attribute.class("assignments-inline-add-label")], [
        text(t(i18n_text.UserProjectsAdd)),
      ]),
      select(
        [
          attribute.value(case selected {
            opt.Some(id) -> int.to_string(id)
            opt.None -> ""
          }),
          event.on_input(fn(value) {
            client_state.admin_msg(
              client_state.AssignmentsInlineAddSelectionChanged(value),
            )
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
            client_state.admin_msg(client_state.AssignmentsInlineAddRoleChanged(
              value,
            ))
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
              client_state.AssignmentsInlineAddCancelled,
            )),
          ],
          [text(t(i18n_text.Cancel))],
        ),
        button(
          [
            attribute.class("btn-xs btn-primary"),
            attribute.disabled(is_disabled || selected == opt.None),
            event.on_click(client_state.admin_msg(
              client_state.AssignmentsInlineAddSubmitted,
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
