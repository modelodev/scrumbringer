////
//// Assignments admin view.
////

import gleam/dict
import gleam/list
import gleam/option as opt
import gleam/set
import gleam/string

import lustre/attribute
import lustre/element
import lustre/element/html.{
  button, div, input, table, tbody, text, th, thead, tr,
}
import lustre/event

import domain/org.{type OrgUser, OrgUser}
import domain/project.{type Project}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/user.{User}

import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/assignments/components/project_card
import scrumbringer_client/features/assignments/components/user_card
import scrumbringer_client/features/projects/view as projects_view
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/section_header

pub fn view_assignments(
  model: client_state.Model,
) -> element.Element(client_state.Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }

  div([attribute.class("section")], [
    section_header.view(icons.Team, t(i18n_text.Assignments)),
    view_toolbar(model),
    case model.admin.assignments.view_mode {
      assignments_view_mode.ByProject -> view_by_project(model)
      assignments_view_mode.ByUser -> view_by_user(model)
    },
    projects_view.view_project_dialogs(model),
  ])
}

fn view_toolbar(model: client_state.Model) -> element.Element(client_state.Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }
  let assignments = model.admin.assignments
  let is_projects = assignments.view_mode == assignments_view_mode.ByProject
  let is_users = assignments.view_mode == assignments_view_mode.ByUser

  div([attribute.class("admin-card assignments-toolbar-card")], [
    div([attribute.class("filters-row assignments-toolbar")], [
      div([attribute.class("field assignments-toggle-field")], [
        div([attribute.class("view-mode-toggle assignments-toggle")], [
          button(
            [
              attribute.class(
                "view-mode-btn"
                <> case is_projects {
                  True -> " active"
                  False -> ""
                },
              ),
              event.on_click(
                client_state.admin_msg(
                  admin_messages.AssignmentsViewModeChanged(
                    assignments_view_mode.ByProject,
                  ),
                ),
              ),
            ],
            [text(t(i18n_text.AssignmentsByProject))],
          ),
          button(
            [
              attribute.class(
                "view-mode-btn"
                <> case is_users {
                  True -> " active"
                  False -> ""
                },
              ),
              event.on_click(
                client_state.admin_msg(
                  admin_messages.AssignmentsViewModeChanged(
                    assignments_view_mode.ByUser,
                  ),
                ),
              ),
            ],
            [text(t(i18n_text.AssignmentsByUser))],
          ),
        ]),
      ]),
      div([attribute.class("field filter-q assignments-search")], [
        input([
          attribute.type_("text"),
          attribute.value(assignments.search_input),
          attribute.placeholder(t(i18n_text.AssignmentsSearchPlaceholder)),
          event.on_input(fn(value) {
            client_state.admin_msg(admin_messages.AssignmentsSearchChanged(
              value,
            ))
          }),
          event.debounce(
            event.on_input(fn(value) {
              client_state.admin_msg(admin_messages.AssignmentsSearchDebounced(
                value,
              ))
            }),
            350,
          ),
        ]),
      ]),
    ]),
  ])
}

fn view_by_project(
  model: client_state.Model,
) -> element.Element(client_state.Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }
  case model.core.projects {
    NotAsked | Loading ->
      loading.loading(t(i18n_text.AssignmentsLoadingProjects))

    Failed(err) -> error_notice.view(err.message)

    Loaded(projects_list) ->
      case projects_list == [] {
        True ->
          empty_state.no_projects(
            t(i18n_text.AssignmentsNoProjectsTitle),
            t(i18n_text.AssignmentsNoProjectsBody),
          )
          |> empty_state.with_action(
            t(i18n_text.CreateProject),
            client_state.admin_msg(admin_messages.ProjectCreateDialogOpened),
          )
          |> empty_state.view

        False ->
          table([attribute.class("table assignments-table")], [
            thead([], [
              tr([], [
                th([], [text(t(i18n_text.AssignmentsByProject))]),
                th([], [text(t(i18n_text.MembersCount))]),
              ]),
            ]),
            tbody([], [
              filter_projects(model, projects_list)
              |> list.flat_map(fn(project) {
                let members_state = case
                  dict.get(model.admin.assignments.project_members, project.id)
                {
                  Ok(state) -> state
                  Error(_) -> NotAsked
                }
                let expanded =
                  set.contains(
                    model.admin.assignments.expanded_projects,
                    project.id,
                  )
                project_card.view_rows(model, project, members_state, expanded)
              })
              |> element.fragment,
            ]),
          ])
      }
  }
}

