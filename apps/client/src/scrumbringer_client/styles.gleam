//// CSS style definitions for Scrumbringer UI.
////
//// Generates all base CSS rules as strings for injection into the page.
//// Includes layout, typography, forms, buttons, and theme variables.

import gleam/list
import gleam/string

import scrumbringer_client/styles/assignments as styles_assignments
import scrumbringer_client/styles/base as styles_base
import scrumbringer_client/styles/components as styles_components
import scrumbringer_client/styles/dialogs as styles_dialogs
import scrumbringer_client/styles/layout as styles_layout
import scrumbringer_client/styles/modals as styles_modals
import scrumbringer_client/styles/notes as styles_notes
import scrumbringer_client/styles/pool as styles_pool
import scrumbringer_client/styles/tables as styles_tables
import scrumbringer_client/styles/ux as styles_ux

/// Provides base css.
///
/// Example:
///   base_css(...)
///
/// Order of precedence (do not reorder without reviewing overrides):
/// 1) base
/// 2) tables
/// 3) assignments
/// 4) modals
/// 5) components
/// 6) pool
/// 7) ux
/// 8) dialogs
/// 9) layout
/// 10) notes
pub fn base_css() -> String {
  [
    styles_base.css(),
    styles_tables.css(),
    styles_assignments.css(),
    styles_modals.css(),
    styles_components.css(),
    styles_pool.css(),
    styles_ux.css(),
    styles_dialogs.css(),
    styles_layout.css(),
    styles_notes.css(),
  ]
  |> list.flatten
  |> string.join("\n")
}
