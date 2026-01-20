// FFI for Lustre Component utilities
//
// Provides JavaScript interop for custom element event emission.

/**
 * Emit a custom event from the current Lustre component.
 *
 * This uses the global `__LUSTRE_CURRENT_COMPONENT__` which Lustre sets
 * during component rendering/update cycles.
 *
 * @param {string} name - Event name (e.g., "close-requested")
 * @param {any} detail - Event detail payload (JSON-serializable)
 */
export function emit_custom_event(name, detail) {
  // Lustre components set this global during render/update
  const component = globalThis.__LUSTRE_CURRENT_COMPONENT__

  if (!component || !component.dispatchEvent) {
    console.warn(`[component.ffi] Cannot emit "${name}": no component context`)
    return
  }

  const event = new CustomEvent(name, {
    bubbles: true,
    composed: true,
    detail: detail,
  })

  component.dispatchEvent(event)
}
