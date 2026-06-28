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
//// - Type-safe navigation icons with exhaustive pattern matching
//// - Render heroicon outline SVG icons (inline via gleroglero)
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
//// - **features/layout/sidebar.gleam**: Uses NavIcon for sidebar

import gleam/int
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span}

import gleroglero/outline

import scrumbringer_client/permissions
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/icon_catalog

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
    permissions.ApiTokens -> Cog6Tooth
    permissions.Members -> Users
    permissions.Capabilities -> PuzzlePiece
    permissions.TaskTypes -> Tag
    permissions.Cards -> DocumentText
    permissions.Workflows -> Cog6Tooth
    permissions.TaskTemplates -> DocumentDuplicate
    permissions.Team -> Users
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
  _theme: Theme,
) -> Element(msg) {
  let url = heroicon_outline_url(name)
  let size_px = int.to_string(size) <> "px"

  span(
    [
      attribute.class("heroicon-inline"),
      attribute.attribute("role", "img"),
      attribute.attribute("aria-label", name),
      attribute.attribute(
        "style",
        "display:inline-block;width:"
          <> size_px
          <> ";height:"
          <> size_px
          <> ";vertical-align:middle;background-color:currentColor;mask:url('"
          <> url
          <> "') center / contain no-repeat;-webkit-mask:url('"
          <> url
          <> "') center / contain no-repeat;",
      ),
    ],
    [],
  )
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
) -> Element(msg) {
  case string.is_empty(icon_name) {
    True -> element.none()
    False ->
      case icon_catalog.exists(icon_name) {
        True ->
          icon_catalog.render_with_class(icon_name, size, theme_class(theme))
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

// =============================================================================
// Navigation Icons (Type-Safe, Exhaustive)
// =============================================================================

/// Navigation icons for sidebar - exhaustive ADT ensures all cases are handled.
///
/// Using an ADT (Algebraic Data Type) instead of strings provides:
/// - Compile-time verification that all icons are handled
/// - No typos possible
/// - Easy refactoring with compiler help
pub type NavIcon {
  // TRABAJO section
  Pool
  List
  Cards
  // CONFIGURACION section
  Team
  Catalog
  Automation
  Metrics
  Workflows
  Capabilities
  TaskTypes
  TaskTemplates
  // ORGANIZACION section
  Invites
  OrgUsers
  Projects
  OrgMetrics
  // Actions
  Copy
  Plus
  Check
  XMark
  // Additional UI icons (Story 4.8 - emoji replacement)
  Warning
  Star
  StarOutline
  HandRaised
  ClipboardDoc
  InboxEmpty
  ChartUp
  CheckCircle
  // Filter icons
  MagnifyingGlass
  Crosshairs
  TagLabel
  // Action icons
  Pencil
  Trash
  Refresh
  DragHandle
  Pause
  Play
  Return
  Cog
  Calendar
  EmptyMailbox
  Close
  Menu
  MoreHorizontal
  // Sub-section icons (Story 4.8 UX)
  Rules
  // Right panel icons (Story 4.8 UX)
  Sun
  Moon
  Globe
  UserCircle
  Logout
  // Informational icons
  Info
  // Link icons (Story 5.4)
  GitHub
  ExternalLink
}

/// Icon size variants for consistent sizing.
pub type IconSize {
  // Story 4.8 UX: Added XSmall for compact task lists in Kanban
  XSmall
  Small
  Medium
  Large
}

/// Get pixel size for an IconSize variant.
pub fn icon_size_px(size: IconSize) -> Int {
  case size {
    XSmall -> 12
    Small -> 16
    Medium -> 20
    Large -> 24
  }
}

/// Render a navigation icon as inline SVG.
///
/// Uses exhaustive pattern matching - compiler ensures all icons are handled.
///
/// ## Example
///
/// ```gleam
/// icons.nav_icon(icons.Pool, icons.Medium)
/// ```
pub fn nav_icon(icon: NavIcon, size: IconSize) -> Element(a) {
  let svg = case icon {
    Pool -> outline.square_3_stack_3d()
    List -> outline.queue_list()
    Cards -> outline.rectangle_stack()
    Team -> outline.user_group()
    Catalog -> outline.tag()
    Automation -> outline.bolt()
    Metrics -> outline.chart_bar()
    Workflows -> outline.cog_6_tooth()
    Capabilities -> outline.puzzle_piece()
    TaskTypes -> outline.tag()
    TaskTemplates -> outline.document_duplicate()
    Invites -> outline.envelope()
    OrgUsers -> outline.users()
    Projects -> outline.folder()
    OrgMetrics -> outline.chart_pie()
    Copy -> outline.clipboard_document()
    Plus -> outline.plus()
    Check -> outline.check()
    XMark -> outline.x_mark()
    // Additional UI icons
    Warning -> outline.exclamation_triangle()
    Star -> outline.star()
    StarOutline -> outline.star()
    HandRaised -> outline.hand_raised()
    ClipboardDoc -> outline.clipboard_document_list()
    InboxEmpty -> outline.inbox()
    ChartUp -> outline.arrow_trending_up()
    CheckCircle -> outline.check_circle()
    // Filter icons
    MagnifyingGlass -> outline.magnifying_glass()
    Crosshairs -> outline.cursor_arrow_rays()
    TagLabel -> outline.tag()
    // Action icons
    Pencil -> outline.pencil()
    Trash -> outline.trash()
    Refresh -> outline.arrow_path()
    DragHandle -> outline.bars_3()
    Pause -> outline.pause()
    Play -> outline.play()
    Return -> outline.arrow_uturn_left()
    Cog -> outline.cog_6_tooth()
    Calendar -> outline.calendar()
    EmptyMailbox -> outline.inbox()
    Close -> outline.x_mark()
    Menu -> outline.bars_3()
    MoreHorizontal -> outline.ellipsis_horizontal()
    // Sub-section icons (Story 4.8 UX)
    Rules -> outline.document_text()
    // Right panel icons (Story 4.8 UX)
    Sun -> outline.sun()
    Moon -> outline.moon()
    Globe -> outline.globe_alt()
    UserCircle -> outline.user_circle()
    Logout -> outline.arrow_right_start_on_rectangle()
    // Informational icons
    Info -> outline.information_circle()
    // Link icons (Story 5.4)
    GitHub -> outline.code_bracket()
    ExternalLink -> outline.arrow_top_right_on_square()
  }

  let px = icon_size_px(size)
  span(
    [
      attribute.class("nav-icon"),
      attribute.attribute(
        "style",
        "display:inline-flex;align-items:center;justify-content:center;width:"
          <> int.to_string(px)
          <> "px;height:"
          <> int.to_string(px)
          <> "px;",
      ),
    ],
    [svg],
  )
}
