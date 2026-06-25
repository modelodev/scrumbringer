import gleam/option

import lustre/effect

import domain/api_error.{ApiError}
import domain/project.{type Project, Project, ProjectDepthName}
import domain/project_role
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/projects as admin_projects
import scrumbringer_client/client_state/types.{
  DialogClosed, DialogOpen, Error as OpError, Idle, InFlight,
}
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/projects/update as projects_update

fn project(id: Int, name: String) -> Project {
  Project(
    id: id,
    name: name,
    my_role: project_role.Manager,
    created_at: "2026-01-01T00:00:00Z",
    members_count: 1,
    card_depth_names: [],
    healthy_pool_limit: 20,
  )
}

fn edit_form(id: Int, name: String) -> admin_projects.ProjectDialogForm {
  edit_form_with_limit(id, name, "20")
}

fn create_form(name: String) -> admin_projects.ProjectDialogForm {
  create_form_at_step(name, admin_projects.ProjectCreateGeneral)
}

fn create_form_at_step(
  name: String,
  step: admin_projects.ProjectCreateStep,
) -> admin_projects.ProjectDialogForm {
  admin_projects.ProjectDialogCreate(
    step: step,
    name: name,
    max_depth: "3",
    healthy_pool_limit: "20",
    card_depth_names: [
      ProjectDepthName(1, "Initiative", "Initiatives"),
      ProjectDepthName(2, "Feature", "Features"),
      ProjectDepthName(3, "Task group", "Task groups"),
    ],
  )
}

fn edit_form_with_limit(
  id: Int,
  name: String,
  healthy_pool_limit: String,
) -> admin_projects.ProjectDialogForm {
  admin_projects.ProjectDialogEdit(
    id: id,
    name: name,
    max_depth: "3",
    healthy_pool_limit: healthy_pool_limit,
    card_depth_names: [
      ProjectDepthName(1, "Initiative", "Initiatives"),
      ProjectDepthName(2, "Feature", "Features"),
      ProjectDepthName(3, "Task group", "Task groups"),
    ],
    depth_reduction: admin_projects.NoDepthReduction,
  )
}

fn context() -> projects_update.Context(Nil) {
  projects_update.Context(
    on_project_created: fn(_result) { Nil },
    on_project_updated: fn(_result) { Nil },
    on_project_deleted: fn(_result) { Nil },
    on_depth_reduction_previewed: fn(_result) { Nil },
    name_required: "Name required",
    pool_soft_limit_positive: "Pool soft limit must be a positive number",
    maximum_depth_positive: "Maximum depth must be a positive number",
    add_level_names_before_increasing_depth: "Add level names before increasing maximum depth",
    review_affected_cards_before_lowering_depth: "Review affected cards before saving a lower maximum depth",
    depth_names_required: "Every level needs singular and plural names",
  )
}

