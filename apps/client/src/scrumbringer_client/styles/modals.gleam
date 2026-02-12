//// Auto-split CSS chunk: modals

/// Provides modals CSS chunk.
pub fn css() -> List(String) {
  [
    ".modal { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; padding: 16px; }",
    ".modal::before { content: \"\"; position: absolute; inset: 0; background: var(--sb-bg); opacity: 0.85; }",
    ".modal-content { position: relative; background: var(--sb-elevated); border: 1px solid var(--sb-border); border-radius: 12px; padding: 16px; width: min(720px, 100%); max-height: 85vh; overflow: auto; }",
    // Modal header with close button
    ".modal-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; padding-bottom: 12px; border-bottom: 1px solid var(--sb-border); }",
    ".modal-header h3 { margin: 0; font-size: 18px; font-weight: 600; }",
    ".btn-close { width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center; background: var(--sb-surface); border: 1px solid var(--sb-border); cursor: pointer; font-size: 14px; color: var(--sb-muted); transition: all 0.15s ease; }",
    ".btn-close:hover { background: var(--sb-elevated); border-color: var(--sb-text); color: var(--sb-text); }",
    // Drilldown modal styles
    ".drilldown-modal { z-index: 100; }",
    ".drilldown-details h3 { font-size: 16px; font-weight: 600; margin: 0 0 12px 0; }",
    ".metrics-summary { display: flex; gap: 12px; margin-bottom: 20px; flex-wrap: wrap; }",
    ".metrics-health { margin: 16px 0; padding: 12px; border: 1px solid var(--sb-border); border-radius: 12px; background: var(--sb-surface); }",
    ".metrics-health-items { display: flex; gap: 12px; flex-wrap: wrap; }",
    ".metrics-health-item { padding: 10px 12px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-elevated); min-width: 160px; display: flex; flex-direction: column; gap: 4px; }",
    ".metrics-health-label { font-size: 12px; color: var(--sb-muted); }",
    ".metrics-health-value { font-size: 16px; font-weight: 600; }",
    ".metrics-overview-stats { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 16px; }",
    ".metrics-overview-stat { padding: 10px 12px; border-radius: 10px; border: 1px solid var(--sb-border); background: var(--sb-surface); min-width: 160px; }",
    ".metrics-overview-label { font-size: 12px; color: var(--sb-muted); }",
    ".metrics-overview-value { font-size: 16px; font-weight: 600; }",
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
  ]
}
