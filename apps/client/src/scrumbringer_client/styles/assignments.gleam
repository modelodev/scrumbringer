//// Auto-split CSS chunk: assignments

/// Provides assignments CSS chunk.
pub fn css() -> List(String) {
  [
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
  ]
}
