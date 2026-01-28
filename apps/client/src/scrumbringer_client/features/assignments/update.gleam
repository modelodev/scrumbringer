////
//// Update handlers for Assignments admin section.
////

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/set

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser}
import domain/project.{type Project, type ProjectMember, Project, ProjectMember}
import domain/project_role.{type ProjectRole, Member, parse}
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/update_helpers

import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects

// =============================================================================
// Helpers
// =============================================================================

fn update_assignments(
  model: client_state.Model,
  updater: fn(client_state.AssignmentsModel) -> client_state.AssignmentsModel,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    client_state.AdminModel(..admin, assignments: updater(admin.assignments))
  })
}

fn set_project_members_state(
  assignments: client_state.AssignmentsModel,
  project_id: Int,
  state: client_state.Remote(List(ProjectMember)),
) -> client_state.AssignmentsModel {
  let client_state.AssignmentsModel(project_members: project_members, ..) =
    assignments
  client_state.AssignmentsModel(
    ..assignments,
    project_members: dict.insert(project_members, project_id, state),
  )
}

fn set_user_projects_state(
  assignments: client_state.AssignmentsModel,
  user_id: Int,
  state: client_state.Remote(List(Project)),
) -> client_state.AssignmentsModel {
  let client_state.AssignmentsModel(user_projects: user_projects, ..) =
    assignments
  client_state.AssignmentsModel(
    ..assignments,
    user_projects: dict.insert(user_projects, user_id, state),
  )
}

fn toggle_expanded_project(
  assignments: client_state.AssignmentsModel,
  project_id: Int,
) -> client_state.AssignmentsModel {
  let client_state.AssignmentsModel(expanded_projects: expanded, ..) =
    assignments
  let next = case set.contains(expanded, project_id) {
    True -> set.delete(expanded, project_id)
    False -> set.insert(expanded, project_id)
  }
  client_state.AssignmentsModel(..assignments, expanded_projects: next)
}

fn toggle_expanded_user(
  assignments: client_state.AssignmentsModel,
  user_id: Int,
) -> client_state.AssignmentsModel {
  let client_state.AssignmentsModel(expanded_users: expanded, ..) = assignments
  let next = case set.contains(expanded, user_id) {
    True -> set.delete(expanded, user_id)
    False -> set.insert(expanded, user_id)
  }
  client_state.AssignmentsModel(..assignments, expanded_users: next)
}

fn update_project_role(project: Project, role: ProjectRole) -> Project {
  Project(..project, my_role: role)
}

fn update_project_members_role(
  members: client_state.Remote(List(ProjectMember)),
  user_id: Int,
  new_role: ProjectRole,
) -> client_state.Remote(List(ProjectMember)) {
  case members {
    client_state.Loaded(members_list) ->
      client_state.Loaded(
        list.map(members_list, fn(member) {
          case member.user_id == user_id {
            True -> ProjectMember(..member, role: new_role)
            False -> member
          }
        }),
      )
    other -> other
  }
}

fn update_user_projects_role(
  projects: client_state.Remote(List(Project)),
  project_id: Int,
  new_role: ProjectRole,
) -> client_state.Remote(List(Project)) {
  case projects {
    client_state.Loaded(projects_list) ->
      client_state.Loaded(
        list.map(projects_list, fn(project) {
          case project.id == project_id {
            True -> update_project_role(project, new_role)
            False -> project
          }
        }),
      )
    other -> other
  }
}

fn current_role_for_assignment(
  assignments: client_state.AssignmentsModel,
  project_id: Int,
  user_id: Int,
) -> opt.Option(ProjectRole) {
  let client_state.AssignmentsModel(
    project_members: project_members,
    user_projects: user_projects,
    ..,
  ) = assignments

  case dict.get(project_members, project_id) {
    Ok(client_state.Loaded(members)) ->
      case list.find(members, fn(member) { member.user_id == user_id }) {
        Ok(member) -> opt.Some(member.role)
        Error(_) -> opt.None
      }
    _ ->
      case dict.get(user_projects, user_id) {
        Ok(client_state.Loaded(projects)) ->
          case list.find(projects, fn(project) { project.id == project_id }) {
            Ok(project) -> opt.Some(project.my_role)
            Error(_) -> opt.None
          }
        _ -> opt.None
      }
  }
}

