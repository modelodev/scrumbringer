# Layout audit: spacing, grouping and action hierarchy

Date: 2026-06-11
Mode: `$impeccable layout apps/client/src/scrumbringer_client`
Scope: `apps/client/src/scrumbringer_client`
Status: findings registered only. No product code or CSS changes were implemented.

## Method

- Reviewed the rendered Pool experience at desktop `1440x900` and mobile `390x844`.
- Captured evidence:
  - `/tmp/scrumbringer-layout-audit-pool-desktop.png`
  - `/tmp/scrumbringer-layout-audit-pool-mobile.png`
- Inspected layout code around:
  - `features/layout/center_panel.gleam`
  - `features/pool/chrome.gleam`
  - `features/layout/left_panel.gleam`
  - `features/layout/right_panel.gleam`
  - `features/admin/*_view.gleam`
  - `styles/layout.gleam`, `styles/pool.gleam`, `styles/tables.gleam`, `styles/dialogs.gleam`

## Findings

### P1 - Pool filters visually absorb the Pool header action

The Pool filters are rendered by the center panel toolbar, while the `Pool` title and `+ Nueva tarea` action are rendered by the Pool view itself. Visually, the filter card ends immediately above the Pool header, with similar spacing to the internal Pool gap. This makes the `+ Nueva tarea` button read as related to the filter/search block instead of clearly belonging to the Pool section.

Evidence:
- `.center-panel-content` uses a small global gap between toolbar and content.
- `.center-filters-work` is a full-width elevated block.
- `.pool-view` and `.pool-header` continue with similarly tight rhythm.
- Desktop screenshot shows the Pool title under the filter block, with `+ Nueva tarea` aligned near the filter card's right edge.

Proposal:
- Treat filters, content header and content body as three semantic zones with different spacing.
- Either move the Pool title/action into a local header band that visually owns the content, or increase the separation after the filter block and tighten title/action together.
- The action should be closer to `Pool` than to the filter card, and should align with a content boundary rather than the filter boundary.

Acceptance criteria:
- At a glance, `+ Nueva tarea` is understood as a Pool action, not a filter action.
- The gap between filters and Pool header is larger or more structurally distinct than the gap between Pool header and Pool body.
- Desktop and mobile preserve the same ownership relationship.

### P1 - Mobile Pool is filter-dominant before work context appears

On mobile, the filter block takes the first viewport's strongest visual weight. The Pool title appears immediately below it, and `+ Nueva tarea` sits to the right of the title with little breathing room. This preserves functionality, but the first read is "filters first, work second".

Evidence:
- Mobile screenshot at `390x844` shows the filter panel as the dominant first block.
- The title/action row follows without a strong section break.
- The first task card starts after a compact title/action row, so work content is visually delayed.

Proposal:
- Introduce a compact mobile filter mode: visible search plus a filter summary or disclosure for secondary filters.
- Keep Pool title/action in a stable local header before the full filter detail, or provide a clearer divider after filters.
- Preserve touch targets, but reduce the filter block's visual authority on initial load.

Acceptance criteria:
- On mobile, users can identify the active work surface before parsing every filter control.
- `Pool` and `+ Nueva tarea` remain visually paired when controls wrap.
- The first task appears sooner or after a clearer hierarchy boundary.

### P2 - Global and contextual create actions compete

The left panel exposes `+ Nueva tarea` and `+ Nueva tarjeta` as primary work actions. The Pool also exposes `+ Nueva tarea` locally. Both are valid, but the current visual system gives the sidebar actions high prominence while the local action sits near filters. This weakens the difference between global creation and context-specific creation.

Evidence:
- `left_panel.gleam` renders primary full-width work CTAs before navigation.
- `pool/chrome.gleam` renders a second `+ Nueva tarea` in the Pool header.
- Desktop screenshot shows both `+ Nueva tarea` actions in the same first scan path.

Proposal:
- Define a role contract:
  - Sidebar CTAs are global shortcuts.
  - Surface header CTAs are contextual and should own the current view.
