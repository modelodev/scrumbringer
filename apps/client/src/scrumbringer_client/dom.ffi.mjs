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
