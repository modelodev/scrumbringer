//// Sidebar state management with type-safe section handling.
////
//// ## Mission
////
//// Provide type-safe management of sidebar accordion state with
//// persistence to localStorage.
////
//// ## Design Principles
////
//// - **Exhaustive ADT**: SidebarSection type covers all sidebar sections
//// - **Safe persistence**: Graceful handling of corrupted localStorage data
//// - **Compile-time safety**: Pattern matching ensures all sections handled
////
//// ## Responsibilities
////
//// - Define sidebar sections as ADT
//// - Manage expanded/collapsed state per section
//// - Persist state to localStorage
//// - Load state with safe fallback
////
//// ## Relations
////
//// - **theme.gleam**: Uses similar localStorage pattern
//// - **client_view.gleam**: Reads sidebar state for rendering

import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string

import scrumbringer_client/theme

// =============================================================================
// Types
// =============================================================================

/// Sidebar sections - exhaustive ADT.
///
/// All possible sections that can be collapsed/expanded.
/// Using an ADT ensures compile-time safety when handling sections.
pub type SidebarSection {
  Trabajo
  Configuracion
  Organizacion
}

/// State for all sidebar sections.
pub type SidebarState {
  SidebarState(expanded: Dict(String, Bool))
}

// =============================================================================
// Constants
// =============================================================================

const storage_key = "scrumbringer_sidebar"

/// List of all sidebar sections (for iteration).
pub fn all_sections() -> List(SidebarSection) {
  [Trabajo, Configuracion, Organizacion]
}

// =============================================================================
// Section Helpers
// =============================================================================

/// Convert section to storage key.
fn section_key(section: SidebarSection) -> String {
  case section {
    Trabajo -> "trabajo"
    Configuracion -> "configuracion"
    Organizacion -> "organizacion"
  }
}

/// Get display name for a section.
pub fn section_label(section: SidebarSection) -> String {
  case section {
    Trabajo -> "TRABAJO"
    Configuracion -> "CONFIGURACIÓN"
    Organizacion -> "ORGANIZACIÓN"
  }
}

// =============================================================================
// State Management
// =============================================================================

/// Create default state (all sections expanded).
pub fn default() -> SidebarState {
  let entries =
    all_sections()
    |> list.map(fn(s) { #(section_key(s), True) })

  SidebarState(expanded: dict.from_list(entries))
}

/// Check if a section is expanded.
pub fn is_expanded(state: SidebarState, section: SidebarSection) -> Bool {
  state.expanded
  |> dict.get(section_key(section))
  |> result.unwrap(True)
}

/// Toggle a section's expanded state.
pub fn toggle(state: SidebarState, section: SidebarSection) -> SidebarState {
  let key = section_key(section)
  let current = is_expanded(state, section)
  SidebarState(expanded: dict.insert(state.expanded, key, !current))
}

/// Set a section's expanded state.
pub fn set_expanded(
  state: SidebarState,
  section: SidebarSection,
  expanded: Bool,
) -> SidebarState {
  let key = section_key(section)
  SidebarState(expanded: dict.insert(state.expanded, key, expanded))
}

/// Expand all sections.
pub fn expand_all(_state: SidebarState) -> SidebarState {
  let entries =
    all_sections()
    |> list.map(fn(s) { #(section_key(s), True) })

  SidebarState(expanded: dict.from_list(entries))
}

/// Collapse all sections.
pub fn collapse_all(_state: SidebarState) -> SidebarState {
  let entries =
    all_sections()
    |> list.map(fn(s) { #(section_key(s), False) })

  SidebarState(expanded: dict.from_list(entries))
}

// =============================================================================
// Persistence
// =============================================================================

/// Load sidebar state from localStorage.
///
/// Returns default state if:
/// - localStorage is empty
/// - Data is corrupted
/// - Parsing fails
pub fn load() -> SidebarState {
  let stored = theme.local_storage_get(storage_key)

  case string.is_empty(stored) {
    True -> default()
    False -> parse_stored(stored)
  }
}

/// Save sidebar state to localStorage.
pub fn save(state: SidebarState) -> Nil {
  let serialized = serialize(state)
  theme.local_storage_set(storage_key, serialized)
}

// =============================================================================
// Serialization (simple key:value;key:value format)
// =============================================================================

fn serialize(state: SidebarState) -> String {
  all_sections()
  |> list.map(fn(s) {
    let key = section_key(s)
    let value = case is_expanded(state, s) {
      True -> "1"
      False -> "0"
    }
    key <> ":" <> value
  })
  |> string.join(";")
}

fn parse_stored(data: String) -> SidebarState {
  let pairs =
    data
    |> string.split(";")
    |> list.filter_map(parse_pair)

  case list.is_empty(pairs) {
    True -> default()
    False -> SidebarState(expanded: dict.from_list(pairs))
  }
}

fn parse_pair(pair: String) -> Result(#(String, Bool), Nil) {
  case string.split(pair, ":") {
    [key, value] -> {
      let expanded = value == "1"
      Ok(#(key, expanded))
    }
    _ -> Error(Nil)
  }
}