fn clear_inline_add(
  assignments: client_state.AssignmentsModel,
) -> client_state.AssignmentsModel {
  client_state.AssignmentsModel(
    ..assignments,
    inline_add_context: opt.None,
    inline_add_selection: opt.None,
    inline_add_search: "",
    inline_add_in_flight: False,
  )
}

fn apply_role_change(
  assignments: client_state.AssignmentsModel,
  project_id: Int,
  user_id: Int,
  new_role: ProjectRole,
) -> client_state.AssignmentsModel {
  let client_state.AssignmentsModel(
    project_members: project_members,
    user_projects: user_projects,
    ..,
  ) = assignments
  let updated_project_members = case dict.get(project_members, project_id) {
    Ok(remote) ->
      dict.insert(
        project_members,
        project_id,
        update_project_members_role(remote, user_id, new_role),
      )
    Error(_) -> project_members
  }
  let updated_user_projects = case dict.get(user_projects, user_id) {
    Ok(remote) ->
      dict.insert(
        user_projects,
        user_id,
        update_user_projects_role(remote, project_id, new_role),
      )
    Error(_) -> user_projects
  }
  client_state.AssignmentsModel(
    ..assignments,
    project_members: updated_project_members,
    user_projects: updated_user_projects,
  )
}

fn handle_role_change_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    case err.status {
      422 -> #(
        model,
        update_helpers.toast_warning(update_helpers.i18n_t(
          model,
          i18n_text.CannotDemoteLastManager,
        )),
      )
      _ -> #(model, update_helpers.toast_error(err.message))
    }
  })
}

// =============================================================================
// View Mode + Search
// =============================================================================

pub fn handle_assignments_view_mode_changed(
  model: client_state.Model,
  view_mode: assignments_view_mode.AssignmentsViewMode,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let model =
    update_assignments(model, fn(assignments) {
      client_state.AssignmentsModel(..assignments, view_mode: view_mode)
    })
  #(model, router.replace_assignments_view(view_mode))
}

pub fn handle_assignments_search_changed(
  model: client_state.Model,
  value: String,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    update_assignments(model, fn(assignments) {
      client_state.AssignmentsModel(..assignments, search_input: value)
    }),
    effect.none(),
  )
}

pub fn handle_assignments_search_debounced(
  model: client_state.Model,
  value: String,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    update_assignments(model, fn(assignments) {
      client_state.AssignmentsModel(..assignments, search_query: value)
    }),
    effect.none(),
  )
}

pub fn handle_assignments_project_toggled(
  model: client_state.Model,
  project_id: Int,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    update_assignments(model, fn(assignments) {
      toggle_expanded_project(assignments, project_id)
    }),
    effect.none(),
  )
}

pub fn handle_assignments_user_toggled(
  model: client_state.Model,
  user_id: Int,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    update_assignments(model, fn(assignments) {
      toggle_expanded_user(assignments, user_id)
    }),
    effect.none(),
  )
}

// =============================================================================
// Data fetch results
// =============================================================================

pub fn handle_assignments_project_members_fetched(
  model: client_state.Model,
  project_id: Int,
  result: Result(List(ProjectMember), ApiError),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case result {
    Ok(members) -> #(
      update_assignments(model, fn(assignments) {
        set_project_members_state(
          assignments,
          project_id,
          client_state.Loaded(members),
        )
      }),
      effect.none(),
    )

    Error(err) ->
      update_helpers.handle_401_or(model, err, fn() {
        #(
          update_assignments(model, fn(assignments) {
            set_project_members_state(
              assignments,
              project_id,
              client_state.Failed(err),
            )
          }),
          effect.none(),
        )
      })
  }
}

