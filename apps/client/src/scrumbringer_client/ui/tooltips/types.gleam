//// Tooltip types for hover components.
////
//// These types support AC16-AC22 for card notes UX improvements.

import gleam/option.{type Option}

/// AC16 - Data for notes preview tooltip on [!] indicator.
pub type NotesPreviewData {
  NotesPreviewData(
    new_count: Int,
    time_ago: String,
    last_note_preview: Option(String),
    last_note_author: Option(String),
  )
}

/// AC18 - Progress breakdown for progress bar tooltip.
pub type ProgressBreakdown {
  ProgressBreakdown(
    completed: Int,
    in_progress: Int,
    pending: Int,
    percentage: Int,
  )
}

/// AC19 - Context for delete note button tooltip.
pub type DeleteNoteContext {
  DeleteOwnNote
  DeleteAsAdmin
}

/// AC20 - Author info for author name tooltip.
pub type AuthorInfo {
  AuthorInfo(name: String, email: String, role: String)
}

/// AC21 - Stats for tab notes badge tooltip.
pub type TabNotesStats {
  TabNotesStats(total: Int, new_for_user: Int)
}
