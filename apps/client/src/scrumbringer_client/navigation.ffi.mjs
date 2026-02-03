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
