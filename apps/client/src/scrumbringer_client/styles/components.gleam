//// Auto-split CSS chunk: components

/// Provides components CSS chunk.
pub fn css() -> List(String) {
  [
    ".toast { position: fixed; top: 12px; left: 50%; transform: translateX(-50%); background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 999px; padding: 8px 12px; color: var(--sb-text); box-shadow: 0 6px 24px rgba(0, 0, 0, 0.15); display: flex; gap: 8px; align-items: center; max-width: calc(100vw - 24px); z-index: 50; }",
    ".toast span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 60vw; }",
    ".toast-dismiss { padding: 2px 8px; line-height: 1; }",
    ".icon-row { display: flex; gap: 8px; align-items: center; }",
    ".icon-preview { width: 32px; height: 32px; border: 1px solid var(--sb-border); border-radius: 10px; display: flex; align-items: center; justify-content: center; background: var(--sb-elevated); }",
    // Icon picker grid styles
    ".icon-picker { display: flex; flex-direction: column; gap: 12px; margin-top: 0; }",
    ".form-control { min-height: 40px; padding: 8px 12px; border: 1px solid var(--sb-border); border-radius: 8px; background: var(--sb-surface); font-size: 14px; }",
    ".form-control:focus { outline: none; border-color: var(--sb-primary); box-shadow: 0 0 0 2px color-mix(in oklab, var(--sb-primary) 20%, transparent); }",
    ".icon-picker-trigger { display: inline-flex; align-items: center; justify-content: space-between; gap: 10px; width: 100%; }",
    ".icon-picker-trigger svg { width: 18px; height: 18px; }",
    ".icon-picker-trigger-left { display: inline-flex; align-items: center; gap: 8px; }",
    ".icon-picker-placeholder { font-size: 13px; color: var(--sb-muted); }",
    ".icon-picker-caret { color: var(--sb-muted); }",
    ".icon-picker-trigger:hover { border-color: var(--sb-primary); }",
    ".icon-picker-search { margin-bottom: 4px; }",
    ".icon-picker-search input { width: 100%; }",
    ".icon-picker-tabs { display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 8px; padding-bottom: 8px; border-bottom: 1px solid var(--sb-border); }",
    ".icon-picker-tab { padding: 6px 12px; font-size: 12px; border-radius: 8px; background: var(--sb-elevated); border: 1px solid var(--sb-border); cursor: pointer; transition: all 0.15s; }",
    ".icon-picker-tab:hover { border-color: var(--sb-primary); }",
    ".icon-picker-tab.active { background: color-mix(in oklab, var(--sb-primary) 15%, var(--sb-elevated)); border-color: var(--sb-primary); color: var(--sb-primary); font-weight: 600; }",
    ".icon-picker-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(80px, 1fr)); gap: 6px; max-height: 240px; overflow-y: auto; padding: 4px; }",
    ".icon-picker-item { display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 8px 4px; border: 1px solid var(--sb-border); border-radius: 10px; background: var(--sb-elevated); cursor: pointer; transition: all 0.15s; }",
    ".icon-picker-item:hover { border-color: var(--sb-primary); background: color-mix(in oklab, var(--sb-primary) 8%, var(--sb-elevated)); }",
    ".icon-picker-item.selected { border-color: var(--sb-primary); background: color-mix(in oklab, var(--sb-primary) 15%, var(--sb-elevated)); box-shadow: 0 0 0 2px color-mix(in oklab, var(--sb-primary) 30%, transparent); }",
    ".icon-picker-icon { display: flex; align-items: center; justify-content: center; }",
    ".icon-picker-label { font-size: 10px; color: var(--sb-muted); text-align: center; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 100%; }",
    ".icon-picker-empty { padding: 24px; text-align: center; color: var(--sb-muted); font-style: italic; }",
    // Icon preview for selected icon
    ".icon-preview-selected { display: flex; align-items: center; gap: 12px; padding: 12px 16px; background: color-mix(in oklab, var(--sb-primary) 8%, var(--sb-elevated)); border: 1px solid color-mix(in oklab, var(--sb-primary) 30%, var(--sb-border)); border-radius: 10px; margin-bottom: 12px; }",
    ".icon-preview-name { font-weight: 500; font-family: ui-monospace, monospace; font-size: 13px; color: var(--sb-text); }",
    // Icon theme class for dark mode
    ".icon-theme-dark svg { filter: invert(1); }",
  ]
}
