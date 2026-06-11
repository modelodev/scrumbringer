import gleam/list
import gleam/string

import scrumbringer_client/theme

pub fn serialize_default_test() {
  let assert "default" = theme.serialize(theme.Default)
}

pub fn serialize_dark_test() {
  let assert "dark" = theme.serialize(theme.Dark)
}

pub fn parse_default_test() {
  let assert Ok(theme.Default) = theme.parse("default")
}

pub fn parse_dark_test() {
  let assert Ok(theme.Dark) = theme.parse("dark")
}

pub fn parse_invalid_returns_error_test() {
  let assert Error(theme.InvalidTheme("nope")) = theme.parse("nope")
}

pub fn decode_storage_invalid_preserves_value_test() {
  let assert theme.ThemeInvalid("nope") = theme.decode_storage("nope")
}

pub fn tokens_default_complete_test() {
  let expected = [
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
    // Card colors
    #("--sb-card-gray", "oklch(55% 0.02 250)"),
    #("--sb-card-red", "oklch(60% 0.2 25)"),
    #("--sb-card-orange", "oklch(67% 0.18 55)"),
    #("--sb-card-yellow", "oklch(75% 0.16 95)"),
    #("--sb-card-green", "oklch(65% 0.16 150)"),
    #("--sb-card-blue", "oklch(60% 0.16 245)"),
    #("--sb-card-purple", "oklch(58% 0.18 300)"),
    #("--sb-card-pink", "oklch(62% 0.2 350)"),
  ]

  let tokens = theme.tokens(theme.Default)

  let assert 51 = list.length(tokens)

  let assert True = tokens == expected
}

pub fn tokens_dark_complete_test() {
  let expected = [
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
    // Card colors (brighter for dark theme)
    #("--sb-card-gray", "oklch(74% 0.025 250)"),
    #("--sb-card-red", "oklch(74% 0.17 25)"),
    #("--sb-card-orange", "oklch(78% 0.15 55)"),
    #("--sb-card-yellow", "oklch(84% 0.14 95)"),
    #("--sb-card-green", "oklch(78% 0.14 150)"),
    #("--sb-card-blue", "oklch(76% 0.13 245)"),
    #("--sb-card-purple", "oklch(76% 0.14 300)"),
    #("--sb-card-pink", "oklch(76% 0.16 350)"),
  ]

  let tokens = theme.tokens(theme.Dark)

  let assert 51 = list.length(tokens)

  let assert True = tokens == expected
}

pub fn design_tokens_include_semantic_spacing_roles_test() {
  let css = theme.design_tokens()

  let assert True = string.contains(css, "--sb-gap-tight: var(--sb-space-xs)")
  let assert True = string.contains(css, "--sb-gap-related: var(--sb-space-md)")
  let assert True = string.contains(css, "--sb-gap-group: var(--sb-space-lg)")
  let assert True = string.contains(css, "--sb-gap-section: var(--sb-space-xl)")
  let assert True =
    string.contains(css, "--sb-gap-surface: var(--sb-space-3xl)")
}
