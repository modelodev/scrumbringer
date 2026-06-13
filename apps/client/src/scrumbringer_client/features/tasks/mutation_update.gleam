//// Effectful feedback workflow for task mutation results.

import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import scrumbringer_client/ui/toast

pub type Success {
  Claimed
  Released
  Completed
}

pub type ErrorLabels {
  ErrorLabels(
    task_not_found: String,
    task_already_claimed: String,
    task_blocked_by_dependencies: String,
    task_version_conflict: String,
    task_mutation_rolled_back: String,
  )
}

pub type Context(parent_msg) {
  Context(
    task_claimed: String,
    task_released: String,
    task_completed: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_work_sessions_refetch: fn() -> Effect(parent_msg),
  )
}

pub type ErrorContext(parent_msg) {
  ErrorContext(
    labels: ErrorLabels,
    on_warning_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

pub fn success_effect(
  success: Success,
  context: Context(parent_msg),
) -> Effect(parent_msg) {
  let toast_fx = context.on_success_toast(success_message(success, context))

  case should_refetch_work_sessions(success) {
    True -> effect.batch([toast_fx, context.on_work_sessions_refetch()])
    False -> toast_fx
  }
}

pub fn should_refetch_work_sessions(success: Success) -> Bool {
  case success {
    Claimed -> False
    Released | Completed -> True
  }
}

fn success_message(success: Success, context: Context(parent_msg)) -> String {
  case success {
    Claimed -> context.task_claimed
    Released -> context.task_released
    Completed -> context.task_completed
  }
}

pub fn error_effect(
  err: ApiError,
  context: ErrorContext(parent_msg),
) -> Effect(parent_msg) {
  let #(message, variant) = error_feedback(err, context.labels)

  case variant {
    toast.Warning -> context.on_warning_toast(message)
    toast.Error -> context.on_error_toast(message)
    _ -> context.on_error_toast(message)
  }
}

pub fn error_feedback(
  err: ApiError,
  labels: ErrorLabels,
) -> #(String, toast.ToastVariant) {
  case err.status {
    404 -> #(labels.task_not_found, toast.Warning)
    409 -> #(conflict_message(err, labels), toast.Warning)
    422 -> #(unprocessable_message(err, labels), toast.Warning)
    _ -> #(labels.task_mutation_rolled_back <> ": " <> err.message, toast.Error)
  }
}

fn conflict_message(err: ApiError, labels: ErrorLabels) -> String {
  case
    string.contains(err.code, "BLOCKED"),
    string.contains(err.code, "CLAIMED")
  {
    True, _ -> labels.task_blocked_by_dependencies
    _, True -> labels.task_already_claimed
    False, False -> labels.task_version_conflict
  }
}

fn unprocessable_message(err: ApiError, labels: ErrorLabels) -> String {
  case string.contains(err.code, "VERSION") {
    True -> labels.task_version_conflict
    False -> err.message
  }
}
