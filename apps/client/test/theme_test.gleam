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
  let tokens = theme.tokens(theme.Default)

  let assert 51 = list.length(tokens)
  assert_theme_contract(tokens)
  assert_token(tokens, "--sb-bg", "oklch(98.2% 0.008 190)")
  assert_token(tokens, "--sb-text", "oklch(21% 0.035 235)")
  assert_token(tokens, "--sb-primary", "oklch(47% 0.09 185)")
  assert_token(tokens, "--sb-card-blue", "oklch(60% 0.16 245)")
}

pub fn tokens_dark_complete_test() {
  let tokens = theme.tokens(theme.Dark)

  let assert 51 = list.length(tokens)
  assert_theme_contract(tokens)
  assert_token(tokens, "--sb-bg", "oklch(16% 0.03 225)")
  assert_token(tokens, "--sb-text", "oklch(91% 0.015 220)")
  assert_token(tokens, "--sb-primary", "oklch(72% 0.11 185)")
  assert_token(tokens, "--sb-card-blue", "oklch(76% 0.13 245)")
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

fn assert_theme_contract(tokens: List(#(String, String))) {
  let required = [
    "--sb-bg",
    "--sb-surface",
    "--sb-text",
    "--sb-border",
    "--sb-primary",
    "--sb-focus-ring",
    "--sb-error",
    "--sb-warning",
    "--sb-success",
    "--sb-info",
    "--sb-shadow-modal",
    "--sb-card-gray",
    "--sb-card-red",
    "--sb-card-orange",
    "--sb-card-yellow",
    "--sb-card-green",
    "--sb-card-blue",
    "--sb-card-purple",
    "--sb-card-pink",
  ]

  list.each(required, fn(name) {
    let assert True = has_token(tokens, name)
  })
}

fn has_token(tokens: List(#(String, String)), name: String) -> Bool {
  list.any(tokens, fn(token) {
    let #(token_name, _) = token
    token_name == name
  })
}

fn assert_token(tokens: List(#(String, String)), name: String, value: String) {
  let assert Ok(#(_, actual)) =
    list.find(tokens, fn(token) {
      let #(token_name, _) = token
      token_name == name
    })

  let assert True = actual == value
}
