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
