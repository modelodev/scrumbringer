//// Theme management and CSS variable generation.
////
//// Handles theme persistence, color token definitions, and
//// localStorage utilities shared across the client.

import gleam/list
import gleam/string
import plinth/javascript/storage as js_storage

/// LocalStorage key for theme preference.
pub const storage_key = "sb_theme"

/// Available visual themes.
pub type Theme {
  Default
  Dark
}

/// Stored theme decoding result.
pub type ThemeStorage {
  ThemeStored(Theme)
  ThemeInvalid(String)
}

/// Converts a theme to its string representation.
pub fn serialize(theme: Theme) -> String {
  case theme {
    Default -> "default"
    Dark -> "dark"
  }
}

/// Parses a string into a theme (defaults to Default).
pub fn deserialize(value: String) -> Theme {
  case string.trim(value) {
    "default" -> Default
    "dark" -> Dark
    _ -> Default
  }
}

/// Encodes a theme for storage.
pub fn encode_storage(theme: Theme) -> String {
  serialize(theme)
}

/// Decodes a stored theme value with explicit invalid state.
pub fn decode_storage(value: String) -> ThemeStorage {
  case string.trim(value) {
    "default" -> ThemeStored(Default)
    "dark" -> ThemeStored(Dark)
    other -> ThemeInvalid(other)
  }
}

/// Gets a value from localStorage (returns "" if not found).
pub fn local_storage_get(key: String) -> String {
  case js_storage.local() {
    Ok(storage) ->
      case js_storage.get_item(storage, key) {
        Ok(value) -> value
        Error(_) -> ""
      }

    Error(_) -> ""
  }
}

/// Sets a value in localStorage.
pub fn local_storage_set(key: String, value: String) -> Nil {
  case js_storage.local() {
    Ok(storage) -> {
      let _ = js_storage.set_item(storage, key, value)
      Nil
    }

    Error(_) -> Nil
  }
}

/// Loads the theme preference from localStorage.
pub fn load_from_storage() -> Theme {
  case local_storage_get(storage_key) |> decode_storage {
    ThemeStored(theme) -> theme
    ThemeInvalid(_) -> Default
  }
}

/// Saves the theme preference to localStorage.
pub fn save_to_storage(theme: Theme) -> Nil {
  local_storage_set(storage_key, encode_storage(theme))
}

/// Returns whether filters should be visible by default.
pub fn filters_default_visible(_theme: Theme) -> Bool {
  True
}

