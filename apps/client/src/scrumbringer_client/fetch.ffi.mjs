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
  const init = {
    method,
    headers: Object.fromEntries(headers),
    credentials: "same-origin",
  }

  const m = String(method || "").trim().toUpperCase()
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

export function element_client_offset(id) {
  if (typeof document === "undefined") return [0, 0]
  const el = document.getElementById(id)
  if (!el) return [0, 0]
  const rect = el.getBoundingClientRect()
  return [Math.round(rect.left), Math.round(rect.top)]
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

export function register_popstate(callback) {
  if (typeof window === "undefined") return undefined
  try {
    window.addEventListener("popstate", () => callback(undefined))
  } catch {
    // ignore
  }
  return undefined
}
