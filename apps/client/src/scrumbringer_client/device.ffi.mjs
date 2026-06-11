export function is_mobile() {
  if (typeof window === "undefined") return false
  const width = Number(window.innerWidth || 0)
  const height = Number(window.innerHeight || 0)
  if (width <= 0 || height <= 0) return false

  const narrow = width <= 640
  const shortLandscape = height <= 480 && width <= 1024

  return narrow || shortLandscape
}

export function navigator_language() {
  if (typeof navigator === "undefined") return ""
  const value = navigator.language || navigator.userLanguage || ""
  return value == null ? "" : String(value)
}
