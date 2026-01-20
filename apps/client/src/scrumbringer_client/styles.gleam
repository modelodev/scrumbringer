//// CSS style definitions for Scrumbringer UI.
////
//// Generates all base CSS rules as strings for injection into the page.
//// Includes layout, typography, forms, buttons, and theme variables.

import gleam/string

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
    ".hint { color: var(--sb-muted); font-size: 0.9em; }",
    ".empty { color: var(--sb-muted); }",
    ".loading { color: var(--sb-info); }",
    ".error { color: var(--sb-danger); }",
    "input, select { padding: 8px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-elevated); color: var(--sb-text); }",
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
    ".table th { text-align: left; color: var(--sb-muted); font-weight: 600; padding: 8px; border-bottom: 1px solid var(--sb-border); }",
    ".table td { padding: 8px; border-bottom: 1px solid var(--sb-border); }",
    ".table tbody tr:hover { background: var(--sb-elevated); }",
    ".nav-item { width: 100%; text-align: left; }",
    ".nav-item.active { border-color: var(--sb-primary); }",
    ".actions { display: flex; gap: 8px; flex-wrap: wrap; }",
    ".modal { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; padding: 16px; }",
    ".modal::before { content: \"\"; position: absolute; inset: 0; background: var(--sb-bg); opacity: 0.85; }",
    ".modal-content { position: relative; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; padding: 16px; width: min(720px, 100%); max-height: 85vh; overflow: auto; }",
    ".toast { position: fixed; top: 12px; left: 50%; transform: translateX(-50%); background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 999px; padding: 8px 12px; color: var(--sb-text); box-shadow: 0 6px 24px rgba(0, 0, 0, 0.15); display: flex; gap: 8px; align-items: center; max-width: calc(100vw - 24px); z-index: 50; }",
    ".toast span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 60vw; }",
    ".toast-dismiss { padding: 2px 8px; line-height: 1; }",
    ".icon-row { display: flex; gap: 8px; align-items: center; }",
    ".icon-preview { width: 32px; height: 32px; border: 1px solid var(--sb-border); border-radius: 10px; display: flex; align-items: center; justify-content: center; background: var(--sb-elevated); }",
    ".icon-picker { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 10px; }",
    ".icon-picker button { width: 44px; height: 44px; padding: 0; border-radius: 12px; display: inline-flex; align-items: center; justify-content: center; background: var(--sb-elevated); }",
    ".icon-picker button.active { border-color: var(--sb-primary); }",
    ".icon-picker img { width: 24px; height: 24px; }",
    ".task-card { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; overflow: hidden; position: relative; }",
    ".task-card:hover, .task-card:focus-within { z-index: 10; overflow: visible; box-shadow: 0 10px 30px rgba(0,0,0,0.18); }",
    ".task-card-top { position: absolute; top: 8px; left: 8px; right: 8px; display: flex; justify-content: space-between; gap: 6px; align-items: center; z-index: 2; }",
    ".task-card-type-icon { display: none; }",
    ".task-card-actions { display: flex; gap: 6px; align-items: center; flex-shrink: 0; }",
    ".task-card-body { height: 100%; display: flex; flex-direction: column; justify-content: center; align-items: center; gap: 6px; padding: 10px 10px 10px 10px; padding-top: 40px; box-sizing: border-box; }
.task-card-center { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; }
.task-card-center-icon { width: 28px; height: 28px; display: inline-flex; align-items: center; justify-content: center; opacity: 0.9; }",
    ".task-card-title { width: 100%; font-weight: 700; font-size: 13px; line-height: 1.15; text-align: center; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }",
    ".task-card.highlight { border: 2px solid var(--sb-primary); }",
    ".task-card .secondary-action { display: inline-flex; opacity: 0.65; }",
    ".task-card:hover .secondary-action, .task-card:focus-within .secondary-action { opacity: 1; }",
    ".task-card-preview { position: absolute; top: 0; left: calc(100% + 8px); width: 280px; max-width: min(360px, calc(100vw - 24px)); background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; padding: 10px 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.18); opacity: 0; transform: scale(0.98); transition: opacity 120ms ease, transform 120ms ease; transition-delay: 200ms; pointer-events: auto; z-index: 20; }
.task-card.preview-left .task-card-preview { left: auto; right: calc(100% + 8px); }",
    ".task-preview-grid { display: grid; grid-template-columns: auto 1fr; column-gap: 10px; row-gap: 6px; align-items: baseline; }",
    ".task-preview-label { color: var(--sb-muted); font-size: 12px; }",
    ".task-preview-value { font-size: 12px; text-align: right; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
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
    ".drag-handle { cursor: grab; user-select: none; padding: 0; border: 1px solid var(--sb-border); border-radius: 8px; background: transparent; color: var(--sb-muted); display: inline-flex; align-items: center; justify-content: center; min-width: 28px; min-height: 28px; line-height: 0; }",
    ".drag-handle:hover { border-color: var(--sb-primary); }
