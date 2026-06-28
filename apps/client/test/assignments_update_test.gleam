import gleam/dict
import gleam/option
import gleam/set
import lustre/effect
import support/assertions.{assert_equal}

import domain/api_error.{ApiError}
import domain/project.{type Project, type ProjectMember, Project, ProjectMember}
import domain/project_role.{Manager, Member}
import domain/remote.{Failed, Loaded, Loading}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/assignments/update as assignments_update
import scrumbringer_client/permissions.{Team}

fn model() -> assignments_state.AssignmentsModel {
  assignments_state.AssignmentsModel(
    view_mode: assignments_view_mode.ByProject,
    search_input: "",
    search_query: "",
    project_members: dict.new(),
    user_projects: dict.new(),
    expanded_projects: set.new(),
    expanded_users: set.new(),
    inline_add_context: option.None,
    inline_add_selection: option.None,
    inline_add_search: "",
    inline_add_role: Member,
    inline_add_in_flight: False,
    inline_remove_confirm: option.None,
    role_change_in_flight: option.None,
    role_change_previous: option.None,
  )
}

fn project(id: Int, role) -> Project {
  Project(
    id: id,
    name: "Project",
    my_role: role,
    created_at: "2026-01-01T00:00:00Z",
    members_count: 1,
    card_depth_names: [],
    healthy_pool_limit: 20,
  )
}

fn member(user_id: Int, role) -> ProjectMember {
  ProjectMember(
    user_id: user_id,
    role: role,
    created_at: "2026-01-01T00:00:00Z",
    claimed_count: 0,
  )
}

fn feedback_context() -> assignments_update.FeedbackContext(Nil) {
  assignments_update.FeedbackContext(on_error_toast: fn(_) {
    effect.from(fn(_dispatch) { Nil })
  })
}

fn context() -> assignments_update.Context(Nil) {
  assignments_update.Context(
    active_section: Team,
    on_project_members_fetched: fn(_, _) { Nil },
    on_user_projects_fetched: fn(_, _) { Nil },
    on_project_member_added: fn(_, _) { Nil },
    on_user_project_added: fn(_, _) { Nil },
    on_remove_completed: fn(_, _, _) { Nil },
    on_role_change_completed: fn(_, _, _) { Nil },
  )
}

fn update(
  model: assignments_state.AssignmentsModel,
  inner: admin_messages.Msg,
) -> assignments_update.Update(Nil) {
  let assert option.Some(update) =
    assignments_update.try_update(model, inner, context(), feedback_context())
  update
}

pub fn view_mode_change_preserves_search_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      search_input: "alpha",
      search_query: "alpha",
    )

  let assignments_update.Update(next, fx, _, _) =
    update(
      initial,
      admin_messages.AssignmentsViewModeChanged(assignments_view_mode.ByUser),
    )

  next.view_mode |> assert_equal(assignments_view_mode.ByUser)
  next.search_input |> assert_equal("alpha")
  next.search_query |> assert_equal("alpha")
  fx |> assert_equal(effect.none())
}

pub fn try_update_view_mode_returns_root_policy_test() {
  let initial =
    assignments_state.AssignmentsModel(..model(), search_input: "alpha")

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      initial,
      admin_messages.AssignmentsViewModeChanged(assignments_view_mode.ByUser),
      context(),
      feedback_context(),
    )

  next.view_mode |> assert_equal(assignments_view_mode.ByUser)
  next.search_input |> assert_equal("alpha")
  fx |> assert_equal(effect.none())
  auth_policy |> assert_equal(assignments_update.NoAuthCheck)
  root_policy
  |> assert_equal(assignments_update.ReplaceAssignmentsView(
    assignments_view_mode.ByUser,
  ))
}

