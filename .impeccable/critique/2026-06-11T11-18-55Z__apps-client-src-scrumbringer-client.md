---
target: apps/client/src/scrumbringer_client
total_score: 23
p0_count: 0
p1_count: 2
timestamp: 2026-06-11T11-18-55Z
slug: apps-client-src-scrumbringer-client
---
#### Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Timers, loading, errors, toasts, and active nav exist; action-level confirmation is uneven. |
| 2 | Match System / Real World | 3 | Pull concepts are present, but `claimed` / `now working` still read as system states rather than human workflow. |
| 3 | User Control and Freedom | 2 | Release/complete/create flows rely on small icon actions and modal patterns with limited undo/recovery visibility. |
| 4 | Consistency and Standards | 2 | Task state appears through cards, rows, kanban, badges, dots, side stripes, timers, and motion. |
| 5 | Error Prevention | 2 | Destructive confirmations exist, but drag/claim/release/admin actions need stronger guardrails and clearer disabled reasons. |
| 6 | Recognition Rather Than Recall | 2 | Many core task actions are icon-only and require learned semantics. |
| 7 | Flexibility and Efficiency | 3 | Dense views, filters, mobile shell, and multiple work views help; keyboard/power flows are not visible. |
| 8 | Aesthetic and Minimalist Design | 2 | Compact and calm, but too many bordered surfaces, section labels, badges, and action clusters compete. |
| 9 | Error Recovery | 2 | Errors render, but recovery paths are generic and not always tied to the failed control. |
| 10 | Help and Documentation | 2 | Inline hints and empty states exist; contextual “why this state/action matters” help is thin. |
| **Total** | | **23/40** | **Functional but fragmented.** |

#### Anti-Patterns Verdict

**LLM assessment:** The app does not look like obvious AI slop. It reads like a real operational product with coherent tokens, dense panels, and practical affordances. The problem is “admin-template gravity”: repeated tables, generic dialogs, side-stripe status accents, icon-only task actions, and evenly weighted panels make it feel more like a competent internal CRUD app than a pull-flow cockpit.

**Deterministic scan:** CLI detector reported no findings for `apps/client/src/scrumbringer_client` (`[]`, exit code 0). Browser overlay on the unauthenticated login screen reported one anti-pattern group: `flat-type-hierarchy` at `body` with sizes `13.3px, 14px, 16px, 24px` and a `layout-transition` signal for `transition: width`.

**Visual overlays:** Overlay injection succeeded in the browser for the login screen only. Authenticated app surfaces were not inspected visually because only the client dev server was running and no API/session was available.

#### Overall Impression

ScrumBringer has the right product bones: three-panel shell, pool-plus-personal-work split, compact tokens, and a mobile execution mode that respects the product. The biggest opportunity is to define one unmistakable task-state/action grammar so the product feels like “I pull the right work now,” not “I operate a dense board of icons and status hints.”

#### What's Working

- The three-panel architecture maps well to the product: navigation, shared work, and personal activity are separate mental zones.
- The visual token system is restrained and appropriate: slate neutrals, teal for action, semantic state colors, compact spacing.
- The mobile philosophy is strong: mobile focuses on active and claimed work instead of pretending the full pool cockpit belongs on a phone.

#### Priority Issues

**[P1] Task state language is visually fragmented**

**Why it matters:** Available, claimed, now working, blocked, stale, and completed are represented by icons, position, badges, timers, dots, side stripes, animation, and hover detail. Users must learn the interface before they can trust the state.

**Fix:** Define one task-state grammar: state chip + primary action slot + secondary health indicators. Reuse it across canvas cards, list rows, right panel, kanban, and mobile.

**Suggested command:** `$impeccable clarify apps/client/src/scrumbringer_client`

**[P1] The primary pull action is too small and icon-dependent**

**Why it matters:** Claiming work is the core product behavior, but on pool cards it is a small icon competing with drag, complete, blocked, and preview affordances.

**Fix:** Make `Claim` the most legible action on available tasks: visible label when card size allows, consistent placement, stronger disabled/blocked explanation, and a clear success state after claiming.

**Suggested command:** `$impeccable polish apps/client/src/scrumbringer_client/features/pool`

**[P2] Side-stripe/card-color pattern conflicts with operational state**

**Why it matters:** Colored left borders appear on active task cards, task items, kanban task items, and my cards. They can be mistaken for task status or urgency, while the design system says not to add new side stripes.

**Fix:** Reserve color dots/swatches for parent card identity. Use chips, full-border treatments, or semantic badges for task state and flow health.

**Suggested command:** `$impeccable colorize apps/client/src/scrumbringer_client`

**[P2] Admin surfaces feel like generic CRUD rather than flow-health tools**

**Why it matters:** Cards, workflows, members, tokens, and rules mostly render as tables plus modal dialogs. That is maintainable, but it underplays attention, risk, and flow-health decisions.

**Fix:** Add task-focused summaries above tables: what needs attention, what is stale/misconfigured, what changed recently. Keep tables for maintenance, not as the first and only information architecture.

**Suggested command:** `$impeccable layout apps/client/src/scrumbringer_client/features/admin`

**[P2] Mobile actions are tactically good but context-thin**

**Why it matters:** Mobile Now Working and claimed rows support execution, but users lose the “why this task” context from desktop pool/card/priority signals.

**Fix:** Add one compact metadata line per mobile row: card, priority/age, blocked state, or capability reason. Keep actions bottom-friendly.

**Suggested command:** `$impeccable adapt apps/client/src/scrumbringer_client/features/now_working`

#### Persona Red Flags

**Alex, power developer:** Can move quickly once trained, but must learn icon meanings for claim/release/complete/drag. No obvious keyboard-first or bulk path is visible from source patterns.

**Sam, accessibility-dependent user:** Focus states and ARIA landmarks exist, but hover previews, icon-only task actions, animated stale-task shakes, and color/side-stripe semantics create keyboard and low-vision risk.

**Casey, distracted mobile user:** Mobile shell is well scoped, but the mini-bar and panel sheet may not explain what changed after pause/complete/release. Context loss is the risk.

#### Minor Observations

- Radial/grid backgrounds may add visual noise to a cockpit that already has many dense signals.
- “Now Working” is conceptually important but awkward in English; “Working now” or “Active work” scans faster.
- Task card hover previews are useful, but relying on hover for detail makes touch and keyboard parity harder.
- Repeated uppercase section labels are acceptable in product UI, but there are enough of them that grouping starts to feel mechanical.
- Login-screen runtime overlay detected flat type hierarchy; this is less important than authenticated app issues but still points to a compressed type scale.

#### Questions to Consider

- What if the pool had exactly one unmistakable primary action per task state?
- What if `claimed` and `now working` were not separate places to inspect, but one personal work lane with clear substates?
- What would let a developer trust the top available task in five seconds without opening its detail preview?
- Are admin tables helping flow health, or mostly preserving configuration records?
