//// Automation execution seed scenario.
////
//// Replays a small set of seeded task transitions through the rules engine so
//// automation execution history exists for metrics and trace validation.

import domain/task/state as task_state
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import pog
import scrumbringer_server/use_case/rules_engine

pub type Context {
  Context(
    org_id: Int,
    admin_id: Int,
    task_ids: List(Int),
    active_project_ids: List(Int),
    task_type_ids: List(#(Int, Int, Int, Int)),
    rule_executions_count: Int,
  )
}

pub fn build(db: pog.Connection, context: Context) -> Result(Context, String) {
  let tasks_to_trigger = list.take(context.task_ids, 3)

  case context.active_project_ids, context.task_type_ids {
    [project_id, ..], [#(_proj, bug_type_id, _feat, _task), ..] -> {
      use _ <- result.try(
        list.try_map(tasks_to_trigger, fn(task_id) {
          let event =
            rules_engine.task_trigger(
              rules_engine.TaskContext(
                task_id: task_id,
                project_id: project_id,
                org_id: context.org_id,
                type_id: bug_type_id,
                card_id: None,
              ),
              context.admin_id,
              Some(task_state.Claimed(context.admin_id, "", task_state.Taken)),
              task_state.Closed(task_state.Done, "", context.admin_id),
            )
          rules_engine.evaluate_rules(db, event)
          |> result.map_error(fn(_) { "Rule evaluation failed" })
        }),
      )

      Ok(
        Context(..context, rule_executions_count: list.length(tasks_to_trigger)),
      )
    }
    _, _ -> Ok(context)
  }
}
