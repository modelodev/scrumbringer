//// Project admin dialogs and state.

import domain/project.{type ProjectDepthName}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/types as state_types

pub type DepthReductionState {
  NoDepthReduction
  DepthReductionNeedsReview(new_max_depth: Int)
  DepthReductionLoading(new_max_depth: Int)
  DepthReductionReady(
    new_max_depth: Int,
    impact: api_projects.DepthReductionImpact,
  )
  DepthReductionConfirmed(new_max_depth: Int)
}

/// Represents the form payload for the projects dialog.
pub type ProjectDialogForm {
  ProjectDialogCreate(name: String)
  ProjectDialogEdit(
    id: Int,
    name: String,
    max_depth: String,
    healthy_pool_limit: String,
    card_depth_names: List(ProjectDepthName),
    depth_reduction: DepthReductionState,
  )
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
