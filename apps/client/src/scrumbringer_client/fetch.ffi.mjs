export function read_cookie(name) {
  if (typeof document === "undefined") return ""
  const all = document.cookie || ""
  const parts = all.split(";")
  for (const part of parts) {
    const trimmed = part.trim()
    if (!trimmed) continue
    const eq = trimmed.indexOf("=")
    if (eq === -1) continue
    const k = trimmed.slice(0, eq)
    if (k !== name) continue
    const v = trimmed.slice(eq + 1)
    try {
      return decodeURIComponent(v)
    } catch {
      return v
    }
  }
  return ""
}

function unwrap_option(value) {
  if (value === undefined || value === null) return undefined

  // Gleam option values are `Some(value)` / `None()` custom types.
  if (typeof value === "object") {
    const name = value.constructor?.name
    if (name === "None") return undefined
    if (name === "Some") return value[0]
  }

  return value
}

export function send(method, url, headers, body, callback) {
  const m = String(method || "").trim().toUpperCase() || "GET"

  const init = {
    method: m,
    headers: Object.fromEntries(headers),
    credentials: "same-origin",
  }

  const unwrappedBody = unwrap_option(body)

  // Fetch forbids a body for GET/HEAD.
  if (unwrappedBody !== undefined && m !== "GET" && m !== "HEAD") {
    init.body = unwrappedBody
  }

  fetch(url, init)
    .then(async (res) => {
      const text = await res.text()
      callback([res.status, text])
    })
    .catch((err) => {
      callback([
        0,
        JSON.stringify({
          error: { code: "NETWORK_ERROR", message: String(err), details: {} },
        }),
      ])
    })
}

export function copy_to_clipboard(text, callback) {
  if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
    navigator.clipboard
      .writeText(text)
      .then(() => callback(true))
      .catch(() => callback(false))
    return
  }

  try {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()
    const ok = document.execCommand("copy")
    document.body.removeChild(textarea)
    callback(Boolean(ok))
  } catch {
    callback(false)
  }
}

export function set_timeout(ms, callback) {
  return setTimeout(() => callback(undefined), ms)
}

export function clear_timeout(id) {
  clearTimeout(id)
}

export function encode_uri_component(value) {
  return encodeURIComponent(value)
}

export function days_since_iso(iso) {
  const parsed = Date.parse(iso)
  if (!Number.isFinite(parsed)) return 0
  const diffMs = Date.now() - parsed
  if (!Number.isFinite(diffMs)) return 0
  return Math.max(0, Math.floor(diffMs / 86400000))
}

export function now_ms() {
  return Date.now()
}

export function parse_iso_ms(iso) {
  const parsed = Date.parse(String(iso || ""))
  if (!Number.isFinite(parsed)) return 0
  return Math.floor(parsed)
}

export function is_mobile() {
  if (typeof window === "undefined") return false
  const width = Number(window.innerWidth || 0)
  return width > 0 && width <= 640
}

export function navigator_language() {
  if (typeof navigator === "undefined") return ""
  const value = navigator.language || navigator.userLanguage || ""
  return value == null ? "" : String(value)
}

export function element_client_offset(id) {
  if (typeof document === "undefined") return [0, 0]
  const el = document.getElementById(id)
  if (!el) return [0, 0]
  const rect = el.getBoundingClientRect()
  return [Math.round(rect.left), Math.round(rect.top)]
}

export function element_client_rect(id) {
  if (typeof document === "undefined") return [0, 0, 0, 0]
  const el = document.getElementById(id)
  if (!el) return [0, 0, 0, 0]
  const rect = el.getBoundingClientRect()
  return [
    Math.round(rect.left),
    Math.round(rect.top),
    Math.round(rect.width),
    Math.round(rect.height),
  ]
}

export function input_value(id) {
  if (typeof document === "undefined") return ""
  const el = document.getElementById(String(id))
  if (!el) return ""
  // input/textarea elements
  const value = el.value
  return value == null ? "" : String(value)
}

export function location_origin() {
  if (typeof window === "undefined") return ""
  return window.location?.origin || ""
}

export function location_pathname() {
  if (typeof window === "undefined") return ""
  return window.location?.pathname || ""
}

export function location_hash() {
  if (typeof window === "undefined") return ""
  return window.location?.hash || ""
}

export function location_search() {
  if (typeof window === "undefined") return ""
  return window.location?.search || ""
}

export function location_query_param(name) {
  if (typeof window === "undefined") return ""
  try {
    const search = window.location?.search || ""
    const params = new URLSearchParams(search)
    return params.get(String(name)) || ""
  } catch {
    return ""
  }
}

export function local_storage_get(key) {
  if (typeof window === "undefined") return ""
  try {
    return window.localStorage?.getItem(String(key)) || ""
  } catch {
    return ""
  }
}

export function local_storage_set(key, value) {
  if (typeof window === "undefined") return undefined
  try {
    window.localStorage?.setItem(String(key), String(value))
  } catch {
    // ignore
  }
  return undefined
}

export function history_push_state(path) {
  if (typeof window === "undefined") return undefined
  try {
    window.history?.pushState(null, "", String(path))
  } catch {
    // ignore
  }
  return undefined
}

export function history_replace_state(path) {
  if (typeof window === "undefined") return undefined
  try {
    window.history?.replaceState(null, "", String(path))
  } catch {
    // ignore
  }
  return undefined
}

export function set_document_title(title) {
  if (typeof document === "undefined") return undefined
  try {
    document.title = String(title)
  } catch {
    // ignore
  }
  return undefined
}

export function register_popstate(callback) {
  if (typeof window === "undefined") return undefined
  try {
    window.addEventListener("popstate", () => callback(undefined))
  } catch {
    // ignore
  }
  return undefined
}

export function focus_element(id) {
  if (typeof document === "undefined") return undefined
  const el = document.getElementById(String(id))
  if (!el) return undefined
  try {
    el.focus()
  } catch {
    // ignore
  }
  return undefined
}

function is_editable_element(el) {
  if (!el) return false
  if (el.isContentEditable) return true
  const tag = String(el.tagName || "").toLowerCase()
  return tag === "input" || tag === "textarea" || tag === "select"
}

export function register_keydown(callback) {
  if (typeof window === "undefined") return undefined
  try {
    window.addEventListener("keydown", (event) => {
      const key = String(event.key || "").toLowerCase()
      const ctrl = Boolean(event.ctrlKey)
      const meta = Boolean(event.metaKey)
      const shift = Boolean(event.shiftKey)
      const is_editing = is_editable_element(event.target)
      const modal_open = Boolean(document.querySelector(".modal"))

      // Prevent browser defaults for our shortcuts, but only when we're not
      // typing and no modal is open (story: ignore shortcuts in those cases).
      if (!is_editing && !modal_open) {
        const cmd = ctrl || meta
        const is_toggle_filters = cmd && shift && key === "f"
        const is_focus_search = cmd && key === "k"
        const is_new_task = !cmd && !shift && key === "n"

        if (is_toggle_filters || is_focus_search || is_new_task) {
          event.preventDefault()
        }
      }

      callback([key, ctrl, meta, shift, is_editing, modal_open])
    })
  } catch {
    // ignore
  }
  return undefined
}

// Quick date range helpers for metrics
function formatDate(d) {
  return d.toISOString().split('T')[0]
}

export function date_today() {
  return formatDate(new Date())
}

export function date_days_ago(days) {
  const d = new Date()
  d.setDate(d.getDate() - days)
  return formatDate(d)
}
