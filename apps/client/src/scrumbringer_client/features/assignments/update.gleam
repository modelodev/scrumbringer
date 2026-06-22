////
//// Update handlers for Assignments admin section.
////

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/set

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/org.{type OrgUser}
import domain/project.{type Project, type ProjectMember, Project, ProjectMember}
import domain/project_role.{type ProjectRole, Member}
import domain/remote.{type Remote, Loaded, Loading, from_result, should_fetch}
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/permissions

import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/features/admin/msg as admin_messages

pub type Context(parent_msg) {
  Context(
    active_section: permissions.AdminSection,
    on_project_members_fetched: fn(Int, ApiResult(List(ProjectMember))) ->
      parent_msg,
    on_user_projects_fetched: fn(Int, ApiResult(List(Project))) -> parent_msg,
    on_project_member_added: fn(Int, ApiResult(ProjectMember)) -> parent_msg,
    on_user_project_added: fn(Int, ApiResult(Project)) -> parent_msg,
    on_remove_completed: fn(Int, Int, ApiResult(Nil)) -> parent_msg,
    on_role_change_completed: fn(
      Int,
      Int,
      ApiResult(api_projects.RoleChangeResult),
    ) ->
      parent_msg,
  )
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(on_error_toast: fn(String) -> Effect(parent_msg))
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
  CheckAuthAfterUpdate(ApiError)
}

pub type RootPolicy {
  NoRootPolicy
  ReplaceAssignmentsView(assignments_view_mode.AssignmentsViewMode)
  MemberRoleSuccessFeedback
  MemberRoleErrorFeedback(ApiError)
}

pub type Update(parent_msg) {
  Update(
    assignments_state.AssignmentsModel,
    Effect(parent_msg),
    AuthPolicy,
    RootPolicy,
  )
}

pub fn try_update(
  model: assignments_state.AssignmentsModel,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.AssignmentsViewModeChanged(view_mode) ->
      handle_assignments_view_mode_changed(model, view_mode)
      |> without_auth_check_with_root(ReplaceAssignmentsView(view_mode))

    admin_messages.AssignmentsSearchChanged(value) ->
      handle_assignments_search_changed(model, value)
      |> without_auth_check

    admin_messages.AssignmentsSearchDebounced(value) ->
      handle_assignments_search_debounced(model, value)
      |> without_auth_check

    admin_messages.AssignmentsProjectToggled(project_id) ->
      handle_assignments_project_toggled(model, project_id)
      |> without_auth_check

    admin_messages.AssignmentsUserToggled(user_id) ->
      handle_assignments_user_toggled(model, user_id)
      |> without_auth_check

    admin_messages.AssignmentsProjectMembersFetched(project_id, Ok(members)) ->
      handle_assignments_project_members_fetched(model, project_id, Ok(members))
      |> without_auth_check

    admin_messages.AssignmentsProjectMembersFetched(project_id, Error(err)) ->
      handle_assignments_project_members_fetched(model, project_id, Error(err))
      |> with_auth_check(err)

    admin_messages.AssignmentsUserProjectsFetched(user_id, Ok(projects)) ->
      handle_assignments_user_projects_fetched(model, user_id, Ok(projects))
      |> without_auth_check

    admin_messages.AssignmentsUserProjectsFetched(user_id, Error(err)) ->
      handle_assignments_user_projects_fetched(model, user_id, Error(err))
      |> with_auth_check(err)

    admin_messages.AssignmentsInlineAddStarted(context) ->
      handle_assignments_inline_add_started(model, context)
      |> without_auth_check

    admin_messages.AssignmentsInlineAddSearchChanged(value) ->
      handle_assignments_inline_add_search_changed(model, value)
      |> without_auth_check

    admin_messages.AssignmentsInlineAddSelectionChanged(value) ->
      handle_assignments_inline_add_selection_changed(model, value)
      |> without_auth_check

    admin_messages.AssignmentsInlineAddRoleChanged(role) ->
      handle_assignments_inline_add_role_changed(model, role)
      |> without_auth_check

    admin_messages.AssignmentsInlineAddSubmitted ->
      handle_assignments_inline_add_submitted(model, context)
      |> without_auth_check

    admin_messages.AssignmentsInlineAddCancelled ->
      handle_assignments_inline_add_cancelled(model)
      |> without_auth_check

    admin_messages.AssignmentsProjectMemberAdded(project_id, Ok(member)) ->
      handle_assignments_project_member_added_ok(
        model,
        project_id,
        member,
        context,
      )
      |> without_auth_check

    admin_messages.AssignmentsProjectMemberAdded(_project_id, Error(err)) ->
      handle_assignments_project_member_added_error(model, err, feedback)
      |> with_auth_check(err)

    admin_messages.AssignmentsUserProjectAdded(user_id, Ok(project)) ->
      handle_assignments_user_project_added_ok(model, user_id, project, context)
      |> without_auth_check

    admin_messages.AssignmentsUserProjectAdded(_user_id, Error(err)) ->
      handle_assignments_user_project_added_error(model, err, feedback)
      |> with_auth_check(err)

    admin_messages.AssignmentsRemoveClicked(project_id, user_id) ->
      handle_assignments_remove_clicked(model, project_id, user_id)
      |> without_auth_check

    admin_messages.AssignmentsRemoveCancelled ->
      handle_assignments_remove_cancelled(model)
      |> without_auth_check

    admin_messages.AssignmentsRemoveConfirmed ->
      handle_assignments_remove_confirmed(model, context)
      |> without_auth_check

    admin_messages.AssignmentsRemoveDone(project_id, user_id, Ok(_)) ->
      handle_assignments_remove_completed_ok(model, project_id, user_id)
      |> without_auth_check

    admin_messages.AssignmentsRemoveDone(_project_id, _user_id, Error(err)) ->
      handle_assignments_remove_completed_error(model, err, feedback)
      |> with_auth_check(err)

    admin_messages.AssignmentsRoleChanged(project_id, user_id, new_role) ->
      handle_assignments_role_changed(
        model,
        project_id,
        user_id,
        new_role,
        context,
      )
      |> without_auth_check

    admin_messages.AssignmentsRoleChangeDone(project_id, user_id, Ok(result)) ->
      handle_assignments_role_change_completed_ok(
        model,
        project_id,
        user_id,
        result,
      )
      |> without_auth_check_with_root(MemberRoleSuccessFeedback)

    admin_messages.AssignmentsRoleChangeDone(project_id, user_id, Error(err)) ->
      handle_assignments_role_change_completed_error(
        model,
        project_id,
        user_id,
        err,
      )
      |> with_auth_check_after_update(err, MemberRoleErrorFeedback(err))

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(assignments_state.AssignmentsModel, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  without_auth_check_with_root(result, NoRootPolicy)
}

fn without_auth_check_with_root(
  result: #(assignments_state.AssignmentsModel, Effect(parent_msg)),
  root_policy: RootPolicy,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck, root_policy)
}

