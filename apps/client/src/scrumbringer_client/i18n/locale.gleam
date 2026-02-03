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

/// Converts a locale to its string representation.
pub fn serialize(locale: Locale) -> String {
  case locale {
    Es -> "es"
    En -> "en"
  }
}

/// Parses a string into a locale (defaults to English).
pub fn deserialize(value: String) -> Locale {
  case value |> string.trim |> string.lowercase {
    "es" -> Es
    "en" -> En
    _ -> En
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
    "" -> {
      let detected = detect()
      theme.local_storage_set(storage_key, serialize(detected))
      detected
    }

    value -> deserialize(value)
  }
}

/// Saves the locale preference to localStorage.
pub fn save(locale: Locale) -> Nil {
  theme.local_storage_set(storage_key, serialize(locale))
}
