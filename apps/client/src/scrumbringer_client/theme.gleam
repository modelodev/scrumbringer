//// Theme management and CSS variable generation.
////
//// Handles theme persistence, color token definitions, and
//// localStorage utilities shared across the client.

import gleam/list
import gleam/string

/// LocalStorage key for theme preference.
pub const storage_key = "sb_theme"

/// Available visual themes.
pub type Theme {
  Default
  Dark
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

@external(javascript, "./fetch.ffi.mjs", "local_storage_get")
fn local_storage_get_ffi(_key: String) -> String {
  ""
}

@external(javascript, "./fetch.ffi.mjs", "local_storage_set")
fn local_storage_set_ffi(_key: String, _value: String) -> Nil {
  Nil
}

/// Gets a value from localStorage (returns "" if not found).
pub fn local_storage_get(key: String) -> String {
  local_storage_get_ffi(key)
}

/// Sets a value in localStorage.
pub fn local_storage_set(key: String, value: String) -> Nil {
  local_storage_set_ffi(key, value)
}

/// Loads the theme preference from localStorage.
pub fn load_from_storage() -> Theme {
  local_storage_get_ffi(storage_key)
  |> deserialize
}

/// Saves the theme preference to localStorage.
pub fn save_to_storage(theme: Theme) -> Nil {
  local_storage_set_ffi(storage_key, serialize(theme))
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
      #("--sb-text", "#0f172a"),
      #("--sb-muted", "#475569"),
      #("--sb-inverse", "#ffffff"),
      #("--sb-border", "#e2e8f0"),
      #("--sb-link", "#2563eb"),
      #("--sb-primary", "#0f766e"),
      #("--sb-primary-hover", "#115e59"),
      #("--sb-focus-ring", "rgba(56, 189, 248, 0.55)"),
      #("--sb-danger", "#dc2626"),
      #("--sb-warning", "#d97706"),
      #("--sb-success", "#16a34a"),
      #("--sb-info", "#0284c7"),
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
      #("--sb-text", "#e2e8f0"),
      #("--sb-muted", "#94a3b8"),
      #("--sb-inverse", "#0f172a"),
      #("--sb-border", "#334155"),
      #("--sb-link", "#60a5fa"),
      #("--sb-primary", "#2dd4bf"),
      #("--sb-primary-hover", "#5eead4"),
      #("--sb-focus-ring", "rgba(125, 211, 252, 0.55)"),
      #("--sb-danger", "#f87171"),
      #("--sb-warning", "#fbbf24"),
      #("--sb-success", "#4ade80"),
      #("--sb-info", "#38bdf8"),
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
