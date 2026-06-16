import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote.{type Remote, Failed, Loaded}
import domain/workflow.{type TaskTemplate, TaskTemplate}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/features/admin/task_templates as task_templates_update
import scrumbringer_client/features/pool/msg as pool_messages

fn template(id: Int, name: String, project_id: opt.Option(Int)) -> TaskTemplate {
  TaskTemplate(
    id: id,
    org_id: 1,
    project_id: project_id,
    name: name,
    description: opt.None,
    type_id: 2,
    type_name: "Bug",
    priority: 3,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    rules_count: 0,
  )
}

fn feedback_context() -> task_templates_update.FeedbackContext(client_state.Msg) {
  task_templates_update.FeedbackContext(
    task_template_created: "Template created",
    task_template_updated: "Template updated",
    task_template_deleted: "Template deleted",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn update(
  state: admin_task_templates.Model,
  msg: pool_messages.Msg,
) -> #(
  admin_task_templates.Model,
  effect.Effect(client_state.Msg),
  task_templates_update.AuthPolicy,
) {
  let assert opt.Some(task_templates_update.Update(next, fx, auth_policy)) =
    task_templates_update.try_update(state, msg, feedback_context())

  #(next, fx, auth_policy)
}

fn state_with_templates(
  org: Remote(List(TaskTemplate)),
  project: Remote(List(TaskTemplate)),
) -> admin_task_templates.Model {
  admin_task_templates.Model(
    task_templates_org: org,
    task_templates_project: project,
    task_templates_dialog_mode: opt.Some(
      admin_task_templates.TaskTemplateDialogCreate,
    ),
  )
}

pub fn local_fetch_transitions_update_project_remote_test() {
  let loaded = [template(1, "Loaded", opt.Some(3))]
  let state = state_with_templates(Loaded([]), Loaded([]))

  let #(next, fx, auth_policy) =
    update(state, pool_messages.TaskTemplatesProjectFetched(Ok(loaded)))
  let assert True = next.task_templates_project == Loaded(loaded)
  let assert True = fx == effect.none()
  let assert task_templates_update.NoAuthCheck = auth_policy

  let err = ApiError(status: 409, code: "CONFLICT", message: "Conflict")
  let #(failed, fx, auth_policy) =
    update(next, pool_messages.TaskTemplatesProjectFetched(Error(err)))
  let assert True = failed.task_templates_project == Failed(err)
  let assert True = fx == effect.none()
  let assert task_templates_update.CheckAuth(auth_err) = auth_policy
  let assert True = auth_err == err
}

pub fn local_dialog_transitions_open_and_close_test() {
  let state = state_with_templates(Loaded([]), Loaded([]))
  let item = template(3, "To delete", opt.Some(3))

  let #(opened, fx, auth_policy) =
    update(
      state,
      pool_messages.OpenTaskTemplateDialog(
        admin_task_templates.TaskTemplateDialogDelete(item),
      ),
    )
  let assert True =
    opened.task_templates_dialog_mode
    == opt.Some(admin_task_templates.TaskTemplateDialogDelete(item))
  let assert True = fx == effect.none()
  let assert task_templates_update.NoAuthCheck = auth_policy

  let #(closed, fx, auth_policy) =
    update(opened, pool_messages.CloseTaskTemplateDialog)
  let assert opt.None = closed.task_templates_dialog_mode
  let assert True = fx == effect.none()
  let assert task_templates_update.NoAuthCheck = auth_policy
}

pub fn local_crud_transitions_update_scopes_test() {
  let existing = template(1, "Existing", opt.Some(3))
  let created = template(2, "Created", opt.Some(3))
  let updated = template(2, "Updated", opt.Some(3))
  let state = state_with_templates(Loaded([]), Loaded([existing]))

  let #(after_create, _, _) =
    update(state, pool_messages.TaskTemplateCrudCreated(created))
  let assert True =
    after_create.task_templates_project == Loaded([created, existing])
  let assert opt.None = after_create.task_templates_dialog_mode

  let #(after_update, _, _) =
    update(after_create, pool_messages.TaskTemplateCrudUpdated(updated))
  let assert True =
    after_update.task_templates_project == Loaded([updated, existing])

  let #(after_delete, _, _) =
    update(after_update, pool_messages.TaskTemplateCrudDeleted(2))
  let assert True = after_delete.task_templates_project == Loaded([existing])
}

pub fn try_update_project_fetch_error_requests_auth_check_test() {
  let err = ApiError(status: 401, code: "UNAUTHORIZED", message: "Unauthorized")
  let state = state_with_templates(Loaded([]), Loaded([]))

  let assert opt.Some(task_templates_update.Update(next, fx, auth_policy)) =
    task_templates_update.try_update(
      state,
      pool_messages.TaskTemplatesProjectFetched(Error(err)),
      feedback_context(),
    )

  let assert True = next.task_templates_project == Failed(err)
  let assert True = fx == effect.none()
  let assert task_templates_update.CheckAuth(auth_err) = auth_policy
  let assert True = auth_err == err
}

pub fn try_update_open_dialog_updates_local_state_test() {
  let state = state_with_templates(Loaded([]), Loaded([]))
  let item = template(3, "To delete", opt.Some(3))

  let assert opt.Some(task_templates_update.Update(next, fx, auth_policy)) =
    task_templates_update.try_update(
      state,
      pool_messages.OpenTaskTemplateDialog(
        admin_task_templates.TaskTemplateDialogDelete(item),
      ),
      feedback_context(),
    )

  let assert True =
    next.task_templates_dialog_mode
    == opt.Some(admin_task_templates.TaskTemplateDialogDelete(item))
  let assert True = fx == effect.none()
  let assert task_templates_update.NoAuthCheck = auth_policy
}

pub fn try_update_created_updates_project_scope_and_emits_feedback_test() {
  let existing = template(1, "Existing", opt.Some(3))
  let created = template(2, "Created", opt.Some(3))
  let state = state_with_templates(Loaded([]), Loaded([existing]))

  let assert opt.Some(task_templates_update.Update(next, fx, auth_policy)) =
    task_templates_update.try_update(
      state,
      pool_messages.TaskTemplateCrudCreated(created),
      feedback_context(),
    )

  let assert True = next.task_templates_project == Loaded([created, existing])
  let assert True = next.task_templates_org == Loaded([])
  let assert opt.None = next.task_templates_dialog_mode
  let assert True = fx != effect.none()
  let assert task_templates_update.NoAuthCheck = auth_policy
}

pub fn try_update_updated_replaces_org_and_project_scope_test() {
  let old = template(1, "Old", opt.Some(3))
  let updated = template(1, "Updated", opt.Some(3))
  let other = template(2, "Other", opt.None)
  let state = state_with_templates(Loaded([old, other]), Loaded([old]))

  let assert opt.Some(task_templates_update.Update(next, fx, auth_policy)) =
    task_templates_update.try_update(
      state,
      pool_messages.TaskTemplateCrudUpdated(updated),
      feedback_context(),
    )

  let assert True = next.task_templates_org == Loaded([updated, other])
  let assert True = next.task_templates_project == Loaded([updated])
  let assert opt.None = next.task_templates_dialog_mode
  let assert True = fx != effect.none()
  let assert task_templates_update.NoAuthCheck = auth_policy
}

pub fn try_update_deleted_removes_from_org_and_project_scope_test() {
  let deleted = template(1, "Deleted", opt.Some(3))
  let kept = template(2, "Kept", opt.None)
  let state = state_with_templates(Loaded([deleted, kept]), Loaded([deleted]))

  let assert opt.Some(task_templates_update.Update(next, fx, auth_policy)) =
    task_templates_update.try_update(
      state,
      pool_messages.TaskTemplateCrudDeleted(deleted.id),
      feedback_context(),
    )

  let assert True = next.task_templates_org == Loaded([kept])
  let assert True = next.task_templates_project == Loaded([])
  let assert opt.None = next.task_templates_dialog_mode
  let assert True = fx != effect.none()
  let assert task_templates_update.NoAuthCheck = auth_policy
}

pub fn try_update_ignores_non_task_template_messages_test() {
  let assert opt.None =
    task_templates_update.try_update(
      admin_task_templates.default_model(),
      pool_messages.MemberPoolFiltersToggled,
      feedback_context(),
    )
}