pub fn handle_assignments_user_projects_fetched(
  model: client_state.Model,
  user_id: Int,
  result: Result(List(Project), ApiError),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case result {
    Ok(projects) -> #(
      update_assignments(model, fn(assignments) {
        set_user_projects_state(
          assignments,
          user_id,
          client_state.Loaded(projects),
        )
      }),
      effect.none(),
    )

    Error(err) ->
      update_helpers.handle_401_or(model, err, fn() {
        #(
          update_assignments(model, fn(assignments) {
            set_user_projects_state(
              assignments,
              user_id,
              client_state.Failed(err),
            )
          }),
          effect.none(),
        )
      })
  }
}

// =============================================================================
// Inline add flows
// =============================================================================

pub fn handle_assignments_inline_add_started(
  model: client_state.Model,
  context: client_state.AssignmentsAddContext,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let model =
    update_assignments(model, fn(assignments) {
      client_state.AssignmentsModel(
        ..assignments,
        inline_add_context: opt.Some(context),
        inline_add_selection: opt.None,
        inline_add_search: "",
        inline_add_role: Member,
        inline_add_in_flight: False,
      )
    })
  #(model, effect.none())
}

pub fn handle_assignments_inline_add_search_changed(
  model: client_state.Model,
  value: String,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    update_assignments(model, fn(assignments) {
      client_state.AssignmentsModel(..assignments, inline_add_search: value)
    }),
    effect.none(),
  )
}

pub fn handle_assignments_inline_add_selection_changed(
  model: client_state.Model,
  value: String,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let selection = case int.parse(value) {
    Ok(id) -> opt.Some(id)
    Error(_) -> opt.None
  }
  #(
    update_assignments(model, fn(assignments) {
      client_state.AssignmentsModel(
        ..assignments,
        inline_add_selection: selection,
      )
    }),
    effect.none(),
  )
}

pub fn handle_assignments_inline_add_role_changed(
  model: client_state.Model,
  value: String,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let role = case parse(value) {
    Ok(parsed) -> parsed
    Error(_) -> Member
  }
  #(
    update_assignments(model, fn(assignments) {
      client_state.AssignmentsModel(..assignments, inline_add_role: role)
    }),
    effect.none(),
  )
}

pub fn handle_assignments_inline_add_submitted(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let assignments = model.admin.assignments
  let client_state.AssignmentsModel(
    inline_add_context: context,
    inline_add_selection: selection,
    inline_add_role: role,
    inline_add_in_flight: in_flight,
    ..,
  ) = assignments

  case in_flight {
    True -> #(model, effect.none())
    False ->
      case context, selection {
        opt.Some(client_state.AddUserToProject(project_id)), opt.Some(user_id) -> {
          let model =
            update_assignments(model, fn(assignments) {
              client_state.AssignmentsModel(
                ..assignments,
                inline_add_in_flight: True,
              )
            })
          let fx =
            api_projects.add_project_member(
              project_id,
              user_id,
              role,
              fn(result) {
                client_state.admin_msg(
                  client_state.AssignmentsProjectMemberAdded(project_id, result),
                )
              },
            )
          #(model, fx)
        }

        opt.Some(client_state.AddProjectToUser(user_id)), opt.Some(project_id) -> {
          let model =
            update_assignments(model, fn(assignments) {
              client_state.AssignmentsModel(
                ..assignments,
                inline_add_in_flight: True,
              )
            })
          let fx =
            api_org.add_user_to_project(
              user_id,
              project_id,
              project_role.to_string(role),
              fn(result) {
                client_state.admin_msg(client_state.AssignmentsUserProjectAdded(
                  user_id,
                  result,
                ))
              },
            )
          #(model, fx)
        }

        _, _ -> #(model, effect.none())
      }
  }
}

pub fn handle_assignments_inline_add_cancelled(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(update_assignments(model, clear_inline_add), effect.none())
}

