//// Locale detection, persistence, and serialization.
////
//// Handles detecting the user's preferred language from the browser,
//// storing/retrieving locale preferences from localStorage, and
//// converting between locale types and string representations.

import gleam/string

import scrumbringer_client/theme

/// LocalStorage key for persisted locale preference.
pub const storage_key = "sb_locale"

/// Supported application locales.
pub type Locale {
  Es
  En
}

/// Locale parse failure.
pub type LocaleParseError {
  InvalidLocale(String)
}

/// Stored locale decoding result.
pub type LocaleStorage {
  LocaleStored(Locale)
  LocaleInvalid(String)
}

/// Converts a locale to its string representation.
pub fn serialize(locale: Locale) -> String {
  case locale {
    Es -> "es"
    En -> "en"
  }
}

/// Parses a string into a supported locale.
pub fn parse(value: String) -> Result(Locale, LocaleParseError) {
  case value |> string.trim |> string.lowercase {
    "es" -> Ok(Es)
    "en" -> Ok(En)
    other -> Error(InvalidLocale(other))
  }
}

/// Decodes a stored locale value with explicit invalid state.
pub fn decode_storage(value: String) -> LocaleStorage {
  case parse(value) {
    Ok(locale) -> LocaleStored(locale)
    Error(InvalidLocale(value)) -> LocaleInvalid(value)
  }
}

/// Normalizes a browser language code to a supported locale.
pub fn normalize_language(language: String) -> Locale {
  let value = language |> string.trim |> string.lowercase

  case string.starts_with(value, "es") {
    True -> Es
    False -> En
  }
}

@external(javascript, "../device.ffi.mjs", "navigator_language")
fn navigator_language_ffi() -> String {
  ""
}

/// Detects the user's preferred locale from the browser.
pub fn detect() -> Locale {
  navigator_language_ffi()
  |> normalize_language
}

/// Loads the locale from storage, detecting if not set.
pub fn load() -> Locale {
  let stored = theme.local_storage_get(storage_key)

  case string.trim(stored) {
    "" -> detect_and_store()

    value -> {
      case decode_storage(value) {
        LocaleStored(locale) -> locale
        LocaleInvalid(_) -> detect_and_store()
      }
    }
  }
}

fn detect_and_store() -> Locale {
  let detected = detect()
  theme.local_storage_set(storage_key, serialize(detected))
  detected
}

/// Saves the locale preference to localStorage.
pub fn save(locale: Locale) -> Nil {
  theme.local_storage_set(storage_key, serialize(locale))
}
