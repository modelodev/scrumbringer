//// Task type domain types for ScrumBringer.
////
//// Defines task type structures used for categorizing tasks within projects.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/task_type.{type TaskType, type TaskTypeInline}
////
//// let task_type = TaskType(id: 1, name: "Bug", icon: "bug", capability_id: None)
//// ```

import gleam/option.{type Option}

// =============================================================================
// Types
// =============================================================================

/// A task type definition with optional capability requirement.
///
/// ## Example
///
/// ```gleam
/// TaskType(id: 1, name: "Bug Fix", icon: "bug", capability_id: Some(3))
/// ```
pub type TaskType {
  TaskType(
    id: Int,
    name: String,
    icon: String,
    capability_id: Option(Int),
  )
}

/// Inline task type info embedded in a task.
///
/// Used when task type details are nested within task responses.
///
/// ## Example
///
/// ```gleam
/// TaskTypeInline(id: 1, name: "Feature", icon: "star")
/// ```
pub type TaskTypeInline {
  TaskTypeInline(id: Int, name: String, icon: String)
}
