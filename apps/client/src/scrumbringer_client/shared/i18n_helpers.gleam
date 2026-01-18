//// Internationalization helper functions.
////
//// ## Mission
////
//// Provides convenience wrappers for i18n translation functions that extract
//// locale from the Model. Reduces boilerplate across view and update modules.
////
//// ## Responsibilities
////
//// - Model-aware translation wrapper (`i18n_t`)
////
//// ## Non-responsibilities
////
//// - Translation lookup logic (see `i18n/i18n.gleam`)
//// - Text key definitions (see `i18n/text.gleam`)
////
//// ## Relations
////
//// - **i18n/i18n.gleam**: Core translation function
//// - **i18n/text.gleam**: Text key definitions
//// - **client_state.gleam**: Provides Model with locale

import scrumbringer_client/client_state.{type Model}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

/// Translate text using the model's current locale.
///
/// Convenience wrapper around `i18n.t` that extracts locale from model.
///
/// ## Example
///
/// ```gleam
/// i18n_t(model, i18n_text.Welcome)
/// // "Welcome" or "Bienvenido" depending on locale
/// ```
pub fn i18n_t(model: Model, text: i18n_text.Text) -> String {
  i18n.t(model.locale, text)
}
