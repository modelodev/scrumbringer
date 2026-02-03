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
