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
//// - **client_update.gleam**: Applies the returned locale to the root model
//// - **i18n/locale.gleam**: Provides locale serialization and persistence

import lustre/effect.{type Effect}

import scrumbringer_client/features/i18n/msg as i18n_messages
import scrumbringer_client/i18n/locale as i18n_locale

// =============================================================================
// Message Handlers
// =============================================================================

/// Handle locale selection from dropdown.
///
/// Parses the locale value, returns the next locale if changed, and persists the
/// preference to local storage.
pub fn update_locale(
  current: i18n_locale.Locale,
  value: String,
) -> #(i18n_locale.Locale, Effect(parent_msg)) {
  case i18n_locale.parse(value) {
    Ok(next_locale) -> {
      case next_locale == current {
        True -> #(current, effect.none())

        False -> #(
          next_locale,
          effect.from(fn(_dispatch) { i18n_locale.save(next_locale) }),
        )
      }
    }

    Error(_) -> #(current, effect.none())
  }
}

/// Updates the locale preference for a message.
pub fn update(
  current: i18n_locale.Locale,
  msg: i18n_messages.Msg,
) -> #(i18n_locale.Locale, Effect(parent_msg)) {
  case msg {
    i18n_messages.LocaleSelected(value) -> update_locale(current, value)
  }
}
