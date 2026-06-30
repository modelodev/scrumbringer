---
name: ScrumBringer
description: Pull-flow task cockpit for autonomous agile teams.
colors:
  bg: "oklch(98.2% 0.008 190)"
  surface: "oklch(100% 0 0)"
  elevated: "oklch(96.2% 0.012 190)"
  surface-2: "oklch(98.4% 0.012 190)"
  surface-3: "oklch(94.2% 0.018 190)"
  text: "oklch(21% 0.035 235)"
  text-strong: "oklch(14% 0.03 235)"
  text-soft: "oklch(34% 0.035 220)"
  muted: "oklch(43% 0.035 220)"
  border: "oklch(88% 0.015 190)"
  link: "oklch(45% 0.13 245)"
  primary: "oklch(47% 0.09 185)"
  primary-hover: "oklch(39% 0.08 185)"
  primary-subtle-bg: "oklch(96% 0.035 185)"
  primary-subtle-border: "oklch(76% 0.08 185)"
  danger: "oklch(43% 0.17 25)"
  warning: "oklch(43% 0.11 70)"
  success: "oklch(40% 0.11 150)"
  info: "oklch(42% 0.12 235)"
  dark-bg: "oklch(16% 0.03 225)"
  dark-surface: "oklch(20% 0.032 225)"
  dark-elevated: "oklch(26% 0.035 225)"
  dark-text: "oklch(91% 0.015 220)"
  dark-border: "oklch(38% 0.035 225)"
  card-red: "oklch(60% 0.2 25)"
  card-orange: "oklch(67% 0.18 55)"
  card-yellow: "oklch(75% 0.16 95)"
  card-green: "oklch(65% 0.16 150)"
  card-blue: "oklch(60% 0.16 245)"
  card-purple: "oklch(58% 0.18 300)"
typography:
  display:
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif"
    fontSize: "24px"
    fontWeight: 800
    lineHeight: 1.15
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "0"
  title:
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.35
    letterSpacing: "0"
  body:
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0"
  label:
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.05em"
rounded:
  sm: "6px"
  md: "8px"
  lg: "10px"
  xl: "12px"
  xxl: "16px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "6px"
  md: "8px"
  lg: "12px"
  xl: "16px"
  xxl: "20px"
  xxxl: "24px"
  xxxxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#ffffff"
    rounded: "{rounded.lg}"
    padding: "10px 16px"
    typography: "{typography.body}"
  button-secondary:
    backgroundColor: "{colors.surface-3}"
    textColor: "{colors.text}"
    rounded: "{rounded.lg}"
    padding: "8px 12px"
    typography: "{typography.body}"
  button-icon:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.muted}"
    rounded: "{rounded.md}"
    size: "32px"
  input:
    backgroundColor: "{colors.elevated}"
    textColor: "{colors.text}"
    rounded: "{rounded.lg}"
    padding: "8px"
    typography: "{typography.body}"
  surface-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.xl}"
    padding: "12px"
  badge-primary:
    backgroundColor: "{colors.primary-subtle-bg}"
    textColor: "{colors.primary}"
    rounded: "{rounded.pill}"
    padding: "2px 8px"
    typography: "{typography.label}"
---

# Design System: ScrumBringer

## 1. Overview

**Creative North Star: "The Pull Flow Cockpit"**

ScrumBringer's visual system is a compact operating cockpit for teams that trust people to pull work. It should feel autonomous, clear, and operational: the UI stays quiet until state changes, then uses direct color, shape, and motion to reveal what is available, claimed, active, blocked, stale, or complete.

The existing system is a restrained product UI: system sans typography, cool slate neutrals, teal primary actions, tight spacing, 8-12px component corners, and strong semantic state colors. It should preserve density and scan speed rather than chasing brand spectacle. The product rejects push-assignment habits, static backlog sprawl, and decorative dashboards that hide the next action.

**Key Characteristics:**

- Dense but legible operational panels.
- Teal is the action and selection color, not decoration.
- State is communicated through labels, chips, borders, icons, and copy, not color alone.
- Cards and rows are compact, bordered surfaces with modest tonal layering.
- Motion exists for feedback, reveal, loading, stale-task decay, and mobile panel movement only.

## 2. Colors

The palette is cool, restrained, and state-rich: slate neutrals carry the workspace, teal marks ownership and action, and semantic colors explain flow health.

### Primary

