//// Shared admin error feedback derivations.

import domain/api_error.{type ApiError}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub type ForbiddenFeedback {
  ForbiddenFeedback(message: String, warning: Bool)
}

pub fn forbidden_feedback(locale: Locale, err: ApiError) -> ForbiddenFeedback {
  case err.status {
    403 ->
      ForbiddenFeedback(
        message: i18n.t(locale, i18n_text.NotPermitted),
        warning: True,
      )
    _ -> ForbiddenFeedback(message: err.message, warning: False)
  }
}