pub fn handle_assignments_project_member_added_ok(
  model: client_state.Model,
  project_id: Int,
  member: ProjectMember,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let model = update_assignments(model, clear_inline_add)
  let model =
    update_assignments(model, fn(assignments) {
      assignments
      |> set_project_members_state(project_id, client_state.Loading)
      |> set_user_projects_state(member.user_id, client_state.Loading)
    })

  let effects = [
    api_projects.list_project_members(project_id, fn(result) {
      client_state.admin_msg(client_state.AssignmentsProjectMembersFetched(
        project_id,
        result,
      ))
    }),
    api_org.list_user_projects(member.user_id, fn(result) {
      client_state.admin_msg(client_state.AssignmentsUserProjectsFetched(
        member.user_id,
        result,
      ))
    }),
  ]

  #(model, effect.batch(effects))
}

pub fn handle_assignments_project_member_added_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    let model = update_assignments(model, clear_inline_add)
    #(model, update_helpers.toast_error(err.message))
  })
}

pub fn handle_assignments_user_project_added_ok(
  model: client_state.Model,
  user_id: Int,
  project: Project,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let model = update_assignments(model, clear_inline_add)
  let model =
    update_assignments(model, fn(assignments) {
      assignments
      |> set_user_projects_state(user_id, client_state.Loading)
      |> set_project_members_state(project.id, client_state.Loading)
    })

  let effects = [
    api_org.list_user_projects(user_id, fn(result) {
      client_state.admin_msg(client_state.AssignmentsUserProjectsFetched(
        user_id,
        result,
      ))
    }),
    api_projects.list_project_members(project.id, fn(result) {
      client_state.admin_msg(client_state.AssignmentsProjectMembersFetched(
        project.id,
        result,
      ))
    }),
  ]

  #(model, effect.batch(effects))
}

pub fn handle_assignments_user_project_added_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    let model = update_assignments(model, clear_inline_add)
    #(model, update_helpers.toast_error(err.message))
  })
}

// =============================================================================
// Remove + Role Change
// =============================================================================

pub fn handle_assignments_remove_clicked(
  model: client_state.Model,
  project_id: Int,
  user_id: Int,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    update_assignments(model, fn(assignments) {
      client_state.AssignmentsModel(
        ..assignments,
        inline_remove_confirm: opt.Some(#(project_id, user_id)),
      )
    }),
    effect.none(),
  )
}

pub fn handle_assignments_remove_cancelled(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    update_assignments(model, fn(assignments) {
      client_state.AssignmentsModel(
        ..assignments,
        inline_remove_confirm: opt.None,
      )
    }),
    effect.none(),
  )
}

pub fn handle_assignments_remove_confirmed(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.admin.assignments.inline_remove_confirm {
    opt.Some(#(project_id, user_id)) -> {
      let model =
        update_assignments(model, fn(assignments) {
          client_state.AssignmentsModel(
            ..assignments,
            inline_remove_confirm: opt.None,
          )
        })
      let fx =
        api_projects.remove_project_member(project_id, user_id, fn(result) {
          client_state.admin_msg(client_state.AssignmentsRemoveCompleted(
            project_id,
            user_id,
            result,
          ))
        })
      #(model, fx)
    }
    opt.None -> #(model, effect.none())
  }
}

pub fn handle_assignments_remove_completed_ok(
  model: client_state.Model,
  project_id: Int,
  user_id: Int,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let model =
    update_assignments(model, fn(assignments) {
      let client_state.AssignmentsModel(
        project_members: project_members,
        user_projects: user_projects,
        ..,
      ) = assignments
      let updated_project_members = case dict.get(project_members, project_id) {
        Ok(client_state.Loaded(members)) ->
          dict.insert(
            project_members,
            project_id,
            client_state.Loaded(
              list.filter(members, fn(member) { member.user_id != user_id }),
            ),
          )
        _ -> project_members
      }
      let updated_user_projects = case dict.get(user_projects, user_id) {
        Ok(client_state.Loaded(projects)) ->
          dict.insert(
            user_projects,
            user_id,
            client_state.Loaded(
              list.filter(projects, fn(project) { project.id != project_id }),
            ),
          )
        _ -> user_projects
      }
      client_state.AssignmentsModel(
        ..assignments,
        project_members: updated_project_members,
        user_projects: updated_user_projects,
      )
    })
  #(model, effect.none())
}

