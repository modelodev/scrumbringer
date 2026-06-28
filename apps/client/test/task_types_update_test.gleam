import gleam/option

import lustre/effect
import support/domain_fixtures

import domain/api_error.{ApiError}
import domain/remote
import domain/task_type.{type TaskType, TaskType}
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/task_types/update as task_types_update

fn task_type(id: Int, name: String) -> TaskType {
  TaskType(..domain_fixtures.task_type(id, name), icon: "box")
}

fn context(selected_project_id) -> task_types_update.Context(Nil) {
  task_types_update.Context(
    selected_project_id: selected_project_id,
    on_task_type_created: fn(_result) { Nil },
    select_project_first: "Select project first",
    name_and_icon_required: "Name and icon required",
  )
}

fn feedback_context() -> task_types_update.FeedbackContext(Nil) {
  task_types_update.FeedbackContext(
    task_type_created: "Task type created",
    task_type_updated: "Task type updated",
    task_type_deleted: "Task type deleted",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_feedback_context() -> task_types_update.ErrorFeedbackContext(Nil) {
  task_types_update.ErrorFeedbackContext(
    not_permitted: "Not permitted",
    on_warning_toast: fn(_message) {
      effect.from(fn(dispatch) { dispatch(Nil) })
    },
  )
}

fn update(
  model: admin_task_types.Model,
  msg: admin_messages.Msg,
  selected_project_id: option.Option(Int),
) -> #(
  admin_task_types.Model,
  effect.Effect(Nil),
  task_types_update.AuthPolicy,
  task_types_update.RefreshPolicy,
) {
  let assert option.Some(task_types_update.Update(
    next,
    fx,
    auth_policy,
    refresh_policy,
  )) =
    task_types_update.try_update(
      model,
      msg,
      context(selected_project_id),
      feedback_context(),
      error_feedback_context(),
    )

  #(next, fx, auth_policy, refresh_policy)
}

pub fn fetched_ok_loads_task_types_test() {
  let task_types = [task_type(1, "Bug")]

  let #(next, fx, auth_policy, refresh_policy) =
    update(
      admin_task_types.default_model(),
      admin_messages.TaskTypesFetched(Ok(task_types)),
      option.None,
    )

  let assert True = next.task_types == remote.Loaded([task_type(1, "Bug")])
  let assert True = fx == effect.none()
  let assert task_types_update.NoAuthCheck = auth_policy
  let assert task_types_update.NoRefresh = refresh_policy
}

pub fn create_dialog_opened_sets_create_mode_test() {
  let #(next, fx, _, _) =
    update(
      admin_task_types.default_model(),
      admin_messages.TaskTypeCreateDialogOpened,
      option.None,
    )

  let assert option.Some(admin_task_types.TaskTypeDialogCreate) =
    next.task_types_dialog_mode
  let assert True = fx == effect.none()
}

pub fn create_dialog_closed_resets_form_state_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types_dialog_mode: option.Some(admin_task_types.TaskTypeDialogCreate),
      task_types_create_name: "Bug",
      task_types_create_icon: "bug",
      task_types_create_icon_search: "bu",
      task_types_create_icon_category: "work",
      task_types_create_capability_id: option.Some("7"),
      task_types_create_in_flight: True,
      task_types_create_error: option.Some("error"),
      task_types_icon_preview: admin_task_types.IconOk,
    )

  let #(next, fx, _, _) =
    update(model, admin_messages.TaskTypeCreateDialogClosed, option.None)

  let assert option.None = next.task_types_dialog_mode
  let assert "" = next.task_types_create_name
  let assert "" = next.task_types_create_icon
  let assert "" = next.task_types_create_icon_search
  let assert "all" = next.task_types_create_icon_category
  let assert option.None = next.task_types_create_capability_id
  let assert False = next.task_types_create_in_flight
  let assert option.None = next.task_types_create_error
  let assert admin_task_types.IconIdle = next.task_types_icon_preview
  let assert True = fx == effect.none()
}

pub fn field_handlers_update_create_form_test() {
  let #(model, _, _, _) =
    update(
      admin_task_types.default_model(),
      admin_messages.TaskTypeCreateNameChanged("Bug"),
      option.None,
    )
  let #(model, _, _, _) =
    update(model, admin_messages.TaskTypeCreateIconChanged("bug"), option.None)
  let #(model, _, _, _) =
    update(
      model,
      admin_messages.TaskTypeCreateIconSearchChanged("bu"),
      option.None,
    )
  let #(model, _, _, _) =
    update(
      model,
      admin_messages.TaskTypeCreateIconCategoryChanged("work"),
      option.None,
    )
  let #(next, fx, _, _) =
    update(
      model,
      admin_messages.TaskTypeCreateCapabilityChanged("7"),
      option.None,
    )

  let assert "Bug" = next.task_types_create_name
  let assert "bug" = next.task_types_create_icon
  let assert admin_task_types.IconOk = next.task_types_icon_preview
  let assert "bu" = next.task_types_create_icon_search
  let assert "work" = next.task_types_create_icon_category
  let assert option.Some("7") = next.task_types_create_capability_id
  let assert True = fx == effect.none()
}

pub fn create_submit_requires_selected_project_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types_create_name: "Bug",
      task_types_create_icon: "bug",
    )

  let #(next, fx, _, _) =
    update(model, admin_messages.TaskTypeCreateSubmitted, option.None)

  let assert option.Some("Select project first") = next.task_types_create_error
  let assert False = next.task_types_create_in_flight
  let assert True = fx == effect.none()
}

