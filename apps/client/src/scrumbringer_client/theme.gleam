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

/// Theme parse failure.
pub type ThemeParseError {
  InvalidTheme(String)
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

/// Parses a string into a theme.
pub fn parse(value: String) -> Result(Theme, ThemeParseError) {
  case string.trim(value) {
    "default" -> Ok(Default)
    "dark" -> Ok(Dark)
    other -> Error(InvalidTheme(other))
  }
}

/// Encodes a theme for storage.
pub fn encode_storage(theme: Theme) -> String {
  serialize(theme)
}

/// Decodes a stored theme value with explicit invalid state.
pub fn decode_storage(value: String) -> ThemeStorage {
  case parse(value) {
    Ok(theme) -> ThemeStored(theme)
    Error(InvalidTheme(value)) -> ThemeInvalid(value)
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
  local_storage_get(storage_key)
  |> decode_storage
  |> stored_theme_or_default
}

fn stored_theme_or_default(stored: ThemeStorage) -> Theme {
  case stored {
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
      #("--sb-bg", "oklch(98.2% 0.008 190)"),
      #("--sb-surface", "oklch(100% 0 0)"),
      #("--sb-elevated", "oklch(96.2% 0.012 190)"),
      #("--sb-surface-1", "oklch(100% 0 0)"),
      #("--sb-surface-2", "oklch(98.4% 0.012 190)"),
      #("--sb-surface-3", "oklch(94.2% 0.018 190)"),
      #("--sb-text", "oklch(21% 0.035 235)"),
      #("--sb-text-strong", "oklch(14% 0.03 235)"),
      #("--sb-text-soft", "oklch(34% 0.035 220)"),
      #("--sb-muted", "oklch(43% 0.035 220)"),
      #("--sb-muted-strong", "oklch(34% 0.035 220)"),
      #("--sb-inverse", "oklch(100% 0 0)"),
      #("--sb-border", "oklch(88% 0.015 190)"),
      #("--sb-hover", "oklch(93.5% 0.025 185)"),
      #("--sb-link", "oklch(45% 0.13 245)"),
      #("--sb-primary", "oklch(47% 0.09 185)"),
      #("--sb-primary-hover", "oklch(39% 0.08 185)"),
      #("--sb-primary-strong", "oklch(34% 0.08 185)"),
      #("--sb-primary-subtle-bg", "oklch(96% 0.035 185)"),
      #("--sb-primary-subtle-border", "oklch(76% 0.08 185)"),
      #("--sb-accent", "oklch(47% 0.09 185)"),
      #("--sb-focus-ring", "oklch(64% 0.11 185 / 0.48)"),
      #("--sb-danger", "oklch(43% 0.17 25)"),
      #("--sb-error", "oklch(43% 0.17 25)"),
      #("--sb-warning", "oklch(43% 0.11 70)"),
      #("--sb-success", "oklch(40% 0.11 150)"),
      #("--sb-info", "oklch(42% 0.12 235)"),
      #("--sb-warning-text", "oklch(43% 0.11 70)"),
      #("--sb-success-text", "oklch(40% 0.11 150)"),
      #("--sb-info-text", "oklch(42% 0.12 235)"),
      #("--sb-error-text", "oklch(43% 0.17 25)"),
      #("--sb-warning-fill", "oklch(62% 0.15 70)"),
      #("--sb-success-fill", "oklch(52% 0.14 150)"),
      #("--sb-info-fill", "oklch(57% 0.15 235)"),
      #("--sb-error-fill", "oklch(55% 0.22 25)"),
      #("--sb-success-subtle-bg", "oklch(95% 0.04 150)"),
      #("--sb-success-subtle-border", "oklch(75% 0.09 150)"),
      #("--sb-warning-subtle-bg", "oklch(95% 0.05 75)"),
      #("--sb-warning-subtle-border", "oklch(77% 0.1 75)"),
      #("--sb-info-subtle-bg", "oklch(95% 0.04 235)"),
      #("--sb-info-subtle-border", "oklch(75% 0.09 235)"),
      #("--sb-shadow-soft", "0 6px 20px oklch(21% 0.035 235 / 0.08)"),
      #("--sb-shadow-modal", "0 24px 60px oklch(21% 0.035 235 / 0.24)"),
      // Card colors (Story 3.4)
      #("--sb-card-gray", "oklch(55% 0.02 250)"),
      #("--sb-card-red", "oklch(60% 0.2 25)"),
      #("--sb-card-orange", "oklch(67% 0.18 55)"),
      #("--sb-card-yellow", "oklch(75% 0.16 95)"),
      #("--sb-card-green", "oklch(65% 0.16 150)"),
      #("--sb-card-blue", "oklch(60% 0.16 245)"),
      #("--sb-card-purple", "oklch(58% 0.18 300)"),
      #("--sb-card-pink", "oklch(62% 0.2 350)"),
    ]

    Dark -> [
      #("--sb-bg", "oklch(16% 0.03 225)"),
      #("--sb-surface", "oklch(20% 0.032 225)"),
      #("--sb-elevated", "oklch(26% 0.035 225)"),
      #("--sb-surface-1", "oklch(20% 0.032 225)"),
      #("--sb-surface-2", "oklch(24% 0.035 225)"),
      #("--sb-surface-3", "oklch(30% 0.04 225)"),
      #("--sb-text", "oklch(91% 0.015 220)"),
      #("--sb-text-strong", "oklch(97% 0.008 220)"),
      #("--sb-text-soft", "oklch(82% 0.02 220)"),
      #("--sb-muted", "oklch(72% 0.025 220)"),
      #("--sb-muted-strong", "oklch(80% 0.025 220)"),
      #("--sb-inverse", "oklch(14% 0.03 225)"),
      #("--sb-border", "oklch(38% 0.035 225)"),
      #("--sb-hover", "oklch(30% 0.04 225)"),
      #("--sb-link", "oklch(76% 0.11 245)"),
      #("--sb-primary", "oklch(72% 0.11 185)"),
      #("--sb-primary-hover", "oklch(82% 0.1 185)"),
      #("--sb-primary-strong", "oklch(86% 0.1 185)"),
      #("--sb-primary-subtle-bg", "oklch(28% 0.06 185)"),
      #("--sb-primary-subtle-border", "oklch(62% 0.1 185)"),
      #("--sb-accent", "oklch(72% 0.11 185)"),
      #("--sb-focus-ring", "oklch(76% 0.11 185 / 0.55)"),
      #("--sb-danger", "oklch(76% 0.14 25)"),
      #("--sb-error", "oklch(76% 0.14 25)"),
      #("--sb-warning", "oklch(81% 0.13 75)"),
      #("--sb-success", "oklch(76% 0.13 150)"),
      #("--sb-info", "oklch(78% 0.12 235)"),
      #("--sb-warning-text", "oklch(81% 0.13 75)"),
      #("--sb-success-text", "oklch(76% 0.13 150)"),
      #("--sb-info-text", "oklch(78% 0.12 235)"),
      #("--sb-error-text", "oklch(76% 0.14 25)"),
      #("--sb-warning-fill", "oklch(68% 0.15 75)"),
      #("--sb-success-fill", "oklch(60% 0.15 150)"),
      #("--sb-info-fill", "oklch(62% 0.14 235)"),
      #("--sb-error-fill", "oklch(58% 0.2 25)"),
      #("--sb-success-subtle-bg", "oklch(25% 0.055 150)"),
      #("--sb-success-subtle-border", "oklch(60% 0.12 150)"),
      #("--sb-warning-subtle-bg", "oklch(28% 0.06 75)"),
      #("--sb-warning-subtle-border", "oklch(64% 0.12 75)"),
      #("--sb-info-subtle-bg", "oklch(27% 0.055 235)"),
      #("--sb-info-subtle-border", "oklch(62% 0.11 235)"),
      #("--sb-shadow-soft", "0 8px 22px oklch(8% 0.025 225 / 0.42)"),
      #("--sb-shadow-modal", "0 28px 72px oklch(8% 0.025 225 / 0.68)"),
      // Card colors (Story 3.4) - slightly brighter for dark theme
      #("--sb-card-gray", "oklch(74% 0.025 250)"),
      #("--sb-card-red", "oklch(74% 0.17 25)"),
      #("--sb-card-orange", "oklch(78% 0.15 55)"),
      #("--sb-card-yellow", "oklch(84% 0.14 95)"),
      #("--sb-card-green", "oklch(78% 0.14 150)"),
      #("--sb-card-blue", "oklch(76% 0.13 245)"),
      #("--sb-card-purple", "oklch(76% 0.14 300)"),
      #("--sb-card-pink", "oklch(76% 0.16 350)"),
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

/// Returns the legacy CSS filter value for icons.
/// Icons should prefer currentColor or token-based styling.
pub fn icon_filter(theme: Theme) -> String {
  case theme {
    Default -> "none"
    Dark -> "none"
  }
}

/// Theme-independent design tokens injected into :root.
/// These do not change between light/dark themes.
pub fn design_tokens() -> String {
  let vars =
    [
      // Typography scale
      #(
        "--sb-font-sans",
        "system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
      ),
      #(
        "--sb-font-mono",
        "ui-monospace, \"SFMono-Regular\", \"Cascadia Code\", \"Liberation Mono\", monospace",
      ),
      #("--sb-font-xs", "0.6875rem"),
      #("--sb-font-sm", "0.75rem"),
      #("--sb-font-base", "0.8125rem"),
      #("--sb-font-md", "0.875rem"),
      #("--sb-font-lg", "1rem"),
      #("--sb-font-xl", "1.125rem"),
      #("--sb-font-2xl", "1.25rem"),
      #("--sb-font-3xl", "1.5rem"),
      #("--sb-weight-regular", "400"),
      #("--sb-weight-medium", "500"),
      #("--sb-weight-semibold", "600"),
      #("--sb-weight-bold", "700"),
      #("--sb-weight-heavy", "800"),
      #("--sb-line-tight", "1.2"),
      #("--sb-line-title", "1.28"),
      #("--sb-line-body", "1.5"),
      #("--sb-line-prose", "1.6"),
      #("--sb-letter-tight", "-0.02em"),
      #("--sb-letter-label", "0.05em"),
      #("--sb-measure-prose", "72ch"),
      // Spacing scale (4px base)
      #("--sb-space-xs", "4px"),
      #("--sb-space-sm", "6px"),
      #("--sb-space-md", "8px"),
      #("--sb-space-lg", "12px"),
      #("--sb-space-xl", "16px"),
      #("--sb-space-2xl", "20px"),
      #("--sb-space-3xl", "24px"),
      #("--sb-space-4xl", "32px"),
      // Semantic spacing roles for visual grouping
      #("--sb-gap-tight", "var(--sb-space-xs)"),
      #("--sb-gap-related", "var(--sb-space-md)"),
      #("--sb-gap-group", "var(--sb-space-lg)"),
      #("--sb-gap-section", "var(--sb-space-xl)"),
      #("--sb-gap-surface", "var(--sb-space-3xl)"),
      // Border radius
      #("--sb-radius-sm", "6px"),
      #("--sb-radius-md", "8px"),
      #("--sb-radius-lg", "10px"),
      #("--sb-radius-xl", "12px"),
      #("--sb-radius-2xl", "16px"),
      #("--sb-radius-pill", "999px"),
      // Transitions
      #("--sb-transition-fast", "0.12s ease"),
      #("--sb-transition-normal", "0.15s ease"),
      #("--sb-transition-slow", "0.3s ease"),
    ]
    |> list.map(fn(pair) {
      let #(name, value) = pair
      name <> ": " <> value
    })
    |> string.join("; ")

  ":root { " <> vars <> "; }"
}
