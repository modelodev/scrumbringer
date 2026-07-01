import domain/task_status.{Available}
import gleam/option
import scrumbringer_client/api/tasks/operations as task_operations

pub fn project_tasks_url_builds_query_params_test() {
  let assert "/api/v1/projects/1/tasks" =
    task_operations.project_tasks_url(
      1,
      task_operations.TaskFilters(
        status: option.None,
        type_id: option.None,
        capability_id: option.None,
        q: option.None,
        blocked: option.None,
        card_id: option.None,
      ),
    )

  let assert "/api/v1/projects/1/tasks?status=available&type_id=2&capability_id=3&q=hello%20world&blocked=true&card_id=4" =
    task_operations.project_tasks_url(
      1,
      task_operations.TaskFilters(
        status: option.Some(Available),
        type_id: option.Some(2),
        capability_id: option.Some(3),
        q: option.Some("hello world"),
        blocked: option.Some(True),
        card_id: option.Some(4),
      ),
    )
}

pub fn card_task_filters_builds_card_scoped_url_test() {
  let assert "/api/v1/projects/1/tasks?card_id=4" =
    task_operations.project_tasks_url(1, task_operations.card_task_filters(4))
}