pub fn create_submit_requires_name_and_icon_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types_create_name: " ",
      task_types_create_icon: "",
    )

  let #(next, fx, _, _) =
    update(model, admin_messages.TaskTypeCreateSubmitted, option.Some(3))

  let assert option.Some("Name and icon required") =
    next.task_types_create_error
  let assert False = next.task_types_create_in_flight
  let assert True = fx == effect.none()
}

pub fn create_submit_sets_in_flight_when_valid_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types_create_name: " Bug ",
      task_types_create_icon: " bug ",
      task_types_create_capability_id: option.Some("7"),
      task_types_create_error: option.Some("old"),
    )

  let #(next, _fx, _, _) =
    update(model, admin_messages.TaskTypeCreateSubmitted, option.Some(3))

  let assert True = next.task_types_create_in_flight
  let assert option.None = next.task_types_create_error
}

pub fn created_ok_closes_dialog_and_resets_form_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types_dialog_mode: option.Some(admin_task_types.TaskTypeDialogCreate),
      task_types_create_name: "Bug",
      task_types_create_icon: "bug",
      task_types_create_icon_search: "bu",
      task_types_create_icon_category: "work",
      task_types_create_capability_id: option.Some("7"),
      task_types_create_in_flight: True,
      task_types_create_error: option.Some("old"),
      task_types_icon_preview: admin_task_types.IconOk,
    )

  let #(next, fx, auth_policy, refresh_policy) =
    update(
      model,
      admin_messages.TaskTypeCreated(Ok(task_type(1, "Bug"))),
      option.Some(7),
    )

  let assert option.None = next.task_types_dialog_mode
  let assert False = next.task_types_create_in_flight
  let assert "" = next.task_types_create_name
  let assert "" = next.task_types_create_icon
  let assert "" = next.task_types_create_icon_search
  let assert "all" = next.task_types_create_icon_category
  let assert option.None = next.task_types_create_capability_id
  let assert option.None = next.task_types_create_error
  let assert admin_task_types.IconIdle = next.task_types_icon_preview
  let assert False = fx == effect.none()
  let assert task_types_update.NoAuthCheck = auth_policy
  let assert task_types_update.RefreshSection = refresh_policy
}

pub fn crud_updated_replaces_loaded_task_type_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types: remote.Loaded([task_type(1, "Bug"), task_type(2, "Feature")]),
      task_types_dialog_mode: option.Some(
        admin_task_types.TaskTypeDialogEdit(task_type(1, "Bug")),
      ),
    )

  let #(next, fx, _, _) =
    update(
      model,
      admin_messages.TaskTypeCrudUpdated(task_type(1, "Incident")),
      option.None,
    )

  let assert True =
    next.task_types
    == remote.Loaded([
      task_type(1, "Incident"),
      task_type(2, "Feature"),
    ])
  let assert option.None = next.task_types_dialog_mode
  let assert False = fx == effect.none()
}

pub fn crud_deleted_removes_loaded_task_type_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types: remote.Loaded([task_type(1, "Bug"), task_type(2, "Feature")]),
      task_types_dialog_mode: option.Some(
        admin_task_types.TaskTypeDialogDelete(task_type(1, "Bug")),
      ),
    )

  let #(next, fx, _, _) =
    update(model, admin_messages.TaskTypeCrudDeleted(1), option.None)

  let assert True = next.task_types == remote.Loaded([task_type(2, "Feature")])
  let assert option.None = next.task_types_dialog_mode
  let assert False = fx == effect.none()
}

pub fn try_update_fetched_ok_returns_local_update_test() {
  let task_types = [task_type(1, "Bug")]

  let assert option.Some(task_types_update.Update(
    next,
    fx,
    task_types_update.NoAuthCheck,
    task_types_update.NoRefresh,
  )) =
    task_types_update.try_update(
      admin_task_types.default_model(),
      admin_messages.TaskTypesFetched(Ok(task_types)),
      context(option.None),
      feedback_context(),
      error_feedback_context(),
    )

  let assert True = next.task_types == remote.Loaded(task_types)
  let assert True = fx == effect.none()
}

pub fn try_update_created_ok_requests_refresh_test() {
  let assert option.Some(task_types_update.Update(
    next,
    fx,
    task_types_update.NoAuthCheck,
    task_types_update.RefreshSection,
  )) =
    task_types_update.try_update(
      admin_task_types.default_model(),
      admin_messages.TaskTypeCreated(Ok(task_type(1, "Bug"))),
      context(option.Some(7)),
      feedback_context(),
      error_feedback_context(),
    )

  let assert option.None = next.task_types_dialog_mode
  let assert False = fx == effect.none()
}

pub fn try_update_created_forbidden_returns_auth_policy_and_warning_test() {
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")

  let assert option.Some(task_types_update.Update(
    next,
    fx,
    task_types_update.CheckAuth(auth_err),
    task_types_update.NoRefresh,
  )) =
    task_types_update.try_update(
      admin_task_types.default_model(),
      admin_messages.TaskTypeCreated(Error(err)),
      context(option.Some(7)),
      feedback_context(),
      error_feedback_context(),
    )

  let assert option.Some("Not permitted") = next.task_types_create_error
  let assert True = auth_err == err
  let assert False = fx == effect.none()
}

pub fn try_update_ignores_non_task_type_messages_test() {
  let assert option.None =
    task_types_update.try_update(
      admin_task_types.default_model(),
      admin_messages.InviteCreateDialogOpened,
      context(option.None),
      feedback_context(),
      error_feedback_context(),
    )
}
