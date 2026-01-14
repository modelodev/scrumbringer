import gleam/list
import gleeunit/should

import scrumbringer_client/theme

pub fn serialize_default_test() {
  theme.serialize(theme.Default)
  |> should.equal("default")
}

pub fn serialize_dark_test() {
  theme.serialize(theme.Dark)
  |> should.equal("dark")
}

pub fn deserialize_default_test() {
  theme.deserialize("default")
  |> should.equal(theme.Default)
}

pub fn deserialize_dark_test() {
  theme.deserialize("dark")
  |> should.equal(theme.Dark)
}

pub fn deserialize_invalid_falls_back_to_default_test() {
  theme.deserialize("nope")
  |> should.equal(theme.Default)
}

pub fn tokens_default_complete_test() {
  let expected = [
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
  ]

  let tokens = theme.tokens(theme.Default)

  list.length(tokens)
  |> should.equal(15)

  tokens
  |> should.equal(expected)
}

pub fn tokens_dark_complete_test() {
  let expected = [
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
  ]

  let tokens = theme.tokens(theme.Dark)

  list.length(tokens)
  |> should.equal(15)

  tokens
  |> should.equal(expected)
}
