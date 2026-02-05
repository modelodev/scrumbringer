//// Admin-specific client state model.

import scrumbringer_client/client_state/admin/assignments as admin_assignments
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/invites as admin_invites
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/admin/projects as admin_projects
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/admin/workflows as admin_workflows

/// Represents invites admin slice.
pub type InvitesModel =
  admin_invites.Model

/// Represents projects admin slice.
pub type ProjectsModel =
  admin_projects.Model

/// Represents capabilities admin slice.
pub type CapabilitiesModel =
  admin_capabilities.Model

/// Represents members admin slice.
pub type MembersModel =
  admin_members.Model

/// Represents metrics admin slice.
pub type MetricsModel =
  admin_metrics.Model

/// Represents workflows admin slice.
pub type WorkflowsModel =
  admin_workflows.Model

/// Represents rules admin slice.
pub type RulesModel =
  admin_rules.Model

/// Represents task templates admin slice.
pub type TaskTemplatesModel =
  admin_task_templates.Model

/// Represents task types admin slice.
pub type TaskTypesModel =
  admin_task_types.Model

/// Represents cards admin slice.
pub type CardsModel =
  admin_cards.Model

/// Represents assignments admin slice.
pub type AssignmentsModel =
  admin_assignments.Model

/// Represents AdminModel.
pub type AdminModel {
  AdminModel(
    invites: InvitesModel,
    projects: ProjectsModel,
    capabilities: CapabilitiesModel,
    members: MembersModel,
    metrics: MetricsModel,
    workflows: WorkflowsModel,
    rules: RulesModel,
    task_templates: TaskTemplatesModel,
    task_types: TaskTypesModel,
    cards: CardsModel,
    assignments: AssignmentsModel,
  )
}

/// Provides default admin state.
pub fn default_model() -> AdminModel {
  AdminModel(
    invites: admin_invites.default_model(),
    projects: admin_projects.default_model(),
    capabilities: admin_capabilities.default_model(),
    members: admin_members.default_model(),
    metrics: admin_metrics.default_model(),
    workflows: admin_workflows.default_model(),
    rules: admin_rules.default_model(),
    task_templates: admin_task_templates.default_model(),
    task_types: admin_task_types.default_model(),
    cards: admin_cards.default_model(),
    assignments: admin_assignments.default_model(),
  )
}
