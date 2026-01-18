//// Internationalization entry point for the client.
////
//// Provides the main translation function that dispatches to
//// locale-specific translation modules.

import scrumbringer_client/i18n/en
import scrumbringer_client/i18n/es
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text.{type Text}

/// Translates a text key to the localized string.
pub fn t(locale: Locale, text: Text) -> String {
  case locale {
    locale.Es -> es.translate(text)
    locale.En -> en.translate(text)
  }
}
