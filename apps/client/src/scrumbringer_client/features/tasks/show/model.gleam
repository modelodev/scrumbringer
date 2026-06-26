//// Local Task Show state.

import gleam/option.{type Option, None}

import scrumbringer_client/ui/show_tabs

pub type Model {
  Model(
    active_tab: show_tabs.TaskShowTab,
    editing: Bool,
    edit_title: String,
    edit_description: String,
    edit_priority: String,
    edit_type_id: String,
    edit_card_id: String,
    edit_card_query: String,
    edit_in_flight: Bool,
    edit_error: Option(String),
  )
}

pub fn default() -> Model {
  Model(
    active_tab: show_tabs.TaskDetailsTab,
    editing: False,
    edit_title: "",
    edit_description: "",
    edit_priority: "3",
    edit_type_id: "",
    edit_card_id: "",
    edit_card_query: "",
    edit_in_flight: False,
    edit_error: None,
  )
}