- Consider reducing sidebar CTA weight when a contextual header CTA is visible, or make the sidebar action a compact shortcut.
- Ensure labels, placement and style explain the difference without extra helper copy.

Acceptance criteria:
- Users can tell whether an action applies globally or to the current surface.
- Duplicate labels do not compete as equal primaries in the same viewport.
- The contextual action remains the strongest action within the Pool content area.

### P2 - Admin filter bars and headers use inconsistent grouping language

Admin views use a stronger reusable section header pattern, but filter bars such as Cards use separate `.filters-bar filters-inline` immediately after the section header. Assignments uses a card-like toolbar. The grouping language differs by view, so filter ownership and action hierarchy may vary across admin surfaces.

Evidence:
- `ui/section_header.gleam` provides a clear title/action pattern.
- `features/admin/cards_view.gleam` places filters directly after `section_header.view_with_action`.
- `styles/tables.gleam` defines `assignments-toolbar-card` with a separate card-like toolbar rhythm.
- `styles/dialogs.gleam` gives admin headers a bottom border and 16px wrapper margin, while filter bars depend on separate component rules.

Proposal:
- Standardize admin page composition as: section header, optional filter/search strip, content container.
- Define whether filters are part of the header area or a separate control panel.
- Keep action buttons visually tied to the section header, not to filters or table rows.

Acceptance criteria:
- Cards, Assignments, API Tokens and similar admin views share the same header/filter/content rhythm.
- Primary create actions stay paired with the section title.
- Filters do not look like they operate on the wrong table or card below.

### P2 - Right panel sections have compact but flat hierarchy

The right panel separates `EN CURSO`, `MIS TAREAS` and `MIS TARJETAS`, but section spacing and card treatment are close enough that active work, claimed work and assigned cards can read with similar weight. The current empty active-work hint is visually quiet, while claimed tasks and cards occupy stronger areas.

Evidence:
- `right-panel-activity` uses a consistent 16px gap.
- `active-task-section`, `my-tasks-section` and `my-cards-section` share compact internal rhythm.
- Desktop screenshot shows the right panel sections readable, but similarly weighted once active work is empty.

Proposal:
- Define section priority states:
  - Active work present: strongest section.
  - Active work empty: compact hint, not a full peer to task lists.
  - Claimed tasks: primary fallback work queue.
  - Cards: secondary ownership context.
- Use spacing and header weight to make those states explicit.

Acceptance criteria:
- When work is active, the active session clearly dominates the right panel.
- When no work is active, `MIS TAREAS` becomes the clear next action area.
- `MIS TARJETAS` remains useful context without competing with task execution.

### P3 - Generic small gaps create monotone grouping

Several surfaces use local gaps around `8px`, `10px`, `12px` and `16px` without a semantic spacing scale that distinguishes related controls, subgroups and section breaks. The result is often tidy, but it can make adjacent blocks look equally related.

Evidence:
- `.section` uses `gap: 10px`.
- `.center-toolbar` uses `gap: 12px`.
- `.center-filters-work` uses `padding: 10px 12px`.
- `.pool-view` uses `gap: 10px`.
- `.right-panel-activity` uses `gap: 16px`.

Proposal:
- Add semantic spacing roles to the design system:
  - related controls
  - controls within a panel
  - section-to-section
  - page/surface break
- Apply those roles before changing individual pixels.

Acceptance criteria:
- Repeated layout code uses named spacing intent instead of incidental local values.
- Adjacent surfaces cannot be mistaken for the same group purely because their gaps match.
- Future layout reviews can flag violations mechanically.

## Recommended backlog

- RB-020: Rebuild Pool header/filter/content grouping.
- RB-021: Define global vs contextual create-action hierarchy.
- RB-022: Reduce mobile filter dominance in work surfaces.
- RB-023: Standardize admin header/filter/content composition.
- RB-024: Introduce semantic spacing roles for layout grouping.

## Non-goals for the next implementation pass

- Do not revert the Pool claim icon-only improvement.
- Do not restore large task `border-left` identity treatment; keep the newer swatch model.
- Do not solve this as a one-off margin tweak unless the design-system spacing roles are also clarified.