fn with_auth_check(
  result: #(assignments_state.AssignmentsModel, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuth(err), NoRootPolicy)
}

fn with_auth_check_after_update(
  result: #(assignments_state.AssignmentsModel, Effect(parent_msg)),
  err: ApiError,
  root_policy: RootPolicy,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuthAfterUpdate(err), root_policy)
}

fn with_policy(
  result: #(assignments_state.AssignmentsModel, Effect(parent_msg)),
  auth_policy: AuthPolicy,
  root_policy: RootPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy, root_policy))
}

// =============================================================================
// Helpers
// =============================================================================

fn set_project_members_state(
  assignments: assignments_state.AssignmentsModel,
  project_id: Int,
  state: Remote(List(ProjectMember)),
) -> assignments_state.AssignmentsModel {
  let assignments_state.AssignmentsModel(project_members: project_members, ..) =
    assignments
  assignments_state.AssignmentsModel(
    ..assignments,
    project_members: dict.insert(project_members, project_id, state),
  )
}

fn set_user_projects_state(
  assignments: assignments_state.AssignmentsModel,
  user_id: Int,
  state: Remote(List(Project)),
) -> assignments_state.AssignmentsModel {
  let assignments_state.AssignmentsModel(user_projects: user_projects, ..) =
    assignments
  assignments_state.AssignmentsModel(
    ..assignments,
    user_projects: dict.insert(user_projects, user_id, state),
  )
}

fn toggle_expanded_project(
  assignments: assignments_state.AssignmentsModel,
  project_id: Int,
) -> assignments_state.AssignmentsModel {
  let assignments_state.AssignmentsModel(expanded_projects: expanded, ..) =
    assignments
  let next = case set.contains(expanded, project_id) {
    True -> set.delete(expanded, project_id)
    False -> set.insert(expanded, project_id)
  }
  assignments_state.AssignmentsModel(..assignments, expanded_projects: next)
}

fn toggle_expanded_user(
  assignments: assignments_state.AssignmentsModel,
  user_id: Int,
) -> assignments_state.AssignmentsModel {
  let assignments_state.AssignmentsModel(expanded_users: expanded, ..) =
    assignments
  let next = case set.contains(expanded, user_id) {
    True -> set.delete(expanded, user_id)
    False -> set.insert(expanded, user_id)
  }
  assignments_state.AssignmentsModel(..assignments, expanded_users: next)
}

