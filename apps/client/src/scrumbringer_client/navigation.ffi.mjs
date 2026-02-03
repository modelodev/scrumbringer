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
