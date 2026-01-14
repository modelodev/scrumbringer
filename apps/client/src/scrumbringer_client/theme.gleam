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

pub fn base_css() -> String {
  [
    ":root { color-scheme: light dark; }",
    "* { box-sizing: border-box; }",
    "body { margin: 0; font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; background: var(--sb-bg); color: var(--sb-text); }",
    ".app { min-height: 100vh; background: var(--sb-bg); color: var(--sb-text); padding: 16px; }",
    ".page { max-width: 480px; margin: 0 auto; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 16px; }",
    ".admin, .member { display: flex; flex-direction: column; gap: 12px; }",
    ".body { display: flex; gap: 12px; align-items: flex-start; }",
    ".nav { width: 220px; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 8px; }",
    ".content { flex: 1; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; min-width: 0; }",
    ".topbar { display: flex; align-items: center; gap: 12px; justify-content: space-between; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; }",
    ".topbar-title { font-weight: 700; }",
    ".topbar-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }",
    ".theme-switch { display: inline-flex; align-items: center; gap: 8px; }",
    ".user { color: var(--sb-muted); }",
    ".section { display: flex; flex-direction: column; gap: 10px; }",
    ".field { display: flex; flex-direction: column; gap: 4px; margin: 8px 0; }",
    ".hint { color: var(--sb-muted); font-size: 0.9em; }",
    ".empty { color: var(--sb-muted); }",
    ".loading { color: var(--sb-info); }",
    ".error { color: var(--sb-danger); }",
    "input, select { padding: 8px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-elevated); color: var(--sb-text); }",
    "button { padding: 8px 12px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-elevated); color: var(--sb-text); cursor: pointer; }",
    "button:hover { border-color: var(--sb-primary); }",
    "button:disabled { opacity: 0.6; cursor: not-allowed; }",
    "button[type=\"submit\"] { background: var(--sb-primary); border-color: var(--sb-primary); color: var(--sb-inverse); }",
    "button[type=\"submit\"]:hover { background: var(--sb-primary-hover); border-color: var(--sb-primary-hover); }",
    "a { color: var(--sb-link); }",
    "a:hover { text-decoration: underline; }",
    ":focus-visible { outline: 3px solid var(--sb-focus-ring); outline-offset: 2px; }",
    ".table { width: 100%; border-collapse: collapse; }",
    ".table th { text-align: left; color: var(--sb-muted); font-weight: 600; padding: 8px; border-bottom: 1px solid var(--sb-border); }",
    ".table td { padding: 8px; border-bottom: 1px solid var(--sb-border); }",
    ".table tbody tr:hover { background: var(--sb-elevated); }",
    ".nav-item { width: 100%; text-align: left; }",
    ".nav-item.active { border-color: var(--sb-primary); }",
    ".actions { display: flex; gap: 8px; flex-wrap: wrap; }",
    ".modal { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; padding: 16px; }",
    ".modal::before { content: \"\"; position: absolute; inset: 0; background: var(--sb-bg); opacity: 0.85; }",
    ".modal-content { position: relative; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; padding: 16px; width: min(720px, 100%); max-height: 85vh; overflow: auto; }",
    ".toast { position: fixed; top: 12px; left: 50%; transform: translateX(-50%); background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 999px; padding: 8px 12px; color: var(--sb-text); box-shadow: 0 6px 24px rgba(0, 0, 0, 0.15); }",
    ".task-card { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; }",
    ".task-card.highlight { border: 2px solid var(--sb-primary); }",
    ".drag-handle { cursor: grab; user-select: none; padding: 2px 6px; border: 1px solid var(--sb-border); border-radius: 8px; }",
    ".drag-handle:hover { border-color: var(--sb-primary); }",
  ]
  |> string.join("\n")
}