fn feedback_context() -> projects_update.FeedbackContext(Nil) {
  projects_update.FeedbackContext(
    project_created: "Project created",
    project_updated: "Saved",
    project_deleted: "Deleted",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_feedback_context() -> projects_update.ErrorFeedbackContext(Nil) {
  projects_update.ErrorFeedbackContext(
    not_permitted: "Not permitted",
    on_warning_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn update(
  model: admin_projects.Model,
  msg: admin_messages.Msg,
) -> #(
  admin_projects.Model,
  effect.Effect(Nil),
  projects_update.AuthPolicy,
  projects_update.CorePolicy,
) {
  let assert option.Some(projects_update.Update(
    next,
    fx,
    auth_policy,
    core_policy,
  )) =
    projects_update.try_update(
      model,
      msg,
      context(),
      feedback_context(),
      error_feedback_context(),
    )
  #(next, fx, auth_policy, core_policy)
}

pub fn create_dialog_opened_sets_empty_create_form_test() {
  let #(next, fx, auth_policy, core_policy) =
    update(
      admin_projects.default_model(),
      admin_messages.ProjectCreateDialogOpened,
    )

  let assert DialogOpen(form: form, operation: Idle) = next.projects_dialog
  let assert True = form == create_form("")
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn create_submit_requires_name_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: create_form("  "),
      operation: Idle,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectCreateSubmitted)

  let assert DialogOpen(form: form, operation: OpError("Name required")) =
    next.projects_dialog
  let assert True = form == create_form("  ")
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn create_submit_advances_general_step_for_valid_name_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: create_form(" New project "),
      operation: Idle,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectCreateSubmitted)

  let assert DialogOpen(form: form, operation: Idle) = next.projects_dialog
  let assert True =
    form
    == create_form_at_step(
      " New project ",
      admin_projects.ProjectCreateStructurePool,
    )
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn create_next_valid_structure_advances_to_capabilities_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: create_form_at_step(
        "Project",
        admin_projects.ProjectCreateStructurePool,
      ),
      operation: Idle,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectCreateNextClicked)

  let assert DialogOpen(form: form, operation: Idle) = next.projects_dialog
  let assert True =
    form
    == create_form_at_step("Project", admin_projects.ProjectCreateCapabilities)
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn create_back_returns_to_previous_step_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: create_form_at_step("Project", admin_projects.ProjectCreateTeam),
      operation: OpError("stale"),
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectCreateBackClicked)

  let assert DialogOpen(form: form, operation: Idle) = next.projects_dialog
  let assert True =
    form
    == create_form_at_step("Project", admin_projects.ProjectCreateCapabilities)
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn create_submit_sets_in_flight_on_review_step_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: create_form_at_step(
        " New project ",
        admin_projects.ProjectCreateReview,
      ),
      operation: Idle,
    ))

  let #(next, _fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectCreateSubmitted)

  let assert DialogOpen(form: form, operation: InFlight) = next.projects_dialog
  let assert True =
    form
    == create_form_at_step(" New project ", admin_projects.ProjectCreateReview)
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn edit_name_changed_preserves_project_id_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: edit_form(9, "Old"),
      operation: Idle,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectEditNameChanged("New"))

  let assert True =
    next.projects_dialog
    == DialogOpen(form: edit_form(9, "New"), operation: Idle)
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn edit_submit_rejects_invalid_pool_limit_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: edit_form_with_limit(9, "Project", "0"),
      operation: Idle,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectEditSubmitted)

  let assert True =
    next.projects_dialog
    == DialogOpen(
      form: edit_form_with_limit(9, "Project", "0"),
      operation: OpError("Pool soft limit must be a positive number"),
    )
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn edit_depth_name_changed_preserves_other_settings_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: edit_form_with_limit(9, "Project", "18"),
      operation: Idle,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectEditDepthSingularChanged(2, "Entrega"))

  let assert DialogOpen(
    form: admin_projects.ProjectDialogEdit(
      id: 9,
      name: "Project",
      max_depth: "3",
      healthy_pool_limit: "18",
      card_depth_names: [
        ProjectDepthName(1, "Initiative", "Initiatives"),
        ProjectDepthName(2, "Entrega", "Features"),
        ProjectDepthName(3, "Task group", "Task groups"),
      ],
      depth_reduction: admin_projects.NoDepthReduction,
    ),
    operation: Idle,
  ) = next.projects_dialog
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn edit_max_depth_changed_marks_reduction_for_review_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: edit_form(9, "Project"),
      operation: Idle,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectEditMaxDepthChanged("2"))

  let assert DialogOpen(
    form: admin_projects.ProjectDialogEdit(
      id: 9,
      name: "Project",
      max_depth: "2",
      healthy_pool_limit: "20",
      card_depth_names: [
        ProjectDepthName(1, "Initiative", "Initiatives"),
        ProjectDepthName(2, "Feature", "Features"),
        ProjectDepthName(3, "Task group", "Task groups"),
      ],
      depth_reduction: admin_projects.DepthReductionNeedsReview(2),
    ),
    operation: Idle,
  ) = next.projects_dialog
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn depth_reduction_previewed_sets_ready_state_test() {
  let form =
    admin_projects.ProjectDialogEdit(
      id: 9,
      name: "Project",
      max_depth: "2",
      healthy_pool_limit: "20",
      card_depth_names: [
        ProjectDepthName(1, "Initiative", "Initiatives"),
        ProjectDepthName(2, "Feature", "Features"),
        ProjectDepthName(3, "Task group", "Task groups"),
      ],
      depth_reduction: admin_projects.DepthReductionLoading(2),
    )
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: form,
      operation: Idle,
    ))
  let impact =
    api_projects.DepthReductionImpact(
      affected_cards_count: 4,
      available_tasks_count: 3,
      claimed_tasks_count: 1,
      blocked: True,
      affected_cards: [
        api_projects.DepthReductionAffectedCard(
          id: 42,
          title: "Deep card",
          depth: 3,
        ),
      ],
    )

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectEditDepthReductionPreviewed(Ok(impact)))

  let assert DialogOpen(
    form: admin_projects.ProjectDialogEdit(
      id: 9,
      name: "Project",
      max_depth: "2",
      healthy_pool_limit: "20",
      card_depth_names: [
        ProjectDepthName(1, "Initiative", "Initiatives"),
        ProjectDepthName(2, "Feature", "Features"),
        ProjectDepthName(3, "Task group", "Task groups"),
      ],
      depth_reduction: admin_projects.DepthReductionReady(2, ready_impact),
    ),
    operation: Idle,
  ) = next.projects_dialog
  let assert True = ready_impact == impact
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn edit_submit_blocks_lower_depth_before_review_test() {
  let form =
    admin_projects.ProjectDialogEdit(
      id: 9,
      name: "Project",
      max_depth: "2",
      healthy_pool_limit: "20",
      card_depth_names: [
        ProjectDepthName(1, "Initiative", "Initiatives"),
        ProjectDepthName(2, "Feature", "Features"),
        ProjectDepthName(3, "Task group", "Task groups"),
      ],
      depth_reduction: admin_projects.DepthReductionNeedsReview(2),
    )
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: form,
      operation: Idle,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectEditSubmitted)

  let assert DialogOpen(
    form: _,
    operation: OpError(
      "Review affected cards before saving a lower maximum depth",
    ),
  ) = next.projects_dialog
  let assert True = fx == effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn edit_submit_allows_confirmed_lower_depth_test() {
  let form =
    admin_projects.ProjectDialogEdit(
      id: 9,
      name: "Project",
      max_depth: "2",
      healthy_pool_limit: "20",
      card_depth_names: [
        ProjectDepthName(1, "Initiative", "Initiatives"),
        ProjectDepthName(2, "Feature", "Features"),
        ProjectDepthName(3, "Task group", "Task groups"),
      ],
      depth_reduction: admin_projects.DepthReductionConfirmed(2),
    )
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: form,
      operation: Idle,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectEditSubmitted)

  let assert DialogOpen(form: submitted_form, operation: InFlight) =
    next.projects_dialog
  let assert True = submitted_form == form
  let assert True = fx != effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn created_ok_closes_dialog_and_emits_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: create_form("Project"),
      operation: InFlight,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectCreated(Ok(project(1, "Project"))))

  let assert True = fx != effect.none()
  let assert DialogClosed(operation: Idle) = next.projects_dialog
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.CoreProjectCreated(created) = core_policy
  let assert 1 = created.id
}

