//// Icon catalog for task types.
////
//// Provides a curated set of Heroicons for use in task type selection.
//// Uses gleroglero for embedded SVG rendering (no CDN dependency).

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

import gleroglero/outline

// =============================================================================
// Types
// =============================================================================

/// Icon category for filtering in the picker.
pub type IconCategory {
  All
  Tasks
  Status
  Priority
  Objects
  Actions
}

/// A curated icon entry with metadata.
pub type CatalogIcon {
  CatalogIcon(id: String, label: String, category: IconCategory)
}

// =============================================================================
// Catalog Data
// =============================================================================

/// Curated catalog of ~60 icons for task management.
pub fn catalog() -> List(CatalogIcon) {
  [
    // Tasks (work items)
    CatalogIcon("bug-ant", "Bug", Tasks),
    CatalogIcon("sparkles", "Feature", Tasks),
    CatalogIcon("clipboard-document-check", "Task", Tasks),
    CatalogIcon("clipboard-document-list", "List", Tasks),
    CatalogIcon("document-text", "Document", Tasks),
    CatalogIcon("light-bulb", "Idea", Tasks),
    CatalogIcon("wrench-screwdriver", "Fix", Tasks),
    CatalogIcon("wrench", "Maintenance", Tasks),
    CatalogIcon("beaker", "Experiment", Tasks),
    CatalogIcon("rocket-launch", "Launch", Tasks),
    CatalogIcon("code-bracket", "Code", Tasks),
    CatalogIcon("command-line", "Script", Tasks),
    CatalogIcon("cube", "Component", Tasks),
    CatalogIcon("puzzle-piece", "Integration", Tasks),
    CatalogIcon("shield-check", "Security", Tasks),
    CatalogIcon("chart-bar", "Analytics", Tasks),
    // Status (states)
    CatalogIcon("check-circle", "Done", Status),
    CatalogIcon("check", "Complete", Status),
    CatalogIcon("x-circle", "Cancelled", Status),
    CatalogIcon("pause-circle", "Paused", Status),
    CatalogIcon("play-circle", "In Progress", Status),
    CatalogIcon("stop-circle", "Blocked", Status),
    CatalogIcon("clock", "Pending", Status),
    CatalogIcon("arrow-path", "Recurring", Status),
    CatalogIcon("eye", "Review", Status),
    CatalogIcon("eye-slash", "Hidden", Status),
    CatalogIcon("lock-closed", "Locked", Status),
    CatalogIcon("lock-open", "Unlocked", Status),
    CatalogIcon("archive-box", "Archived", Status),
    // Priority (importance)
    CatalogIcon("bolt", "Urgent", Priority),
    CatalogIcon("fire", "Critical", Priority),
    CatalogIcon("flag", "Flagged", Priority),
    CatalogIcon("star", "Important", Priority),
    CatalogIcon("exclamation-triangle", "Warning", Priority),
    CatalogIcon("exclamation-circle", "Alert", Priority),
    CatalogIcon("bell", "Notification", Priority),
    CatalogIcon("bell-alert", "Alarm", Priority),
    // Objects (things)
    CatalogIcon("folder", "Folder", Objects),
    CatalogIcon("folder-open", "Open Folder", Objects),
    CatalogIcon("inbox", "Inbox", Objects),
    CatalogIcon("inbox-stack", "Queue", Objects),
    CatalogIcon("tag", "Tag", Objects),
    CatalogIcon("bookmark", "Bookmark", Objects),
    CatalogIcon("paper-clip", "Attachment", Objects),
    CatalogIcon("link", "Link", Objects),
    CatalogIcon("photo", "Image", Objects),
    CatalogIcon("calendar", "Calendar", Objects),
    CatalogIcon("calendar-days", "Schedule", Objects),
    CatalogIcon("globe-alt", "Web", Objects),
    CatalogIcon("server", "Server", Objects),
    CatalogIcon("cpu-chip", "Hardware", Objects),
    // Actions (verbs)
    CatalogIcon("pencil", "Edit", Actions),
    CatalogIcon("pencil-square", "Write", Actions),
    CatalogIcon("trash", "Delete", Actions),
    CatalogIcon("plus-circle", "Add", Actions),
    CatalogIcon("minus-circle", "Remove", Actions),
    CatalogIcon("magnifying-glass", "Search", Actions),
    CatalogIcon("paper-airplane", "Send", Actions),
    CatalogIcon("chat-bubble-left-right", "Discuss", Actions),
    CatalogIcon("hand-thumb-up", "Approve", Actions),
    CatalogIcon("hand-thumb-down", "Reject", Actions),
    CatalogIcon("arrow-down-tray", "Download", Actions),
    CatalogIcon("arrow-up-tray", "Upload", Actions),
    CatalogIcon("cog-6-tooth", "Settings", Actions),
    CatalogIcon("adjustments-horizontal", "Configure", Actions),
  ]
}

/// Get all category values for tabs.
pub fn categories() -> List(IconCategory) {
  [All, Tasks, Status, Priority, Objects, Actions]
}

/// Convert category to display label.
pub fn category_label(cat: IconCategory) -> String {
  case cat {
    All -> "Todos"
    Tasks -> "Tareas"
    Status -> "Estado"
    Priority -> "Prioridad"
    Objects -> "Objetos"
    Actions -> "Acciones"
  }
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
    // Fallback
    #("question-mark-circle", outline.question_mark_circle),
  ])
}

// =============================================================================
// Render Functions
// =============================================================================

/// Render an icon by its ID with specified size.
/// Returns a fallback icon if the ID is not found.
pub fn render(icon_id: String, size: Int) -> Element(a) {
  let icon_el =
    icon_registry()
    |> dict.get(icon_id)
    |> result.map(fn(icon_fn) { icon_fn() })
    |> result.unwrap(outline.question_mark_circle())

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
  let icon_el =
    icon_registry()
    |> dict.get(icon_id)
    |> result.map(fn(icon_fn) { icon_fn() })
    |> result.unwrap(outline.question_mark_circle())

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

/// Filter catalog by category.
pub fn by_category(cat: IconCategory) -> List(CatalogIcon) {
  case cat {
    All -> catalog()
    _ -> list.filter(catalog(), fn(icon) { icon.category == cat })
  }
}

/// Search catalog by query (matches ID or label).
pub fn search(query: String) -> List(CatalogIcon) {
  let q = string.lowercase(string.trim(query))
  case q {
    "" -> catalog()
    _ ->
      catalog()
      |> list.filter(fn(icon) {
        string.contains(string.lowercase(icon.label), q)
        || string.contains(icon.id, q)
      })
  }
}

/// Get the default fallback icon ID.
pub fn fallback_id() -> String {
  "question-mark-circle"
}
