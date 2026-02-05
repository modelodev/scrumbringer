//// Project admin dialogs and state.

import scrumbringer_client/client_state/types as state_types

/// Represents project admin state.
pub type Model {
  Model(projects_dialog: state_types.DialogState(state_types.ProjectDialogForm))
}

/// Provides default project admin state.
pub fn default_model() -> Model {
  Model(projects_dialog: state_types.DialogClosed(operation: state_types.Idle))
}
