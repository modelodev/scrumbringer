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
      // Check for dialogs too - Lustre components with shadow DOM may not
      // expose their internal textarea as the event target
      const modal_open = Boolean(
        document.querySelector(".modal") ||
        document.querySelector(".dialog-overlay")
      )

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
