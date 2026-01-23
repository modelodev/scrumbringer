//// Section Header Component for Admin Views.
////
//// ## Mission
////
//// Provides a consistent, reusable section header pattern for all admin views.
//// Ensures visual consistency between sidebar navigation and view headers.
////
//// ## Design Principles (Story 4.8 UX)
////
//// - Icons in headers MUST match sidebar icons (visual continuity)
//// - Uses NavIcon ADT for type-safe icon rendering (no emojis)
//// - Consistent sizing: Medium (20px) icons for headers
//// - Consistent height whether or not there's an action button
//// - Optional subtitle for descriptive help text
////
//// ## Usage
////
//// ```gleam
//// // Simple header (no action, no subtitle)
//// section_header.view(icons.OrgUsers, "Usuarios")
////
//// // Header with subtitle
//// section_header.view_with_subtitle(
////   icons.OrgUsers,
////   "Usuarios",
////   "Gestiona los roles de la organización.",
//// )
////
//// // Header with action button
//// section_header.view_with_action(
////   icons.Crosshairs,
////   "Capacidades",
////   dialog.add_button(model, i18n_text.CreateCapability, OpenDialog),
//// )
////
//// // Header with action AND subtitle
//// section_header.view_full(
////   icons.Team,
////   "Miembros",
////   "Los miembros pueden ver y reclamar tareas.",
////   dialog.add_button(model, i18n_text.AddMember, OpenDialog),
//// )
//// ```

import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, p, span, text}

import scrumbringer_client/ui/icons.{type NavIcon}

// =============================================================================
// Public API
// =============================================================================

/// Render a section header with icon and title (no action, no subtitle).
pub fn view(icon: NavIcon, title: String) -> Element(msg) {
  view_internal(icon, title, None, element.none())
}

/// Render a section header with icon, title, and subtitle (no action).
pub fn view_with_subtitle(
  icon: NavIcon,
  title: String,
  subtitle: String,
) -> Element(msg) {
  view_internal(icon, title, Some(subtitle), element.none())
}

/// Render a section header with icon, title, and action (no subtitle).
pub fn view_with_action(
  icon: NavIcon,
  title: String,
  action: Element(msg),
) -> Element(msg) {
  view_internal(icon, title, None, action)
}

/// Render a full section header with icon, title, subtitle, and action.
pub fn view_full(
  icon: NavIcon,
  title: String,
  subtitle: String,
  action: Element(msg),
) -> Element(msg) {
  view_internal(icon, title, Some(subtitle), action)
}

// =============================================================================
// Internal
// =============================================================================

fn view_internal(
  icon: NavIcon,
  title: String,
  subtitle: Option(String),
  action: Element(msg),
) -> Element(msg) {
  div([attribute.class("admin-section-header-wrapper")], [
    // Main header row (icon + title + action)
    div([attribute.class("admin-section-header")], [
      div([attribute.class("admin-section-title")], [
        span([attribute.class("admin-section-icon")], [
          icons.nav_icon(icon, icons.Medium),
        ]),
        text(title),
      ]),
      // Action slot (empty div if no action, for consistent layout)
      div([attribute.class("admin-section-action")], [action]),
    ]),
    // Optional subtitle
    case subtitle {
      Some(sub) ->
        p([attribute.class("admin-section-subtitle")], [text(sub)])
      None -> element.none()
    },
  ])
}