- **Pool Teal** (`primary`): Used for primary actions, active navigation, selected states, progress fills, focusable task links, and pull-flow emphasis.
- **Deep Pool Teal** (`primary-hover`): Used only for hover and pressed primary action states.
- **Teal Mist** (`primary-subtle-bg`): Used for selected or active surfaces where a full teal fill would be too loud.

### Secondary

- **Action Blue** (`link`, `info`): Used for links, informational states, and status badges that are not ownership or success.
- **Flow Green** (`success`): Used for claim, complete, active-session positive signals, and completion progress.
- **Stale Amber** (`warning`): Used for aging, incomplete rules, stale work, and attention states.
- **Stop Red** (`danger`): Used for destructive actions, validation errors, and denied flows.

### Neutral

- **Workspace Slate** (`bg`): The app canvas and background field.
- **Panel White** (`surface`): Primary content and panels in the default theme.
- **Raised Slate** (`elevated`): Toolbars, filters, row backgrounds, empty hints, and secondary panels.
- **Ink Slate** (`text`, `text-strong`): Main reading text and high-emphasis labels.
- **Muted Slate** (`muted`, `text-soft`): Secondary metadata, hints, helper text, and low-emphasis labels.
- **Line Slate** (`border`): Dividers, panel outlines, table rows, inputs, and inactive button borders.
- **Night Slate** (`dark-bg`, `dark-surface`, `dark-elevated`): Dark theme surface vocabulary; use the same roles rather than inventing a parallel color language.

### Named Rules

**The Teal Is Action Rule.** Pool Teal is reserved for things the user can act on or states that prove ownership. Do not use it as decorative chrome.

**The State Vocabulary Rule.** Success, warning, danger, and info are semantic. Never use them because a screen "needs more color."

**The No New Side-Stripe Rule.** Do not add new colored border-left or border-right stripe patterns. Existing legacy status edges should be contained and replaced by chips, dots, or full state treatments when a surface is redesigned.

## 3. Typography

**Display Font:** system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif
**Body Font:** system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif
**Label/Mono Font:** ui-monospace, monospace for timers, API tokens, variable hints, and tabular operational values.

**Character:** The type system is utilitarian and compact. It uses one familiar sans family for trust and speed, with monospace reserved for values where alignment and precision matter.

### Hierarchy

- **Display** (800, 24px, 1.15): Rare page-level titles and auth screens. Keep letter spacing no tighter than -0.02em.
- **Headline** (700, 20px, 1.25): Dialog titles, milestone detail headings, and major section titles.
- **Title** (700, 16px, 1.35): Admin card titles, empty-state titles, and dense panel headers.
- **Body** (400, 13px, 1.5): Default product copy, table cells, task metadata, and panel content. Prose should stay within 65-75ch when it is explanatory rather than tabular.
- **Label** (600, 11-12px, 0.03-0.06em): Section titles, table headers, metadata labels, and compact badge labels. Uppercase is allowed for navigation groups and table headers only.

### Named Rules

**The One Sans Rule.** Do not introduce display fonts or decorative type into product UI. This interface earns confidence through consistency.

**The Data First Rule.** Timers, API secrets, counts, progress values, and variable hints use monospace or tabular numerals when alignment improves comprehension.

## 4. Elevation

ScrumBringer uses a hybrid depth model: borders and tonal layers define most surfaces, while shadows are reserved for popovers, hover previews, toasts, dialogs, and mobile sheets. Static panels should look organized, not floating.

### Shadow Vocabulary

- **Soft Panel Shadow** (`--sb-shadow-soft: 0 6px 20px rgba(15, 23, 42, 0.08)`): Existing light-theme panel lift. Use sparingly on app shell containers.
- **Modal Shadow** (`--sb-shadow-modal: 0 24px 60px rgba(15, 23, 42, 0.24)`): Dialog and modal elevation.
- **Preview Shadow** (`box-shadow: 0 10px 30px rgba(0,0,0,0.18)`): Task preview and settings dropdown hover elevation.
- **Menu Shadow** (`box-shadow: 0 8px 20px rgba(0, 0, 0, 0.08)`): Lightweight dropdowns and move menus.
- **Mobile Sheet Shadow** (`box-shadow: 0 -8px 24px rgba(0,0,0,0.15)`): Bottom sheets and mobile working panels.

### Named Rules

**The Border First Rule.** Resting product surfaces use a 1px Line Slate border before they use shadow.

**The Shadow Means Overlay Rule.** If an element casts a strong shadow, it should be a dialog, dropdown, preview, toast, drawer, or actively hovered surface.

## 5. Components

### Buttons

