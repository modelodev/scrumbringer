import domain/task.{TaskFilters}
import domain/task_status.{Available}
import gleam/option
import scrumbringer_client/api/tasks/operations as task_operations

pub fn project_tasks_url_builds_query_params_test() {
  let assert "/api/v1/projects/1/tasks" =
    task_operations.project_tasks_url(
      1,
      TaskFilters(
        status: option.None,
        type_id: option.None,
        capability_id: option.None,
        q: option.None,
        blocked: option.None,
      ),
    )

  let assert "/api/v1/projects/1/tasks?status=available&type_id=2&capability_id=3&q=hello%20world&blocked=true" =
    task_operations.project_tasks_url(
      1,
      TaskFilters(
        status: option.Some(Available),
        type_id: option.Some(2),
        capability_id: option.Some(3),
        q: option.Some("hello world"),
        blocked: option.Some(True),
      ),
    )
}
