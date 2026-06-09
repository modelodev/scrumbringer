import domain/api_error.{ApiError}
import scrumbringer_client/features/admin/error_feedback
import scrumbringer_client/i18n/locale

pub fn forbidden_feedback_localizes_403_test() {
  let feedback =
    error_feedback.forbidden_feedback(
      locale.En,
      ApiError(status: 403, code: "FORBIDDEN", message: "Forbidden"),
    )

  let assert error_feedback.ForbiddenFeedback(
    message: "Not permitted",
    warning: True,
  ) = feedback
}

pub fn forbidden_feedback_preserves_backend_message_for_non_403_test() {
  let feedback =
    error_feedback.forbidden_feedback(
      locale.En,
      ApiError(status: 409, code: "CONFLICT", message: "Still assigned"),
    )

  let assert error_feedback.ForbiddenFeedback(
    message: "Still assigned",
    warning: False,
  ) = feedback
}
