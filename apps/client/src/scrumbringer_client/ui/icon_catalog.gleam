//// Icon catalog for task types.
////
//// Provides a curated set of Heroicons for use in task type selection.
//// Uses gleroglero for embedded SVG rendering (no CDN dependency).

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

import gleroglero/outline

// =============================================================================
// Types
// =============================================================================

/// A curated icon entry with metadata.
pub type CatalogIcon {
  CatalogIcon(id: String, label: String)
}

// =============================================================================
// Catalog Data
// =============================================================================

/// Curated catalog of ~60 icons for task management.
pub fn catalog() -> List(CatalogIcon) {
  [
    // Tasks (work items)
    CatalogIcon("bug-ant", "Bug"),
    CatalogIcon("sparkles", "Feature"),
    CatalogIcon("clipboard-document-check", "Task"),
    CatalogIcon("clipboard-document-list", "List"),
    CatalogIcon("document-text", "Document"),
    CatalogIcon("light-bulb", "Idea"),
    CatalogIcon("wrench-screwdriver", "Fix"),
    CatalogIcon("wrench", "Maintenance"),
    CatalogIcon("beaker", "Experiment"),
    CatalogIcon("rocket-launch", "Launch"),
    CatalogIcon("code-bracket", "Code"),
    CatalogIcon("command-line", "Script"),
    CatalogIcon("cube", "Component"),
    CatalogIcon("puzzle-piece", "Integration"),
    CatalogIcon("shield-check", "Security"),
    CatalogIcon("chart-bar", "Analytics"),
    // Status (states)
    CatalogIcon("check-circle", "Closed"),
    CatalogIcon("check", "Check"),
    CatalogIcon("x-circle", "Cancelled"),
    CatalogIcon("pause-circle", "Paused"),
    CatalogIcon("play-circle", "In Progress"),
    CatalogIcon("stop-circle", "Blocked"),
    CatalogIcon("clock", "Pending"),
    CatalogIcon("arrow-path", "Recurring"),
    CatalogIcon("eye", "Review"),
    CatalogIcon("eye-slash", "Hidden"),
    CatalogIcon("lock-closed", "Locked"),
    CatalogIcon("lock-open", "Unlocked"),
    CatalogIcon("archive-box", "Archived"),
    // Priority (importance)
    CatalogIcon("bolt", "Urgent"),
    CatalogIcon("fire", "Critical"),
    CatalogIcon("flag", "Flagged"),
    CatalogIcon("star", "Important"),
    CatalogIcon("exclamation-triangle", "Warning"),
    CatalogIcon("exclamation-circle", "Alert"),
    CatalogIcon("bell", "Notification"),
    CatalogIcon("bell-alert", "Alarm"),
    // Objects (things)
    CatalogIcon("folder", "Folder"),
    CatalogIcon("folder-open", "Open Folder"),
    CatalogIcon("inbox", "Inbox"),
    CatalogIcon("inbox-stack", "Queue"),
    CatalogIcon("tag", "Tag"),
    CatalogIcon("bookmark", "Bookmark"),
    CatalogIcon("paper-clip", "Attachment"),
    CatalogIcon("link", "Link"),
    CatalogIcon("photo", "Image"),
    CatalogIcon("calendar", "Calendar"),
    CatalogIcon("calendar-days", "Schedule"),
    CatalogIcon("globe-alt", "Web"),
    CatalogIcon("server", "Server"),
    CatalogIcon("cpu-chip", "Hardware"),
    // Actions (verbs)
    CatalogIcon("pencil", "Edit"),
    CatalogIcon("pencil-square", "Write"),
    CatalogIcon("trash", "Delete"),
    CatalogIcon("plus-circle", "Add"),
    CatalogIcon("minus-circle", "Remove"),
    CatalogIcon("magnifying-glass", "Search"),
    CatalogIcon("paper-airplane", "Send"),
    CatalogIcon("chat-bubble-left-right", "Discuss"),
    CatalogIcon("hand-thumb-up", "Approve"),
    CatalogIcon("hand-thumb-down", "Reject"),
    CatalogIcon("arrow-down-tray", "Download"),
    CatalogIcon("arrow-up-tray", "Upload"),
    CatalogIcon("cog-6-tooth", "Settings"),
    CatalogIcon("adjustments-horizontal", "Configure"),
  ]
}

// =============================================================================
// Icon Registry (Dict for dynamic lookup)
// =============================================================================

