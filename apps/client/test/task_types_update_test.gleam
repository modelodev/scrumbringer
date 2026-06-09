import gleam/option

import lustre/effect

import domain/api_error.{ApiError}
import domain/remote
import domain/task_type.{type TaskType, TaskType}
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/task_types/update as task_types_update

fn task_type(id: Int, name: String) -> TaskType {
  TaskType(
    id: id,
    name: name,
    icon: "box",
    capability_id: option.None,
    tasks_count: 0,
  )
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

pub fn fetched_ok_loads_task_types_test() {
  let task_types = [task_type(1, "Bug")]

  let #(next, fx) =
    task_types_update.handle_task_types_fetched_ok(
      admin_task_types.default_model(),
      task_types,
    )

  let assert True = next.task_types == remote.Loaded([task_type(1, "Bug")])
  let assert True = fx == effect.none()
}

pub fn create_dialog_opened_sets_create_mode_test() {
  let #(next, fx) =
    task_types_update.handle_task_type_dialog_opened(
      admin_task_types.default_model(),
    )

  let assert option.Some(state_types.TaskTypeDialogCreate) =
    next.task_types_dialog_mode
  let assert True = fx == effect.none()
}

pub fn create_dialog_closed_resets_form_state_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types_dialog_mode: option.Some(state_types.TaskTypeDialogCreate),
      task_types_create_name: "Bug",
      task_types_create_icon: "bug",
      task_types_create_icon_search: "bu",
      task_types_create_icon_category: "work",
      task_types_create_capability_id: option.Some("7"),
      task_types_create_in_flight: True,
      task_types_create_error: option.Some("error"),
      task_types_icon_preview: state_types.IconOk,
    )

  let #(next, fx) = task_types_update.handle_task_type_dialog_closed(model)

  let assert option.None = next.task_types_dialog_mode
  let assert "" = next.task_types_create_name
  let assert "" = next.task_types_create_icon
  let assert "" = next.task_types_create_icon_search
  let assert "all" = next.task_types_create_icon_category
  let assert option.None = next.task_types_create_capability_id
  let assert False = next.task_types_create_in_flight
  let assert option.None = next.task_types_create_error
  let assert state_types.IconIdle = next.task_types_icon_preview
  let assert True = fx == effect.none()
}

pub fn field_handlers_update_create_form_test() {
  let #(model, _) =
    task_types_update.handle_task_type_create_name_changed(
      admin_task_types.default_model(),
      "Bug",
    )
  let #(model, _) =
    task_types_update.handle_task_type_create_icon_changed(model, "bug")
  let #(model, _) =
    task_types_update.handle_task_type_create_icon_search_changed(model, "bu")
  let #(model, _) =
    task_types_update.handle_task_type_create_icon_category_changed(
      model,
      "work",
    )
  let #(next, fx) =
    task_types_update.handle_task_type_create_capability_changed(model, "7")

  let assert "Bug" = next.task_types_create_name
  let assert "bug" = next.task_types_create_icon
  let assert state_types.IconOk = next.task_types_icon_preview
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

  let #(next, fx) =
    task_types_update.handle_task_type_create_submitted(
      model,
      context(option.None),
    )

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

  let #(next, fx) =
    task_types_update.handle_task_type_create_submitted(
      model,
      context(option.Some(3)),
    )

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

  let #(next, _fx) =
    task_types_update.handle_task_type_create_submitted(
      model,
      context(option.Some(3)),
    )

  let assert True = next.task_types_create_in_flight
  let assert option.None = next.task_types_create_error
}

pub fn created_ok_closes_dialog_and_resets_form_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types_dialog_mode: option.Some(state_types.TaskTypeDialogCreate),
      task_types_create_name: "Bug",
      task_types_create_icon: "bug",
      task_types_create_icon_search: "bu",
      task_types_create_icon_category: "work",
      task_types_create_capability_id: option.Some("7"),
      task_types_create_in_flight: True,
      task_types_create_error: option.Some("old"),
      task_types_icon_preview: state_types.IconOk,
    )

  let #(next, fx) =
    task_types_update.handle_task_type_created_ok(model, feedback_context())

  let assert option.None = next.task_types_dialog_mode
  let assert False = next.task_types_create_in_flight
  let assert "" = next.task_types_create_name
  let assert "" = next.task_types_create_icon
  let assert "" = next.task_types_create_icon_search
  let assert "all" = next.task_types_create_icon_category
  let assert option.None = next.task_types_create_capability_id
  let assert option.None = next.task_types_create_error
  let assert state_types.IconIdle = next.task_types_icon_preview
  let assert False = fx == effect.none()
}

pub fn crud_updated_replaces_loaded_task_type_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types: remote.Loaded([task_type(1, "Bug"), task_type(2, "Feature")]),
      task_types_dialog_mode: option.Some(
        state_types.TaskTypeDialogEdit(task_type(1, "Bug")),
      ),
    )

  let #(next, fx) =
    task_types_update.handle_task_type_crud_updated(
      model,
      task_type(1, "Incident"),
      feedback_context(),
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
        state_types.TaskTypeDialogDelete(task_type(1, "Bug")),
      ),
    )

  let #(next, fx) =
    task_types_update.handle_task_type_crud_deleted(
      model,
      1,
      feedback_context(),
    )

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