pub fn handle_assignments_remove_completed_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(model, update_helpers.toast_error(err.message))
  })
}

pub fn handle_assignments_role_changed(
  model: client_state.Model,
  project_id: Int,
  user_id: Int,
  new_role: ProjectRole,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let assignments = model.admin.assignments
  let previous_role =
    current_role_for_assignment(assignments, project_id, user_id)
  let model =
    update_assignments(model, fn(assignments) {
      assignments
      |> apply_role_change(project_id, user_id, new_role)
      |> fn(updated) {
        client_state.AssignmentsModel(
          ..updated,
          role_change_in_flight: opt.Some(#(project_id, user_id)),
          role_change_previous: case previous_role {
            opt.Some(role) -> opt.Some(#(project_id, user_id, role))
            opt.None -> opt.None
          },
        )
      }
    })

  let fx =
    api_projects.update_member_role(project_id, user_id, new_role, fn(result) {
      client_state.admin_msg(client_state.AssignmentsRoleChangeCompleted(
        project_id,
        user_id,
        result,
      ))
    })

  #(model, fx)
}

pub fn handle_assignments_role_change_completed_ok(
  model: client_state.Model,
  project_id: Int,
  user_id: Int,
  result: api_projects.RoleChangeResult,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let model =
    update_assignments(model, fn(assignments) {
      let updated =
        apply_role_change(assignments, project_id, user_id, result.role)
      client_state.AssignmentsModel(
        ..updated,
        role_change_in_flight: opt.None,
        role_change_previous: opt.None,
      )
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.RoleUpdated,
    ))
  #(model, toast_fx)
}

pub fn handle_assignments_role_change_completed_error(
  model: client_state.Model,
  project_id: Int,
  user_id: Int,
  err: ApiError,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let assignments = model.admin.assignments
  let updated = case assignments.role_change_previous {
    opt.Some(#(pid, uid, previous)) if pid == project_id && uid == user_id ->
      apply_role_change(assignments, project_id, user_id, previous)
    _ -> assignments
  }
  let model =
    update_assignments(model, fn(_) {
      client_state.AssignmentsModel(
        ..updated,
        role_change_in_flight: opt.None,
        role_change_previous: opt.None,
      )
    })
  handle_role_change_error(model, err)
}

// =============================================================================
// Fetch helpers for assignments
// =============================================================================

pub fn start_user_projects_fetch(
  model: client_state.Model,
  users: List(OrgUser),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.core.active_section {
    permissions.Assignments -> {
      let assignments = model.admin.assignments
      let #(next_assignments, effects) =
        list.fold(users, #(assignments, []), fn(state, user) {
          let #(current, fx) = state
          let client_state.AssignmentsModel(user_projects: projects, ..) =
            current
          let should_fetch = case dict.get(projects, user.id) {
            Ok(client_state.Loading) -> False
            Ok(client_state.Loaded(_)) -> False
            Ok(client_state.NotAsked) -> True
            Ok(client_state.Failed(_)) -> True
            Error(_) -> True
          }
          case should_fetch {
            False -> #(current, fx)
            True -> {
              let updated =
                set_user_projects_state(current, user.id, client_state.Loading)
              let effect =
                api_org.list_user_projects(user.id, fn(result) {
                  client_state.admin_msg(
                    client_state.AssignmentsUserProjectsFetched(user.id, result),
                  )
                })
              #(updated, [effect, ..fx])
            }
          }
        })

      let model = update_assignments(model, fn(_) { next_assignments })
      #(model, effect.batch(list.reverse(effects)))
    }

    _ -> #(model, effect.none())
  }
}