/// Returns the CSS custom property values for a theme.
pub fn tokens(theme: Theme) -> List(#(String, String)) {
  case theme {
    Default -> [
      #("--sb-bg", "#f8fafc"),
      #("--sb-surface", "#ffffff"),
      #("--sb-elevated", "#f1f5f9"),
      #("--sb-surface-1", "#ffffff"),
      #("--sb-surface-2", "#f8fbff"),
      #("--sb-surface-3", "#eef3fa"),
      #("--sb-text", "#0f172a"),
      #("--sb-text-strong", "#020617"),
      #("--sb-text-soft", "#334155"),
      #("--sb-muted", "#475569"),
      #("--sb-muted-strong", "#334155"),
      #("--sb-inverse", "#ffffff"),
      #("--sb-border", "#e2e8f0"),
      #("--sb-link", "#2563eb"),
      #("--sb-primary", "#0f766e"),
      #("--sb-primary-hover", "#115e59"),
      #("--sb-primary-subtle-bg", "#e6f6f3"),
      #("--sb-primary-subtle-border", "#8ad3ca"),
      #("--sb-focus-ring", "rgba(56, 189, 248, 0.55)"),
      #("--sb-danger", "#dc2626"),
      #("--sb-warning", "#d97706"),
      #("--sb-success", "#16a34a"),
      #("--sb-info", "#0284c7"),
      #("--sb-success-subtle-bg", "#e9f8ef"),
      #("--sb-success-subtle-border", "#91d8aa"),
      #("--sb-warning-subtle-bg", "#fef5e7"),
      #("--sb-warning-subtle-border", "#f2cc86"),
      #("--sb-info-subtle-bg", "#e8f5fb"),
      #("--sb-info-subtle-border", "#8bcce8"),
      #("--sb-shadow-soft", "0 6px 20px rgba(15, 23, 42, 0.08)"),
      #("--sb-shadow-modal", "0 24px 60px rgba(15, 23, 42, 0.24)"),
      // Card colors (Story 3.4)
      #("--sb-card-gray", "#6B7280"),
      #("--sb-card-red", "#EF4444"),
      #("--sb-card-orange", "#F97316"),
      #("--sb-card-yellow", "#EAB308"),
      #("--sb-card-green", "#22C55E"),
      #("--sb-card-blue", "#3B82F6"),
      #("--sb-card-purple", "#8B5CF6"),
      #("--sb-card-pink", "#EC4899"),
    ]

    Dark -> [
      #("--sb-bg", "#0b1220"),
      #("--sb-surface", "#0f172a"),
      #("--sb-elevated", "#1e293b"),
      #("--sb-surface-1", "#0f172a"),
      #("--sb-surface-2", "#162338"),
      #("--sb-surface-3", "#223247"),
      #("--sb-text", "#e2e8f0"),
      #("--sb-text-strong", "#f8fafc"),
      #("--sb-text-soft", "#cbd5e1"),
      #("--sb-muted", "#94a3b8"),
      #("--sb-muted-strong", "#b8c5d8"),
      #("--sb-inverse", "#0f172a"),
      #("--sb-border", "#334155"),
      #("--sb-link", "#60a5fa"),
      #("--sb-primary", "#2dd4bf"),
      #("--sb-primary-hover", "#5eead4"),
      #("--sb-primary-subtle-bg", "#173b3a"),
      #("--sb-primary-subtle-border", "#3ebbad"),
      #("--sb-focus-ring", "rgba(125, 211, 252, 0.55)"),
      #("--sb-danger", "#f87171"),
      #("--sb-warning", "#fbbf24"),
      #("--sb-success", "#4ade80"),
      #("--sb-info", "#38bdf8"),
      #("--sb-success-subtle-bg", "#153329"),
      #("--sb-success-subtle-border", "#4ade80"),
      #("--sb-warning-subtle-bg", "#3b3015"),
      #("--sb-warning-subtle-border", "#fbbf24"),
      #("--sb-info-subtle-bg", "#143140"),
      #("--sb-info-subtle-border", "#38bdf8"),
      #("--sb-shadow-soft", "0 8px 22px rgba(2, 6, 23, 0.35)"),
      #("--sb-shadow-modal", "0 28px 72px rgba(2, 6, 23, 0.62)"),
      // Card colors (Story 3.4) - slightly brighter for dark theme
      #("--sb-card-gray", "#9CA3AF"),
      #("--sb-card-red", "#F87171"),
      #("--sb-card-orange", "#FB923C"),
      #("--sb-card-yellow", "#FACC15"),
      #("--sb-card-green", "#4ADE80"),
      #("--sb-card-blue", "#60A5FA"),
      #("--sb-card-purple", "#A78BFA"),
      #("--sb-card-pink", "#F472B6"),
    ]
  }
}

/// Generates a CSS custom property string for inline styles.
pub fn css_vars(theme: Theme) -> String {
  let parts =
    list.map(tokens(theme), fn(pair) {
      let #(name, value) = pair
      name <> ":" <> value
    })

  string.join(parts, ";") <> ";"
}

/// Returns a CSS filter value for icons based on theme.
/// For dark theme, inverts the icon colors to be visible.
pub fn icon_filter(theme: Theme) -> String {
  case theme {
    Default -> "none"
    Dark -> "invert(0.9) hue-rotate(180deg)"
  }
}
