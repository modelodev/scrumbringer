import gleam/string

import scrumbringer_client/theme

pub const storage_key = "sb_locale"

pub type Locale {
  Es
  En
}

pub fn serialize(locale: Locale) -> String {
  case locale {
    Es -> "es"
    En -> "en"
  }
}

pub fn deserialize(value: String) -> Locale {
  case value |> string.trim |> string.lowercase {
    "es" -> Es
    "en" -> En
    _ -> En
  }
}

pub fn normalize_language(language: String) -> Locale {
  let value = language |> string.trim |> string.lowercase

  case string.starts_with(value, "es") {
    True -> Es
    False -> En
  }
}

@external(javascript, "../fetch.ffi.mjs", "navigator_language")
fn navigator_language_ffi() -> String {
  ""
}

pub fn detect() -> Locale {
  navigator_language_ffi()
  |> normalize_language
}

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

pub fn save(locale: Locale) -> Nil {
  theme.local_storage_set(storage_key, serialize(locale))
}