.drag-handle:active { cursor: grabbing; }",
    ".task-list { display: flex; flex-direction: column; gap: 8px; }",
    ".task-row { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; padding: 10px; border: 1px solid var(--sb-border); border-radius: 12px; background: var(--sb-elevated); }",
    ".task-row-title { font-weight: 700; }",
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
    ".empty-state-icon { width: 64px; height: 64px; margin-bottom: 16px; opacity: 0.4; color: var(--sb-muted); }",
    ".empty-state-title { font-size: 18px; font-weight: 600; margin-bottom: 8px; color: var(--sb-text); }",
    ".empty-state-description { font-size: 14px; color: var(--sb-muted); max-width: 320px; margin-bottom: 16px; line-height: 1.5; }",
    ".empty-state-actions { display: flex; gap: 12px; flex-wrap: wrap; justify-content: center; }",
    // =====================================================
    // UX IMPROVEMENTS - Info Callout/Banner (E09, E10, E01)
    // =====================================================
    ".info-callout { display: flex; align-items: flex-start; gap: 12px; padding: 12px 16px; background: color-mix(in oklab, var(--sb-info) 10%, var(--sb-surface)); border: 1px solid color-mix(in oklab, var(--sb-info) 30%, var(--sb-border)); border-radius: 10px; margin-bottom: 16px; }",
    ".info-callout-icon { width: 20px; height: 20px; flex-shrink: 0; color: var(--sb-info); margin-top: 2px; }",
    ".info-callout-content { flex: 1; }",
    ".info-callout-title { font-weight: 600; margin-bottom: 4px; }",
    ".info-callout-text { font-size: 14px; color: var(--sb-muted); line-height: 1.5; }",
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
    // UX IMPROVEMENTS - Confirmation Modal (IF02)
    // =====================================================
    ".modal-confirm { text-align: center; }",
    ".modal-confirm-title { font-size: 18px; font-weight: 700; margin-bottom: 12px; }",
    ".modal-confirm-text { color: var(--sb-muted); margin-bottom: 20px; line-height: 1.5; }",
    ".modal-confirm-actions { display: flex; gap: 12px; justify-content: center; }",
    ".btn-danger { background: var(--sb-danger); border-color: var(--sb-danger); color: var(--sb-inverse); }",
    ".btn-danger:hover { background: color-mix(in oklab, var(--sb-danger) 85%, black); border-color: color-mix(in oklab, var(--sb-danger) 85%, black); }",
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
    // =====================================================
    "@media (max-width: 768px) { button, a.btn, .clickable { min-height: 44px; min-width: 44px; } .topbar { flex-wrap: wrap; gap: 8px; padding: 10px; } .topbar-actions { width: 100%; justify-content: space-between; } .user { display: none; } .user-avatar { display: flex; width: 32px; height: 32px; border-radius: 50%; background: var(--sb-primary); color: var(--sb-inverse); align-items: center; justify-content: center; font-weight: 600; } }",
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
    ".session-icon { flex-shrink: 0; }",
    ".session-title { flex: 1; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".session-timer { font-variant-numeric: tabular-nums; font-weight: 600; color: var(--sb-primary); }",
    ".session-actions { display: flex; gap: 6px; flex-shrink: 0; }",
    // Claimed row (CLAIMED)
    ".claimed-row { display: flex; align-items: center; gap: 10px; padding: 10px 12px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 8px; margin-bottom: 8px; }",
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
    ".modal-backdrop { position: absolute; inset: 0; background: rgba(0,0,0,0.5); }",
    ".modal-content.card-detail { border-left-width: 4px; }",
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
    ".card-detail-tasks-section { }",
    ".card-detail-tasks-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }",
    ".card-detail-tasks-title { font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; color: var(--sb-muted); }",
    ".card-add-task-form { padding: 16px; border: 1px dashed var(--sb-border); border-radius: 8px; background: var(--sb-surface); margin-bottom: 16px; }",
    ".form-group { display: flex; flex-direction: column; gap: 6px; margin-bottom: 12px; }",
    ".form-group label { font-size: 13px; font-weight: 500; color: var(--sb-muted); }",
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
    // Dialog error
    ".dialog-error { display: flex; align-items: center; gap: 8px; padding: 10px 16px; background: color-mix(in oklab, var(--sb-danger) 10%, var(--sb-surface)); border: 1px solid color-mix(in oklab, var(--sb-danger) 30%, var(--sb-border)); border-radius: 10px; margin: 0 20px 0 20px; margin-top: -4px; color: var(--sb-danger); font-size: 14px; }",
    // Dialog footer
    ".dialog-footer { display: flex; justify-content: flex-end; gap: 12px; padding: 16px 20px; border-top: 1px solid var(--sb-border); }",
    // Add button (for opening dialogs)
    ".btn-add { display: inline-flex; align-items: center; gap: 6px; padding: 10px 16px; background: var(--sb-primary); color: var(--sb-inverse); border: none; border-radius: 10px; font-weight: 500; cursor: pointer; transition: background 0.2s, transform 0.1s; }",
    ".btn-add:hover { background: var(--sb-primary-hover); }",
    ".btn-add:active { transform: scale(0.98); }",
    ".btn-add::before { content: '+'; font-weight: 700; font-size: 1.1em; }",
    // Admin section header with action button
    ".admin-section-header { display: flex; align-items: center; justify-content: space-between; padding-bottom: 12px; margin-bottom: 16px; border-bottom: 1px solid var(--sb-border); }",
    ".admin-section-title { display: flex; align-items: center; gap: 8px; font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; color: var(--sb-muted); }",
    ".admin-section-icon { font-size: 16px; }",
    // Responsive dialog
    "@media (max-width: 640px) { .dialog { max-height: 100vh; border-radius: 0; } .dialog-overlay { padding: 0; } .dialog-sm, .dialog-md, .dialog-lg, .dialog-xl { width: 100%; height: 100%; } .dialog-body { padding: 16px; } .dialog-header, .dialog-footer { padding: 12px 16px; } }",
  ]
  |> string.join("\n")
}
