//// Auto-split CSS chunk: notes

/// Provides notes CSS chunk.
pub fn css() -> List(String) {
  [
    // Notes List (Story 5.3 - Card Notes)
    // =============================================================================
    ".notes-list { display: flex; flex-direction: column; gap: 12px; }",
    ".note-item { padding: 12px; background: var(--sb-bg); border: 1px solid var(--sb-border); border-radius: 8px; }",
    ".note-header { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; font-size: var(--sb-font-sm); }",
    ".note-author { font-weight: var(--sb-weight-medium); color: var(--sb-text); }",
    ".note-date { color: var(--sb-muted); }",
    ".note-header .btn-xs { margin-left: auto; opacity: 0; transition: opacity 0.15s; }",
    ".note-item:hover .note-header .btn-xs { opacity: 1; }",
    ".note-content { margin: 0; font-size: var(--sb-font-md); line-height: var(--sb-line-body); color: var(--sb-text); white-space: pre-wrap; max-width: var(--sb-measure-prose); }",
    // Story 5.4 - Link Detection in Notes
    // AC3: Notes with PR links highlighted with green border
    ".note-delivery { border-color: var(--sb-success); border-width: 2px; }",
    // AC1: Generic links are clickable
    ".note-link { color: var(--sb-link); text-decoration: none; word-break: break-all; }",
    ".note-link:hover { text-decoration: underline; }",
    // AC2: GitHub links show icon and short path
    ".github-link { display: inline-flex; align-items: center; gap: 2px; }",
    ".github-link .nav-icon { color: var(--sb-muted); }",
    // Pinned context
    ".pinned-context { display: flex; flex-direction: column; gap: 8px; padding: 10px 0; }",
    ".pinned-context-title { margin: 0; font-size: var(--sb-font-sm); font-weight: var(--sb-weight-semibold); color: var(--sb-muted); letter-spacing: 0.03em; text-transform: uppercase; }",
    ".pinned-context-list { display: flex; flex-direction: column; gap: 6px; list-style: none; margin: 0; padding: 0; }",
    ".pinned-context-item { padding: 8px 10px; border: 1px solid var(--sb-border); border-radius: 8px; background: var(--sb-bg); color: var(--sb-text); font-size: var(--sb-font-sm); line-height: var(--sb-line-body); white-space: pre-wrap; }",
    ".pinned-context-more { align-self: flex-start; border: 1px solid var(--sb-border); border-radius: 8px; background: var(--sb-surface); color: var(--sb-link); font-size: var(--sb-font-sm); font-weight: var(--sb-weight-medium); padding: 5px 8px; cursor: pointer; }",
    ".pinned-context-more:hover { background: var(--sb-bg); }",
    ".pinned-context-more:focus-visible { outline: 2px solid var(--sb-focus-ring); outline-offset: 2px; }",
    // AC20: CSS-only tooltip for author info
    ".tooltip-trigger { position: relative; cursor: help; }",
    ".tooltip-trigger[data-tooltip]::after { content: attr(data-tooltip); display: none; position: absolute; left: 0; top: calc(100% + 4px); background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 6px; padding: 4px 8px; font-size: var(--sb-font-xs); color: var(--sb-text); white-space: nowrap; z-index: 10; box-shadow: 0 2px 8px rgba(0,0,0,0.15); }",
    ".tooltip-trigger[data-tooltip]:hover::after { display: block; }",
  ]
}
