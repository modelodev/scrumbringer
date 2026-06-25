//// Effectful post-create feedback update flow for pool tasks.

import lustre/effect.{type Effect}

import domain/task.{type Task}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/features/pool/task_created_feedback
import scrumbringer_client/ui/toast

const created_highlight_ms = 4000

pub type Context(parent_msg) {
  Context(
    on_task_created_feedback: fn(Int) -> parent_msg,
    on_highlight_expired: fn(Int) -> parent_msg,
    on_toast: fn(String, toast.ToastVariant, toast.ToastAction) ->
      Effect(parent_msg),
  )
}

pub fn effects(
  config: task_created_feedback.Config,
  task: Task,
  context: Context(parent_msg),
) -> Effect(parent_msg) {
  let #(toast_message, toast_variant, toast_action) =
    task_created_feedback.view(config, task)

  effect.batch([
    effect.from(fn(dispatch) {
      dispatch(context.on_task_created_feedback(task.id))
    }),
    app_effects.schedule_timeout(created_highlight_ms, fn() {
      context.on_highlight_expired(task.id)
    }),
    context.on_toast(toast_message, toast_variant, toast_action),
  ])
}