pub fn updated_ok_closes_dialog_and_emits_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: edit_form(9, "Project"),
      operation: InFlight,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectUpdated(Ok(project(9, "Project"))))

  let assert True = fx != effect.none()
  let assert DialogClosed(operation: Idle) = next.projects_dialog
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.CoreProjectUpdated(updated) = core_policy
  let assert 9 = updated.id
}

pub fn update_error_sets_edit_dialog_error_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: edit_form(9, "Name"),
      operation: InFlight,
    ))

  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")
  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectUpdated(Error(err)))

  let assert True =
    next.projects_dialog
    == DialogOpen(
      form: edit_form(9, "Name"),
      operation: OpError("Not permitted"),
    )
  let assert True = fx == effect.none()
  let assert projects_update.CheckAuth(auth_err) = auth_policy
  let assert True = auth_err == err
  let assert projects_update.NoCoreChange = core_policy
}

pub fn create_forbidden_error_sets_dialog_error_and_emits_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: create_form("Project"),
      operation: InFlight,
    ))

  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")
  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectCreated(Error(err)))

  let assert DialogOpen(form: form, operation: OpError("Not permitted")) =
    next.projects_dialog
  let assert True = form == create_form("Project")
  let assert True = fx != effect.none()
  let assert projects_update.CheckAuth(auth_err) = auth_policy
  let assert True = auth_err == err
  let assert projects_update.NoCoreChange = core_policy
}

pub fn delete_submit_sets_in_flight_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: admin_projects.ProjectDialogDelete(id: 5, name: "Project"),
      operation: Idle,
    ))

  let #(next, _fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectDeleteSubmitted)

  let assert DialogOpen(
    form: admin_projects.ProjectDialogDelete(id: 5, name: "Project"),
    operation: InFlight,
  ) = next.projects_dialog
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.NoCoreChange = core_policy
}

