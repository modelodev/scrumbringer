//// CSS style definitions for Scrumbringer UI.
////
//// Generates all base CSS rules as strings for injection into the page.
//// Includes layout, typography, forms, buttons, and theme variables.

import gleam/string

/// Provides base css.
///
/// Example:
///   base_css(...)
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn base_css() -> String {
  [
    ":root { color-scheme: light dark; }",
    "* { box-sizing: border-box; }",
    "body { margin: 0; font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; background: var(--sb-bg); color: var(--sb-text); }",
    ".app { min-height: 100vh; background: var(--sb-bg); color: var(--sb-text); padding: 16px; }",
    ".page { max-width: 480px; margin: 0 auto; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 16px; }",
    ".admin, .member { display: flex; flex-direction: column; gap: 12px; }",
    ".body { display: flex; gap: 12px; align-items: flex-start; }",
    ".nav { width: 220px; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 8px; }",
    ".content { flex: 1; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; min-width: 0; }",
    ".content.pool-main { overflow: hidden; min-height: 520px; }",
    ".pool-layout { display: flex; gap: 12px; align-items: flex-start; width: 100%; }",
    ".pool-main { flex: 1 1 auto; min-width: 0; position: relative; overflow: hidden; }",
    ".pool-right { width: 360px; flex-shrink: 0; position: relative; z-index: 2; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 10px; align-self: stretch; }
.pool-my-tasks-dropzone { border: 1px dashed transparent; border-radius: 12px; padding: 8px; transition: border-color 120ms ease, background 120ms ease; min-height: 120px; }
.pool-my-tasks-dropzone.drag-active { border-color: var(--sb-border); background: color-mix(in oklab, var(--sb-elevated) 70%, transparent); }
.pool-my-tasks-dropzone.drop-over { border-color: var(--sb-primary); background: color-mix(in oklab, var(--sb-primary) 12%, var(--sb-elevated)); }
.dropzone-hint { font-size: 12px; color: var(--sb-muted); margin-bottom: 6px; }",
    "@media (max-width: 1280px) { .pool-right { width: 320px; } }
@media (max-width: 1024px) { .pool-layout { flex-direction: column; } .pool-right { width: 100%; } }",
    // Pool unified toolbar (Story 4.8 - simplified)
    ".pool-toolbar { display: flex; align-items: center; gap: 12px; padding: 8px 0; margin-bottom: 12px; }",
    ".pool-toolbar-minimal { justify-content: flex-end; }",
    ".pool-toolbar-spacer { flex: 1; }",
    ".pool-toolbar-left { display: flex; gap: 4px; }",
    ".pool-toolbar-center { flex: 1; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }",
    ".pool-toolbar-right { display: flex; gap: 4px; }",
    ".btn-filter-toggle { position: relative; }",
    ".btn-filter-toggle.has-active { border-color: var(--sb-accent); }",
    ".filter-count-badge { display: inline-flex; align-items: center; justify-content: center; min-width: 16px; height: 16px; padding: 0 4px; margin-left: 4px; background: var(--sb-accent); color: var(--sb-bg); border-radius: 8px; font-size: 10px; font-weight: 600; }",
    ".pool-inline-filters { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }",
    ".pool-inline-filters .filter-select { height: 28px; padding: 4px 8px; font-size: 12px; min-width: 100px; max-width: 140px; }",
    ".pool-inline-filters .filter-search { height: 28px; padding: 4px 8px; font-size: 12px; width: 120px; }",
    ".pool-inline-filters .btn-xs { height: 28px; padding: 4px 8px; }",
    ".pool-inline-filters .btn-clear { padding: 4px 6px; font-size: 11px; color: var(--sb-muted); }",
    ".pool-inline-filters .btn-clear:hover { color: var(--sb-danger); border-color: var(--sb-danger); }",
    "@media (max-width: 768px) { .pool-toolbar { flex-wrap: wrap; } .pool-toolbar-center { order: 3; width: 100%; } }",
    ".topbar { display: flex; align-items: center; gap: 12px; justify-content: space-between; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; }",
    ".topbar-title { font-weight: 700; }",
    ".topbar-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }",
    ".topbar-group { display: inline-flex; align-items: center; gap: 8px; }",
    // H01-H03: Settings group in topbar
    ".topbar-settings-group { display: inline-flex; align-items: center; gap: 4px; padding: 4px 8px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 10px; }",
    ".theme-switch { display: inline-flex; align-items: center; gap: 8px; }",
    ".user { color: var(--sb-muted); }",
    ".section { display: flex; flex-direction: column; gap: 10px; }",
    ".field { display: flex; flex-direction: column; gap: 4px; margin: 8px 0; }",
    ".filters-row { display: flex; gap: 10px; align-items: stretch; flex-wrap: nowrap; overflow-x: auto; padding-bottom: 2px; }",
    ".filters-row .field { margin: 0; min-width: 140px; position: relative; }",
    ".filters-row .field.filter-q { min-width: 180px; }",
    ".filters-row .filter-icon { display: none; font-size: 12px; color: var(--sb-muted); }",
    ".filters-row select, .filters-row input, .filters-row button { height: 36px; }",
    ".filters-row button { padding: 8px 12px; }",
    ".filters-row .filter-tooltip { display: none; position: absolute; left: 0; top: -26px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 999px; padding: 2px 8px; font-size: 12px; color: var(--sb-text); white-space: nowrap; }",
    "@media (max-width: 1024px) { .filters-row { gap: 8px; } .filters-row .filter-label { display: none; } .filters-row .filter-icon { display: inline; } .filters-row .field { min-width: 56px; } .filters-row select, .filters-row input { padding: 6px; } .filters-row .field:hover .filter-tooltip, .filters-row .field:focus-within .filter-tooltip { display: inline-flex; } }",
    ".filter-actions { display: flex; align-items: center; gap: 8px; margin-left: auto; }",
    ".filter-badge { display: inline-flex; align-items: center; justify-content: center; min-width: 20px; height: 20px; padding: 0 6px; background: var(--sb-accent); color: var(--sb-bg); border-radius: 10px; font-size: 12px; font-weight: 600; }",
    ".btn-clear-filters { font-size: 12px; padding: 4px 10px !important; height: 28px !important; }",
    ".hint { color: var(--sb-muted); font-size: 0.9em; }",
    ".empty { color: var(--sb-muted); }",
    ".loading { color: var(--sb-info); }",
    ".error { color: var(--sb-danger); }",
    "input, select, textarea { padding: 8px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-elevated); color: var(--sb-text); font-family: inherit; }",
    "button { padding: 8px 12px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-elevated); color: var(--sb-text); cursor: pointer; }",
    ".btn-xs { padding: 4px 8px; font-size: 12px; border-radius: 8px; }",
    ".btn-active { border-color: var(--sb-primary); }",
    ".btn-icon { display: inline-flex; align-items: center; justify-content: center; min-width: 28px; min-height: 28px; line-height: 1; position: relative; }",
    ".btn-icon[data-tooltip]::after { content: attr(data-tooltip); display: none; position: absolute; right: 0; top: -28px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 999px; padding: 2px 8px; font-size: 12px; color: var(--sb-text); white-space: nowrap; }",
    ".btn-icon[data-tooltip]:hover::after, .btn-icon[data-tooltip]:focus-visible::after { display: inline-flex; }",
    "button:hover { border-color: var(--sb-primary); }",
    "button:disabled { opacity: 0.6; cursor: not-allowed; }",
    "button[type=\"submit\"] { background: var(--sb-primary); border-color: var(--sb-primary); color: var(--sb-inverse); }",
    "button[type=\"submit\"]:hover { background: var(--sb-primary-hover); border-color: var(--sb-primary-hover); }",
    "a { color: var(--sb-link); }",
    "a:hover { text-decoration: underline; }",
    ":focus-visible { outline: 3px solid var(--sb-focus-ring); outline-offset: 2px; }",
    ".table { width: 100%; border-collapse: collapse; }",
    ".table th { text-align: left; color: var(--sb-muted); font-weight: 600; font-size: 12px; text-transform: uppercase; letter-spacing: 0.03em; padding: 10px 12px; border-bottom: 2px solid var(--sb-border); background: var(--sb-surface); }",
    ".table td { padding: 10px 12px; border-bottom: 1px solid var(--sb-border); vertical-align: middle; }",
    ".table tbody tr:nth-child(even) { background: color-mix(in oklab, var(--sb-surface) 50%, var(--sb-bg)); }",
    ".table tbody tr:hover { background: var(--sb-elevated); }",
    // Expansion rows for subtables
    ".expansion-row { background: var(--sb-surface) !important; }",
    ".expansion-row:hover { background: var(--sb-surface) !important; }",
    ".expansion-content { padding: 8px 0 8px 24px; border-left: 3px solid var(--sb-primary); margin-left: 8px; }",
    ".expansion-content .table { background: var(--sb-elevated); border-radius: 8px; overflow: hidden; }",
    ".expansion-content .table th { background: var(--sb-surface); font-size: 11px; padding: 8px 10px; }",
    ".expansion-content .table td { padding: 8px 10px; font-size: 14px; }",
    // Story 4.10: Expandable rules table with template attachment
    ".rules-expandable-table { }",
    ".col-expand { width: 40px; text-align: center; }",
    ".cell-expand { text-align: center; }",
    ".btn-expand { background: transparent; border: none; padding: 4px 8px; cursor: pointer; font-size: 12px; color: var(--sb-muted); border-radius: 4px; }",
    ".btn-expand:hover { background: var(--sb-elevated); color: var(--sb-text); }",
    ".cell-templates { text-align: center; }",
    ".badge { display: inline-flex; align-items: center; justify-content: center; min-width: 24px; height: 20px; padding: 0 6px; border-radius: 10px; font-size: 12px; font-weight: 600; }",
    ".badge-empty { background: var(--sb-surface); color: var(--sb-muted); border: 1px solid var(--sb-border); }",
    ".badge-count { background: color-mix(in oklab, var(--sb-primary) 15%, var(--sb-elevated)); color: var(--sb-primary); border: 1px solid color-mix(in oklab, var(--sb-primary) 40%, var(--sb-border)); }",
    // Templates expansion panel
    ".templates-expansion { padding: 12px 16px; background: var(--sb-surface); border-radius: 8px; margin: 4px 8px 4px 40px; border-left: 3px solid var(--sb-primary); }",
    ".templates-header { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 12px; }",
    ".templates-title { font-weight: 600; font-size: 13px; color: var(--sb-text); }",
    ".templates-empty { color: var(--sb-muted); font-size: 13px; font-style: italic; padding: 8px 0; }",
    ".templates-list { display: flex; flex-direction: column; gap: 6px; }",
    ".template-item { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 8px 12px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 8px; }",
    ".template-name { font-size: 13px; font-weight: 500; }",
    ".template-item .btn-danger { padding: 2px 8px; font-size: 14px; line-height: 1; border-radius: 4px; }",
    ".template-item .detaching { font-size: 12px; color: var(--sb-muted); font-style: italic; }",
    // Story 4.10: AC2 - Clickable rule rows
    ".rule-row-expandable { cursor: pointer; transition: background 0.1s ease; }",
    ".rule-row-expandable:hover { background: var(--sb-elevated); }",
    ".rule-row-expandable:focus-visible { outline: 2px solid var(--sb-primary); outline-offset: -2px; }",
    ".rule-row-expanded { background: var(--sb-surface); }",
    // AC2: Prevent row click on actions column
    ".cell-no-expand { pointer-events: auto; }",
    ".cell-no-expand * { position: relative; z-index: 1; }",
    // Story 4.10: AC5 - Expand icon (triangles)
    ".rule-expand-icon { display: inline-flex; align-items: center; justify-content: center; font-size: 12px; color: var(--sb-muted); width: 16px; }",
    // Story 4.10: AC6-8 - Status indicators
    ".cell-status { text-align: center; width: 50px; }",
    ".rule-complete-indicator { color: var(--sb-success); }",
    ".rule-incomplete-indicator { color: var(--sb-warning); cursor: help; }",
    ".rule-inactive-indicator { color: var(--sb-muted); }",
    // Resource type cell with task type info
    ".cell-resource-type { white-space: nowrap; }",
    ".resource-type-task { display: inline-flex; align-items: center; }",
    ".resource-type-separator { color: var(--sb-muted); margin: 0 2px; }",
    ".task-type-inline { display: inline-flex; align-items: center; vertical-align: middle; }",
    ".task-type-inline svg { width: 14px; height: 14px; }",
    // Story 4.10: AC4 - Attached template row with icon and priority
    ".attached-template-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 8px 12px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 8px; }",
    ".attached-template-info { display: flex; align-items: center; gap: 8px; }",
    ".template-type-icon { display: inline-flex; opacity: 0.8; }",
    ".attached-template-name { font-size: 13px; font-weight: 500; }",
    ".attached-template-meta { display: flex; align-items: center; gap: 8px; }",
    ".priority-badge { font-size: 11px; font-weight: 600; color: var(--sb-muted); background: var(--sb-surface); padding: 2px 8px; border-radius: 4px; }",
    // Story 4.10: AC13 - Empathetic empty hint
    ".templates-empty-hint { display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 16px 12px; text-align: center; color: var(--sb-muted); }",
    ".templates-empty-hint .hint-icon { color: var(--sb-primary); opacity: 0.6; }",
    ".templates-empty-hint p { margin: 0; font-size: 13px; line-height: 1.5; }",
    // Story 4.10: AC12 - Radio buttons in modal
    ".radio-group { display: flex; flex-direction: column; gap: 6px; max-height: 240px; overflow-y: auto; }",
    ".template-radio-list { margin-bottom: 12px; }",
    ".radio-option { display: flex; align-items: center; gap: 10px; padding: 10px 12px; border-radius: 8px; border: 1px solid var(--sb-border); background: var(--sb-surface); cursor: pointer; transition: all 0.1s ease; }",
    ".radio-option:hover { border-color: var(--sb-primary); background: var(--sb-elevated); }",
    ".radio-option.selected { border-color: var(--sb-primary); background: color-mix(in oklab, var(--sb-primary) 10%, var(--sb-elevated)); }",
    ".radio-option input[type=radio] { width: 16px; height: 16px; margin: 0; accent-color: var(--sb-primary); cursor: pointer; }",
    ".radio-label { display: flex; align-items: center; gap: 8px; flex: 1; cursor: pointer; }",
    ".radio-label .template-name { font-size: 14px; font-weight: 500; flex: 1; }",
    ".radio-label .template-priority { font-size: 11px; color: var(--sb-muted); background: var(--sb-surface); padding: 2px 6px; border-radius: 4px; }",
    // Story 4.10: AC14-15 - Empty state in modal with link
    ".modal-empty-state { display: flex; flex-direction: column; align-items: center; gap: 12px; padding: 24px 16px; text-align: center; }",
    ".modal-empty-state p { margin: 0; color: var(--sb-muted); font-size: 14px; }",
    ".link-to-templates { color: var(--sb-primary); text-decoration: none; font-weight: 500; }",
    ".link-to-templates:hover { text-decoration: underline; }",
    // Form hints
    ".form-hint { font-size: 13px; color: var(--sb-muted); margin-bottom: 8px; }",
    ".form-hint-secondary { display: flex; align-items: center; gap: 4px; font-size: 12px; color: var(--sb-muted); margin-top: 8px; }",
    // Attach template modal
    ".modal-backdrop { position: fixed; inset: 0; z-index: 100; display: flex; align-items: center; justify-content: center; padding: 16px; background: rgba(0, 0, 0, 0.5); }",
    ".modal-sm { position: relative; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; padding: 0; width: min(400px, 100%); max-height: 85vh; overflow: hidden; }",
    ".modal-sm .modal-header { padding: 16px; border-bottom: 1px solid var(--sb-border); margin: 0; }",
    ".modal-sm .modal-body { padding: 16px; }",
    ".modal-sm .modal-footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--sb-border); background: var(--sb-surface); }",
    ".btn-sm { padding: 6px 12px; font-size: 13px; border-radius: 8px; }",
    ".btn-primary { background: var(--sb-primary); border-color: var(--sb-primary); color: var(--sb-inverse); }",
    ".btn-primary:hover { background: var(--sb-primary-hover); border-color: var(--sb-primary-hover); }",
    ".btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }",
    ".btn-secondary { background: var(--sb-surface); border-color: var(--sb-border); color: var(--sb-text); }",
    ".btn-secondary:hover { background: var(--sb-elevated); border-color: var(--sb-text); }",
    ".btn-danger { background: transparent; border-color: var(--sb-danger); color: var(--sb-danger); }",
    ".btn-danger:hover { background: color-mix(in oklab, var(--sb-danger) 15%, transparent); }",
    ".form-group { margin-bottom: 12px; }",
    ".form-group label { display: block; font-size: 13px; font-weight: 500; margin-bottom: 6px; color: var(--sb-muted); }",
    ".form-group .select { width: 100%; padding: 10px 12px; font-size: 14px; }",
    // Metric cells in tables
    ".metric-cell { text-align: center; }",
    ".metric { display: inline-block; padding: 2px 10px; border-radius: 12px; font-weight: 600; font-size: 13px; }",
    ".metric.applied { background: color-mix(in oklab, var(--sb-success) 15%, transparent); color: var(--sb-success); }",
    ".metric.suppressed { background: color-mix(in oklab, var(--sb-warning) 15%, transparent); color: var(--sb-warning); }",
    ".nav-item { width: 100%; text-align: left; }",
    ".nav-item.active { border-color: var(--sb-primary); }",
    ".actions { display: flex; gap: 8px; flex-wrap: wrap; }",
    // Assignments (Story 5.7)
    ".assignments-toolbar { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }",
    ".assignments-toggle { display: inline-flex; align-items: center; gap: 6px; padding: 4px; border-radius: 12px; border: 1px solid var(--sb-border); background: var(--sb-elevated); }",
    ".assignments-toggle .btn-xs { min-width: 120px; }",
    ".assignments-search input { min-width: 240px; }",
    ".assignments-cards { display: flex; flex-direction: column; gap: 12px; }",
    ".assignments-card { display: flex; flex-direction: column; gap: 10px; border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; background: var(--sb-surface); }",
    ".assignments-card-header { display: grid; grid-template-columns: 1fr auto; align-items: center; gap: 8px; }",
    ".assignments-card-title { display: flex; align-items: center; gap: 8px; font-weight: 600; }",
    ".assignments-card-icon { display: inline-flex; }",
    ".assignments-card-meta { font-size: 12px; color: var(--sb-muted); text-align: right; }",
    ".assignments-card-actions { display: flex; gap: 6px; justify-self: end; }",
    ".assignments-card-body { display: flex; flex-direction: column; gap: 8px; }",
    ".assignments-row { display: flex; align-items: center; gap: 8px; padding: 6px 0; border-bottom: 1px dashed var(--sb-border); }",
    ".assignments-row:last-child { border-bottom: none; }",
    ".assignments-row-title { flex: 1; min-width: 0; }",
    ".assignments-row-actions { display: flex; gap: 6px; }",
    ".assignments-inline-add { margin-top: 8px; padding: 8px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-elevated); }",
    ".assignments-inline-add-row { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }",
    ".assignments-inline-add-label { font-size: 12px; color: var(--sb-muted); }",
    ".assignments-inline-add-actions { display: flex; gap: 6px; }",
    ".assignments-inline-add input, .assignments-inline-add select, .assignments-row select { min-height: 32px; }",
    ".assignments-empty { color: var(--sb-muted); font-size: 13px; }",
    "@media (max-width: 768px) { .assignments-search input { width: 100%; } .assignments-toolbar { align-items: stretch; } .assignments-toggle { width: 100%; justify-content: space-between; } .assignments-toggle .btn-xs { flex: 1; } .assignments-card-header { grid-template-columns: 1fr; } .assignments-card-actions { width: 100%; justify-content: flex-end; } .assignments-row { flex-direction: column; align-items: flex-start; } .assignments-row-actions { width: 100%; justify-content: flex-end; } }",
    ".modal { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; padding: 16px; }",
    ".modal::before { content: \"\"; position: absolute; inset: 0; background: var(--sb-bg); opacity: 0.85; }",
    ".modal-content { position: relative; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; padding: 16px; width: min(720px, 100%); max-height: 85vh; overflow: auto; }",
    // Modal header with close button
    ".modal-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; padding-bottom: 12px; border-bottom: 1px solid var(--sb-border); }",
    ".modal-header h3 { margin: 0; font-size: 18px; font-weight: 600; }",
    ".btn-close { width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center; background: var(--sb-surface); border: 1px solid var(--sb-border); cursor: pointer; font-size: 14px; color: var(--sb-muted); transition: all 0.15s ease; }",
    ".btn-close:hover { background: var(--sb-elevated); border-color: var(--sb-text); color: var(--sb-text); }",
    ".modal-body { }",
    // Drilldown modal styles
    ".drilldown-modal { z-index: 100; }",
    ".drilldown-details h3 { font-size: 16px; font-weight: 600; margin: 0 0 12px 0; }",
    ".metrics-summary { display: flex; gap: 12px; margin-bottom: 20px; flex-wrap: wrap; }",
    ".metric-box { padding: 12px 16px; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 10px; min-width: 100px; }",
    ".metric-box .metric-label { display: block; font-size: 12px; color: var(--sb-muted); margin-bottom: 4px; }",
    ".metric-box .metric-value { display: block; font-size: 20px; font-weight: 700; }",
    ".metric-box.applied { border-color: var(--sb-success); background: color-mix(in oklab, var(--sb-success) 10%, var(--sb-surface)); }",
    ".metric-box.applied .metric-value { color: var(--sb-success); }",
    ".metric-box.suppressed { border-color: var(--sb-warning); background: color-mix(in oklab, var(--sb-warning) 10%, var(--sb-surface)); }",
    ".metric-box.suppressed .metric-value { color: var(--sb-warning); }",
    ".suppression-breakdown { display: flex; flex-direction: column; gap: 8px; margin-bottom: 20px; }",
    ".breakdown-item { display: flex; justify-content: space-between; align-items: center; padding: 8px 12px; background: var(--sb-surface); border-radius: 8px; }",
    ".breakdown-label { color: var(--sb-muted); font-size: 14px; }",
    ".breakdown-value { font-weight: 600; font-size: 14px; }",
    ".drilldown-executions h3 { font-size: 16px; font-weight: 600; margin: 16px 0 12px 0; }",
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
    ".task-card { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; overflow: hidden; position: relative; }",
    ".task-card:hover, .task-card:focus-within { z-index: 10; overflow: visible; box-shadow: 0 10px 30px rgba(0,0,0,0.18); }",
    ".task-card-top { position: absolute; top: 8px; left: 8px; right: 8px; display: flex; justify-content: space-between; gap: 6px; align-items: center; z-index: 2; }",
    ".task-card-type-icon { display: none; }",
    ".task-card-actions-left { display: flex; gap: 6px; align-items: center; flex-shrink: 0; }",
    ".task-card-actions-right { display: flex; gap: 6px; align-items: center; flex-shrink: 0; }",
    ".task-card-body { height: 100%; display: flex; flex-direction: column; justify-content: center; align-items: center; gap: 6px; padding: 10px 10px 10px 10px; padding-top: 40px; box-sizing: border-box; }
.task-card-center { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; }
.task-card-center-icon { width: 28px; height: 28px; display: inline-flex; align-items: center; justify-content: center; opacity: 0.9; }",
    ".task-card-title { width: 100%; font-weight: 700; font-size: 13px; line-height: 1.15; text-align: center; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }",
    ".task-card.highlight { border: 2px solid var(--sb-primary); }",
    ".task-card .secondary-action { display: inline-flex; opacity: 0.65; }",
    ".task-card:hover .secondary-action, .task-card:focus-within .secondary-action { opacity: 1; }",
    ".task-card-preview { position: absolute; top: 0; left: calc(100% + 8px); width: 320px; max-width: min(420px, calc(100vw - 24px)); background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px 14px; box-shadow: 0 10px 30px rgba(0,0,0,0.18); opacity: 0; transform: scale(0.98); transition: opacity 120ms ease, transform 120ms ease; transition-delay: 200ms; pointer-events: auto; z-index: 20; }
.task-card.preview-left .task-card-preview { left: auto; right: calc(100% + 8px); }",
    ".task-preview-grid { display: grid; grid-template-columns: auto 1fr; column-gap: 10px; row-gap: 6px; align-items: baseline; }",
    ".task-preview-label { color: var(--sb-muted); font-size: 12px; }",
    ".task-preview-label-strong { color: var(--sb-text); font-weight: 600; }",
    ".task-preview-value { font-size: 12px; text-align: left; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".task-preview-description { white-space: normal; line-height: 1.4; }",
    ".task-preview-extras { display: flex; flex-direction: column; gap: 8px; margin-top: 10px; }",
    ".task-preview-section { display: flex; flex-direction: column; gap: 6px; padding-top: 6px; border-top: 1px dashed var(--sb-border); }",
    ".task-preview-section-title { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; color: var(--sb-muted); }",
    ".task-preview-list { display: flex; flex-direction: column; gap: 4px; list-style: disc; margin: 0; padding-left: 16px; }",
    ".task-preview-list-item { margin: 0; }",
    ".task-preview-blocked-list { display: flex; flex-direction: column; gap: 4px; }",
    ".task-preview-blocked-item { font-size: 12px; color: var(--sb-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }",
    ".task-preview-notes { display: flex; flex-direction: column; gap: 6px; }",
    ".task-preview-note { display: flex; flex-direction: column; gap: 2px; }",
    ".task-preview-note-meta { font-size: 11px; color: var(--sb-muted); }",
    ".task-preview-note-content { font-size: 12px; color: var(--sb-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }",
    ".task-preview-actions { margin-top: 10px; display: flex; justify-content: flex-end; }",
    ".task-preview-btn { font-size: 12px; }",
    ".task-preview-badge { display: inline-flex; align-items: center; padding: 2px 8px; border-radius: 999px; border: 1px solid var(--sb-border); background: color-mix(in oklab, var(--sb-elevated) 70%, transparent); font-weight: 600; }",
    ".task-preview-badge-available { border-color: color-mix(in oklab, var(--sb-primary) 60%, var(--sb-border)); background: color-mix(in oklab, var(--sb-primary) 12%, var(--sb-elevated)); }",
    ".task-preview-badge-claimed { border-color: color-mix(in oklab, var(--sb-info) 60%, var(--sb-border)); background: color-mix(in oklab, var(--sb-info) 12%, var(--sb-elevated)); }",
    ".task-preview-badge-ongoing { border-color: color-mix(in oklab, var(--sb-warning) 60%, var(--sb-border)); background: color-mix(in oklab, var(--sb-warning) 14%, var(--sb-elevated)); }",
    ".task-preview-badge-completed { border-color: color-mix(in oklab, var(--sb-success) 60%, var(--sb-border)); background: color-mix(in oklab, var(--sb-success) 12%, var(--sb-elevated)); }",
    ".task-card-preview::before { content: \"\"; position: absolute; left: -8px; top: 50%; transform: translateY(-50%); border-width: 8px 8px 8px 0; border-style: solid; border-color: transparent var(--sb-elevated) transparent transparent; }",
    ".task-card-preview::after { content: \"\"; position: absolute; left: -9px; top: 50%; transform: translateY(-50%); border-width: 9px 9px 9px 0; border-style: solid; border-color: transparent var(--sb-border) transparent transparent; }",
    ".task-card.preview-left .task-card-preview::before { left: auto; right: -8px; border-width: 8px 0 8px 8px; border-color: transparent transparent transparent var(--sb-elevated); }",
    ".task-card.preview-left .task-card-preview::after { left: auto; right: -9px; border-width: 9px 0 9px 9px; border-color: transparent transparent transparent var(--sb-border); }",
    ".task-card:hover .task-card-preview { opacity: 1; transform: scale(1); transition-delay: 350ms; }",
    ".task-card:focus-within .task-card-preview { opacity: 1; transform: scale(1); transition-delay: 0ms; }",
    ".task-card.touch-preview .task-card-preview { opacity: 1; transform: scale(1); transition-delay: 0ms; }",
    ".drag-handle { cursor: grab; user-select: none; padding: 0; border: 1px solid var(--sb-border); border-radius: 8px; background: transparent; color: var(--sb-muted); display: inline-flex; align-items: center; justify-content: center; min-width: 28px; min-height: 28px; line-height: 0; }",
    ".drag-handle:hover { border-color: var(--sb-primary); }
.drag-handle:active { cursor: grabbing; }",
    ".task-list { display: flex; flex-direction: column; gap: 8px; }",
    ".task-row { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; padding: 10px; border: 1px solid var(--sb-border); border-radius: 12px; background: var(--sb-elevated); }",
    ".task-row-title { font-weight: 700; display: flex; align-items: center; gap: 6px; }",
    ".task-row-meta { color: var(--sb-muted); font-size: 0.9em; }",
    ".task-row-actions { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; justify-content: flex-end; }",
    ".skills-list { display: flex; flex-direction: column; gap: 6px; }",
    ".skill-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 8px 10px; border: 1px solid var(--sb-border); border-radius: 12px; background: var(--sb-elevated); }",
    ".skill-name { font-weight: 600; }",
    // Now Working section in right panel (unified layout)
    ".now-working-section { padding: 12px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 10px; margin-bottom: 12px; }",
    ".now-working-section.now-working-active { background: color-mix(in oklab, var(--sb-primary) 8%, var(--sb-elevated)); border-color: color-mix(in oklab, var(--sb-primary) 30%, var(--sb-border)); position: relative; }",
    ".now-working-section.now-working-active::before { content: ''; position: absolute; top: 12px; right: 12px; width: 8px; height: 8px; background: var(--sb-success); border-radius: 50%; animation: pulse-dot 2s ease-in-out infinite; }",
    "@keyframes pulse-dot { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.5; transform: scale(1.2); } }",
    ".now-working-task-title { font-weight: 600; margin-bottom: 4px; }",
    ".now-working-timer { font-variant-numeric: tabular-nums; color: var(--sb-muted); }",
    ".now-working-section .now-working-timer { font-size: 1.5rem; font-weight: 600; font-family: ui-monospace, monospace; text-align: center; margin: 8px 0; }",
    ".now-working-actions { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }",
    ".now-working-empty { display: flex; align-items: center; gap: 8px; justify-content: center; padding: 8px 0; color: var(--sb-muted); font-style: italic; }",
    ".now-working-empty-icon { font-size: 1.2em; opacity: 0.7; }",
    ".now-working-section .now-working-actions { justify-content: center; }",
    // Multi-session support for EN CURSO panel
    ".now-working-multi { padding: 8px; }",
    ".now-working-multi::before { display: none; }",
    ".now-working-sessions { display: flex; flex-direction: column; gap: 8px; max-height: 240px; overflow-y: auto; }",
    ".now-working-session-item { display: flex; flex-direction: column; gap: 4px; padding: 10px 12px; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 8px; position: relative; }",
    ".now-working-session-item::before { content: ''; position: absolute; top: 10px; right: 10px; width: 6px; height: 6px; background: var(--sb-success); border-radius: 50%; animation: pulse-dot 2s ease-in-out infinite; }",
    ".now-working-session-item .now-working-task-title { font-size: 0.9rem; font-weight: 600; padding-right: 16px; }",
    ".now-working-session-item .now-working-timer { font-size: 1.1rem; font-weight: 600; font-family: ui-monospace, monospace; color: var(--sb-primary); }",
    ".now-working-session-item .now-working-actions { flex-direction: row; justify-content: flex-start; margin-top: 4px; }",
    // Task row active state
    ".task-row-active { background: color-mix(in oklab, var(--sb-primary) 10%, var(--sb-elevated)); border-color: var(--sb-primary); }",
    "@media (max-width: 640px) { .body { flex-direction: column; } .nav { width: 100%; } }",
    // =====================================================
    // UX IMPROVEMENTS - Cards & Sections (E03-E10)
    // =====================================================
    ".admin-card { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 16px; margin-bottom: 16px; }",
    ".admin-card-header { font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; color: var(--sb-muted); margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid var(--sb-border); }",
    ".admin-card-title { font-size: 16px; font-weight: 700; margin-bottom: 8px; }",
    ".admin-section-gap { height: 24px; }",
    // =====================================================
    // UX IMPROVEMENTS - Sidebar Groups (SA01-SA05)
    // =====================================================
    ".sidebar-group { margin-bottom: 16px; }",
    ".sidebar-group:last-child { margin-bottom: 0; }",
    ".sidebar-group-title { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--sb-muted); padding: 0 8px 6px; margin-bottom: 4px; }",
    ".sidebar-group-items { display: flex; flex-direction: column; gap: 2px; }",
    ".nav-item-icon { width: 18px; height: 18px; opacity: 0.7; flex-shrink: 0; }",
    ".nav-item { display: flex; align-items: center; gap: 8px; padding: 8px 10px; border-radius: 8px; border: 1px solid transparent; transition: background 0.15s, border-color 0.15s; }",
    ".nav-item:hover { background: var(--sb-hover); }",
    ".nav-item.active { background: color-mix(in oklab, var(--sb-primary) 12%, var(--sb-surface)); border-color: var(--sb-primary); color: var(--sb-primary); }",
    ".nav-item.active .nav-item-icon { opacity: 1; }",
    // =====================================================
    // UX IMPROVEMENTS - Form States (FG01-FG04, L01-L03)
    // =====================================================
    "input:focus, select:focus, textarea:focus { outline: none; border-color: var(--sb-primary); box-shadow: 0 0 0 3px color-mix(in oklab, var(--sb-primary) 15%, transparent); }",
    ".field-error-msg { display: flex; align-items: center; gap: 4px; margin-top: 4px; font-size: 12px; color: var(--sb-danger); }",
    ".field-error-msg svg { width: 14px; height: 14px; flex-shrink: 0; }",
    ".field-hint { font-size: 11px; color: var(--sb-muted); margin-top: 4px; font-family: var(--sb-font-mono, monospace); opacity: 0.8; }",
    ".field-variables-hint { display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px; margin-top: 8px; padding: 8px 10px; background: color-mix(in oklab, var(--sb-info) 8%, var(--sb-surface)); border-radius: 6px; border: 1px solid color-mix(in oklab, var(--sb-info) 20%, var(--sb-border)); }",
    ".field-variables-label { font-size: 11px; color: var(--sb-muted); font-weight: 500; }",
    ".field-variables-list { font-size: 11px; color: var(--sb-info); font-family: var(--sb-font-mono, monospace); }",
    ".input-error { border-color: var(--sb-danger) !important; }",
    ".input-error:focus { box-shadow: 0 0 0 3px color-mix(in oklab, var(--sb-danger) 15%, transparent) !important; }",
    ".input-success { border-color: var(--sb-success); }",
    // =====================================================
    // UX IMPROVEMENTS - Button States (L01, FG04)
    // =====================================================
    ".btn-loading { position: relative; color: transparent !important; pointer-events: none; }",
    ".btn-loading::after { content: ''; position: absolute; top: 50%; left: 50%; width: 16px; height: 16px; margin: -8px 0 0 -8px; border: 2px solid var(--sb-inverse); border-right-color: transparent; border-radius: 50%; animation: btn-spin 0.6s linear infinite; }",
    "@keyframes btn-spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }",
    "button.btn-loading[type='submit']::after { border-color: var(--sb-inverse); border-right-color: transparent; }",
    // =====================================================
    // UX IMPROVEMENTS - Empty States (P01, MB02, E08)
    // =====================================================
    ".empty-state { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 32px 16px; text-align: center; }",
    ".empty-state-icon { font-size: 48px; margin-bottom: 16px; opacity: 0.5; }",
    ".empty-state-title { font-size: 18px; font-weight: 600; margin-bottom: 8px; color: var(--sb-text); }",
    ".empty-state-description { font-size: 14px; color: var(--sb-muted); max-width: 320px; margin-bottom: 16px; line-height: 1.5; }",
    ".empty-state-actions { display: flex; gap: 12px; flex-wrap: wrap; justify-content: center; }",
    // AC32: Empty state actionable hints
    ".empty-state-hint { font-size: 12px; color: var(--sb-link); text-align: center; margin-top: 8px; opacity: 0.8; }",
    // =====================================================
    // UX IMPROVEMENTS - Info Callout/Banner (E09, E10, E01)
    // =====================================================
    ".info-callout { display: flex; align-items: flex-start; gap: 12px; padding: 12px 16px; background: color-mix(in oklab, var(--sb-info) 10%, var(--sb-surface)); border: 1px solid color-mix(in oklab, var(--sb-info) 30%, var(--sb-border)); border-radius: 10px; margin-bottom: 16px; }",
    ".info-callout-icon { width: 20px; height: 20px; flex-shrink: 0; color: var(--sb-info); margin-top: 2px; }",
    ".info-callout-content { flex: 1; display: flex; flex-direction: column; gap: 6px; }",
    ".info-callout-title { font-weight: 600; margin-bottom: 4px; }",
    ".info-callout-text { font-size: 14px; color: var(--sb-muted); line-height: 1.5; }",
    ".info-callout-variables { font-size: 12px; color: var(--sb-muted); font-family: var(--sb-font-mono, monospace); opacity: 0.85; }",
    ".error-banner { display: flex; align-items: center; gap: 12px; padding: 10px 16px; background: color-mix(in oklab, var(--sb-danger) 10%, var(--sb-surface)); border: 1px solid color-mix(in oklab, var(--sb-danger) 30%, var(--sb-border)); border-radius: 10px; margin-bottom: 12px; }",
    ".error-banner-icon { width: 20px; height: 20px; flex-shrink: 0; color: var(--sb-danger); }",
    ".error-banner-text { flex: 1; font-size: 14px; color: var(--sb-danger); }",
    ".error-banner-actions { display: flex; gap: 8px; }",
    ".error-banner-dismiss { padding: 4px 8px; background: transparent; border: none; color: var(--sb-danger); cursor: pointer; opacity: 0.7; }",
    ".error-banner-dismiss:hover { opacity: 1; }",
    // =====================================================
    // UX IMPROVEMENTS - Table Actions (AC02, E06)
    // =====================================================
    ".table-actions { display: flex; gap: 4px; justify-content: flex-end; }",
    ".table-actions button { padding: 4px 8px; min-width: 32px; min-height: 32px; }",
    ".table td.actions-cell { text-align: right; }",
    // DataTable component (extends .table)
    ".data-table { width: 100%; border-collapse: collapse; }",
    ".data-table th { text-align: left; color: var(--sb-muted); font-weight: 600; font-size: 12px; text-transform: uppercase; letter-spacing: 0.03em; padding: 10px 12px; border-bottom: 2px solid var(--sb-border); background: var(--sb-surface); }",
    ".data-table td { padding: 10px 12px; border-bottom: 1px solid var(--sb-border); vertical-align: middle; }",
    ".data-table tbody tr:nth-child(even) { background: color-mix(in oklab, var(--sb-surface) 50%, var(--sb-bg)); }",
    ".data-table tbody tr:hover { background: var(--sb-elevated); }",
    ".data-table th.sortable { cursor: pointer; user-select: none; }",
    ".data-table th.sortable:hover { background: var(--sb-hover); }",
    ".data-table th .sort-icon { margin-left: 4px; opacity: 0.4; font-size: 10px; }",
    ".data-table th.sortable:hover .sort-icon { opacity: 1; }",
    // DataTable responsive collapse (card view on mobile)
    "@media (max-width: 640px) { .data-table, .data-table thead, .data-table tbody, .data-table th, .data-table td, .data-table tr { display: block; } .data-table thead { position: absolute; top: -9999px; left: -9999px; } .data-table tr { margin-bottom: 12px; border: 1px solid var(--sb-border); border-radius: 8px; padding: 12px; background: var(--sb-surface); } .data-table td { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border: none; border-bottom: 1px solid var(--sb-border); } .data-table td:last-child { border-bottom: none; } .data-table td::before { content: attr(data-label); font-weight: 600; color: var(--sb-muted); font-size: 12px; text-transform: uppercase; } }",
    ".usage-badge { font-size: 12px; color: var(--sb-muted); }",
    // =====================================================
    // UX IMPROVEMENTS - Form Sections (E07)
    // =====================================================
    ".form-section { margin-bottom: 20px; }",
    ".form-section:last-child { margin-bottom: 0; }",
    ".form-section-title { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--sb-muted); margin-bottom: 10px; }",
    ".form-section-content { padding-left: 0; }",
    ".icon-preview-large { width: 48px; height: 48px; font-size: 28px; border: 1px solid var(--sb-border); border-radius: 12px; display: flex; align-items: center; justify-content: center; background: var(--sb-elevated); margin: 8px 0; }",
    // =====================================================
    // UX IMPROVEMENTS - Decay Badge (P02)
    // =====================================================
    ".decay-badge { position: absolute; top: 6px; right: 6px; font-size: 10px; font-weight: 600; padding: 2px 6px; border-radius: 6px; background: var(--sb-elevated); border: 1px solid var(--sb-border); color: var(--sb-muted); z-index: 3; }",
    ".decay-badge.decay-low { background: color-mix(in oklab, var(--sb-info) 15%, var(--sb-elevated)); border-color: color-mix(in oklab, var(--sb-info) 40%, var(--sb-border)); color: var(--sb-info); }",
    ".decay-badge.decay-medium { background: color-mix(in oklab, var(--sb-warning) 15%, var(--sb-elevated)); border-color: color-mix(in oklab, var(--sb-warning) 40%, var(--sb-border)); color: var(--sb-warning); }",
    ".decay-badge.decay-high { background: color-mix(in oklab, var(--sb-danger) 15%, var(--sb-elevated)); border-color: color-mix(in oklab, var(--sb-danger) 40%, var(--sb-border)); color: var(--sb-danger); }",
    // =====================================================
    // DECAY SHAKE ANIMATIONS - Visual indicator for stale tasks
    // Shake intensity increases with age. Colors remain intact.
    // =====================================================
    "@keyframes decay-shake-low { 0%, 92% { transform: translate(0, 0); } 93% { transform: translate(-0.5px, 0); } 95% { transform: translate(0.5px, 0); } 97% { transform: translate(-0.5px, 0); } 100% { transform: translate(0, 0); } }",
    "@keyframes decay-shake-medium { 0%, 88% { transform: translate(0, 0); } 89% { transform: translate(-1px, 0); } 91% { transform: translate(1px, 0); } 93% { transform: translate(-1px, 0); } 95% { transform: translate(1px, 0); } 97% { transform: translate(-0.5px, 0); } 100% { transform: translate(0, 0); } }",
    "@keyframes decay-shake-high { 0%, 84% { transform: translate(0, 0); } 85% { transform: translate(-1.5px, -0.5px); } 87% { transform: translate(1.5px, 0.5px); } 89% { transform: translate(-1.5px, 0); } 91% { transform: translate(1.5px, -0.5px); } 93% { transform: translate(-1px, 0.5px); } 95% { transform: translate(1px, 0); } 97% { transform: translate(-0.5px, 0); } 100% { transform: translate(0, 0); } }",
    ".decay-shake-low { animation: decay-shake-low 4s ease-in-out infinite; }",
    ".decay-shake-medium { animation: decay-shake-medium 3s ease-in-out infinite; }",
    ".decay-shake-high { animation: decay-shake-high 2s ease-in-out infinite; }",
    // =====================================================
    // UX IMPROVEMENTS - Confirmation Modal (IF02)
    // =====================================================
    ".modal-confirm { text-align: center; }",
    ".modal-confirm-title { font-size: 18px; font-weight: 700; margin-bottom: 12px; }",
    ".modal-confirm-text { color: var(--sb-muted); margin-bottom: 20px; line-height: 1.5; }",
    ".modal-confirm-actions { display: flex; gap: 12px; justify-content: center; }",
    ".btn-danger { background: var(--sb-danger); border-color: var(--sb-danger); color: var(--sb-inverse); }",
    ".btn-danger:hover { background: color-mix(in oklab, var(--sb-danger) 85%, black); border-color: color-mix(in oklab, var(--sb-danger) 85%, black); }",
    // Delete button hover (Story 4.8 AC39)
    ".btn-delete:hover { color: var(--sb-danger); border-color: var(--sb-danger); }",
    // Dialog warning text (Story 4.8 AC39)
    ".dialog-message { font-size: 15px; margin-bottom: 12px; }",
    ".dialog-warning { font-size: 13px; color: var(--sb-muted); line-height: 1.5; padding: 10px 12px; background: color-mix(in oklab, var(--sb-warning) 10%, transparent); border-radius: 6px; border-left: 3px solid var(--sb-warning); }",
    // =====================================================
    // UX IMPROVEMENTS - Skeleton Loading (IF03)
    // =====================================================
    ".skeleton { background: linear-gradient(90deg, var(--sb-surface) 25%, var(--sb-hover) 50%, var(--sb-surface) 75%); background-size: 200% 100%; animation: skeleton-shimmer 1.5s infinite; border-radius: 6px; }",
    "@keyframes skeleton-shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }",
    ".skeleton-text { height: 16px; margin-bottom: 8px; }",
    ".skeleton-title { height: 24px; width: 60%; margin-bottom: 12px; }",
    ".skeleton-button { height: 36px; width: 100px; }",
    // =====================================================
    // UX IMPROVEMENTS - Accessibility (A01-A06)
    // =====================================================
    ".skip-link { position: absolute; left: -9999px; top: auto; width: 1px; height: 1px; overflow: hidden; z-index: 100; }",
    ".skip-link:focus { position: fixed; left: 16px; top: 16px; width: auto; height: auto; padding: 12px 16px; background: var(--sb-primary); color: var(--sb-inverse); border-radius: 8px; font-weight: 600; text-decoration: none; }",
    // A05: Screen reader only text
    ".sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }",
    // A06: Focus states
    ":focus-visible { outline: 2px solid var(--sb-primary); outline-offset: 2px; }",
    ":focus:not(:focus-visible) { outline: none; }",
    // A07: Reduced motion (AC41)
    "@media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation-duration: 0.01ms !important; animation-iteration-count: 1 !important; transition-duration: 0.01ms !important; scroll-behavior: auto !important; } }",
    // A08: Touch targets (AC38) - explicit class for guaranteed 44px minimum
    ".touch-target { display: inline-flex; align-items: center; justify-content: center; min-width: 44px; min-height: 44px; }",
    // =====================================================
    // UX IMPROVEMENTS - Settings Menu (H01-H03)
    // =====================================================
    ".settings-menu { position: relative; display: inline-block; }",
    ".settings-menu-trigger { display: inline-flex; align-items: center; justify-content: center; width: 36px; height: 36px; border-radius: 8px; }",
    ".settings-menu-dropdown { position: absolute; top: 100%; right: 0; margin-top: 4px; min-width: 200px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 10px; padding: 8px; box-shadow: 0 10px 30px rgba(0,0,0,0.15); z-index: 50; display: none; }",
    ".settings-menu.open .settings-menu-dropdown { display: block; }",
    ".settings-menu-item { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 8px 12px; border-radius: 6px; }",
    ".settings-menu-item:hover { background: var(--sb-hover); }",
    ".settings-menu-label { font-size: 14px; }",
    ".settings-menu-item select { min-width: 100px; }",
    // =====================================================
    // UX IMPROVEMENTS - Responsive Mobile (RM01-RM04)
    // AC38: All interactive elements must have min 44px touch targets on mobile
    // =====================================================
    "@media (max-width: 768px) { button, a.btn, .clickable, select, input[type='checkbox'], input[type='radio'], .btn-xs, .btn-icon, .nav-item { min-height: 44px; } button, a.btn, .clickable, .btn-icon { min-width: 44px; } select { padding: 10px 12px; font-size: 16px; } input { min-height: 44px; padding: 10px 12px; font-size: 16px; } .btn-xs { min-height: 44px; padding: 10px 16px; } .filters-row select, .filters-row input, .filters-row button { min-height: 44px; height: 44px; } .topbar { flex-wrap: wrap; gap: 8px; padding: 10px; } .topbar-actions { width: 100%; justify-content: space-between; } .user { display: none; } .user-avatar { display: flex; width: 32px; height: 32px; border-radius: 50%; background: var(--sb-primary); color: var(--sb-inverse); align-items: center; justify-content: center; font-weight: 600; } }",
    ".hamburger-menu { display: none; }",
    "@media (max-width: 768px) { .hamburger-menu { display: flex; align-items: center; justify-content: center; width: 44px; height: 44px; } .admin .nav { position: fixed; left: -280px; top: 0; bottom: 0; width: 280px; z-index: 100; transition: left 0.3s ease; background: var(--sb-surface); border-right: 1px solid var(--sb-border); border-radius: 0; padding-top: 60px; } .admin .nav.open { left: 0; } .admin .nav-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 99; } .admin .nav.open + .nav-overlay { display: block; } }",
    // =====================================================
    // MOBILE - Mini-Bar & Panel Sheet
    // =====================================================
    // Mini-bar: hidden on desktop, shown on mobile
    ".member-mini-bar { display: none; }",
    "@media (max-width: 768px) { .member-mini-bar { display: flex; position: fixed; bottom: 0; left: 0; right: 0; align-items: center; gap: 8px; padding: 12px 16px; min-height: 48px; background: var(--sb-elevated); border-top: 1px solid var(--sb-border); box-shadow: 0 -4px 12px rgba(0,0,0,0.1); z-index: 40; cursor: pointer; } }",
    ".member-mini-bar-expand { font-size: 16px; color: var(--sb-primary); margin-right: 6px; font-weight: 600; }",
    ".member-mini-bar-status { flex: 1; display: flex; align-items: center; gap: 8px; min-width: 0; }",
    ".member-mini-bar-label { font-weight: 600; font-size: 14px; }",
    ".member-mini-bar-timer { font-variant-numeric: tabular-nums; font-size: 14px; color: var(--sb-muted); }",
    // Panel sheet: hidden by default
    ".member-panel-sheet { display: none; position: fixed; bottom: 0; left: 0; right: 0; max-height: 70vh; background: var(--sb-surface); border-top: 1px solid var(--sb-border); border-radius: 16px 16px 0 0; box-shadow: 0 -8px 24px rgba(0,0,0,0.15); transform: translateY(100%); transition: transform 280ms cubic-bezier(0.32, 0.72, 0, 1); z-index: 45; overflow: hidden; }",
    "@media (max-width: 768px) { .member-panel-sheet { display: block; } }",
    ".member-panel-sheet.open { transform: translateY(0); }",
    ".member-panel-sheet-handle { display: flex; justify-content: center; padding: 16px 12px; cursor: pointer; }",
    ".member-panel-sheet-handle::before { content: ''; width: 48px; height: 5px; background: var(--sb-muted); border-radius: 3px; opacity: 0.6; }",
    ".member-panel-sheet-handle:active::before { opacity: 1; background: var(--sb-primary); }",
    ".member-panel-sheet-content { padding: 0 16px 16px; overflow-y: auto; max-height: calc(70vh - 40px); }",
    // Panel sheet sections
    ".sheet-section { margin-bottom: 16px; }",
    ".sheet-section h3 { font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: var(--sb-muted); margin-bottom: 12px; }",
    ".sheet-section-primary h3 { color: var(--sb-primary); }",
    ".sheet-empty { display: flex; align-items: center; justify-content: center; gap: 8px; padding: 12px; color: var(--sb-muted); font-style: italic; }",
    ".sheet-empty-icon { font-size: 1.1em; opacity: 0.7; }",
    ".sheet-divider { border: none; border-top: 1px dashed var(--sb-border); margin: 16px 0; }",
    // Session row (NOW WORKING)
    ".session-row { display: flex; align-items: center; gap: 10px; padding: 10px 12px; background: color-mix(in oklab, var(--sb-primary) 8%, var(--sb-elevated)); border: 1px solid color-mix(in oklab, var(--sb-primary) 25%, var(--sb-border)); border-radius: 8px; margin-bottom: 8px; }",
    ".session-row-content { display: flex; align-items: center; gap: 10px; flex: 1; }",
    ".session-icon { flex-shrink: 0; }",
    ".session-title { flex: 1; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".session-timer { font-variant-numeric: tabular-nums; font-weight: 600; color: var(--sb-primary); }",
    ".session-actions { display: flex; gap: 6px; flex-shrink: 0; }",
    // Claimed row (CLAIMED)
    ".claimed-row { display: flex; align-items: center; gap: 10px; padding: 10px 12px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 8px; margin-bottom: 8px; }",
    ".claimed-row-content { display: flex; align-items: center; gap: 10px; flex: 1; }",
    ".claimed-icon { flex-shrink: 0; }",
    ".claimed-title { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".claimed-actions { display: flex; gap: 6px; flex-shrink: 0; }",
    // Action buttons in sheet
    ".btn-action { display: flex; align-items: center; justify-content: center; width: 44px; height: 44px; border-radius: 8px; background: var(--sb-surface); border: 1px solid var(--sb-border); font-size: 18px; cursor: pointer; transition: background 0.15s, border-color 0.15s; }",
    ".btn-action:hover { background: var(--sb-hover); }",
    ".btn-action:disabled { opacity: 0.5; cursor: not-allowed; }",
    ".btn-action.btn-start { background: color-mix(in oklab, var(--sb-success) 15%, var(--sb-surface)); border-color: var(--sb-success); }",
    ".btn-action.btn-complete { background: color-mix(in oklab, var(--sb-success) 15%, var(--sb-surface)); border-color: var(--sb-success); }",
    // Overlay
    ".member-panel-overlay { display: none; }",
    "@media (max-width: 768px) { .member-panel-overlay.visible { display: block; position: fixed; inset: 0; background: rgba(0,0,0,0.3); z-index: 42; } }",
    // Content padding when mini-bar is visible
    "@media (max-width: 768px) { .member-content-mobile { padding-bottom: 70px; } }",
    // =====================================================
    // UX IMPROVEMENTS - Responsive Tablet (RT01-RT02)
    // =====================================================
    "@media (min-width: 769px) and (max-width: 1024px) { .nav { width: 200px; padding: 8px; } .nav-item { padding: 8px; font-size: 13px; } .pool-right { width: 280px; } }",
    // =====================================================
    // UX IMPROVEMENTS - Progress Bar (AF04)
    // =====================================================
    ".progress-bar { height: 6px; background: var(--sb-border); border-radius: 3px; overflow: hidden; }",
    ".progress-bar-fill { height: 100%; background: var(--sb-primary); border-radius: 3px; transition: width 0.3s ease; }",
    ".progress-text { font-size: 12px; color: var(--sb-muted); margin-top: 4px; }",
    // =====================================================
    // UX IMPROVEMENTS - Card Task List (AF02)
    // =====================================================
    ".card-tasks { margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--sb-border); }",
    ".card-tasks-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }",
    ".card-tasks-title { font-size: 13px; font-weight: 600; color: var(--sb-muted); }",
    ".card-task-item { display: flex; align-items: center; gap: 8px; padding: 6px 8px; border-radius: 6px; font-size: 13px; }",
    ".card-task-item:hover { background: var(--sb-hover); }",
    ".card-task-status { width: 16px; height: 16px; flex-shrink: 0; }",
    ".card-task-status.available { color: var(--sb-muted); }",
    ".card-task-status.claimed { color: var(--sb-info); }",
    ".card-task-status.completed { color: var(--sb-success); }",
    // =====================================================
    // UX IMPROVEMENTS - Animations (IF04)
    // =====================================================
    ".modal { animation: modal-fade-in 0.2s ease; }",
    "@keyframes modal-fade-in { from { opacity: 0; } to { opacity: 1; } }",
    ".modal-content { animation: modal-scale-in 0.2s ease; }",
    "@keyframes modal-scale-in { from { opacity: 0; transform: scale(0.95); } to { opacity: 1; transform: scale(1); } }",
    ".toast { animation: toast-slide-in 0.3s ease; }",
    "@keyframes toast-slide-in { from { opacity: 0; transform: translateX(-50%) translateY(-20px); } to { opacity: 1; transform: translateX(-50%) translateY(0); } }",
    // =====================================================
    // STORY 4.8 - Badge Component & Toast Variants
    // =====================================================
    // Badge base styles
    ".badge { display: inline-flex; align-items: center; padding: 2px 8px; border-radius: 999px; font-size: 12px; font-weight: 600; white-space: nowrap; }",
    ".badge-inline { padding: 1px 6px; font-size: 11px; vertical-align: middle; }",
    // Badge variants
    ".badge-primary { background: color-mix(in oklab, var(--sb-primary) 15%, var(--sb-elevated)); border: 1px solid color-mix(in oklab, var(--sb-primary) 40%, var(--sb-border)); color: var(--sb-primary); }",
    ".badge-success { background: color-mix(in oklab, var(--sb-success) 15%, var(--sb-elevated)); border: 1px solid color-mix(in oklab, var(--sb-success) 40%, var(--sb-border)); color: var(--sb-success); }",
    ".badge-warning { background: color-mix(in oklab, var(--sb-warning) 15%, var(--sb-elevated)); border: 1px solid color-mix(in oklab, var(--sb-warning) 40%, var(--sb-border)); color: var(--sb-warning); }",
    ".badge-danger { background: color-mix(in oklab, var(--sb-danger) 15%, var(--sb-elevated)); border: 1px solid color-mix(in oklab, var(--sb-danger) 40%, var(--sb-border)); color: var(--sb-danger); }",
    ".badge-neutral { background: var(--sb-elevated); border: 1px solid var(--sb-border); color: var(--sb-muted); }",
    // Toast container for multiple toasts
    ".toast-container { position: fixed; top: 12px; left: 50%; transform: translateX(-50%); z-index: 50; display: flex; flex-direction: column; gap: 8px; max-width: calc(100vw - 24px); }",
    // Toast variants
    ".toast-success { border-color: color-mix(in oklab, var(--sb-success) 40%, var(--sb-border)); }",
    ".toast-success .toast-icon { color: var(--sb-success); }",
    ".toast-error { border-color: color-mix(in oklab, var(--sb-danger) 40%, var(--sb-border)); }",
    ".toast-error .toast-icon { color: var(--sb-danger); }",
    ".toast-warning { border-color: color-mix(in oklab, var(--sb-warning) 40%, var(--sb-border)); }",
    ".toast-warning .toast-icon { color: var(--sb-warning); }",
    ".toast-info { border-color: color-mix(in oklab, var(--sb-info) 40%, var(--sb-border)); }",
    ".toast-info .toast-icon { color: var(--sb-info); }",
    ".toast-icon { font-size: 14px; flex-shrink: 0; }",
    ".toast-message { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    // Nav icon styling
    ".nav-icon { flex-shrink: 0; }",
    ".nav-icon svg { width: 100%; height: 100%; }",
    // =====================================================
    // STORY 3.4 - Card Colors & Color Picker
    // =====================================================
    // Card border (left edge) for task cards in Pool
    ".card-border-gray { border-left: 4px solid var(--sb-card-gray); }",
    ".card-border-red { border-left: 4px solid var(--sb-card-red); }",
    ".card-border-orange { border-left: 4px solid var(--sb-card-orange); }",
    ".card-border-yellow { border-left: 4px solid var(--sb-card-yellow); }",
    ".card-border-green { border-left: 4px solid var(--sb-card-green); }",
    ".card-border-blue { border-left: 4px solid var(--sb-card-blue); }",
    ".card-border-purple { border-left: 4px solid var(--sb-card-purple); }",
    ".card-border-pink { border-left: 4px solid var(--sb-card-pink); }",
    // Initials badge
    ".card-initials-badge { display: inline-flex; align-items: center; justify-content: center; width: 24px; height: 24px; border-radius: 4px; font-size: 10px; font-weight: 700; color: white; text-transform: uppercase; flex-shrink: 0; }",
    ".card-initials-gray { background: var(--sb-card-gray); }",
    ".card-initials-red { background: var(--sb-card-red); }",
    ".card-initials-orange { background: var(--sb-card-orange); }",
    ".card-initials-yellow { background: var(--sb-card-yellow); }",
    ".card-initials-green { background: var(--sb-card-green); }",
    ".card-initials-blue { background: var(--sb-card-blue); }",
    ".card-initials-purple { background: var(--sb-card-purple); }",
    ".card-initials-pink { background: var(--sb-card-pink); }",
    ".card-initials-none { background: var(--sb-muted); }",
    "@media (max-width: 640px) { .card-initials-badge { width: 20px; height: 20px; font-size: 9px; } }",
    // Color picker dropdown
    ".color-picker { position: relative; }",
    ".color-picker-trigger { display: flex; align-items: center; gap: 8px; padding: 8px 12px; border: 1px solid var(--sb-border); border-radius: 10px; background: var(--sb-elevated); cursor: pointer; min-width: 160px; }",
    ".color-picker-trigger:hover { border-color: var(--sb-primary); }",
    ".color-picker-swatch { width: 16px; height: 16px; border-radius: 50%; flex-shrink: 0; }",
    ".color-picker-swatch-none { border: 2px dashed var(--sb-muted); background: transparent; }",
    ".color-picker-label { flex: 1; }",
    ".color-picker-arrow { margin-left: auto; color: var(--sb-muted); }",
    ".color-picker-dropdown { position: absolute; top: 100%; left: 0; margin-top: 4px; min-width: 180px; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 10px; padding: 6px; box-shadow: 0 10px 30px rgba(0,0,0,0.15); z-index: 50; display: none; }",
    ".color-picker.open .color-picker-dropdown { display: block; }",
    // Story 4.8 UX: Color picker inside dialogs needs higher z-index
    ".dialog .color-picker-dropdown { z-index: 1010; }",
    ".color-picker-option { display: flex; align-items: center; gap: 10px; padding: 8px 10px; border-radius: 6px; cursor: pointer; }",
    ".color-picker-option:hover { background: var(--sb-hover); }",
    ".color-picker-option.selected { background: color-mix(in oklab, var(--sb-primary) 12%, var(--sb-surface)); }",
    ".color-picker-option .color-picker-swatch { border: 2px solid transparent; }",
    ".color-picker-option.selected .color-picker-swatch { border-color: var(--sb-primary); }",
    // Card group header in My Bar
    ".my-bar-card-group { margin-bottom: 16px; }",
    ".my-bar-card-header { display: flex; align-items: center; gap: 12px; padding: 8px 12px; background: var(--sb-surface-elevated, var(--sb-elevated)); border-radius: 8px 8px 0 0; font-weight: 600; font-size: 14px; }",
    ".my-bar-card-tasks { display: flex; flex-direction: column; gap: 8px; padding: 12px; background: var(--sb-surface); border-radius: 0 0 8px 8px; border-left: 4px solid var(--sb-muted); }",
    ".my-bar-card-tasks.card-border-gray { border-left-color: var(--sb-card-gray); }",
    ".my-bar-card-tasks.card-border-red { border-left-color: var(--sb-card-red); }",
    ".my-bar-card-tasks.card-border-orange { border-left-color: var(--sb-card-orange); }",
    ".my-bar-card-tasks.card-border-yellow { border-left-color: var(--sb-card-yellow); }",
    ".my-bar-card-tasks.card-border-green { border-left-color: var(--sb-card-green); }",
    ".my-bar-card-tasks.card-border-blue { border-left-color: var(--sb-card-blue); }",
    ".my-bar-card-tasks.card-border-purple { border-left-color: var(--sb-card-purple); }",
    ".my-bar-card-tasks.card-border-pink { border-left-color: var(--sb-card-pink); }",
    ".my-bar-card-progress { font-size: 12px; color: var(--sb-muted); margin-left: auto; }",
    // Member Fichas section
    ".fichas-list { display: flex; flex-direction: column; gap: 12px; }",
    ".ficha-card { display: flex; flex-direction: column; padding: 14px 16px; border: 1px solid var(--sb-border); border-radius: 10px; background: var(--sb-elevated); cursor: pointer; transition: border-color 0.15s, box-shadow 0.15s; }",
    ".ficha-card:hover { border-color: var(--sb-primary); box-shadow: 0 4px 12px rgba(0,0,0,0.08); }",
    ".ficha-card.card-border-gray, .ficha-card.card-border-red, .ficha-card.card-border-orange, .ficha-card.card-border-yellow, .ficha-card.card-border-green, .ficha-card.card-border-blue, .ficha-card.card-border-purple, .ficha-card.card-border-pink { border-left-width: 4px; }",
    ".ficha-header { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }",
    ".ficha-title { flex: 1; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".ficha-state-badge { display: inline-flex; align-items: center; padding: 2px 8px; border-radius: 999px; font-size: 11px; font-weight: 600; }",
    ".ficha-state-pendiente { background: color-mix(in oklab, var(--sb-muted) 15%, var(--sb-surface)); color: var(--sb-muted); }",
    ".ficha-state-en_curso { background: color-mix(in oklab, var(--sb-warning) 15%, var(--sb-surface)); color: var(--sb-warning); }",
    ".ficha-state-cerrada { background: color-mix(in oklab, var(--sb-success) 15%, var(--sb-surface)); color: var(--sb-success); }",
    ".ficha-description { font-size: 13px; color: var(--sb-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".ficha-meta { display: flex; align-items: center; gap: 12px; margin-top: 8px; font-size: 12px; color: var(--sb-muted); }",
    // Card detail modal
    ".ficha-detail-header { display: flex; align-items: flex-start; gap: 12px; margin-bottom: 16px; }",
    ".ficha-detail-info { flex: 1; }",
    ".ficha-detail-title { font-size: 20px; font-weight: 700; margin-bottom: 8px; }",
    ".ficha-detail-meta { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-bottom: 8px; }",
    ".ficha-detail-description { color: var(--sb-muted); line-height: 1.5; margin-bottom: 16px; }",
    ".ficha-detail-progress { margin-bottom: 16px; }",
    ".ficha-detail-tasks-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }",
    ".ficha-detail-tasks-title { font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; color: var(--sb-muted); }",
    ".ficha-task-item { display: flex; align-items: center; gap: 10px; padding: 10px 12px; border: 1px solid var(--sb-border); border-radius: 8px; background: var(--sb-elevated); margin-bottom: 8px; }",
    ".ficha-task-icon { flex-shrink: 0; font-size: 16px; }",
    ".ficha-task-content { flex: 1; min-width: 0; }",
    ".ficha-task-title { font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".ficha-task-meta { font-size: 12px; color: var(--sb-muted); }",
    ".ficha-task-actions { display: flex; gap: 6px; flex-shrink: 0; }",
    // Add task form inside card detail
    ".ficha-add-task-form { padding: 12px; border: 1px dashed var(--sb-border); border-radius: 8px; background: var(--sb-surface); margin-bottom: 12px; }",
    ".ficha-add-task-form .field { margin: 0 0 10px 0; }",
    ".ficha-add-task-form .field:last-child { margin-bottom: 0; }",
    ".ficha-add-task-actions { display: flex; gap: 8px; justify-content: flex-end; }",
    // Card detail modal
    ".card-detail-modal { position: fixed; inset: 0; z-index: 40; display: flex; align-items: center; justify-content: center; padding: 16px; }",
    ".card-detail-modal .modal-backdrop { position: absolute; inset: 0; background: rgba(0,0,0,0.5); z-index: 1; }",
    ".modal-content.card-detail { border-left-width: 4px; z-index: 2; position: relative; }",
    ".card-detail-header { padding-bottom: 16px; border-bottom: 1px solid var(--sb-border); margin-bottom: 16px; }",
    ".card-detail-title-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 12px; }",
    ".card-detail-title { font-size: 20px; font-weight: 700; }",
    ".card-detail-meta { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-bottom: 12px; }",
    ".card-state-badge { display: inline-flex; align-items: center; padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }",
    ".card-state-pendiente { background: color-mix(in oklab, var(--sb-muted) 15%, var(--sb-surface)); color: var(--sb-muted); }",
    ".card-state-en_curso { background: color-mix(in oklab, var(--sb-warning) 15%, var(--sb-surface)); color: var(--sb-warning); }",
    ".card-state-cerrada { background: color-mix(in oklab, var(--sb-success) 15%, var(--sb-surface)); color: var(--sb-success); }",
    ".card-detail-progress-text { font-size: 14px; color: var(--sb-muted); }",
    ".card-detail-progress-bar { width: 100%; height: 8px; background: var(--sb-border); border-radius: 4px; overflow: hidden; margin-bottom: 12px; }",
    ".card-detail-progress-fill { height: 100%; background: var(--sb-primary); border-radius: 4px; transition: width 0.3s ease; }",
    ".card-detail-description { color: var(--sb-muted); line-height: 1.5; }",
    // AC21: Card modal tabs
    ".card-tabs { display: flex; border-bottom: 2px solid var(--sb-border); margin-bottom: 16px; gap: 4px; }",
    ".card-tab { padding: 10px 16px; background: transparent; border: none; border-bottom: 2px solid transparent; margin-bottom: -2px; cursor: pointer; font-size: 14px; font-weight: 500; color: var(--sb-muted); transition: all 0.15s; display: flex; align-items: center; gap: 6px; }",
    ".card-tab:hover { color: var(--sb-text); border-bottom-color: var(--sb-border); }",
    ".card-tab.tab-active { color: var(--sb-primary); border-bottom-color: var(--sb-primary); }",
    ".tab-count { font-size: 12px; color: var(--sb-muted); }",
    ".tab-active .tab-count { color: var(--sb-primary); }",
    ".new-notes-indicator { color: var(--sb-warning); font-size: 10px; margin-left: 2px; }",
    ".card-detail-activity-section { padding: 24px; text-align: center; color: var(--sb-muted); }",
    // Shared section header for card detail tabs (Tasks, Notes)
    ".card-section-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }",
    ".card-section-title { font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; color: var(--sb-muted); }",
    ".card-detail-tasks-section { }",
    ".card-detail-notes-section { }",
    // Note dialog (modal within card detail modal)
    ".note-dialog-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.4); display: flex; align-items: center; justify-content: center; z-index: 1100; }",
    ".note-dialog { background: var(--sb-elevated); border-radius: 8px; padding: 16px; min-width: 320px; max-width: 90%; box-shadow: 0 4px 20px rgba(0,0,0,0.2); }",
    ".note-dialog-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }",
    ".note-dialog-title { font-size: 16px; font-weight: 600; color: var(--sb-text); }",
    ".note-dialog-body { margin-bottom: 12px; }",
    ".note-dialog-footer { display: flex; justify-content: flex-end; gap: 8px; }",
    // Task notes section (Story 5.4 UX unification)
    ".task-notes-section { position: relative; }",
    ".task-notes-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-weight: 500; }",
    // Task Detail Modal (Story 5.4.1)
    ".task-detail-modal { position: fixed; inset: 0; z-index: 1000; display: flex; align-items: center; justify-content: center; }",
    ".task-detail-modal .modal-backdrop { position: absolute; inset: 0; background: rgba(0,0,0,0.5); z-index: 1; }",
    ".task-detail-modal .modal-content { position: relative; background: var(--sb-surface); border-radius: 12px; max-width: 600px; width: 90%; max-height: 80vh; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 8px 32px rgba(0,0,0,0.2); z-index: 2; }",
    ".task-detail-header { padding: 20px 20px 16px; border-bottom: 1px solid var(--sb-border); position: relative; }",
    ".task-detail-header .modal-close { position: absolute; top: 16px; right: 16px; background: none; border: none; font-size: 24px; color: var(--sb-muted); cursor: pointer; padding: 4px 8px; line-height: 1; }",
    ".task-detail-header .modal-close:hover { color: var(--sb-text); }",
    ".task-detail-title { font-size: 1.25rem; font-weight: 600; margin: 0 0 12px 0; padding-right: 40px; color: var(--sb-text); }",
    ".task-detail-meta { display: flex; flex-wrap: wrap; gap: 8px; font-size: 0.875rem; color: var(--sb-muted); }",
    ".task-meta-chip { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 999px; border: 1px solid var(--sb-border); background: var(--sb-elevated); color: var(--sb-text); font-size: 12px; font-weight: 500; }",
    ".task-meta-assignee.muted { color: var(--sb-muted); opacity: 0.7; }",
    // Task tabs (aligned with card-tabs)
    ".task-tabs { display: flex; border-bottom: 2px solid var(--sb-border); margin-bottom: 16px; gap: 4px; }",
    ".task-tab { padding: 10px 16px; background: transparent; border: none; border-bottom: 2px solid transparent; margin-bottom: -2px; cursor: pointer; font-size: 14px; font-weight: 500; color: var(--sb-muted); transition: all 0.15s; display: flex; align-items: center; gap: 6px; }",
    ".task-tab:hover { color: var(--sb-text); border-bottom-color: var(--sb-border); }",
    ".task-tab.tab-active { color: var(--sb-primary); border-bottom-color: var(--sb-primary); }",
    ".task-tab .tab-count { font-size: 0.85em; }",
    ".task-tab .new-notes-indicator { color: var(--sb-accent); font-size: 0.7em; margin-left: 4px; animation: pulse 2s infinite; }",
    // Task detail tab content
    ".task-details-section { padding: 20px; overflow-y: auto; flex: 1; }",
    ".task-detail-grid { display: grid; gap: 14px; }",
    ".detail-row { display: grid; grid-template-columns: 140px minmax(0, 1fr); align-items: center; gap: 12px; }",
    ".detail-label { font-weight: 600; color: var(--sb-muted); }",
    ".detail-value { color: var(--sb-text); }",
    ".detail-value.muted { color: var(--sb-muted); }",
    ".task-dependencies-section { padding: 20px; overflow-y: auto; flex: 1; }",
    ".task-dependencies-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }",
    ".task-dependencies-list { display: flex; flex-direction: column; gap: 8px; }",
    ".task-dependency-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 8px 10px; border: 1px solid var(--sb-border); border-radius: 10px; background: var(--sb-elevated); }",
    ".task-dependency-main { display: flex; align-items: center; gap: 10px; }",
    ".task-dependency-icon { color: var(--sb-warning); }",
    ".task-dependency-text { display: flex; flex-direction: column; gap: 2px; }",
    ".task-dependency-title { font-weight: 600; }",
    ".task-dependency-status { font-size: 12px; color: var(--sb-muted); }",
    ".task-dependency-remove { color: var(--sb-muted); }",
    ".task-dependency-candidates { display: flex; flex-direction: column; gap: 6px; max-height: 240px; overflow-y: auto; }",
    ".dependency-candidate { display: flex; justify-content: space-between; gap: 10px; padding: 8px 10px; border: 1px solid var(--sb-border); border-radius: 8px; background: var(--sb-surface); text-align: left; }",
    ".dependency-candidate.selected { border-color: var(--sb-primary); background: color-mix(in oklab, var(--sb-primary) 10%, var(--sb-surface)); }",
    ".dependency-candidate-title { font-weight: 600; }",
    ".dependency-candidate-status { font-size: 12px; color: var(--sb-muted); }",
    ".search-select { display: flex; flex-direction: column; gap: 10px; }",
    ".search-select-label { font-size: 13px; font-weight: 600; }",
    ".search-select-results { display: flex; flex-direction: column; gap: 6px; max-height: 240px; overflow-y: auto; }",
    ".search-select-item { display: flex; align-items: center; gap: 10px; justify-content: space-between; padding: 8px 10px; border: 1px solid var(--sb-border); border-radius: 8px; background: var(--sb-surface); }",
    ".search-select-primary { font-weight: 600; }",
    ".search-select-secondary { font-size: 12px; color: var(--sb-muted); }",
    ".task-blocked { opacity: 0.6; }",
    ".task-blocked-badge { display: inline-flex; align-items: center; gap: 4px; padding: 2px 6px; border-radius: 999px; border: 1px solid color-mix(in oklab, var(--sb-warning) 40%, var(--sb-border)); background: color-mix(in oklab, var(--sb-warning) 12%, var(--sb-surface)); color: var(--sb-warning); font-size: 11px; font-weight: 600; line-height: 1; }",
    ".task-blocked-count { font-size: 11px; font-weight: 600; }",
    ".task-blocked-inline { margin-left: 6px; }",
    ".task-blocked-card { font-size: 10px; }",
    ".task-item-meta { display: inline-flex; align-items: center; gap: 6px; flex-wrap: wrap; }",
    ".blocked-claim-title { font-weight: 600; margin-bottom: 6px; }",
    ".blocked-claim-warning { color: var(--sb-muted); margin-bottom: 8px; }",
    ".blocked-claim-list { margin: 0; padding-left: 18px; display: flex; flex-direction: column; gap: 4px; }",
    // Modal footer
    ".task-detail-modal .modal-footer { padding: 16px 20px; border-top: 1px solid var(--sb-border); display: flex; justify-content: flex-end; gap: 10px; background: var(--sb-surface); }",
    ".task-detail-footer { align-items: center; }",
    ".task-section-hint { font-size: 13px; color: var(--sb-muted); margin-bottom: 12px; }",
    ".task-empty-state { display: flex; flex-direction: column; gap: 6px; padding: 14px; border: 1px dashed var(--sb-border); border-radius: 10px; background: color-mix(in oklab, var(--sb-elevated) 94%, var(--sb-bg)); }",
    ".task-empty-title { font-weight: 600; color: var(--sb-text); }",
    ".task-empty-body { color: var(--sb-muted); font-size: 13px; }",
    ".card-add-task-form { padding: 16px; border: 1px dashed var(--sb-border); border-radius: 8px; background: var(--sb-surface); margin-bottom: 16px; }",
    ".form-group { display: flex; flex-direction: column; gap: 6px; margin-bottom: 12px; }",
    ".form-group label { font-size: 13px; font-weight: 500; color: var(--sb-muted); }",
    ".form-group-optional { border: 1px dashed color-mix(in oklab, var(--sb-border) 60%, var(--sb-bg)); border-radius: 8px; padding: 6px 8px; background: color-mix(in oklab, var(--sb-surface) 94%, var(--sb-bg)); }",
    ".form-group-optional label { color: var(--sb-muted); }",
    ".form-group-optional .optional-title { font-weight: 600; font-size: 12px; text-transform: uppercase; letter-spacing: 0.04em; color: color-mix(in oklab, var(--sb-muted) 85%, var(--sb-bg)); }",
    ".form-group-optional .optional-fields { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; margin-top: 6px; align-items: stretch; }",
    "@media (max-width: 640px) { .form-group-optional .optional-fields { grid-template-columns: 1fr; } }",
    ".form-input { padding: 10px 12px; border: 1px solid var(--sb-border); border-radius: 8px; background: var(--sb-elevated); color: var(--sb-text); font-size: 14px; }",
    ".form-row { display: flex; gap: 16px; }",
    ".form-group-half { flex: 1; }",
    ".form-static { font-size: 14px; padding: 10px 0; }",
    ".form-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 16px; }",
    ".priority-dots { display: flex; gap: 6px; padding: 8px 0; }",
    ".priority-dot { width: 20px; height: 20px; border-radius: 50%; background: var(--sb-border); border: 2px solid var(--sb-border); cursor: pointer; transition: all 0.15s; padding: 0; }",
    ".priority-dot.active { background: var(--sb-primary); border-color: var(--sb-primary); }",
    ".priority-dot:hover { border-color: var(--sb-primary); }",
    ".card-tasks-empty { text-align: center; padding: 24px; color: var(--sb-muted); }",
    ".card-task-list { display: flex; flex-direction: column; gap: 8px; }",
    ".card-task-item { display: flex; align-items: center; gap: 12px; padding: 12px; border: 1px solid var(--sb-border); border-radius: 8px; background: var(--sb-elevated); }",
    ".card-task-status { font-size: 16px; flex-shrink: 0; }",
    ".card-task-title { flex: 1; font-weight: 500; }",
    ".card-task-info { font-size: 12px; color: var(--sb-muted); }",
    ".btn-sm { padding: 6px 12px; font-size: 13px; }",
    ".btn-primary { background: var(--sb-primary); border-color: var(--sb-primary); color: var(--sb-inverse); }",
    ".btn-primary:hover { background: var(--sb-primary-hover); border-color: var(--sb-primary-hover); }",
    ".btn-secondary { background: var(--sb-elevated); border-color: var(--sb-border); color: var(--sb-text); }",
    ".btn-secondary:hover { border-color: var(--sb-primary); }",
    // Chip buttons (for quick actions like date ranges)
    ".btn-chip { padding: 4px 12px; font-size: 13px; border-radius: 999px; background: var(--sb-elevated); border: 1px solid var(--sb-border); color: var(--sb-text); cursor: pointer; transition: all 0.15s ease; }",
    ".btn-chip:hover { border-color: var(--sb-primary); background: color-mix(in oklab, var(--sb-primary) 10%, var(--sb-elevated)); }",
    // Button with icon
    ".btn-icon-left { margin-right: 6px; font-weight: 700; }",
    ".btn-spinner { display: inline-block; width: 14px; height: 14px; margin-right: 6px; border: 2px solid currentColor; border-right-color: transparent; border-radius: 50%; animation: btn-spin 0.6s linear infinite; }",
    // Quick ranges container
    ".quick-ranges { display: flex; align-items: center; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }",
    ".quick-ranges-label { font-size: 13px; color: var(--sb-muted); }",
    // Loading state
    ".loading-state { display: flex; align-items: center; justify-content: center; gap: 12px; padding: 32px; color: var(--sb-muted); }",
    ".loading-spinner { width: 24px; height: 24px; border: 3px solid var(--sb-border); border-top-color: var(--sb-primary); border-radius: 50%; animation: btn-spin 0.8s linear infinite; }",
    // Error state
    ".error-state { display: flex; align-items: center; gap: 12px; padding: 16px; background: color-mix(in oklab, var(--sb-danger) 10%, var(--sb-surface)); border: 1px solid color-mix(in oklab, var(--sb-danger) 30%, var(--sb-border)); border-radius: 10px; color: var(--sb-danger); }",
    ".error-icon { font-size: 1.2em; }",
    // My bar card groups
    ".my-bar-card-groups { display: flex; flex-direction: column; gap: 16px; }",
    ".my-bar-card-group { border: 1px solid var(--sb-border); border-radius: 10px; overflow: hidden; }",
    ".my-bar-card-group.card-border-gray, .my-bar-card-group.card-border-red, .my-bar-card-group.card-border-orange, .my-bar-card-group.card-border-yellow, .my-bar-card-group.card-border-green, .my-bar-card-group.card-border-blue, .my-bar-card-group.card-border-purple, .my-bar-card-group.card-border-pink { border-left-width: 4px; }",
    ".my-bar-card-header { display: flex; align-items: center; gap: 10px; padding: 10px 14px; background: var(--sb-elevated); border-bottom: 1px solid var(--sb-border); }",
    ".my-bar-card-title { flex: 1; font-weight: 600; font-size: 14px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".my-bar-card-progress { font-size: 13px; color: var(--sb-muted); flex-shrink: 0; }",
    ".my-bar-card-group > .task-list { padding: 8px 10px; }",
    // Mobile adaptations
    "@media (max-width: 640px) { .my-bar-card-groups { gap: 12px; } .my-bar-card-header { padding: 8px 10px; gap: 8px; } .my-bar-card-title { font-size: 13px; } .my-bar-card-progress { font-size: 12px; } }",
    "@media (max-width: 640px) { .fichas-list { gap: 8px; } .ficha-card { padding: 10px 12px; } .ficha-header { gap: 8px; } .ficha-title { font-size: 14px; } .ficha-state-badge { font-size: 10px; padding: 2px 6px; } }",
    "@media (max-width: 640px) { .card-detail-modal { padding: 8px; } .modal-content.card-detail { padding: 12px; } .card-detail-title { font-size: 18px; } .card-detail-tasks-section { } .card-add-task-form { padding: 12px; } }",
    // =====================================================
    // STORY 3.5 - Unified Dialog System
    // =====================================================
    // Dialog overlay
    ".dialog-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; padding: 16px; z-index: 1000; animation: dialog-fade-in 0.2s ease; }",
    "@keyframes dialog-fade-in { from { opacity: 0; } to { opacity: 1; } }",
    // Dialog container
    ".dialog { position: relative; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 16px; padding: 0; max-height: calc(100vh - 32px); display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3); animation: dialog-scale-in 0.2s ease; }",
    "@keyframes dialog-scale-in { from { opacity: 0; transform: scale(0.95); } to { opacity: 1; transform: scale(1); } }",
    // Dialog sizes
    ".dialog-sm { width: min(400px, 100%); }",
    ".dialog-md { width: min(520px, 100%); }",
    ".dialog-lg { width: min(680px, 100%); }",
    ".dialog-lg-tight { width: min(620px, 100%); }",
    ".dialog-xl { width: min(860px, 100%); }",
    // Dialog header
    ".dialog-header { display: flex; align-items: center; justify-content: space-between; padding: 16px 20px; border-bottom: 1px solid var(--sb-border); }",
    ".dialog-title { display: flex; align-items: center; gap: 10px; }",
    ".dialog-title h3 { margin: 0; font-size: 18px; font-weight: 600; }",
    ".dialog-icon { font-size: 20px; }",
    ".dialog-close { display: inline-flex; align-items: center; justify-content: center; width: 32px; height: 32px; border: none; background: transparent; color: var(--sb-muted); cursor: pointer; border-radius: 8px; font-size: 18px; line-height: 1; }",
    ".dialog-close:hover { background: var(--sb-hover); color: var(--sb-text); }",
    // Dialog body
    ".dialog-body { padding: 20px; overflow-y: auto; flex: 1; }",
    // Story 4.8 UX: Allow color picker dropdown to overflow dialog-body when open
    ".dialog-body:has(.color-picker.open) { overflow: visible; }",
    // Dialog error
    ".dialog-error { display: flex; align-items: center; gap: 8px; padding: 10px 16px; background: color-mix(in oklab, var(--sb-danger) 10%, var(--sb-surface)); border: 1px solid color-mix(in oklab, var(--sb-danger) 30%, var(--sb-border)); border-radius: 10px; margin: 0 20px 0 20px; margin-top: -4px; color: var(--sb-danger); font-size: 14px; }",
    // Dialog footer
    ".dialog-footer { display: flex; justify-content: flex-end; gap: 12px; padding: 16px 20px; border-top: 1px solid var(--sb-border); }",
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
    // Three-panel layout (Story 4.4)
    // =============================================================================
    // Base layout - desktop 3 columns
    ".three-panel-layout { display: grid; grid-template-columns: 240px 1fr 300px; gap: 12px; min-height: calc(100vh - 48px); }",
    // Left panel (navigation)
    ".panel-left { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 8px; position: sticky; top: 12px; max-height: calc(100vh - 48px); overflow-y: auto; }",
    // Center panel (main content)
    ".panel-center { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; min-width: 0; }",
    // Right panel (activity/profile)
    ".panel-right { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 10px; position: sticky; top: 12px; max-height: calc(100vh - 48px); overflow-y: auto; }",
    // Tablet: 2 columns (left + center, right as drawer)
    "@media (max-width: 1024px) { .three-panel-layout { grid-template-columns: 220px 1fr; } .panel-right { display: none; } }",
    // Mobile: 1 column (center only, both panels as drawers)
    "@media (max-width: 768px) { .three-panel-layout { grid-template-columns: 1fr; } .panel-left { display: none; } .panel-right { display: none; } }",
    // =============================================================================
    // Left Panel Components (Story 4.4)
    // =============================================================================
    ".left-panel-content { display: flex; flex-direction: column; gap: 16px; }",
    ".project-selector-section { margin-bottom: 8px; }",
    ".project-selector-dropdown { width: 100%; padding: 10px 12px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-elevated); font-weight: 500; }",
    ".panel-section { display: flex; flex-direction: column; gap: 8px; }",
    ".section-title { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--sb-muted); margin: 0 0 4px 0; }",
    ".btn-action { display: flex; align-items: center; gap: 8px; width: 100%; padding: 8px 12px; text-align: left; background: transparent; border: 1px solid transparent; border-radius: 8px; cursor: pointer; color: var(--sb-text); }",
    ".btn-action:hover { background: var(--sb-elevated); }",
    ".btn-action:disabled { opacity: 0.5; cursor: not-allowed; }",
    ".btn-icon-prefix { font-weight: 700; color: var(--sb-primary); }",
    // Primary action buttons (Story 4.8 UX: solid button for clear affordance)
    ".btn-action-primary { background: var(--sb-primary); border: 1px solid var(--sb-primary); color: var(--sb-inverse); font-weight: 500; }",
    ".btn-action-primary:hover { background: var(--sb-primary-hover); border-color: var(--sb-primary-hover); }",
    ".btn-action-primary .btn-icon-prefix { color: inherit; }",
    ".btn-primary .btn-icon-prefix { color: inherit; }",
    // Navigation links within TRABAJO section (Story 4.7 AC2, AC3)
    ".nav-links { display: flex; flex-direction: column; gap: 2px; margin-top: 8px; }",
    ".nav-link { display: flex; align-items: center; gap: 8px; width: 100%; padding: 8px 12px; text-align: left; background: transparent; border: 1px solid transparent; border-radius: 8px; cursor: pointer; color: var(--sb-text); }",
    ".nav-link:hover { background: var(--sb-elevated); }",
    ".nav-link:disabled { opacity: 0.5; cursor: not-allowed; }",
    ".nav-link.active { background: var(--sb-elevated); border-color: var(--sb-primary); }",
    ".nav-icon { font-size: 14px; }",
    ".nav-label { flex: 1; }",
    ".active-indicator { color: var(--sb-primary); font-size: 8px; }",
    // =============================================================================
    // Right Panel Components (Story 4.4)
    // =============================================================================
    ".right-panel-content { display: flex; flex-direction: column; gap: 16px; height: 100%; }",
    ".active-task-section, .my-tasks-section, .my-cards-section { display: flex; flex-direction: column; gap: 8px; }",
    ".active-task-card { background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 10px; padding: 12px; position: relative; }",
    ".active-task-card.card-border-gray, .active-task-card.card-border-red, .active-task-card.card-border-orange, .active-task-card.card-border-yellow, .active-task-card.card-border-green, .active-task-card.card-border-blue, .active-task-card.card-border-purple, .active-task-card.card-border-pink { border-left-width: 4px; border-left-style: solid; }",
    ".active-task-card.card-border-gray { border-left-color: var(--sb-card-gray); }",
    ".active-task-card.card-border-red { border-left-color: var(--sb-card-red); }",
    ".active-task-card.card-border-orange { border-left-color: var(--sb-card-orange); }",
    ".active-task-card.card-border-yellow { border-left-color: var(--sb-card-yellow); }",
    ".active-task-card.card-border-green { border-left-color: var(--sb-card-green); }",
    ".active-task-card.card-border-blue { border-left-color: var(--sb-card-blue); }",
    ".active-task-card.card-border-purple { border-left-color: var(--sb-card-purple); }",
    ".active-task-card.card-border-pink { border-left-color: var(--sb-card-pink); }",
    ".active-tasks-list { display: flex; flex-direction: column; gap: 8px; max-height: 200px; overflow-y: auto; }",
    ".active-tasks-list .active-task-card { padding: 10px; }",
    ".active-tasks-list .task-timer { font-size: 18px; margin: 4px 0; }",
    ".task-timer { font-size: 24px; font-weight: 700; font-variant-numeric: tabular-nums; text-align: center; margin: 8px 0; }",
    ".task-actions { display: flex; gap: 8px; justify-content: center; }",
    ".task-list { display: flex; flex-direction: column; gap: 6px; }",
    ".task-item { display: flex; align-items: center; justify-content: space-between; padding: 8px 10px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 8px; gap: 8px; }",
    ".task-item.card-border-gray, .task-item.card-border-red, .task-item.card-border-orange, .task-item.card-border-yellow, .task-item.card-border-green, .task-item.card-border-blue, .task-item.card-border-purple, .task-item.card-border-pink { border-left-width: 4px; border-left-style: solid; }",
    ".task-item.card-border-gray { border-left-color: var(--sb-card-gray); }",
    ".task-item.card-border-red { border-left-color: var(--sb-card-red); }",
    ".task-item.card-border-orange { border-left-color: var(--sb-card-orange); }",
    ".task-item.card-border-yellow { border-left-color: var(--sb-card-yellow); }",
    ".task-item.card-border-green { border-left-color: var(--sb-card-green); }",
    ".task-item.card-border-blue { border-left-color: var(--sb-card-blue); }",
    ".task-item.card-border-purple { border-left-color: var(--sb-card-purple); }",
    ".task-item.card-border-pink { border-left-color: var(--sb-card-pink); }",
    ".task-title-row { display: flex; align-items: center; gap: 6px; flex: 1; min-width: 0; }",
    ".task-type-icon { flex-shrink: 0; display: flex; align-items: center; justify-content: center; }",
    ".task-item .task-title { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 13px; }",
    ".task-item .task-actions { display: flex; gap: 4px; flex-shrink: 0; }",
    ".active-task-card .task-title-row { justify-content: center; }",
    ".active-task-card .task-title { text-align: center; font-weight: 500; }",
    // My cards list (right panel)
    ".my-cards-list { display: flex; flex-direction: column; gap: 6px; }",
    ".my-card-item { display: flex; flex-direction: column; gap: 4px; width: 100%; padding: 10px 12px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 8px; cursor: pointer; text-align: left; }",
    ".my-card-item.card-border-gray, .my-card-item.card-border-red, .my-card-item.card-border-orange, .my-card-item.card-border-yellow, .my-card-item.card-border-green, .my-card-item.card-border-blue, .my-card-item.card-border-purple, .my-card-item.card-border-pink { border-left-width: 4px; border-left-style: solid; }",
    ".my-card-item.card-border-gray { border-left-color: var(--sb-card-gray); }",
    ".my-card-item.card-border-red { border-left-color: var(--sb-card-red); }",
    ".my-card-item.card-border-orange { border-left-color: var(--sb-card-orange); }",
    ".my-card-item.card-border-yellow { border-left-color: var(--sb-card-yellow); }",
    ".my-card-item.card-border-green { border-left-color: var(--sb-card-green); }",
    ".my-card-item.card-border-blue { border-left-color: var(--sb-card-blue); }",
    ".my-card-item.card-border-purple { border-left-color: var(--sb-card-purple); }",
    ".my-card-item.card-border-pink { border-left-color: var(--sb-card-pink); }",
    ".my-card-item:hover { border-color: var(--sb-primary); background: var(--sb-surface); }",
    ".my-card-item .card-title { font-weight: 500; font-size: 14px; }",
    ".card-progress-row { display: flex; align-items: center; gap: 8px; }",
    ".progress-bar-mini { flex: 1; height: 4px; background: var(--sb-border); border-radius: 2px; overflow: hidden; }",
    ".progress-bar-mini .progress-bar-fill { height: 100%; background: var(--sb-primary); border-radius: 2px; }",
    ".card-progress { font-size: 12px; color: var(--sb-muted); font-variant-numeric: tabular-nums; }",
    // My Metrics section (Story 4.7 Task 6.1)
    // Right panel layout (Story 4.8 UX)
    ".right-panel-activity { display: flex; flex-direction: column; gap: 16px; flex: 1; }",
    ".right-panel-footer { display: flex; flex-direction: column; gap: 12px; margin-top: auto; padding-top: 16px; border-top: 1px solid var(--sb-border); }",
    // Section titles with icons (Story 4.8 UX)
    ".section-title-with-icon { display: flex; align-items: center; gap: 8px; }",
    ".section-title-with-icon .nav-icon { color: var(--sb-muted); }",
    // Preferences popup (Story 4.8 UX: moved from inline to popup)
    ".preferences-popup-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.3); display: flex; align-items: center; justify-content: center; z-index: 1000; }",
    ".preferences-popup { background: var(--sb-surface); border-radius: 12px; padding: 20px; min-width: 280px; max-width: 320px; box-shadow: 0 8px 32px rgba(0,0,0,0.2); }",
    ".popup-title { display: flex; align-items: center; gap: 8px; margin: 0 0 16px 0; font-size: 16px; font-weight: 600; }",
    ".popup-title .nav-icon { color: var(--sb-muted); }",
    ".preferences-popup-content { display: flex; flex-direction: column; gap: 12px; }",
    ".preference-item { display: flex; align-items: center; gap: 8px; cursor: pointer; }",
    ".preference-icon { display: flex; align-items: center; color: var(--sb-muted); }",
    ".preference-select { flex: 1; padding: 8px 12px; border-radius: 8px; border: 1px solid var(--sb-border); background: var(--sb-elevated); font-size: 14px; cursor: pointer; }",
    ".preference-select:hover { border-color: var(--sb-primary); }",
    // Profile section (Story 4.8 UX: compact with icon buttons)
    ".profile-section { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 12px 0; }",
    ".profile-section .user-info { display: flex; align-items: center; gap: 6px; flex: 1; min-width: 0; }",
    ".profile-section .user-info .nav-icon { color: var(--sb-muted); flex-shrink: 0; }",
    ".profile-section .user-email { font-size: 13px; color: var(--sb-text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".profile-actions { display: flex; align-items: center; gap: 4px; flex-shrink: 0; }",
    ".btn-icon-only { display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; padding: 0; background: transparent; border: 1px solid transparent; border-radius: 8px; cursor: pointer; color: var(--sb-muted); transition: all 0.15s ease; }",
    ".btn-icon-only:hover { background: var(--sb-elevated); color: var(--sb-text); border-color: var(--sb-border); }",
    ".btn-icon-only.btn-logout:hover { color: var(--sb-error); border-color: var(--sb-error); }",
    // =============================================================================
    // View Mode Toggle (Story 4.4)
    // =============================================================================
    ".view-mode-toggle { display: inline-flex; gap: 4px; padding: 4px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; }",
    ".view-mode-btn { display: flex; align-items: center; gap: 6px; padding: 8px 12px; background: transparent; border: none; border-radius: 8px; cursor: pointer; color: var(--sb-text); transition: all 0.15s ease; }",
    ".view-mode-btn:hover { background: var(--sb-surface); }",
    ".view-mode-btn.active { background: var(--sb-primary); color: var(--sb-inverse); }",
    ".view-mode-icon { font-size: 16px; }",
    ".view-mode-label { font-size: 14px; font-weight: 500; }",
    "@media (max-width: 768px) { .view-mode-label { display: none; } }",
    // =============================================================================
    // Center Panel / Toolbar (Story 4.4)
    // =============================================================================
    ".center-panel-content { display: flex; flex-direction: column; gap: 12px; height: 100%; }",
    ".center-toolbar { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }",
    ".center-filters { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; margin-left: auto; }",
    ".filter-field { display: flex; flex-direction: column; gap: 4px; }",
    ".filter-field label { font-size: 11px; color: var(--sb-muted); }",
    ".filter-field select, .filter-field input { padding: 6px 10px; border-radius: 8px; border: 1px solid var(--sb-border); background: var(--sb-elevated); min-width: 120px; }",
    ".filter-search input { min-width: 160px; }",
    ".center-content { flex: 1; overflow: auto; }",
    // =============================================================================
    // Grouped List View (Story 4.4)
    // =============================================================================
    ".grouped-list { display: flex; flex-direction: column; gap: 12px; }",
    ".grouped-list-empty { text-align: center; color: var(--sb-muted); padding: 40px 20px; }",
    ".card-group { background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; overflow: hidden; }",
    ".card-group-header { display: flex; align-items: center; gap: 10px; width: 100%; padding: 12px 16px; background: transparent; border: none; cursor: pointer; text-align: left; }",
    ".card-group-header:hover { background: var(--sb-surface); }",
    ".expand-icon { font-size: 12px; color: var(--sb-muted); width: 16px; }",
    ".card-title { flex: 1; font-weight: 500; }",
    ".card-progress { font-size: 13px; color: var(--sb-muted); }",
    ".card-color-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }",
    ".card-task-list { list-style: none; margin: 0; padding: 0 16px 12px 16px; display: flex; flex-direction: column; gap: 6px; }",
    ".task-item-content { flex: 1; background: transparent; border: none; cursor: pointer; text-align: left; display: flex; justify-content: space-between; align-items: center; gap: 8px; padding: 0; }",
    ".task-status { font-size: 12px; color: var(--sb-muted); }",
    ".task-status-muted { font-size: 12px; color: var(--sb-muted); }",
    // AC7: Claimed by user display
    ".task-claimed-by { font-size: 12px; color: var(--sb-muted); font-style: italic; display: inline-flex; align-items: center; gap: 4px; }",
    ".task-claimed-icon { display: inline-flex; align-items: center; }",
    // AC9: Claim button as icon with tooltip
    ".btn-claim { background: var(--sb-success); color: white; border-color: var(--sb-success); }",
    ".btn-claim.btn-icon { padding: 6px; border-radius: 6px; display: flex; align-items: center; justify-content: center; min-width: 28px; min-height: 28px; }",
    ".btn-claim.btn-icon:hover { background: var(--sb-success-hover, #059669); }",
    // =============================================================================
    // Kanban Board View (Story 4.4)
    // =============================================================================
    ".kanban-board { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; height: 100%; min-height: 400px; }",
    "@media (max-width: 900px) { .kanban-board { grid-template-columns: 1fr; } }",
    ".kanban-column { background: var(--sb-bg); border: 1px solid var(--sb-border); border-radius: 12px; display: flex; flex-direction: column; min-height: 200px; }",
    ".kanban-column.pendiente { border-top: 3px solid var(--sb-muted); }",
    ".kanban-column.en-curso { border-top: 3px solid var(--sb-primary); }",
    ".kanban-column.cerrada { border-top: 3px solid var(--sb-success); }",
    ".kanban-column-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid var(--sb-border); }",
    ".kanban-column-header h4 { margin: 0; font-size: 14px; font-weight: 600; }",
    ".column-count { font-size: 12px; color: var(--sb-muted); background: var(--sb-elevated); padding: 2px 8px; border-radius: 10px; }",
    ".kanban-column-content { flex: 1; padding: 12px; display: flex; flex-direction: column; gap: 10px; overflow-y: auto; }",
    ".kanban-empty-column { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; padding: 24px 16px; border: 2px dashed var(--sb-border); border-radius: 10px; color: var(--sb-muted); text-align: center; min-height: 100px; }",
    ".kanban-empty-column .empty-icon { font-size: 24px; opacity: 0.6; }",
    ".kanban-empty-column .empty-text { font-size: 13px; }",
    ".kanban-card { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 10px; padding: 12px; }",
    ".kanban-card-header { display: flex; align-items: flex-start; gap: 8px; margin-bottom: 8px; }",
    ".kanban-card-title { flex: 1; background: transparent; border: none; cursor: pointer; text-align: left; font-weight: 500; padding: 0; display: flex; align-items: center; gap: 6px; }",
    ".kanban-card-title:hover { color: var(--sb-primary); }",
    ".card-notes-indicator { font-weight: 600; color: var(--sb-warning); }",
    ".kanban-card-menu { display: flex; gap: 4px; opacity: 0; transition: opacity 0.15s; }",
    ".kanban-card:hover .kanban-card-menu { opacity: 1; }",
    ".kanban-card-desc { font-size: 13px; color: var(--sb-muted); margin-bottom: 8px; line-height: 1.4; }",
    ".kanban-card-progress { display: flex; align-items: center; gap: 8px; }",
    // Note: .progress-bar defined in UX IMPROVEMENTS section (L385). kanban uses flex container for layout.
    ".kanban-card-progress .progress-bar { flex: 1; }",
    ".progress-fill { height: 100%; background: var(--sb-success); transition: width 0.3s ease; }",
    ".progress-text { font-size: 12px; color: var(--sb-muted); min-width: 40px; text-align: right; }",
    // =============================================================================
    // Kanban Task Items (Story 4.8 UX - Homogeneous with Lista view)
    // =============================================================================
    ".kanban-card-tasks { margin-top: 8px; padding-top: 8px; border-top: 1px solid var(--sb-border); display: flex; flex-direction: column; gap: 4px; }",
    ".kanban-task-item { display: flex; align-items: center; gap: 6px; padding: 4px 6px; border-radius: 6px; font-size: 12px; transition: background 0.15s; }",
    ".kanban-task-item.card-border-gray, .kanban-task-item.card-border-red, .kanban-task-item.card-border-orange, .kanban-task-item.card-border-yellow, .kanban-task-item.card-border-green, .kanban-task-item.card-border-blue, .kanban-task-item.card-border-purple, .kanban-task-item.card-border-pink { border-left-width: 4px; border-left-style: solid; }",
    ".kanban-task-item.card-border-gray { border-left-color: var(--sb-card-gray); }",
    ".kanban-task-item.card-border-red { border-left-color: var(--sb-card-red); }",
    ".kanban-task-item.card-border-orange { border-left-color: var(--sb-card-orange); }",
    ".kanban-task-item.card-border-yellow { border-left-color: var(--sb-card-yellow); }",
    ".kanban-task-item.card-border-green { border-left-color: var(--sb-card-green); }",
    ".kanban-task-item.card-border-blue { border-left-color: var(--sb-card-blue); }",
    ".kanban-task-item.card-border-purple { border-left-color: var(--sb-card-purple); }",
    ".kanban-task-item.card-border-pink { border-left-color: var(--sb-card-pink); }",
    ".kanban-task-item:hover { background: var(--sb-bg); }",
    ".kanban-task-content { flex: 1; display: flex; align-items: center; gap: 6px; background: transparent; border: none; cursor: pointer; text-align: left; padding: 0; min-width: 0; }",
    ".kanban-task-content:hover .task-title { color: var(--sb-primary); }",
    ".kanban-task-item .task-type-icon { flex-shrink: 0; display: flex; align-items: center; justify-content: center; width: 14px; height: 14px; }",
    ".kanban-task-item .task-title { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--sb-text); }",
    ".kanban-task-item .task-claimed-by { font-size: 10px; color: var(--sb-muted); flex-shrink: 0; max-width: 60px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    // Status-specific colors
    ".kanban-task-item.status-completed .task-title { text-decoration: line-through; color: var(--sb-muted); }",
    // Status dot for available tasks
    ".status-dot { width: 6px; height: 6px; border-radius: 50%; background: currentColor; }",
    // Mini claim button
    ".btn-claim-mini { background: transparent; border: none; cursor: pointer; padding: 2px; border-radius: 4px; color: var(--sb-muted); opacity: 0; transition: opacity 0.15s, color 0.15s; display: flex; align-items: center; justify-content: center; }",
    ".kanban-task-item:hover .btn-claim-mini { opacity: 1; }",
    ".btn-claim-mini:hover { color: var(--sb-primary); background: var(--sb-surface); }",
    // =============================================================================
    // Responsive Drawers (Story 4.4 - Phase 6)
    // =============================================================================
    ".drawer-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 100; opacity: 0; pointer-events: none; transition: opacity 0.2s ease; }",
    ".drawer-overlay.open { opacity: 1; pointer-events: auto; }",
    ".drawer { position: fixed; top: 0; bottom: 0; width: 280px; background: var(--sb-surface); z-index: 101; transform: translateX(-100%); transition: transform 0.3s ease; display: flex; flex-direction: column; }",
    ".drawer.right { right: 0; left: auto; transform: translateX(100%); }",
    ".drawer.open { transform: translateX(0); }",
    ".drawer-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid var(--sb-border); }",
    ".drawer-content { flex: 1; overflow-y: auto; padding: 16px; }",
    ".drawer-close { background: transparent; border: none; font-size: 24px; cursor: pointer; color: var(--sb-muted); }",
    // =============================================================================
    // Mobile Mini Task Bar (Story 4.4 - Phase 6)
    // =============================================================================
    ".mini-task-bar { position: fixed; bottom: 0; left: 0; right: 0; background: var(--sb-primary); color: var(--sb-inverse); padding: 12px 16px; display: none; align-items: center; gap: 12px; z-index: 90; }",
    "@media (max-width: 768px) { .mini-task-bar.visible { display: flex; } }",
    ".mini-task-bar .task-title { flex: 1; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }",
    ".mini-task-bar .task-timer { font-variant-numeric: tabular-nums; font-weight: 600; }",
    // =============================================================================
    // Mobile Header (Story 4.4 - Phase 6)
    // =============================================================================
    ".mobile-header { display: none; align-items: center; justify-content: space-between; padding: 12px 16px; background: var(--sb-surface); border-bottom: 1px solid var(--sb-border); }",
    "@media (max-width: 768px) { .mobile-header { display: flex; } }",
    ".menu-hamburger, .menu-user { background: transparent; border: none; font-size: 24px; cursor: pointer; padding: 8px; }",
    // =============================================================================
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
  |> string.join("\n")
}
