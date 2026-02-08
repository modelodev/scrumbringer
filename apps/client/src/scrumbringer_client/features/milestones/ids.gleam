import gleam/int

pub fn region_id(milestone_id: Int) -> String {
  "milestone-details-" <> int.to_string(milestone_id)
}

pub fn toggle_id(milestone_id: Int) -> String {
  "milestone-toggle-" <> int.to_string(milestone_id)
}

pub fn details_button_id(milestone_id: Int) -> String {
  "milestone-details-button-" <> int.to_string(milestone_id)
}

pub fn activate_button_id(milestone_id: Int) -> String {
  "milestone-activate-button-" <> int.to_string(milestone_id)
}

pub fn edit_button_id(milestone_id: Int) -> String {
  "milestone-edit-button-" <> int.to_string(milestone_id)
}

pub fn delete_button_id(milestone_id: Int) -> String {
  "milestone-delete-button-" <> int.to_string(milestone_id)
}

pub fn create_card_button_id(milestone_id: Int) -> String {
  "milestone-create-card-button-" <> int.to_string(milestone_id)
}

pub fn quick_create_card_button_id(milestone_id: Int) -> String {
  "milestone-quick-create-card-button-" <> int.to_string(milestone_id)
}

pub fn quick_create_task_button_id(milestone_id: Int) -> String {
  "milestone-quick-create-task-button-" <> int.to_string(milestone_id)
}

pub fn create_button_id() -> String {
  "milestone-create-button"
}

pub fn create_empty_button_id() -> String {
  "milestone-create-empty-button"
}