- **Shape:** Gently compact rounded controls (8-10px), with pill shape only for badges and segmented pills.
- **Primary:** Pool Teal fill with white text, 10px 16px padding, 500-600 weight. Use for create, save, claim, and other decisive actions.
- **Hover / Focus:** Hover deepens the teal. Focus uses a visible ring or outline, not a color-only change.
- **Secondary / Ghost:** Secondary buttons use raised slate or transparent backgrounds with Line Slate borders. Icon-only controls must stay at least 28px desktop and 44px mobile when touch-targeted.

### Chips

- **Style:** Chips and badges are inline-flex, 2px 8px, pill radius, 11-12px text. They use subtle color-mix backgrounds and semantic text colors.
- **State:** Use primary chips for selected or ownership states, success for completion and active positive states, warning for stale or incomplete states, danger for destructive or error states, and neutral for metadata.

### Cards / Containers

- **Corner Style:** Standard cards use 10-12px radius; dialogs and mobile sheets may use 16-18px only when the surface is modal.
- **Background:** Primary cards use Panel White; nested or secondary surfaces use Raised Slate.
- **Shadow Strategy:** Cards are border-first. Shadows appear on hover previews, active overlays, dialogs, and elevated shell containers.
- **Border:** Default is 1px Line Slate. Avoid new colored side stripes; use chips, dots, or full-border state treatments for status.
- **Internal Padding:** Dense cards use 10px 12px; admin cards use 16px; dialogs use 16-20px.

### Inputs / Fields

- **Style:** Inputs use Raised Slate background, Line Slate border, 8-10px radius, and 8-12px padding.
- **Focus:** Border shifts to Pool Teal and receives a subtle teal ring.
- **Error / Disabled:** Error fields use Stop Red border and red focus ring. Disabled controls reduce opacity and keep the same shape vocabulary.

### Navigation

- **Style:** Desktop uses a three-panel grid with a 240px left panel, fluid center panel, and 300px right activity panel. Panel gaps are 12px.
- **States:** Navigation items are compact 8px-radius rows. Hover uses Raised Slate; active state uses Teal Mist, a primary border treatment, and stronger text.
- **Mobile:** At 768px and below, panels collapse into focused mobile shells, drawers, mini-bars, and bottom sheets. Touch targets become at least 44px.

### Task Card

Task cards are the signature operational object. They use bordered compact surfaces, centered task titles, always-accessible action controls, visible drag affordances, and hover/focus previews. Priority and decay may change size or motion, but actions must remain usable even on small cards.

### Pool Canvas

The pool canvas should avoid native scrollbars in normal desktop use. Preserve task size and user-arranged positions whenever possible; when legacy or manual positions place tasks outside the visible pool area, only those out-of-viewport tasks should be visually relocated into free visible space. Do not disturb tasks that are already visible, and do not solve pool overflow by shrinking task cards.

### Dialog

Dialogs use a fixed overlay, Panel White body, Raised Slate header/footer, 18px corner radius on desktop, and full-screen treatment on small screens. Dialogs are for confirmation and complex CRUD only; inline or progressive alternatives should be exhausted first.

## 6. Do's and Don'ts

### Do:

- **Do** make pull behavior obvious: available, claimed, now working, released, and completed must remain visually distinct.
- **Do** use Pool Teal for primary actions, current selection, ownership, and progress.
- **Do** preserve compact panel density with 8-12px spacing, 8-12px radii, and clear scan paths.
- **Do** communicate state with words, icons, chips, and shape as well as color.
- **Do** keep task actions visible and reachable even when the card is small.
- **Do** use skeletons, inline hints, and empty states that teach the next action.
- **Do** keep motion short: 120-300ms for feedback and reveal, with reduced-motion behavior preserved.

### Don't:

- **Don't** create push-assignment patterns that imply someone else owns deciding who does the work.
- **Don't** make the product feel like Jira, Asana, or Trello when those tools reinforce direct assignment, backlog sprawl, and manager-driven routing.
- **Don't** build static backlog views where old and urgent work look the same.
- **Don't** add decorative dashboards that hide the next action.
- **Don't** make workflows, rules, cards, or process surfaces feel like paperwork.
- **Don't** blur "assigned", "claimed", and "now working" into one ambiguous ownership state.
- **Don't** add visual noise that makes the shared pool harder to scan.
- **Don't** use gradient text, glassmorphism, decorative stripes, or large soft shadow plus 1px border as a default card style.
- **Don't** add new colored side-stripe border patterns. Use chips, dots, full borders, or semantic badges instead.
