//// Auto-split CSS chunk: notes

/// Provides notes CSS chunk.
pub fn css() -> List(String) {
  [
    // Notes List (Story 5.3 - Card Notes)
    // =============================================================================
    ".notes-list { display: flex; flex-direction: column; gap: 12px; }",
    ".note-item { padding: 12px; background: var(--sb-bg); border: 1px solid var(--sb-border); border-radius: 8px; }",
    ".note-header { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; font-size: 12px; }",
    ".note-author { font-weight: 500; color: var(--sb-text); }",
    ".note-date { color: var(--sb-muted); }",
    ".note-header .btn-xs { margin-left: auto; opacity: 0; transition: opacity 0.15s; }",
    ".note-item:hover .note-header .btn-xs { opacity: 1; }",
    ".note-content { margin: 0; font-size: 14px; line-height: 1.5; color: var(--sb-text); white-space: pre-wrap; }",
    // Story 5.4 - Link Detection in Notes
    // AC3: Notes with PR links highlighted with green border
    ".note-delivery { border-color: var(--sb-success); border-width: 2px; }",
    // AC1: Generic links are clickable
    ".note-link { color: var(--sb-link); text-decoration: none; word-break: break-all; }",
    ".note-link:hover { text-decoration: underline; }",
    // AC2: GitHub links show icon and short path
    ".github-link { display: inline-flex; align-items: center; gap: 2px; }",
    ".github-link .nav-icon { color: var(--sb-muted); }",
    // AC20: CSS-only tooltip for author info
    ".tooltip-trigger { position: relative; cursor: help; }",
    ".tooltip-trigger[data-tooltip]::after { content: attr(data-tooltip); display: none; position: absolute; left: 0; top: calc(100% + 4px); background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 6px; padding: 4px 8px; font-size: 11px; color: var(--sb-text); white-space: nowrap; z-index: 10; box-shadow: 0 2px 8px rgba(0,0,0,0.15); }",
    ".tooltip-trigger[data-tooltip]:hover::after { display: block; }",
  ]
}