fn view_by_user(model: client_state.Model) -> element.Element(client_state.Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }
  case model.admin.members.org_users_cache {
    NotAsked | Loading -> loading.loading(t(i18n_text.LoadingUsers))

    Failed(err) -> error_notice.view(err.message)

    Loaded(users_list) -> {
      let only_current_user = case model.core.user, list.first(users_list) {
        opt.Some(User(id: user_id, ..)), Ok(OrgUser(id: org_user_id, ..)) ->
          list.length(users_list) == 1 && user_id == org_user_id
        _, _ -> False
      }
      case users_list == [] || only_current_user {
        True ->
          empty_state.no_members(
            t(i18n_text.AssignmentsNoUsersTitle),
            t(i18n_text.AssignmentsNoUsersBody),
          )
          |> empty_state.with_action(
            t(i18n_text.CreateInviteLink),
            client_state.NavigateTo(
              router.Org(permissions.Invites),
              client_state.Push,
            ),
          )
          |> empty_state.view

        False ->
          table([attribute.class("table assignments-table")], [
            thead([], [
              tr([], [
                th([], [text(t(i18n_text.AssignmentsByUser))]),
                th([], [text(t(i18n_text.Projects))]),
              ]),
            ]),
            tbody([], [
              filter_users(model, users_list)
              |> list.flat_map(fn(user) {
                let projects_state = case
                  dict.get(model.admin.assignments.user_projects, user.id)
                {
                  Ok(state) -> state
                  Error(_) -> NotAsked
                }
                let expanded =
                  set.contains(model.admin.assignments.expanded_users, user.id)
                user_card.view_rows(model, user, projects_state, expanded)
              })
              |> element.fragment,
            ]),
          ])
      }
    }
  }
}

fn filter_projects(
  model: client_state.Model,
  projects: List(Project),
) -> List(Project) {
  let query =
    string.lowercase(string.trim(model.admin.assignments.search_query))
  case query == "" {
    True -> projects
    False ->
      list.filter(projects, fn(project) {
        let project_name = string.lowercase(project.name)
        case string.contains(project_name, query) {
          True -> True
          False -> project_members_match(model, project.id, query)
        }
      })
  }
}

fn project_members_match(
  model: client_state.Model,
  project_id: Int,
  query: String,
) -> Bool {
  case dict.get(model.admin.assignments.project_members, project_id) {
    Ok(Loaded(members)) ->
      list.any(members, fn(member) {
        case
          helpers_lookup.resolve_org_user(
            model.admin.members.org_users_cache,
            member.user_id,
          )
        {
          opt.Some(user) -> string.contains(string.lowercase(user.email), query)
          opt.None -> False
        }
      })
    _ -> False
  }
}

fn filter_users(
  model: client_state.Model,
  users: List(OrgUser),
) -> List(OrgUser) {
  let query =
    string.lowercase(string.trim(model.admin.assignments.search_query))
  case query == "" {
    True -> users
    False ->
      list.filter(users, fn(user) {
        case string.contains(string.lowercase(user.email), query) {
          True -> True
          False -> user_projects_match(model, user.id, query)
        }
      })
  }
}

fn user_projects_match(
  model: client_state.Model,
  user_id: Int,
  query: String,
) -> Bool {
  case dict.get(model.admin.assignments.user_projects, user_id) {
    Ok(Loaded(projects)) ->
      list.any(projects, fn(project) {
        string.contains(string.lowercase(project.name), query)
      })
    _ -> False
  }
}
