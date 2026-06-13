////
//// Team admin view.
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
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}

import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/assignments/components/project_card
import scrumbringer_client/features/assignments/components/user_card
import scrumbringer_client/features/projects/view as projects_view
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/admin_surface
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/section_header

pub type Config(msg) {
  Config(
    locale: Locale,
    assignments: state_types.AssignmentsModel,
    projects: Remote(List(Project)),
    org_users: Remote(List(OrgUser)),
    project_card: project_card.Config(msg),
    user_card: user_card.Config(msg),
    on_view_mode_changed: fn(assignments_view_mode.AssignmentsViewMode) -> msg,
    on_search_changed: fn(String) -> msg,
    on_search_debounced: fn(String) -> msg,
    on_project_create_clicked: msg,
    on_invites_clicked: msg,
    project_dialogs: projects_view.Config(msg),
  )
}

pub fn view_assignments(config: Config(msg)) -> element.Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }

  admin_surface.view_with_filters(
    section_header.view(icons.Team, t(i18n_text.Team)),
    view_toolbar(config),
    case config.assignments.view_mode {
      assignments_view_mode.ByProject -> view_by_project(config)
      assignments_view_mode.ByUser -> view_by_user(config)
    },
    [projects_view.view_project_dialogs(config.project_dialogs)],
  )
}

fn view_toolbar(config: Config(msg)) -> element.Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let assignments = config.assignments
  let is_projects = assignments.view_mode == assignments_view_mode.ByProject
  let is_users = assignments.view_mode == assignments_view_mode.ByUser

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
            event.on_click(config.on_view_mode_changed(
              assignments_view_mode.ByProject,
            )),
          ],
          [text(t(i18n_text.TeamByProject))],
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
            event.on_click(config.on_view_mode_changed(
              assignments_view_mode.ByUser,
            )),
          ],
          [text(t(i18n_text.TeamByPerson))],
        ),
      ]),
    ]),
    div([attribute.class("field filter-q assignments-search")], [
      input([
        attribute.type_("text"),
        attribute.value(assignments.search_input),
        attribute.placeholder(t(i18n_text.TeamSearchPlaceholder)),
        event.on_input(config.on_search_changed),
        event.debounce(event.on_input(config.on_search_debounced), 350),
      ]),
    ]),
  ])
}

fn view_by_project(config: Config(msg)) -> element.Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  case config.projects {
    NotAsked | Loading -> loading.loading(t(i18n_text.TeamLoadingProjects))

    Failed(err) -> error_notice.view(err.message)

    Loaded(projects_list) ->
      case projects_list == [] {
        True ->
          empty_state.no_projects(
            t(i18n_text.TeamNoProjectsTitle),
            t(i18n_text.TeamNoProjectsBody),
          )
          |> empty_state.with_action(
            t(i18n_text.CreateProject),
            config.on_project_create_clicked,
          )
          |> empty_state.view

        False ->
          table([attribute.class("table assignments-table")], [
            thead([], [
              tr([], [
                th([], [text(t(i18n_text.TeamByProject))]),
                th([], [text(t(i18n_text.MembersCount))]),
              ]),
            ]),
            tbody([], [
              filter_projects(config, projects_list)
              |> list.flat_map(fn(project) {
                let members_state = case
                  dict.get(config.assignments.project_members, project.id)
                {
                  Ok(state) -> state
                  Error(_) -> NotAsked
                }
                let expanded =
                  set.contains(config.assignments.expanded_projects, project.id)
                project_card.view_rows(
                  config.project_card,
                  project,
                  members_state,
                  expanded,
                )
              })
              |> element.fragment,
            ]),
          ])
      }
  }
}

fn view_by_user(config: Config(msg)) -> element.Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  case config.org_users {
    NotAsked | Loading -> loading.loading(t(i18n_text.LoadingUsers))

    Failed(err) -> error_notice.view(err.message)

    Loaded(users_list) -> {
      let only_current_user = case
        config.project_card.current_user_id,
        list.first(users_list)
      {
        opt.Some(user_id), Ok(OrgUser(id: org_user_id, ..)) ->
          list.length(users_list) == 1 && user_id == org_user_id
        _, _ -> False
      }
      case users_list == [] || only_current_user {
        True ->
          empty_state.no_members(
            t(i18n_text.TeamNoPeopleTitle),
            t(i18n_text.TeamNoPeopleBody),
          )
          |> empty_state.with_action(
            t(i18n_text.CreateInviteLink),
            config.on_invites_clicked,
          )
          |> empty_state.view

        False ->
          table([attribute.class("table assignments-table")], [
            thead([], [
              tr([], [
                th([], [text(t(i18n_text.TeamByPerson))]),
                th([], [text(t(i18n_text.Projects))]),
              ]),
            ]),
            tbody([], [
              filter_users(config, users_list)
              |> list.flat_map(fn(user) {
                let projects_state = case
                  dict.get(config.assignments.user_projects, user.id)
                {
                  Ok(state) -> state
                  Error(_) -> NotAsked
                }
                let expanded =
                  set.contains(config.assignments.expanded_users, user.id)
                user_card.view_rows(
                  config.user_card,
                  user,
                  projects_state,
                  expanded,
                )
              })
              |> element.fragment,
            ]),
          ])
      }
    }
  }
}

fn filter_projects(
  config: Config(msg),
  projects: List(Project),
) -> List(Project) {
  let query = string.lowercase(string.trim(config.assignments.search_query))
  case query == "" {
    True -> projects
    False ->
      list.filter(projects, fn(project) {
        let project_name = string.lowercase(project.name)
        case string.contains(project_name, query) {
          True -> True
          False -> project_members_match(config, project.id, query)
        }
      })
  }
}

fn project_members_match(
  config: Config(msg),
  project_id: Int,
  query: String,
) -> Bool {
  case dict.get(config.assignments.project_members, project_id) {
    Ok(Loaded(members)) ->
      list.any(members, fn(member) {
        case helpers_lookup.resolve_org_user(config.org_users, member.user_id) {
          opt.Some(user) -> string.contains(string.lowercase(user.email), query)
          opt.None -> False
        }
      })
    _ -> False
  }
}

fn filter_users(config: Config(msg), users: List(OrgUser)) -> List(OrgUser) {
  let query = string.lowercase(string.trim(config.assignments.search_query))
  case query == "" {
    True -> users
    False ->
      list.filter(users, fn(user) {
        case string.contains(string.lowercase(user.email), query) {
          True -> True
          False -> user_projects_match(config, user.id, query)
        }
      })
  }
}

fn user_projects_match(config: Config(msg), user_id: Int, query: String) -> Bool {
  case dict.get(config.assignments.user_projects, user_id) {
    Ok(Loaded(projects)) ->
      list.any(projects, fn(project) {
        string.contains(string.lowercase(project.name), query)
      })
    _ -> False
  }
}
