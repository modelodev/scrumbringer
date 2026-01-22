//// ViewModeToggle - Toggle component for switching between view modes
////
//// Mission: Provide a type-safe toggle for switching between Pool, List, and Cards
//// view modes with proper accessibility and visual feedback.
////
//// Responsibilities:
//// - Render 3 toggle buttons for view modes
//// - Highlight active mode
//// - Emit messages on mode change
//// - Include data-testid for E2E testing
////
//// Non-responsibilities:
//// - Managing view state (handled by parent)
//// - Rendering view content (handled by center panel)

import domain/view_mode.{type ViewMode, Cards, List, Pool}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

// =============================================================================
// Types
// =============================================================================

/// Configuration for the view mode toggle
pub type ToggleConfig(msg) {
  ToggleConfig(
    locale: Locale,
    current_mode: ViewMode,
    on_mode_change: fn(ViewMode) -> msg,
  )
}

// =============================================================================
// View
// =============================================================================

/// Renders the view mode toggle with 3 buttons
pub fn view(config: ToggleConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("view-mode-toggle"),
      attribute.attribute("role", "tablist"),
      attribute.attribute("aria-label", "View mode"),
    ],
    [
      view_mode_button(config, Pool, "view-mode-pool", i18n_text.Pool),
      view_mode_button(config, List, "view-mode-list", i18n_text.List),
      view_mode_button(config, Cards, "view-mode-cards", i18n_text.MemberFichas),
    ],
  )
}

fn view_mode_button(
  config: ToggleConfig(msg),
  mode: ViewMode,
  testid: String,
  label_key: i18n_text.Text,
) -> Element(msg) {
  let is_active = config.current_mode == mode
  let class = case is_active {
    True -> "view-mode-btn active"
    False -> "view-mode-btn"
  }

  button(
    [
      attribute.class(class),
      attribute.attribute("data-testid", testid),
      attribute.attribute("role", "tab"),
      attribute.attribute("aria-selected", bool_to_string(is_active)),
      attribute.attribute("tabindex", case is_active {
        True -> "0"
        False -> "-1"
      }),
      event.on_click(config.on_mode_change(mode)),
    ],
    [
      span([attribute.class("view-mode-icon")], [text(mode_icon(mode))]),
      span([attribute.class("view-mode-label")], [
        text(i18n.t(config.locale, label_key)),
      ]),
    ],
  )
}

fn mode_icon(mode: ViewMode) -> String {
  case mode {
    Pool -> "🎯"
    List -> "≡"
    Cards -> "🎴"
  }
}

fn bool_to_string(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}