fn update_project_role(project: Project, role: ProjectRole) -> Project {
  Project(..project, my_role: role)
}

fn update_project_members_role(
  members: Remote(List(ProjectMember)),
  user_id: Int,
  new_role: ProjectRole,
) -> Remote(List(ProjectMember)) {
  case members {
    Loaded(members_list) ->
      Loaded(
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
  projects: Remote(List(Project)),
  project_id: Int,
  new_role: ProjectRole,
) -> Remote(List(Project)) {
  case projects {
    Loaded(projects_list) ->
      Loaded(
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
  assignments: assignments_state.AssignmentsModel,
  project_id: Int,
  user_id: Int,
) -> opt.Option(ProjectRole) {
  let assignments_state.AssignmentsModel(
    project_members: project_members,
    user_projects: user_projects,
    ..,
  ) = assignments

  case dict.get(project_members, project_id) {
    Ok(Loaded(members)) ->
      case list.find(members, fn(member) { member.user_id == user_id }) {
        Ok(member) -> opt.Some(member.role)
        Error(_) -> opt.None
      }
    _ ->
      case dict.get(user_projects, user_id) {
        Ok(Loaded(projects)) ->
          case list.find(projects, fn(project) { project.id == project_id }) {
            Ok(project) -> opt.Some(project.my_role)
            Error(_) -> opt.None
          }
        _ -> opt.None
      }
  }
}

fn clear_inline_add(
  assignments: assignments_state.AssignmentsModel,
) -> assignments_state.AssignmentsModel {
  assignments_state.AssignmentsModel(
    ..assignments,
    inline_add_context: opt.None,
    inline_add_selection: opt.None,
    inline_add_search: "",
    inline_add_in_flight: False,
  )
}

fn apply_role_change(
  assignments: assignments_state.AssignmentsModel,
  project_id: Int,
  user_id: Int,
  new_role: ProjectRole,
) -> assignments_state.AssignmentsModel {
  let assignments_state.AssignmentsModel(
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
  assignments_state.AssignmentsModel(
    ..assignments,
    project_members: updated_project_members,
    user_projects: updated_user_projects,
  )
}

fn handle_assignments_view_mode_changed(
  model: assignments_state.AssignmentsModel,
  view_mode: assignments_view_mode.AssignmentsViewMode,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(
    assignments_state.AssignmentsModel(..model, view_mode: view_mode),
    effect.none(),
  )
}

fn handle_assignments_search_changed(
  model: assignments_state.AssignmentsModel,
  value: String,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(
    assignments_state.AssignmentsModel(..model, search_input: value),
    effect.none(),
  )
}

fn handle_assignments_search_debounced(
  model: assignments_state.AssignmentsModel,
  value: String,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(
    assignments_state.AssignmentsModel(..model, search_query: value),
    effect.none(),
  )
}

fn handle_assignments_project_toggled(
  model: assignments_state.AssignmentsModel,
  project_id: Int,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(toggle_expanded_project(model, project_id), effect.none())
}

fn handle_assignments_user_toggled(
  model: assignments_state.AssignmentsModel,
  user_id: Int,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(toggle_expanded_user(model, user_id), effect.none())
}

// =============================================================================
// Data fetch results
// =============================================================================

fn handle_assignments_project_members_fetched(
  model: assignments_state.AssignmentsModel,
  project_id: Int,
  result: Result(List(ProjectMember), ApiError),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let remote_state = from_result(result)
  #(set_project_members_state(model, project_id, remote_state), effect.none())
}

fn handle_assignments_user_projects_fetched(
  model: assignments_state.AssignmentsModel,
  user_id: Int,
  result: Result(List(Project), ApiError),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let remote_state = from_result(result)
  #(set_user_projects_state(model, user_id, remote_state), effect.none())
}

// =============================================================================
// Inline add flows
// =============================================================================

fn handle_assignments_inline_add_started(
  model: assignments_state.AssignmentsModel,
  context: assignments_state.AssignmentsAddContext,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(
    assignments_state.AssignmentsModel(
      ..model,
      inline_add_context: opt.Some(context),
      inline_add_selection: opt.None,
      inline_add_search: "",
      inline_add_role: Member,
      inline_add_in_flight: False,
    ),
    effect.none(),
  )
}

fn handle_assignments_inline_add_search_changed(
  model: assignments_state.AssignmentsModel,
  value: String,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(
    assignments_state.AssignmentsModel(..model, inline_add_search: value),
    effect.none(),
  )
}

fn handle_assignments_inline_add_selection_changed(
  model: assignments_state.AssignmentsModel,
  value: String,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let selection = case int.parse(value) {
    Ok(id) -> opt.Some(id)
    Error(_) -> opt.None
  }
  #(
    assignments_state.AssignmentsModel(..model, inline_add_selection: selection),
    effect.none(),
  )
}

fn handle_assignments_inline_add_role_changed(
  model: assignments_state.AssignmentsModel,
  role: ProjectRole,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(
    assignments_state.AssignmentsModel(..model, inline_add_role: role),
    effect.none(),
  )
}

fn handle_assignments_inline_add_submitted(
  model: assignments_state.AssignmentsModel,
  callbacks: Context(parent_msg),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let assignments_state.AssignmentsModel(
    inline_add_context: context,
    inline_add_selection: selection,
    inline_add_role: role,
    inline_add_in_flight: in_flight,
    ..,
  ) = model

  case in_flight {
    True -> #(model, effect.none())
    False ->
      case context, selection {
        opt.Some(assignments_state.AddUserToProject(project_id)),
          opt.Some(user_id)
        -> {
          let model =
            assignments_state.AssignmentsModel(
              ..model,
              inline_add_in_flight: True,
            )
          let fx =
            api_projects.add_project_member(
              project_id,
              user_id,
              role,
              fn(result) {
                callbacks.on_project_member_added(project_id, result)
              },
            )
          #(model, fx)
        }

        opt.Some(assignments_state.AddProjectToUser(user_id)),
          opt.Some(project_id)
        -> {
          let model =
            assignments_state.AssignmentsModel(
              ..model,
              inline_add_in_flight: True,
            )
          let fx =
            api_org.add_user_to_project(user_id, project_id, role, fn(result) {
              callbacks.on_user_project_added(user_id, result)
            })
          #(model, fx)
        }

        _, _ -> #(model, effect.none())
      }
  }
}

fn handle_assignments_inline_add_cancelled(
  model: assignments_state.AssignmentsModel,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(clear_inline_add(model), effect.none())
}

fn handle_assignments_project_member_added_ok(
  model: assignments_state.AssignmentsModel,
  project_id: Int,
  member: ProjectMember,
  callbacks: Context(parent_msg),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let model = clear_inline_add(model)
  let model =
    model
    |> set_project_members_state(project_id, Loading)
    |> set_user_projects_state(member.user_id, Loading)

  let effects = [
    api_projects.list_project_members(project_id, fn(result) {
      callbacks.on_project_members_fetched(project_id, result)
    }),
    api_org.list_user_projects(member.user_id, fn(result) {
      callbacks.on_user_projects_fetched(member.user_id, result)
    }),
  ]

  #(model, effect.batch(effects))
}

fn handle_assignments_project_member_added_error(
  model: assignments_state.AssignmentsModel,
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(clear_inline_add(model), error_effect(err, feedback))
}

fn handle_assignments_user_project_added_ok(
  model: assignments_state.AssignmentsModel,
  user_id: Int,
  project: Project,
  callbacks: Context(parent_msg),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let model = clear_inline_add(model)
  let model =
    model
    |> set_user_projects_state(user_id, Loading)
    |> set_project_members_state(project.id, Loading)

  let effects = [
    api_org.list_user_projects(user_id, fn(result) {
      callbacks.on_user_projects_fetched(user_id, result)
    }),
    api_projects.list_project_members(project.id, fn(result) {
      callbacks.on_project_members_fetched(project.id, result)
    }),
  ]

  #(model, effect.batch(effects))
}

fn handle_assignments_user_project_added_error(
  model: assignments_state.AssignmentsModel,
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(clear_inline_add(model), error_effect(err, feedback))
}

// =============================================================================
// Remove + Role Change
// =============================================================================

fn handle_assignments_remove_clicked(
  model: assignments_state.AssignmentsModel,
  project_id: Int,
  user_id: Int,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(
    assignments_state.AssignmentsModel(
      ..model,
      inline_remove_confirm: opt.Some(#(project_id, user_id)),
    ),
    effect.none(),
  )
}

fn handle_assignments_remove_cancelled(
  model: assignments_state.AssignmentsModel,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(
    assignments_state.AssignmentsModel(..model, inline_remove_confirm: opt.None),
    effect.none(),
  )
}

fn handle_assignments_remove_confirmed(
  model: assignments_state.AssignmentsModel,
  callbacks: Context(parent_msg),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  case model.inline_remove_confirm {
    opt.Some(#(project_id, user_id)) -> {
      let model =
        assignments_state.AssignmentsModel(
          ..model,
          inline_remove_confirm: opt.None,
        )
      let fx =
        api_projects.remove_project_member(project_id, user_id, fn(result) {
          callbacks.on_remove_completed(project_id, user_id, result)
        })
      #(model, fx)
    }
    opt.None -> #(model, effect.none())
  }
}

fn handle_assignments_remove_completed_ok(
  model: assignments_state.AssignmentsModel,
  project_id: Int,
  user_id: Int,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let assignments_state.AssignmentsModel(
    project_members: project_members,
    user_projects: user_projects,
    ..,
  ) = model
  let updated_project_members = case dict.get(project_members, project_id) {
    Ok(Loaded(members)) ->
      dict.insert(
        project_members,
        project_id,
        Loaded(list.filter(members, fn(member) { member.user_id != user_id })),
      )
    _ -> project_members
  }
  let updated_user_projects = case dict.get(user_projects, user_id) {
    Ok(Loaded(projects)) ->
      dict.insert(
        user_projects,
        user_id,
        Loaded(list.filter(projects, fn(project) { project.id != project_id })),
      )
    _ -> user_projects
  }
  #(
    assignments_state.AssignmentsModel(
      ..model,
      project_members: updated_project_members,
      user_projects: updated_user_projects,
    ),
    effect.none(),
  )
}

fn handle_assignments_remove_completed_error(
  model: assignments_state.AssignmentsModel,
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  #(model, error_effect(err, feedback))
}

fn error_effect(
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  feedback.on_error_toast(err.message)
}

fn handle_assignments_role_changed(
  model: assignments_state.AssignmentsModel,
  project_id: Int,
  user_id: Int,
  new_role: ProjectRole,
  callbacks: Context(parent_msg),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let previous_role = current_role_for_assignment(model, project_id, user_id)
  let model =
    model
    |> apply_role_change(project_id, user_id, new_role)
    |> fn(updated) {
      assignments_state.AssignmentsModel(
        ..updated,
        role_change_in_flight: opt.Some(#(project_id, user_id)),
        role_change_previous: case previous_role {
          opt.Some(role) -> opt.Some(#(project_id, user_id, role))
          opt.None -> opt.None
        },
      )
    }

  let fx =
    api_projects.update_member_role(project_id, user_id, new_role, fn(result) {
      callbacks.on_role_change_completed(project_id, user_id, result)
    })

  #(model, fx)
}

fn handle_assignments_role_change_completed_ok(
  model: assignments_state.AssignmentsModel,
  project_id: Int,
  user_id: Int,
  result: api_projects.RoleChangeResult,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let updated = apply_role_change(model, project_id, user_id, result.role)
  #(
    assignments_state.AssignmentsModel(
      ..updated,
      role_change_in_flight: opt.None,
      role_change_previous: opt.None,
    ),
    effect.none(),
  )
}

fn handle_assignments_role_change_completed_error(
  model: assignments_state.AssignmentsModel,
  project_id: Int,
  user_id: Int,
  _err: ApiError,
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  let updated = case model.role_change_previous {
    opt.Some(#(pid, uid, previous)) if pid == project_id && uid == user_id ->
      apply_role_change(model, project_id, user_id, previous)
    _ -> model
  }
  #(
    assignments_state.AssignmentsModel(
      ..updated,
      role_change_in_flight: opt.None,
      role_change_previous: opt.None,
    ),
    effect.none(),
  )
}

// =============================================================================
// Fetch helpers for assignments
// =============================================================================

pub fn start_user_projects_fetch(
  model: assignments_state.AssignmentsModel,
  users: List(OrgUser),
  callbacks: Context(parent_msg),
) -> #(assignments_state.AssignmentsModel, Effect(parent_msg)) {
  case callbacks.active_section {
    permissions.Team -> {
      let #(next_assignments, effects) =
        list.fold(users, #(model, []), fn(state, user) {
          let #(current, fx) = state
          let assignments_state.AssignmentsModel(user_projects: projects, ..) =
            current
          let needs_fetch = case dict.get(projects, user.id) {
            Ok(remote) -> should_fetch(remote)
            Error(_) -> True
          }
          case needs_fetch {
            False -> #(current, fx)
            True -> {
              let updated = set_user_projects_state(current, user.id, Loading)
              let effect =
                api_org.list_user_projects(user.id, fn(result) {
                  callbacks.on_user_projects_fetched(user.id, result)
                })
              #(updated, [effect, ..fx])
            }
          }
        })

      #(next_assignments, effect.batch(list.reverse(effects)))
    }

    _ -> #(model, effect.none())
  }
}
