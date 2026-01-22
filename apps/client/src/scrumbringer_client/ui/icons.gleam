//// Icon Components for Scrumbringer client.
////
//// ## Mission
////
//// Provide type-safe icon definitions and rendering utilities.
//// Centralizes all icon definitions to prevent typos and ensure consistency.
////
//// ## Responsibilities
////
//// - Type-safe emoji icon constants
//// - Type-safe heroicon definitions for admin navigation
//// - Render heroicon outline SVG icons
//// - Render task type icons with theme awareness
////
//// ## Non-responsibilities
////
//// - Icon selection logic (handled by callers)
//// - Icon picker UI (see features/admin/view.gleam)
////
//// ## Relations
////
//// - **features/admin/view.gleam**: Uses for task type icons
//// - **features/my_bar/view.gleam**: Uses for task type icons
//// - **features/pool/view.gleam**: Uses for task type icons
//// - **client_view.gleam**: Uses for admin navigation icons

import gleam/int
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{img}

import scrumbringer_client/client_state.{type Msg}
import scrumbringer_client/permissions
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/icon_catalog

// =============================================================================
// Emoji Icons (Type-Safe)
// =============================================================================

/// Emoji icons used in UI components.
pub type EmojiIcon {
  Target
  Search
  Hand
  Checkmark
  Drag
  Release
  Lightbulb
  Wave
  Backpack
  Clock
  Inbox
  // Empty state icons
  Clipboard
  FolderEmoji
  UsersEmoji
  Sparkles
}

/// Converts an emoji icon to its string representation.
pub fn emoji_to_string(icon: EmojiIcon) -> String {
  case icon {
    Target -> "🎯"
    Search -> "🔍"
    Hand -> "✋"
    Checkmark -> "☑"
    Drag -> "⠿"
    Release -> "⟲"
    Lightbulb -> "💡"
    Wave -> "👋"
    Backpack -> "🎒"
    Clock -> "⏱"
    Inbox -> "📥"
    // Empty state icons
    Clipboard -> "📋"
    FolderEmoji -> "📁"
    UsersEmoji -> "👥"
    Sparkles -> "✨"
  }
}

// =============================================================================
// Heroicons (Type-Safe)
// =============================================================================

/// Heroicon names for admin navigation.
pub type HeroIcon {
  Envelope
  BuildingOffice
  Folder
  ChartBar
  ChartPie
  Users
  PuzzlePiece
  Tag
  DocumentText
  Cog6Tooth
  DocumentDuplicate
}

/// Converts a heroicon to its name string.
pub fn heroicon_name(icon: HeroIcon) -> String {
  case icon {
    Envelope -> "envelope"
    BuildingOffice -> "building-office"
    Folder -> "folder"
    ChartBar -> "chart-bar"
    ChartPie -> "chart-pie"
    Users -> "users"
    PuzzlePiece -> "puzzle-piece"
    Tag -> "tag"
    DocumentText -> "document-text"
    Cog6Tooth -> "cog-6-tooth"
    DocumentDuplicate -> "document-duplicate"
  }
}

/// Maps admin section to its heroicon.
pub fn section_icon(section: permissions.AdminSection) -> HeroIcon {
  case section {
    permissions.Invites -> Envelope
    permissions.OrgSettings -> BuildingOffice
    permissions.Projects -> Folder
    permissions.Metrics -> ChartBar
    permissions.RuleMetrics -> ChartPie
    permissions.Members -> Users
    permissions.Capabilities -> PuzzlePiece
    permissions.TaskTypes -> Tag
    permissions.Cards -> DocumentText
    permissions.Workflows -> Cog6Tooth
    permissions.TaskTemplates -> DocumentDuplicate
  }
}

/// Build the URL for a typed heroicon.
pub fn heroicon_typed_url(icon: HeroIcon) -> String {
  heroicon_outline_url(heroicon_name(icon))
}

// =============================================================================
// Heroicon Utilities
// =============================================================================

/// Build the URL for a heroicon outline SVG.
pub fn heroicon_outline_url(name: String) -> String {
  "https://cdn.jsdelivr.net/npm/heroicons@2.2.0/24/outline/" <> name <> ".svg"
}

/// Render a heroicon outline as an inline img element.
pub fn view_heroicon_inline(
  name: String,
  size: Int,
  theme: Theme,
) -> Element(Msg) {
  let filter = case theme {
    theme.Dark -> "invert(1)"
    theme.Default -> ""
  }

  img([
    attribute.src(heroicon_outline_url(name)),
    attribute.alt(name),
    attribute.attribute("width", int.to_string(size)),
    attribute.attribute("height", int.to_string(size)),
    attribute.attribute(
      "style",
      "vertical-align:middle; filter:" <> filter <> ";",
    ),
  ])
}

// =============================================================================
// Task Type Icon Utilities
// =============================================================================

/// Render a task type icon inline with theme awareness.
///
/// Uses the curated icon catalog for embedded SVG rendering.
/// Falls back to CDN for icons not in the catalog.
pub fn view_task_type_icon_inline(
  icon_name: String,
  size: Int,
  theme: Theme,
) -> Element(Msg) {
  case string.is_empty(icon_name) {
    True -> element.none()
    False ->
      case icon_catalog.exists(icon_name) {
        True -> icon_catalog.render_with_class(icon_name, size, theme_class(theme))
        False -> view_heroicon_inline(icon_name, size, theme)
      }
  }
}

/// Convert theme to CSS class for icon styling.
fn theme_class(theme: Theme) -> String {
  case theme {
    theme.Dark -> "icon-theme-dark"
    theme.Default -> ""
  }
}
