//// Auto-split CSS chunk: ux

/// Provides ux CSS chunk.
pub fn css() -> List(String) {
  [
    // =====================================================
    // UX IMPROVEMENTS - Cards & Sections (E03-E10)
    // =====================================================
    ".admin-card { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; padding: 16px; margin-bottom: 16px; }",
    ".admin-card-header { font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; color: var(--sb-muted); margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid var(--sb-border); }",
    ".admin-card-title { font-size: 16px; font-weight: 700; margin-bottom: 8px; }",
    ".admin-center-panel { display: flex; flex-direction: column; min-height: 0; }",
    ".panel { min-height: 0; }",
    ".form { display: flex; flex-direction: column; gap: 12px; }",
    ".forbidden { color: var(--sb-danger); }",
    ".dropzone-hint { font-size: 12px; color: var(--sb-muted); }",
    ".invite-result { margin-top: 12px; }",
    ".loading-indicator { display: inline-flex; align-items: center; gap: 8px; color: var(--sb-muted); }",
    ".not-permitted { padding: 16px; border: 1px solid var(--sb-border); border-radius: 12px; background: color-mix(in oklab, var(--sb-warning) 8%, var(--sb-surface)); }",
    ".not-permitted h2 { margin: 0 0 8px 0; font-size: 16px; }",
    ".not-permitted p { margin: 0; color: var(--sb-muted); line-height: 1.5; }",
    ".section-description { display: flex; align-items: center; gap: 8px; margin: 0 0 12px 0; color: var(--sb-muted); font-size: 13px; line-height: 1.5; }",
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
    ".info-callout-link { color: var(--sb-primary); text-decoration: underline; text-underline-offset: 2px; }",
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
    ".table-actions button { padding: 12px; min-width: 44px; min-height: 44px; }",
    ".cell-actions .btn-icon, .actions-row .btn-icon, .btn-group .btn-icon { padding: 12px; min-width: 44px; min-height: 44px; }",
    ".table td.actions-cell { text-align: right; }",
    ".pagination { display: flex; align-items: center; justify-content: flex-end; gap: 6px; margin-top: 12px; }",
    ".page-info { min-width: 68px; text-align: center; font-size: 12px; color: var(--sb-muted); }",
    // DataTable component (extends .table)
    ".data-table { width: 100%; border-collapse: collapse; }",
    ".data-table th { text-align: left; color: var(--sb-muted); font-weight: 600; font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; padding: 10px 12px; border-bottom: 2px solid var(--sb-border); background: var(--sb-surface); }",
    ".data-table td { padding: 10px 12px; border-bottom: 1px solid var(--sb-border); vertical-align: middle; }",
    ".data-table tbody tr:nth-child(even) { background: color-mix(in oklab, var(--sb-surface) 50%, var(--sb-bg)); }",
    ".data-table tbody tr:hover { background: var(--sb-elevated); }",
    ".data-table th.sortable { cursor: pointer; user-select: none; }",
    ".data-table th.sortable:hover { background: var(--sb-hover); }",
    ".data-table th .sort-icon { margin-left: 4px; opacity: 0.4; font-size: 10px; }",
    ".data-table th.sortable:hover .sort-icon { opacity: 1; }",
    // DataTable responsive collapse (card view on mobile)
    "@media (max-width: 640px) { .data-table, .data-table thead, .data-table tbody, .data-table th, .data-table td, .data-table tr { display: block; } .data-table thead { position: absolute; top: -9999px; left: -9999px; } .data-table tr { margin-bottom: 12px; border: 1px solid var(--sb-border); border-radius: 8px; padding: 12px; background: var(--sb-surface); } .data-table td { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border: none; border-bottom: 1px solid var(--sb-border); } .data-table td:last-child { border-bottom: none; } .data-table td::before { content: attr(data-label); font-weight: 600; color: var(--sb-muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; } }",
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
    "@media (max-width: 768px) { button, a.btn, .clickable, select, input[type='checkbox'], input[type='radio'], .btn-xs, .btn-icon, .nav-item { min-height: 44px; } button, a.btn, .clickable, .btn-icon { min-width: 44px; } select { padding: 10px 12px; font-size: 16px; } input { min-height: 44px; padding: 10px 12px; font-size: 16px; } .btn-xs { min-height: 44px; padding: 10px 16px; } .filters-row select, .filters-row input, .filters-row button { min-height: 44px; height: 44px; } .topbar { flex-wrap: wrap; gap: 8px; padding: 10px; } .topbar-actions { width: 100%; justify-content: space-between; } .user { display: none; } .user-avatar { display: flex; width: 32px; height: 32px; border-radius: 50%; background: var(--sb-primary); color: var(--sb-inverse); align-items: center; justify-content: center; font-weight: 600; } .pagination { justify-content: center; } }",
    ".hamburger-menu { display: none; }",
    ".member-mobile { min-height: 100dvh; background: var(--sb-bg); }",
    ".member-content-mobile { min-height: calc(100dvh - 56px); }",
    ".mobile-topbar { position: sticky; top: 0; z-index: 30; display: grid; grid-template-columns: 44px 1fr 44px; align-items: center; gap: 8px; min-height: 56px; padding: 8px 12px; border-bottom: 1px solid var(--sb-border); background: var(--sb-surface); }",
    ".mobile-menu-btn, .mobile-user-btn { display: inline-flex; align-items: center; justify-content: center; width: 44px; height: 44px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-elevated); color: var(--sb-text); }",
    ".topbar-title-mobile { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; text-align: center; font-size: 13px; font-weight: 700; letter-spacing: 0.03em; text-transform: uppercase; color: var(--sb-muted); }",
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
    ".color-picker-dropdown { position: absolute; top: 100%; left: 0; margin-top: 4px; min-width: 180px; max-height: min(280px, 50vh); overflow-y: auto; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 10px; padding: 6px; box-shadow: 0 10px 30px rgba(0,0,0,0.15); z-index: 50; display: none; }",
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
    ".modal-content.card-detail { border-left-width: 4px; z-index: 2; position: relative; height: min(84vh, 760px); min-height: 60vh; max-height: 84vh; padding: 0; overflow: hidden; display: flex; flex-direction: column; }",
    ".modal-header-block { border-bottom: 1px solid var(--sb-border); background: var(--sb-surface-2); }",
    // Shared detail header primitives (milestone/card/task)
    ".detail-header-block { padding: 20px 20px 12px; }",
    ".detail-header { display: flex; flex-direction: column; gap: 12px; }",
    ".detail-title-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 12px; }",
    ".detail-title { font-size: 20px; font-weight: 700; line-height: 1.25; }",
    ".detail-meta { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }",
    ".detail-summary { padding: 14px 16px; border: 1px solid color-mix(in oklab, var(--sb-border) 75%, transparent); border-radius: 12px; background: color-mix(in oklab, var(--sb-elevated) 88%, transparent); }",
    ".detail-tabs { margin-top: 2px; padding: 8px; border: 1px solid color-mix(in oklab, var(--sb-border) 82%, transparent); border-radius: 12px; background: color-mix(in oklab, var(--sb-surface) 85%, var(--sb-elevated)); }",
    ".modal-tabs.detail-tabs { display: flex; align-items: stretch; justify-content: center; align-self: stretch; width: 100%; gap: 8px; padding: 8px; border-bottom: 0; }",
    ".detail-tab { min-height: 38px; padding-inline: 12px; font-size: 13px; font-weight: 600; }",
    ".detail-tabpanel { min-height: 300px; padding: 6px 0 4px; }",
    ".detail-content { display: flex; flex-direction: column; gap: 16px; padding-top: 4px; }",
    ".detail-grid { display: grid; gap: 14px; }",
    ".detail-section { padding: 12px 14px; border-radius: 10px; border: 1px solid color-mix(in oklab, var(--sb-border) 70%, transparent); background: color-mix(in oklab, var(--sb-elevated) 92%, transparent); }",
    ".detail-section + .detail-section { margin-top: 8px; }",
    ".detail-section-title { font-size: 12px; letter-spacing: 0.05em; margin-bottom: 8px; text-transform: uppercase; color: var(--sb-muted); }",
    ".detail-item-row { padding: 10px 12px; min-height: 44px; gap: 10px; }",
    ".detail-empty-state { display: flex; flex-direction: column; gap: 6px; padding: 14px; border: 1px dashed var(--sb-border); border-radius: 10px; background: color-mix(in oklab, var(--sb-elevated) 94%, var(--sb-bg)); }",
    ".detail-section .card-section-title { font-size: 12px; letter-spacing: 0.05em; text-transform: uppercase; color: var(--sb-muted); }",
    ".modal-body { padding: 16px 20px 20px; overflow-y: auto; flex: 1; background: var(--sb-surface-1); }",
    ".card-state-badge { display: inline-flex; align-items: center; padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }",
    ".card-state-pendiente { background: color-mix(in oklab, var(--sb-muted) 15%, var(--sb-surface)); color: var(--sb-muted); }",
    ".card-state-en_curso { background: color-mix(in oklab, var(--sb-warning) 15%, var(--sb-surface)); color: var(--sb-warning); }",
    ".card-state-cerrada { background: color-mix(in oklab, var(--sb-success) 15%, var(--sb-surface)); color: var(--sb-success); }",
    ".card-detail-progress-text { font-size: 14px; color: var(--sb-muted); }",
    ".card-detail-progress-bar { width: 100%; height: 8px; background: var(--sb-border); border-radius: 4px; overflow: hidden; margin-bottom: 12px; }",
    ".card-detail-progress-fill { height: 100%; background: var(--sb-primary); border-radius: 4px; transition: width 0.3s ease; }",
    ".card-detail-description { color: var(--sb-muted); line-height: 1.5; }",
    // AC21: Card modal tabs
    ".modal-tabs { display: grid; grid-auto-flow: column; grid-auto-columns: minmax(0, 1fr); gap: 8px; padding: 0 20px 12px; border-bottom: 1px solid var(--sb-border); background: var(--sb-surface-2); align-items: stretch; }",
    ".modal-tab { padding: 6px 14px; background: transparent; border: 1px solid transparent; border-radius: 999px; cursor: pointer; font-size: 13px; font-weight: 600; color: color-mix(in oklab, var(--sb-text) 68%, var(--sb-muted)); transition: all 0.15s; display: inline-flex; align-items: center; gap: 6px; justify-content: center; min-height: 34px; min-width: 112px; }",
    ".modal-tab:hover { color: var(--sb-text); background: var(--sb-elevated); }",
    ".modal-tab.tab-active { color: var(--sb-text-strong); font-weight: 600; border-color: var(--sb-primary-subtle-border); background: var(--sb-primary-subtle-bg); box-shadow: 0 1px 0 rgba(0,0,0,0.04); }",
    ".card-tabs, .task-tabs { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); }",
    ".card-tab, .task-tab { width: 100%; }",
    ".card-tab.detail-tab, .task-tab.detail-tab, .modal-tab.detail-tab { flex: 1 1 0; width: 100%; max-width: 220px; }",
    ".tab-count { font-size: 12px; color: color-mix(in oklab, var(--sb-text) 62%, var(--sb-muted)); }",
    ".tab-active .tab-count { color: var(--sb-text); }",
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
    // Shared detail modal shell (used by milestone detail)
    ".detail-modal-overlay { position: fixed; inset: 0; z-index: 1000; display: flex; align-items: center; justify-content: center; }",
    ".detail-modal-overlay .modal-backdrop { position: absolute; inset: 0; background: rgba(0,0,0,0.5); z-index: 1; }",
    ".detail-modal-overlay .modal-content.detail-modal-content { position: relative; background: var(--sb-surface); border-radius: 12px; max-width: 760px; width: 92%; height: min(84vh, 760px); max-height: 84vh; min-height: 60vh; padding: 0; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 8px 32px rgba(0,0,0,0.2); z-index: 2; }",
    ".milestone-detail-body { padding: 14px 20px 18px; }",
    // Task Detail Modal (Story 5.4.1)
    ".task-detail-modal { position: fixed; inset: 0; z-index: 1000; display: flex; align-items: center; justify-content: center; }",
    ".task-detail-modal .modal-backdrop { position: absolute; inset: 0; background: rgba(0,0,0,0.5); z-index: 1; }",
    ".task-detail-modal .modal-content { position: relative; background: var(--sb-surface); border-radius: 12px; max-width: 760px; width: 92%; height: min(84vh, 760px); max-height: 84vh; min-height: 60vh; padding: 0; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 8px 32px rgba(0,0,0,0.2); z-index: 2; }",
    ".modal-close { min-width: 40px; min-height: 40px; border-radius: 10px; color: var(--sb-text-soft); }",
    ".modal-close:hover { background: var(--sb-surface-3); color: var(--sb-text-strong); border-color: var(--sb-border); }",
    ".task-meta-chip { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 999px; border: 1px solid var(--sb-border); background: var(--sb-elevated); color: color-mix(in oklab, var(--sb-text) 84%, var(--sb-muted)); font-size: 12px; font-weight: 500; }",
    ".task-meta-assignee.muted { color: var(--sb-muted); opacity: 0.7; }",
    // Task tabs (aligned with card-tabs)
    ".task-tabs { }",
    ".task-tab .tab-count { font-size: 0.85em; }",
    ".task-tab .new-notes-indicator { color: var(--sb-accent); font-size: 0.7em; margin-left: 4px; animation: pulse 2s infinite; }",
    // Task detail tab content
    ".task-details-section { padding: 0; }",
    ".task-details-stack { display: flex; flex-direction: column; gap: 10px; }",
    ".task-detail-field { padding: 10px 12px; border: 1px solid color-mix(in oklab, var(--sb-border) 72%, transparent); border-radius: 10px; background: color-mix(in oklab, var(--sb-surface) 90%, var(--sb-elevated)); }",
    ".task-detail-field-label { font-size: 12px; font-weight: 600; letter-spacing: 0.02em; color: var(--sb-muted-strong); margin-bottom: 4px; }",
    ".task-detail-field-value { color: var(--sb-text-strong); line-height: 1.4; }",
    ".task-detail-field-value.muted { color: var(--sb-muted); }",
    ".task-detail-grid { display: grid; gap: 10px; }",
    ".detail-row { display: grid; grid-template-columns: 140px minmax(0, 1fr); align-items: center; gap: 12px; padding: 2px 0; }",
    ".detail-label { font-weight: 500; color: var(--sb-muted-strong); }",
    ".detail-value { color: var(--sb-text-strong); }",
    ".detail-value.muted { color: var(--sb-muted); }",
    ".task-metrics-grid, .card-metrics-grid, .milestone-metrics-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px 16px; padding: 10px; border: 1px solid var(--sb-border); border-radius: 12px; background: var(--sb-surface-2); }",
    "@media (max-width: 640px) { .task-metrics-grid, .card-metrics-grid, .milestone-metrics-grid { grid-template-columns: 1fr; } .detail-row { grid-template-columns: 1fr; gap: 6px; } }",
    ".task-metrics-empty, .card-metrics-loading, .milestone-metrics-loading, .card-metrics-empty, .milestone-metrics-empty { color: color-mix(in oklab, var(--sb-text) 64%, var(--sb-muted)); padding: 10px 12px; border: 1px dashed var(--sb-border); border-radius: 10px; background: var(--sb-surface-2); }",
    ".card-metrics-error, .milestone-metrics-error { color: var(--sb-danger); padding: 8px 0; }",
    ".metrics-workflow-list { margin-top: 8px; }",
    ".metrics-workflow-items { display: flex; flex-direction: column; gap: 8px; }",
    ".metrics-workflow-item { display: flex; justify-content: space-between; align-items: center; gap: 8px; padding: 8px 10px; border: 1px solid var(--sb-border); border-radius: 10px; background: var(--sb-surface-3); }",
    ".metrics-workflow-name { color: var(--sb-text); font-weight: 500; }",
    ".metrics-workflow-empty { color: color-mix(in oklab, var(--sb-text) 64%, var(--sb-muted)); font-size: 13px; padding: 10px 12px; border: 1px dashed var(--sb-border); border-radius: 10px; background: var(--sb-surface-2); }",
    ".task-dependencies-section { padding: 0; }",
    ".task-dependencies-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px; }",
    ".task-dependencies-list { display: flex; flex-direction: column; gap: 8px; }",
    ".task-dependencies-section .task-dependencies-list, .task-notes-section .notes-list { margin-top: 12px; }",
    ".task-dependencies-section .task-empty-state, .task-notes-section .task-empty-state { margin-top: 14px; padding: 14px 16px; }",
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
    ".search-select-item.selected { border-color: var(--sb-primary); background: color-mix(in oklab, var(--sb-primary) 8%, var(--sb-surface)); }",
    ".search-select-main { display: flex; align-items: center; gap: 8px; min-width: 0; }",
    ".search-select-primary { font-weight: 600; }",
    ".search-select-secondary { font-size: 12px; color: var(--sb-muted); }",
    ".search-select-role { font-size: 11px; padding: 2px 8px; line-height: 1.2; }",
    ".member-selected-hint { align-items: center; justify-content: space-between; gap: 8px; padding: 8px 10px; border: 1px solid color-mix(in oklab, var(--sb-primary) 30%, var(--sb-border)); border-radius: 8px; background: color-mix(in oklab, var(--sb-primary) 6%, var(--sb-surface)); }",
    ".member-selected-hint-icon { color: var(--sb-primary); display: inline-flex; align-items: center; }",
    ".member-selected-badge { margin-left: auto; }",
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
    ".task-section-hint { font-size: 13px; color: var(--sb-muted); margin-bottom: 8px; padding-inline: 2px; line-height: 1.45; }",
    ".card-section-header .btn.btn-sm { padding: 8px 14px; border-radius: 10px; }",
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
    // Error icon helper
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
    "@media (max-width: 640px) { .card-detail-modal { padding: 8px; } .modal-content.card-detail { padding: 0; } .detail-header-block { padding: 16px 16px 10px; } .modal-body { padding: 12px 16px 16px; } .detail-title { font-size: 18px; } .card-detail-tasks-section { } .card-add-task-form { padding: 12px; } .detail-modal-overlay .modal-content.detail-modal-content { width: calc(100% - 16px); max-height: 88vh; } .milestone-detail-body { padding: 12px 16px 16px; } }",
    // =====================================================
  ]
}
