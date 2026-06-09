import scrumbringer_client/features/milestones/error_codes
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text as i18n_text

pub fn milestone_error_code_uses_locale_without_root_model_test() {
  let message =
    error_codes.to_user_message(
      locale.En,
      "MILESTONE_ALREADY_ACTIVE",
      "",
      i18n_text.MetricsLoadError,
    )

  let assert "Another milestone is already active" = message
}

pub fn milestone_unknown_error_uses_backend_message_test() {
  let message =
    error_codes.to_user_message(
      locale.En,
      "UNKNOWN",
      "Backend message",
      i18n_text.MetricsLoadError,
    )

  let assert "Backend message" = message
}

pub fn milestone_unknown_empty_error_uses_fallback_test() {
  let message =
    error_codes.to_user_message(
      locale.En,
      "UNKNOWN",
      "",
      i18n_text.MetricsLoadError,
    )

  let assert "Could not load metrics" = message
}
