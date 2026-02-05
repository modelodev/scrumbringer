//// i18n helpers.

import scrumbringer_client/client_state.{type Model}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/shared/i18n_helpers

/// Translate text using the model's current locale.
pub fn i18n_t(model: Model, text: i18n_text.Text) -> String {
  i18n_helpers.i18n_t(model, text)
}