pub fn deleted_ok_without_delete_dialog_has_no_core_delete_id_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: create_form("Project"),
      operation: Idle,
    ))

  let #(_next, _fx, _auth_policy, core_policy) =
    update(model, admin_messages.ProjectDeleted(Ok(Nil)))

  let assert projects_update.CoreProjectDeleted(option.None) = core_policy
}

pub fn deleted_ok_closes_dialog_and_emits_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: admin_projects.ProjectDialogDelete(id: 5, name: "Project"),
      operation: InFlight,
    ))

  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectDeleted(Ok(Nil)))

  let assert True = fx != effect.none()
  let assert DialogClosed(operation: Idle) = next.projects_dialog
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.CoreProjectDeleted(option.Some(5)) = core_policy
}

pub fn deleted_error_returns_delete_dialog_to_idle_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: admin_projects.ProjectDialogDelete(id: 5, name: "Project"),
      operation: InFlight,
    ))

  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")
  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectDeleted(Error(err)))

  let assert DialogOpen(
    form: admin_projects.ProjectDialogDelete(id: 5, name: "Project"),
    operation: Idle,
  ) = next.projects_dialog
  let assert True = fx != effect.none()
  let assert projects_update.CheckAuth(auth_err) = auth_policy
  let assert True = auth_err == err
  let assert projects_update.NoCoreChange = core_policy
}

pub fn deleted_generic_error_returns_to_idle_and_emits_error_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: admin_projects.ProjectDialogDelete(id: 5, name: "Project"),
      operation: InFlight,
    ))

  let err = ApiError(status: 500, code: "ERR", message: "Boom")
  let #(next, fx, auth_policy, core_policy) =
    update(model, admin_messages.ProjectDeleted(Error(err)))

  let assert DialogOpen(
    form: admin_projects.ProjectDialogDelete(id: 5, name: "Project"),
    operation: Idle,
  ) = next.projects_dialog
  let assert True = fx != effect.none()
  let assert projects_update.CheckAuth(auth_err) = auth_policy
  let assert True = auth_err == err
  let assert projects_update.NoCoreChange = core_policy
}

pub fn try_update_created_ok_returns_core_policy_test() {
  let created = project(7, "Project")
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: create_form("Project"),
      operation: InFlight,
    ))

  let assert option.Some(projects_update.Update(
    next,
    fx,
    auth_policy,
    core_policy,
  )) =
    projects_update.try_update(
      model,
      admin_messages.ProjectCreated(Ok(created)),
      context(),
      feedback_context(),
      error_feedback_context(),
    )

  let assert DialogClosed(operation: Idle) = next.projects_dialog
  let assert True = fx != effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.CoreProjectCreated(policy_project) = core_policy
  let assert 7 = policy_project.id
}

pub fn try_update_deleted_ok_preserves_delete_id_in_core_policy_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: admin_projects.ProjectDialogDelete(id: 5, name: "Project"),
      operation: InFlight,
    ))

  let assert option.Some(projects_update.Update(
    next,
    fx,
    auth_policy,
    core_policy,
  )) =
    projects_update.try_update(
      model,
      admin_messages.ProjectDeleted(Ok(Nil)),
      context(),
      feedback_context(),
      error_feedback_context(),
    )

  let assert DialogClosed(operation: Idle) = next.projects_dialog
  let assert True = fx != effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.CoreProjectDeleted(option.Some(5)) = core_policy
}

pub fn try_update_error_requests_auth_check_test() {
  let err = ApiError(status: 500, code: "ERR", message: "Backend failed")
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: edit_form(9, "Project"),
      operation: InFlight,
    ))

  let assert option.Some(projects_update.Update(
    next,
    fx,
    auth_policy,
    core_policy,
  )) =
    projects_update.try_update(
      model,
      admin_messages.ProjectUpdated(Error(err)),
      context(),
      feedback_context(),
      error_feedback_context(),
    )

  let assert True =
    next.projects_dialog
    == DialogOpen(
      form: edit_form(9, "Project"),
      operation: OpError("Backend failed"),
    )
  let assert True = fx == effect.none()
  let assert projects_update.CheckAuth(auth_err) = auth_policy
  let assert True = auth_err == err
  let assert projects_update.NoCoreChange = core_policy
}
