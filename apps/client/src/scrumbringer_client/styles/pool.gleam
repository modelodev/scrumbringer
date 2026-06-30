//// Auto-split CSS chunk: pool

/// Provides pool CSS chunk.
pub fn css() -> List(String) {
  [
    "#member-canvas { background-image: radial-gradient(circle, color-mix(in oklab, var(--sb-border) 55%, transparent) 1px, transparent 1px); background-size: 24px 24px; border-radius: var(--sb-radius-lg); isolation: isolate; }",
    ".task-card { background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 12px; overflow: hidden; position: relative; }",
    ".task-card.task-blocked { border-color: color-mix(in oklab, var(--sb-warning) 32%, var(--sb-border)); background: color-mix(in oklab, var(--sb-surface) 92%, var(--sb-warning) 8%); }",
    ".task-card.card-border-gray, .task-card.card-border-red, .task-card.card-border-orange, .task-card.card-border-yellow, .task-card.card-border-green, .task-card.card-border-blue, .task-card.card-border-purple, .task-card.card-border-pink { border-color: color-mix(in oklab, var(--sb-card-accent, var(--sb-border)) 72%, var(--sb-border)); outline: 2px solid color-mix(in oklab, var(--sb-card-accent, transparent) 34%, transparent); outline-offset: -3px; }",
    ".task-card.task-blocked.card-border-gray, .task-card.task-blocked.card-border-red, .task-card.task-blocked.card-border-orange, .task-card.task-blocked.card-border-yellow, .task-card.task-blocked.card-border-green, .task-card.task-blocked.card-border-blue, .task-card.task-blocked.card-border-purple, .task-card.task-blocked.card-border-pink { border-color: color-mix(in oklab, var(--sb-card-accent, var(--sb-warning)) 58%, var(--sb-warning)); outline-color: color-mix(in oklab, var(--sb-card-accent, transparent) 28%, transparent); }",
    ".task-card:hover, .task-card:focus-within { z-index: 40; overflow: visible; box-shadow: 0 10px 30px rgba(0,0,0,0.18); }",
    ".task-card-top { position: absolute; top: 8px; left: 8px; right: 8px; display: flex; justify-content: space-between; gap: 6px; align-items: center; z-index: 2; }",
    ".task-card-actions-left { display: flex; gap: 6px; align-items: center; flex-shrink: 0; }",
    ".task-card-actions-right { display: flex; gap: 6px; align-items: center; flex-shrink: 0; }",
    ".task-card-primary-action { width: 28px; min-width: 28px; min-height: 28px; display: inline-flex; align-items: center; justify-content: center; padding: 0; border: 1px solid var(--sb-primary-subtle-border); border-radius: 8px; background: var(--sb-primary-subtle-bg); color: var(--sb-primary); font-size: var(--sb-font-sm); font-weight: var(--sb-weight-semibold); line-height: var(--sb-line-tight); cursor: pointer; box-shadow: 0 1px 0 rgba(0,0,0,0.04); }
.task-card-primary-action:hover, .task-card-primary-action:focus-visible { border-color: var(--sb-primary); background: color-mix(in oklab, var(--sb-primary) 16%, var(--sb-elevated)); color: var(--sb-primary-strong); }
.task-card-primary-action:disabled { opacity: 0.55; cursor: not-allowed; }
.task-card-primary-action[aria-disabled=\"true\"] { position: relative; border-color: var(--sb-border); background: var(--sb-surface-3); color: var(--sb-muted-strong); box-shadow: none; opacity: 0.72; cursor: not-allowed; }
.task-card-primary-action[aria-disabled=\"true\"]:hover, .task-card-primary-action[aria-disabled=\"true\"]:focus-visible { border-color: var(--sb-border); background: var(--sb-surface-3); color: var(--sb-muted-strong); }
.task-card-primary-action-blocked::before { content: ''; position: absolute; width: 18px; height: 2px; border-radius: 999px; background: currentColor; transform: rotate(-35deg); opacity: 0.9; pointer-events: none; }",
    ".task-card-body { height: 100%; display: flex; flex-direction: column; justify-content: center; align-items: center; gap: 6px; padding: 10px; padding-top: 40px; box-sizing: border-box; }
.task-card-open-action { appearance: none; border: 0; background: transparent; color: inherit; font: inherit; width: 100%; min-width: 0; min-height: 0; padding: 0; display: flex; align-items: center; justify-content: center; cursor: pointer; text-align: inherit; }
.task-card-open-action:focus-visible { outline: 2px solid var(--sb-primary); outline-offset: 3px; border-radius: 8px; }
.task-card-center { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; }
.task-card-center-icon { width: 28px; height: 28px; display: inline-flex; align-items: center; justify-content: center; color: var(--sb-text-soft); opacity: 0.9; }",
    ".task-card-title { width: 100%; font-weight: var(--sb-weight-bold); font-size: var(--sb-font-base); line-height: var(--sb-line-tight); text-align: center; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }",
    ".task-card-mobile-context { display: none; }",
    "@media (max-width: 640px), (max-height: 480px) and (max-width: 1024px) { #member-canvas { display: grid; grid-template-columns: 1fr; gap: var(--sb-space-lg); width: 100% !important; min-width: 0 !important; min-height: 0 !important; padding: var(--sb-space-sm); touch-action: pan-y !important; background-size: 20px 20px; } #member-canvas .task-card { position: relative !important; left: auto !important; top: auto !important; width: 100% !important; height: auto !important; min-height: 164px; } #member-canvas .task-card-top { position: static; padding: var(--sb-space-md) var(--sb-space-md) 0; } #member-canvas .task-card-actions-left, #member-canvas .task-card-actions-right { min-width: 0; } #member-canvas .task-card-primary-action, #member-canvas .drag-handle, #member-canvas .secondary-action { min-height: 44px; min-width: 44px; } #member-canvas .task-card-primary-action { width: 44px; max-width: 44px; padding: 0; } #member-canvas .task-card-body { height: auto; min-height: 104px; padding: var(--sb-space-md); padding-top: var(--sb-space-sm); } #member-canvas .task-card-open-action { min-height: 96px; } #member-canvas .task-card-center { width: 100%; gap: var(--sb-space-sm); } #member-canvas .task-card-title { font-size: var(--sb-font-md); } #member-canvas .task-card-mobile-context { display: flex; flex-wrap: wrap; align-items: center; justify-content: center; gap: 4px 8px; max-width: 100%; color: var(--sb-muted-strong); font-size: var(--sb-font-sm); line-height: var(--sb-line-tight); text-align: center; } #member-canvas .task-card-mobile-context span { min-width: 0; max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; } #member-canvas .task-card-mobile-context span + span::before { content: '·'; margin-right: 8px; color: var(--sb-muted); } #member-canvas .task-card-mobile-description { flex-basis: 100%; color: var(--sb-muted); } #member-canvas .task-card-preview { display: none; } }",
    "@media (hover: none) { .task-card:hover, .task-card:focus-within { box-shadow: none; } .task-card:hover .task-card-preview { opacity: 0; transform: scale(0.98); } }",
    ".task-card.highlight { border: 2px solid var(--sb-primary); }",
    ".is-highlight-source { border-color: color-mix(in oklab, var(--sb-warning) 65%, var(--sb-border)) !important; box-shadow: 0 0 0 2px color-mix(in oklab, var(--sb-warning) 25%, transparent) !important; }",
    ".is-highlight-target { border-color: color-mix(in oklab, var(--sb-warning) 55%, var(--sb-border)) !important; box-shadow: 0 0 0 2px color-mix(in oklab, var(--sb-warning) 18%, transparent) !important; }",
    ".is-highlight-dimmed { opacity: 0.55; }",
    ".highlight-warning { outline: 0; }",
    ".highlight-info { outline: 0; }",
    ".highlight-success { outline: 0; }",
    ".task-card .secondary-action { display: inline-flex; opacity: 0.65; }",
    ".task-card:hover .secondary-action, .task-card:focus-within .secondary-action { opacity: 1; }",
    ".task-card-preview { position: absolute; top: 0; left: calc(100% + 8px); width: 320px; max-width: min(420px, calc(100vw - 24px)); background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; padding: 12px 14px; box-shadow: 0 10px 30px rgba(0,0,0,0.18); opacity: 0; transform: scale(0.98); transition: opacity 120ms ease, transform 120ms ease; transition-delay: 200ms; pointer-events: auto; z-index: 20; }
.task-card.preview-left .task-card-preview { left: auto; right: calc(100% + 8px); }",
    ".task-preview-grid { display: grid; grid-template-columns: auto 1fr; column-gap: 10px; row-gap: 6px; align-items: baseline; }",
    ".task-preview-label { color: var(--sb-muted-strong); font-size: var(--sb-font-sm); }",
    ".task-preview-label-strong { color: var(--sb-text); font-weight: var(--sb-weight-semibold); }",
    ".task-preview-value { font-size: var(--sb-font-sm); line-height: var(--sb-line-body); text-align: left; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
    ".task-preview-description { white-space: normal; line-height: var(--sb-line-body); }",
    ".task-preview-extras { display: flex; flex-direction: column; gap: 8px; margin-top: 10px; }",
    ".task-preview-section { display: flex; flex-direction: column; gap: 6px; padding-top: 6px; border-top: 1px dashed var(--sb-border); }",
    ".task-preview-section-title { font-size: var(--sb-font-xs); font-weight: var(--sb-weight-semibold); text-transform: uppercase; letter-spacing: var(--sb-letter-label); color: var(--sb-muted-strong); }",
    ".task-preview-list { display: flex; flex-direction: column; gap: 4px; list-style: disc; margin: 0; padding-left: 16px; }",
    ".task-preview-list-item { margin: 0; }",
    ".task-preview-blocked-list { display: flex; flex-direction: column; gap: 4px; }",
    ".task-preview-blocked-item { font-size: var(--sb-font-sm); color: var(--sb-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }",
    ".task-preview-blocked-hidden-note { font-size: var(--sb-font-xs); color: var(--sb-muted); margin-top: 4px; display: inline-block; }",
    ".task-preview-notes { display: flex; flex-direction: column; gap: 6px; }",
    ".task-preview-note { display: flex; flex-direction: column; gap: 2px; }",
    ".task-preview-note-meta { font-size: var(--sb-font-xs); color: var(--sb-muted); }",
    ".task-preview-note-content { font-size: var(--sb-font-sm); color: var(--sb-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }",
    ".task-preview-actions { margin-top: 10px; display: flex; justify-content: flex-end; }",
    ".task-preview-btn { font-size: var(--sb-font-sm); }",
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
    ".task-row-title { font-weight: var(--sb-weight-bold); display: flex; align-items: center; gap: 6px; }",
    ".task-row-meta { display: inline-flex; align-items: center; gap: 6px; flex-wrap: wrap; color: var(--sb-muted); font-size: var(--sb-font-base); }",
    ".task-automation-origin { display: inline-flex; align-items: center; min-height: 20px; padding: 1px 7px; border: 1px solid color-mix(in oklab, var(--sb-primary) 30%, var(--sb-border)); border-radius: var(--sb-radius-pill); background: color-mix(in oklab, var(--sb-primary) 7%, var(--sb-surface)); color: var(--sb-primary); font-size: var(--sb-font-xs); font-weight: var(--sb-weight-semibold); line-height: var(--sb-line-tight); }",
    ".task-row-actions { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; justify-content: flex-end; }",
    // Now Working section in right panel (unified layout)
    ".now-working-section { padding: 12px; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 10px; margin-bottom: 12px; }",
    ".now-working-section.now-working-active { background: color-mix(in oklab, var(--sb-primary) 8%, var(--sb-elevated)); border-color: color-mix(in oklab, var(--sb-primary) 30%, var(--sb-border)); position: relative; }",
    ".now-working-section.now-working-active::before { content: ''; position: absolute; top: 12px; right: 12px; width: 8px; height: 8px; background: var(--sb-success); border-radius: 50%; animation: pulse-dot 2s ease-in-out infinite; }",
    "@keyframes pulse-dot { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.5; transform: scale(1.2); } }",
    ".now-working-task-title { font-weight: var(--sb-weight-semibold); margin-bottom: 4px; }",
    ".now-working-timer { font-variant-numeric: tabular-nums; color: var(--sb-muted); }",
    ".now-working-section .now-working-timer { font-size: var(--sb-font-3xl); font-weight: var(--sb-weight-semibold); font-family: var(--sb-font-mono); font-variant-numeric: tabular-nums; line-height: var(--sb-line-tight); text-align: center; margin: 8px 0; }",
    ".now-working-actions { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }",
    ".now-working-empty { display: flex; align-items: center; gap: 8px; justify-content: center; padding: 8px 0; color: var(--sb-muted); font-style: italic; }",
    ".now-working-section .now-working-actions { justify-content: center; }",
    // Multi-session support for EN CURSO panel
    ".now-working-multi { padding: 8px; }",
    ".now-working-multi::before { display: none; }",
    ".now-working-sessions { display: flex; flex-direction: column; gap: 8px; max-height: 240px; overflow-y: auto; }",
    ".now-working-session-item { display: flex; flex-direction: column; gap: 4px; padding: 10px 12px; background: var(--sb-surface); border: 1px solid var(--sb-border); border-radius: 8px; position: relative; }",
    ".now-working-session-item::before { content: ''; position: absolute; top: 10px; right: 10px; width: 6px; height: 6px; background: var(--sb-success); border-radius: 50%; animation: pulse-dot 2s ease-in-out infinite; }",
    ".now-working-session-item .now-working-task-title { font-size: var(--sb-font-md); font-weight: var(--sb-weight-semibold); padding-right: 16px; }",
    ".now-working-session-item .now-working-timer { font-size: var(--sb-font-xl); font-weight: var(--sb-weight-semibold); font-family: var(--sb-font-mono); font-variant-numeric: tabular-nums; color: var(--sb-primary); }",
    ".now-working-session-item .now-working-actions { flex-direction: row; justify-content: flex-start; margin-top: 4px; }",
    "@media (max-width: 640px) { .body { flex-direction: column; } .nav { width: 100%; } }",
  ]
}