pub fn try_update_project_members_error_returns_auth_policy_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      model(),
      admin_messages.AssignmentsProjectMembersFetched(7, Error(err)),
      context(),
      feedback_context(),
    )

  let assert Ok(Failed(stored_error)) = dict.get(next.project_members, 7)
  stored_error |> assert_equal(err)
  fx |> assert_equal(effect.none())
  auth_policy |> assert_equal(assignments_update.CheckAuth(err))
  root_policy |> assert_equal(assignments_update.NoRootPolicy)
}

pub fn try_update_ignores_non_assignment_messages_test() {
  assignments_update.try_update(
    model(),
    admin_messages.MemberAddDialogOpened,
    context(),
    feedback_context(),
  )
  |> assert_equal(option.None)
}

pub fn try_update_inline_add_submitted_starts_project_member_request_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      inline_add_context: option.Some(assignments_state.AddUserToProject(7)),
      inline_add_selection: option.Some(9),
    )

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      initial,
      admin_messages.AssignmentsInlineAddSubmitted,
      context(),
      feedback_context(),
    )

  next.inline_add_in_flight |> assert_equal(True)
  let assert True = fx != effect.none()
  auth_policy |> assert_equal(assignments_update.NoAuthCheck)
  root_policy |> assert_equal(assignments_update.NoRootPolicy)
}

pub fn try_update_inline_add_error_clears_state_and_checks_auth_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      inline_add_context: option.Some(assignments_state.AddUserToProject(7)),
      inline_add_selection: option.Some(9),
      inline_add_search: "ana",
      inline_add_in_flight: True,
    )

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      initial,
      admin_messages.AssignmentsProjectMemberAdded(7, Error(err)),
      context(),
      feedback_context(),
    )

  next.inline_add_context |> assert_equal(option.None)
  next.inline_add_selection |> assert_equal(option.None)
  next.inline_add_search |> assert_equal("")
  next.inline_add_in_flight |> assert_equal(False)
  let assert True = fx != effect.none()
  auth_policy |> assert_equal(assignments_update.CheckAuth(err))
  root_policy |> assert_equal(assignments_update.NoRootPolicy)
}

pub fn project_member_added_ok_clears_add_and_refreshes_both_caches_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      inline_add_context: option.Some(assignments_state.AddUserToProject(7)),
      inline_add_selection: option.Some(9),
      inline_add_search: "ana",
      inline_add_in_flight: True,
    )

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      initial,
      admin_messages.AssignmentsProjectMemberAdded(7, Ok(member(9, Member))),
      context(),
      feedback_context(),
    )

  next.inline_add_context |> assert_equal(option.None)
  next.inline_add_selection |> assert_equal(option.None)
  next.inline_add_search |> assert_equal("")
  next.inline_add_in_flight |> assert_equal(False)
  let assert Ok(Loading) = dict.get(next.project_members, 7)
  let assert Ok(Loading) = dict.get(next.user_projects, 9)
  let assert True = fx != effect.none()
  auth_policy |> assert_equal(assignments_update.NoAuthCheck)
  root_policy |> assert_equal(assignments_update.NoRootPolicy)
}

pub fn user_project_added_ok_clears_add_and_refreshes_both_caches_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      inline_add_context: option.Some(assignments_state.AddProjectToUser(9)),
      inline_add_selection: option.Some(7),
      inline_add_search: "project",
      inline_add_in_flight: True,
    )

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      initial,
      admin_messages.AssignmentsUserProjectAdded(9, Ok(project(7, Member))),
      context(),
      feedback_context(),
    )

  next.inline_add_context |> assert_equal(option.None)
  next.inline_add_selection |> assert_equal(option.None)
  next.inline_add_search |> assert_equal("")
  next.inline_add_in_flight |> assert_equal(False)
  let assert Ok(Loading) = dict.get(next.project_members, 7)
  let assert Ok(Loading) = dict.get(next.user_projects, 9)
  let assert True = fx != effect.none()
  auth_policy |> assert_equal(assignments_update.NoAuthCheck)
  root_policy |> assert_equal(assignments_update.NoRootPolicy)
}

