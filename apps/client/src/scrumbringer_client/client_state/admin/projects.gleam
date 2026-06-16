//// Project admin dialogs and state.

import scrumbringer_client/client_state/types as state_types

/// Represents the form payload for the projects dialog.
pub type ProjectDialogForm {
  ProjectDialogCreate(name: String)
  ProjectDialogEdit(id: Int, name: String)
  ProjectDialogDelete(id: Int, name: String)
}

/// Represents project admin state.
pub type Model {
  Model(projects_dialog: state_types.DialogState(ProjectDialogForm))
}

/// Provides default project admin state.
pub fn default_model() -> Model {
  Model(projects_dialog: state_types.DialogClosed(operation: state_types.Idle))
}
