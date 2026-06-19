//// HTTP handler for task view tracking.

import pog
import scrumbringer_server/http/auth
import scrumbringer_server/http/resource_views
import scrumbringer_server/http/service_error_response
import scrumbringer_server/repository/tasks/queries as tasks_queries
import scrumbringer_server/use_case/user_task_views_db
import wisp

/// Routes PUT /api/v1/views/tasks/:id requests.
pub fn handle_task_view(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  resource_views.handle_put(
    req,
    ctx,
    task_id,
    fetch_task_project_id,
    user_task_views_db.touch_task_view,
  )
}

fn fetch_task_project_id(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Int, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(task) -> Ok(task.project_id)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}