pub fn try_update_remove_confirmed_starts_request_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      inline_remove_confirm: option.Some(#(7, 9)),
    )

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      initial,
      admin_messages.AssignmentsRemoveConfirmed,
      context(),
      feedback_context(),
    )

  next.inline_remove_confirm |> assert_equal(option.None)
  let assert True = fx != effect.none()
  auth_policy |> assert_equal(assignments_update.NoAuthCheck)
  root_policy |> assert_equal(assignments_update.NoRootPolicy)
}

pub fn try_update_remove_completed_ok_updates_loaded_caches_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      project_members: dict.from_list([
        #(7, Loaded([member(9, Member), member(10, Member)])),
      ]),
      user_projects: dict.from_list([
        #(9, Loaded([project(7, Member), project(8, Member)])),
      ]),
    )

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      initial,
      admin_messages.AssignmentsRemoveDone(7, 9, Ok(Nil)),
      context(),
      feedback_context(),
    )

  let assert Ok(Loaded([remaining_member])) = dict.get(next.project_members, 7)
  remaining_member.user_id |> assert_equal(10)
  let assert Ok(Loaded([remaining_project])) = dict.get(next.user_projects, 9)
  remaining_project.id |> assert_equal(8)
  fx |> assert_equal(effect.none())
  auth_policy |> assert_equal(assignments_update.NoAuthCheck)
  root_policy |> assert_equal(assignments_update.NoRootPolicy)
}

pub fn try_update_remove_completed_error_returns_auth_policy_test() {
  let err = ApiError(status: 401, code: "UNAUTHORIZED", message: "expired")

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      model(),
      admin_messages.AssignmentsRemoveDone(7, 9, Error(err)),
      context(),
      feedback_context(),
    )

  next |> assert_equal(model())
  let assert True = fx != effect.none()
  auth_policy |> assert_equal(assignments_update.CheckAuth(err))
  root_policy |> assert_equal(assignments_update.NoRootPolicy)
}

pub fn try_update_role_change_completed_ok_returns_feedback_policy_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      project_members: dict.from_list([
        #(7, Loaded([member(9, Member)])),
      ]),
      user_projects: dict.from_list([
        #(9, Loaded([project(7, Member)])),
      ]),
      role_change_in_flight: option.Some(#(7, 9)),
      role_change_previous: option.Some(#(7, 9, Member)),
    )
  let result =
    api_projects.RoleChangeResult(
      user_id: 9,
      email: "ana@example.com",
      role: Manager,
      previous_role: Member,
    )

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      initial,
      admin_messages.AssignmentsRoleChangeDone(7, 9, Ok(result)),
      context(),
      feedback_context(),
    )

  let assert Ok(Loaded([next_member])) = dict.get(next.project_members, 7)
  next_member.role |> assert_equal(Manager)
  let assert Ok(Loaded([next_project])) = dict.get(next.user_projects, 9)
  next_project.my_role |> assert_equal(Manager)
  next.role_change_in_flight |> assert_equal(option.None)
  next.role_change_previous |> assert_equal(option.None)
  fx |> assert_equal(effect.none())
  auth_policy |> assert_equal(assignments_update.NoAuthCheck)
  root_policy |> assert_equal(assignments_update.MemberRoleSuccessFeedback)
}

