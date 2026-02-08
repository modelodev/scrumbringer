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
    // Card colors
    #("--sb-card-gray", "#6B7280"),
    #("--sb-card-red", "#EF4444"),
    #("--sb-card-orange", "#F97316"),
    #("--sb-card-yellow", "#EAB308"),
    #("--sb-card-green", "#22C55E"),
    #("--sb-card-blue", "#3B82F6"),
    #("--sb-card-purple", "#8B5CF6"),
    #("--sb-card-pink", "#EC4899"),
  ]

  let tokens = theme.tokens(theme.Default)

  list.length(tokens)
  |> should.equal(39)

  tokens
  |> should.equal(expected)
}

pub fn tokens_dark_complete_test() {
  let expected = [
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
    // Card colors (brighter for dark theme)
    #("--sb-card-gray", "#9CA3AF"),
    #("--sb-card-red", "#F87171"),
    #("--sb-card-orange", "#FB923C"),
    #("--sb-card-yellow", "#FACC15"),
    #("--sb-card-green", "#4ADE80"),
    #("--sb-card-blue", "#60A5FA"),
    #("--sb-card-purple", "#A78BFA"),
    #("--sb-card-pink", "#F472B6"),
  ]

  let tokens = theme.tokens(theme.Dark)

  list.length(tokens)
  |> should.equal(39)

  tokens
  |> should.equal(expected)
}