/// Build the icon function registry.
/// Maps icon ID (string) to the gleroglero function.
fn icon_registry() -> Dict(String, fn() -> Element(a)) {
  dict.from_list([
    // Tasks
    #("bug-ant", outline.bug_ant),
    #("sparkles", outline.sparkles),
    #("clipboard-document-check", outline.clipboard_document_check),
    #("clipboard-document-list", outline.clipboard_document_list),
    #("document-text", outline.document_text),
    #("light-bulb", outline.light_bulb),
    #("wrench-screwdriver", outline.wrench_screwdriver),
    #("wrench", outline.wrench),
    #("beaker", outline.beaker),
    #("rocket-launch", outline.rocket_launch),
    #("code-bracket", outline.code_bracket),
    #("command-line", outline.command_line),
    #("cube", outline.cube),
    #("puzzle-piece", outline.puzzle_piece),
    #("shield-check", outline.shield_check),
    #("chart-bar", outline.chart_bar),
    // Status
    #("check-circle", outline.check_circle),
    #("check", outline.check),
    #("x-circle", outline.x_circle),
    #("pause-circle", outline.pause_circle),
    #("play-circle", outline.play_circle),
    #("stop-circle", outline.stop_circle),
    #("clock", outline.clock),
    #("arrow-path", outline.arrow_path),
    #("eye", outline.eye),
    #("eye-slash", outline.eye_slash),
    #("lock-closed", outline.lock_closed),
    #("lock-open", outline.lock_open),
    #("archive-box", outline.archive_box),
    // Priority
    #("bolt", outline.bolt),
    #("fire", outline.fire),
    #("flag", outline.flag),
    #("star", outline.star),
    #("exclamation-triangle", outline.exclamation_triangle),
    #("exclamation-circle", outline.exclamation_circle),
    #("bell", outline.bell),
    #("bell-alert", outline.bell_alert),
    // Objects
    #("folder", outline.folder),
    #("folder-open", outline.folder_open),
    #("inbox", outline.inbox),
    #("inbox-stack", outline.inbox_stack),
    #("tag", outline.tag),
    #("bookmark", outline.bookmark),
    #("paper-clip", outline.paper_clip),
    #("link", outline.link),
    #("photo", outline.photo),
    #("calendar", outline.calendar),
    #("calendar-days", outline.calendar_days),
    #("globe-alt", outline.globe_alt),
    #("server", outline.server),
    #("cpu-chip", outline.cpu_chip),
    // Actions
    #("pencil", outline.pencil),
    #("pencil-square", outline.pencil_square),
    #("trash", outline.trash),
    #("plus-circle", outline.plus_circle),
    #("minus-circle", outline.minus_circle),
    #("magnifying-glass", outline.magnifying_glass),
    #("paper-airplane", outline.paper_airplane),
    #("chat-bubble-left-right", outline.chat_bubble_left_right),
    #("hand-thumb-up", outline.hand_thumb_up),
    #("hand-thumb-down", outline.hand_thumb_down),
    #("arrow-down-tray", outline.arrow_down_tray),
    #("arrow-up-tray", outline.arrow_up_tray),
    #("cog-6-tooth", outline.cog_6_tooth),
    #("adjustments-horizontal", outline.adjustments_horizontal),
    #("hand-raised", outline.hand_raised),
    #("user-group", outline.user_group),
    // Fallback
    #("question-mark-circle", outline.question_mark_circle),
  ])
}

// =============================================================================
// Render Functions
// =============================================================================

fn icon_element(icon_id: String) -> Element(a) {
  case icon_registry() |> dict.get(icon_id) {
    Ok(icon_fn) -> icon_fn()
    Error(_) -> outline.question_mark_circle()
  }
}

/// Render an icon by its ID with specified size.
/// Returns a fallback icon if the ID is not found.
pub fn render(icon_id: String, size: Int) -> Element(a) {
  let icon_el = icon_element(icon_id)

  html.span(
    [
      attribute.class("icon-wrapper"),
      attribute.attribute(
        "style",
        "display:inline-flex;align-items:center;justify-content:center;width:"
          <> int.to_string(size)
          <> "px;height:"
          <> int.to_string(size)
          <> "px;",
      ),
    ],
    [
      html.span(
        [
          attribute.attribute(
            "style",
            "width:100%;height:100%;display:flex;align-items:center;justify-content:center;",
          ),
          attribute.attribute("aria-hidden", "true"),
        ],
        [icon_el],
      ),
    ],
  )
}

/// Render icon with additional CSS class.
pub fn render_with_class(
  icon_id: String,
  size: Int,
  class: String,
) -> Element(a) {
  let icon_el = icon_element(icon_id)

  html.span(
    [
      attribute.class("icon-wrapper " <> class),
      attribute.attribute(
        "style",
        "display:inline-flex;align-items:center;justify-content:center;width:"
          <> int.to_string(size)
          <> "px;height:"
          <> int.to_string(size)
          <> "px;",
      ),
    ],
    [
      html.span(
        [
          attribute.attribute(
            "style",
            "width:100%;height:100%;display:flex;align-items:center;justify-content:center;",
          ),
          attribute.attribute("aria-hidden", "true"),
        ],
        [icon_el],
      ),
    ],
  )
}

// =============================================================================
// Search & Filter
// =============================================================================

/// Check if an icon ID exists in the catalog.
pub fn exists(icon_id: String) -> Bool {
  dict.has_key(icon_registry(), icon_id)
}

/// Get icon metadata by ID.
pub fn get(icon_id: String) -> Option(CatalogIcon) {
  catalog()
  |> list.find(fn(icon) { icon.id == icon_id })
  |> option.from_result
}