pub fn try_update_role_change_completed_error_rolls_back_then_checks_auth_test() {
  let err =
    ApiError(
      status: 422,
      code: "LAST_MANAGER",
      message: "Cannot demote last manager",
    )
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      project_members: dict.from_list([
        #(7, Loaded([member(9, Manager)])),
      ]),
      user_projects: dict.from_list([
        #(9, Loaded([project(7, Manager)])),
      ]),
      role_change_in_flight: option.Some(#(7, 9)),
      role_change_previous: option.Some(#(7, 9, Member)),
    )

  let assert option.Some(assignments_update.Update(
    next,
    fx,
    auth_policy,
    root_policy,
  )) =
    assignments_update.try_update(
      initial,
      admin_messages.AssignmentsRoleChangeDone(7, 9, Error(err)),
      context(),
      feedback_context(),
    )

  let assert Ok(Loaded([next_member])) = dict.get(next.project_members, 7)
  next_member.role |> assert_equal(Member)
  let assert Ok(Loaded([next_project])) = dict.get(next.user_projects, 9)
  next_project.my_role |> assert_equal(Member)
  next.role_change_in_flight |> assert_equal(option.None)
  next.role_change_previous |> assert_equal(option.None)
  fx |> assert_equal(effect.none())
  auth_policy |> assert_equal(assignments_update.CheckAuthAfterUpdate(err))
  root_policy
  |> assert_equal(assignments_update.MemberRoleErrorFeedback(err))
}

pub fn inline_add_started_resets_selection_and_role_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      inline_add_selection: option.Some(99),
      inline_add_search: "old",
      inline_add_role: Manager,
      inline_add_in_flight: True,
    )

  let assignments_update.Update(next, fx, _, _) =
    update(
      initial,
      admin_messages.AssignmentsInlineAddStarted(
        assignments_state.AddUserToProject(7),
      ),
    )

  next.inline_add_context
  |> assert_equal(option.Some(assignments_state.AddUserToProject(7)))
  next.inline_add_selection |> assert_equal(option.None)
  next.inline_add_search |> assert_equal("")
  next.inline_add_role |> assert_equal(Member)
  next.inline_add_in_flight |> assert_equal(False)
  fx |> assert_equal(effect.none())
}

pub fn role_change_error_restores_previous_role_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      project_members: dict.from_list([
        #(7, Loaded([member(9, Member)])),
      ]),
      user_projects: dict.from_list([
        #(9, Loaded([project(7, Member)])),
      ]),
    )

  let assignments_update.Update(changed, _, _, _) =
    update(initial, admin_messages.AssignmentsRoleChanged(7, 9, Manager))
  let assignments_update.Update(next, fx, _, _) =
    update(
      changed,
      admin_messages.AssignmentsRoleChangeDone(
        7,
        9,
        Error(ApiError(
          status: 422,
          code: "LAST_MANAGER",
          message: "Cannot demote last manager",
        )),
      ),
    )

  let assert Ok(Loaded([next_member])) = dict.get(next.project_members, 7)
  next_member.role |> assert_equal(Member)
  let assert Ok(Loaded([next_project])) = dict.get(next.user_projects, 9)
  next_project.my_role |> assert_equal(Member)
  next.role_change_in_flight |> assert_equal(option.None)
  next.role_change_previous |> assert_equal(option.None)
  fx |> assert_equal(effect.none())
}

pub fn project_member_added_error_clears_inline_add_and_emits_feedback_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      inline_add_context: option.Some(assignments_state.AddUserToProject(9)),
      inline_add_selection: option.Some(7),
      inline_add_search: "ana",
      inline_add_in_flight: True,
    )

  let assignments_update.Update(next, fx, _, _) =
    update(
      initial,
      admin_messages.AssignmentsProjectMemberAdded(
        9,
        Error(ApiError(status: 500, code: "ERR", message: "boom")),
      ),
    )

  next.inline_add_context |> assert_equal(option.None)
  next.inline_add_selection |> assert_equal(option.None)
  next.inline_add_search |> assert_equal("")
  next.inline_add_in_flight |> assert_equal(False)
  let assert True = fx != effect.none()
}

pub fn remove_completed_error_preserves_model_and_emits_feedback_test() {
  let initial =
    assignments_state.AssignmentsModel(
      ..model(),
      inline_remove_confirm: option.Some(#(7, 9)),
    )

  let assignments_update.Update(next, fx, _, _) =
    update(
      initial,
      admin_messages.AssignmentsRemoveDone(
        7,
        9,
        Error(ApiError(status: 500, code: "ERR", message: "boom")),
      ),
    )

  next |> assert_equal(initial)
  let assert True = fx != effect.none()
}
