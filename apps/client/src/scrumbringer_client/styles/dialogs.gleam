//// Auto-split CSS chunk: dialogs

/// Provides dialogs CSS chunk.
pub fn css() -> List(String) {
  [
    // STORY 3.5 - Unified Dialog System
    // =====================================================
    // Dialog overlay
    ".dialog-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; padding: 16px; z-index: 1000; animation: dialog-fade-in 0.2s ease; }",
    "@keyframes dialog-fade-in { from { opacity: 0; } to { opacity: 1; } }",
    // Dialog container
    ".dialog { position: relative; background: var(--sb-surface-1); border: 1px solid var(--sb-border); border-radius: 18px; overflow: hidden; padding: 0; max-height: calc(100vh - 32px); display: flex; flex-direction: column; box-shadow: var(--sb-shadow-modal); animation: dialog-scale-in 0.2s ease; }",
    // Keep dropdowns visible when a picker is open inside dialog
    ".dialog.dialog-color-picker-open { overflow: visible; }",
    "@keyframes dialog-scale-in { from { opacity: 0; transform: scale(0.95); } to { opacity: 1; transform: scale(1); } }",
    // Dialog sizes
    ".dialog-sm { width: min(400px, 100%); }",
    ".dialog-md { width: min(520px, 100%); }",
    ".dialog-lg { width: min(680px, 100%); }",
    ".dialog-lg-tight { width: min(620px, 100%); }",
    ".dialog-xl { width: min(860px, 100%); }",
    // Dialog header
    ".dialog-header { display: flex; align-items: center; justify-content: space-between; padding: 16px 20px; border-bottom: 1px solid var(--sb-border); background: var(--sb-surface-2); }",
    ".dialog-title { display: flex; align-items: center; gap: 10px; }",
    ".dialog-title h3 { margin: 0; font-size: 18px; font-weight: 600; }",
    ".dialog-icon { font-size: 20px; }",
    ".dialog-close { display: inline-flex; align-items: center; justify-content: center; width: 40px; height: 40px; border: none; background: transparent; color: var(--sb-muted); cursor: pointer; border-radius: 10px; font-size: 18px; line-height: 1; }",
    ".dialog-close:hover { background: var(--sb-hover); color: var(--sb-text); }",
    // Dialog body
    ".dialog-body { padding: 20px; overflow-y: auto; flex: 1; background: var(--sb-surface-1); }",
    // Story 4.8 UX: Allow color picker dropdown to overflow dialog-body when open
    ".dialog-body:has(.color-picker.open) { overflow: visible; }",
    // Dialog error
    ".dialog-error { display: flex; align-items: center; gap: 8px; padding: 10px 16px; background: color-mix(in oklab, var(--sb-danger) 10%, var(--sb-surface)); border: 1px solid color-mix(in oklab, var(--sb-danger) 30%, var(--sb-border)); border-radius: 10px; margin: 0 20px 0 20px; margin-top: -4px; color: var(--sb-danger); font-size: 14px; }",
    // Dialog footer
    ".dialog-footer { display: flex; justify-content: flex-end; gap: 12px; padding: 12px 20px; border-top: 1px solid var(--sb-border); background: var(--sb-surface-2); }",
    ".dialog-footer .btn-compact { padding-left: 14px; padding-right: 14px; }",
    // Add button (for opening dialogs)
    ".btn-add { display: inline-flex; align-items: center; gap: 6px; padding: 10px 16px; background: var(--sb-primary); color: var(--sb-inverse); border: none; border-radius: 10px; font-weight: 500; cursor: pointer; transition: background 0.2s, transform 0.1s; }",
    ".btn-add:hover { background: var(--sb-primary-hover); }",
    ".btn-add:active { transform: scale(0.98); }",
    ".btn-add::before { content: '+'; font-weight: 700; font-size: 1.1em; }",
    // Admin section header with action button (Story 4.8 UX: consistent height)
    ".admin-section-header-wrapper { margin-bottom: 16px; }",
    ".admin-section-header { display: flex; align-items: center; justify-content: space-between; min-height: 44px; padding-bottom: 12px; border-bottom: 1px solid var(--sb-border); }",
    ".admin-section-title { display: flex; align-items: center; gap: 8px; font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; color: var(--sb-muted); }",
    ".admin-section-icon { font-size: 16px; }",
    ".admin-section-action { display: flex; align-items: center; }",
    ".admin-section-subtitle { margin: 12px 0 0 0; padding: 10px 14px; font-size: 13px; line-height: 1.5; color: var(--sb-muted); background: var(--sb-elevated); border-radius: 8px; border-left: 3px solid var(--sb-primary); }",
    // Story 4.8 AC25: Unified vertical layout for capability checklists
    ".capabilities-checklist, .members-checklist { display: flex; flex-direction: column; gap: 8px; max-height: 300px; overflow-y: auto; padding: 4px 0; }",
    ".capabilities-checklist .checkbox-label, .members-checklist .checkbox-label { display: flex; align-items: center; gap: 10px; padding: 8px 12px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 8px; cursor: pointer; transition: all 0.15s ease; }",
    ".capabilities-checklist .checkbox-label:hover, .members-checklist .checkbox-label:hover { background: var(--sb-hover); border-color: var(--sb-primary); }",
    ".capabilities-checklist input[type='checkbox'], .members-checklist input[type='checkbox'] { width: 18px; height: 18px; accent-color: var(--sb-primary); cursor: pointer; }",
    ".capabilities-checklist .capability-name, .members-checklist .member-name, .members-checklist .member-email { font-size: 14px; font-weight: 500; }",
    // Story 4.8 UX: Table column alignment
    // Note: Never use display:flex on td elements - it breaks table-cell borders
    ".col-number, .cell-number { text-align: right; width: 80px; }",
    "th.col-actions, td.cell-actions { text-align: right; white-space: nowrap; padding-right: 12px; }",
    ".cell-actions .btn-icon { margin-left: 8px; }",
    ".cell-actions .btn-icon:first-child { margin-left: 0; }",
    ".count-badge { display: inline-block; min-width: 28px; height: 24px; line-height: 22px; padding: 0 8px; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 6px; font-size: 13px; font-weight: 600; color: var(--sb-muted); text-align: center; vertical-align: middle; box-sizing: border-box; }",
    ".claimed-badge { min-width: 28px; padding: 2px 8px; border-radius: 999px; font-weight: 600; font-size: 12px; line-height: 1; text-align: center; background: #eaf1ff; color: #1e3a8a; }",
    ".release-btn { width: 28px; height: 28px; }",
    ".btn-danger-icon { color: var(--sb-danger); }",
    ".btn-danger-icon:hover { background: color-mix(in oklab, var(--sb-danger) 15%, transparent); }",
    // UX: Cards config improvements (Sally UX review)
    // Inline filters layout
    ".filters-inline { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; }",
    ".filters-inline .filter-group { margin-bottom: 0; }",
    ".filters-inline .filter-search { flex: 1; min-width: 150px; max-width: 250px; }",
    // Card title with color dot
    ".card-title-with-color { display: flex; align-items: center; gap: 10px; }",
    ".card-title-button { background: none; border: none; padding: 0; color: inherit; font: inherit; cursor: pointer; text-align: left; }",
    ".card-title-button:hover { color: var(--sb-primary); text-decoration: underline; }",
    ".card-color-dot { width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; border: 1px solid color-mix(in oklab, currentColor 20%, transparent); }",
    // State badges with semantic colors
    ".state-badge { display: inline-flex; align-items: center; gap: 4px; padding: 2px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }",
    ".state-badge::before { content: ''; width: 6px; height: 6px; border-radius: 50%; }",
    ".state-pending { background: color-mix(in oklab, var(--sb-warning) 15%, transparent); color: var(--sb-warning); }",
    ".state-pending::before { background: var(--sb-warning); }",
    ".state-active { background: color-mix(in oklab, var(--sb-info) 15%, transparent); color: var(--sb-info); }",
    ".state-active::before { background: var(--sb-info); }",
    ".state-completed { background: color-mix(in oklab, var(--sb-success) 15%, transparent); color: var(--sb-success); }",
    ".state-completed::before { background: var(--sb-success); }",
    // Mini progress bar for cards table
    ".card-progress-cell { display: flex; align-items: center; gap: 8px; }",
    ".progress-bar-mini { width: 60px; height: 6px; background: var(--sb-border); border-radius: 3px; overflow: hidden; }",
    ".progress-fill-mini { height: 100%; background: var(--sb-success); transition: width 0.3s ease; }",
    ".progress-text-mini { font-size: 12px; color: var(--sb-muted); font-variant-numeric: tabular-nums; }",
    // Responsive dialog
    "@media (max-width: 640px) { .dialog { max-height: 100vh; border-radius: 0; } .dialog-overlay { padding: 0; } .dialog-sm, .dialog-md, .dialog-lg, .dialog-xl { width: 100%; height: 100%; } .dialog-body { padding: 16px; } .dialog-header, .dialog-footer { padding: 12px 16px; } }",
    // =============================================================================
  ]
}
