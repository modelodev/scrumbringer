import gleam/list
import gleam/string

pub const storage_key = "sb_theme"

pub type Theme {
  Default
  Dark
}

pub fn serialize(theme: Theme) -> String {
  case theme {
    Default -> "default"
    Dark -> "dark"
  }
}

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

pub fn load_from_storage() -> Theme {
  local_storage_get_ffi(storage_key)
  |> deserialize
}

pub fn save_to_storage(theme: Theme) -> Nil {
  local_storage_set_ffi(storage_key, serialize(theme))
}

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
    ]
  }
}

pub fn css_vars(theme: Theme) -> String {
  let parts =
    list.map(tokens(theme), fn(pair) {
      let #(name, value) = pair
      name <> ":" <> value
    })

  string.join(parts, ";") <> ";"
}
