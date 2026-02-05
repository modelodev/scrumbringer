//// I18n workflow for Scrumbringer client.
////
//// ## Mission
////
//// Manages locale selection and persistence.
//// Handles locale dropdown changes and saves preferences to local storage.
////
//// ## Responsibilities
////
//// - Handle locale selector changes
//// - Persist locale preference to local storage
//// - Avoid redundant updates when locale unchanged
////
//// ## Non-responsibilities
////
//// - Translation text definitions (see `i18n/text.gleam`)
//// - Locale type definitions (see `i18n/locale.gleam`)
//// - View rendering (see `client_view.gleam`)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg types
//// - **client_update.gleam**: Delegates LocaleSelected message here
//// - **i18n/locale.gleam**: Provides locale serialization and persistence

import lustre/effect.{type Effect}

import scrumbringer_client/client_state.{type Model, type Msg, update_ui}
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/i18n/msg as i18n_messages
import scrumbringer_client/i18n/locale as i18n_locale

// =============================================================================
// Message Handlers
// =============================================================================

/// Handle locale selection from dropdown.
///
/// Deserializes the locale value, updates model if changed,
/// and persists the preference to local storage.
pub fn handle_locale_selected(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  let next_locale = i18n_locale.deserialize(value)

  case next_locale == model.ui.locale {
    True -> #(model, effect.none())

    False -> #(
      update_ui(model, fn(ui) { ui_state.UiModel(..ui, locale: next_locale) }),
      effect.from(fn(_dispatch) { i18n_locale.save(next_locale) }),
    )
  }
}

/// Updates the model for a message.
pub fn update(model: Model, msg: i18n_messages.Msg) -> #(Model, Effect(Msg)) {
  case msg {
    i18n_messages.LocaleSelected(value) -> handle_locale_selected(model, value)
  }
}
