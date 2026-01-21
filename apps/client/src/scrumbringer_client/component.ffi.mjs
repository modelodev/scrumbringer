// FFI for Lustre Component utilities
//
// Provides JavaScript interop for custom element event emission.

/**
 * Emit a custom event from a Lustre component.
 *
 * Tries multiple strategies to find the component element:
 * 1. Lustre's global __LUSTRE_CURRENT_COMPONENT__ (set during render/update)
 * 2. Fallback to document.querySelector for known component tags
 *
 * @param {string} name - Event name (e.g., "close-requested")
 * @param {any} detail - Event detail payload (JSON-serializable)
 */
export function emit_custom_event(name, detail) {
  // Strategy 1: Use Lustre's global (works during render/update cycle)
  let component = globalThis.__LUSTRE_CURRENT_COMPONENT__

  // Strategy 2: Fallback to querySelector for known component tags
  // This works for effects that run outside the render cycle
  if (!component || !component.dispatchEvent) {
    // List of known Lustre component tag names in this app
    const knownComponents = ['card-detail-modal', 'card-crud-dialog', 'workflow-crud-dialog', 'task-template-crud-dialog', 'rule-crud-dialog']

    for (const tag of knownComponents) {
      const el = document.querySelector(tag)
      if (el && el.dispatchEvent) {
        component = el
        break
      }
    }
  }

  if (!component || !component.dispatchEvent) {
    console.warn(`[component.ffi] Cannot emit "${name}": no component found`)
    return
  }

  const event = new CustomEvent(name, {
    bubbles: true,
    composed: true,
    detail: detail,
  })

  component.dispatchEvent(event)
}
