import gleam/int
import support/render_assertions

import domain/project.{type Project, Project, ProjectDepthName}
import domain/project_role
import domain/remote
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/projects as projects_state
import scrumbringer_client/client_state/types.{DialogOpen, InFlight}
import scrumbringer_client/features/projects/view as projects_view
import scrumbringer_client/i18n/locale

fn project() -> Project {
  Project(
    id: 7,
    name: "Project Alpha",
    my_role: project_role.Manager,
    created_at: "2026-01-01T10:00:00Z",
    members_count: 3,
    card_depth_names: [
      ProjectDepthName(1, "Hito", "Hitos"),
      ProjectDepthName(2, "Entrega", "Entregas"),
    ],
    healthy_pool_limit: 12,
  )
}

fn config(
  projects: remote.Remote(List(Project)),
) -> projects_view.Config(String) {
  projects_view.Config(
    locale: locale.En,
    projects: projects,
    project_dialog: projects_state.default_model(),
    on_create_dialog_opened: "create-open",
    on_create_dialog_closed: "create-close",
    on_create_submitted: "create-submit",
    on_create_next_clicked: "create-next",
    on_create_back_clicked: "create-back",
    on_create_name_changed: fn(value) { "create-name:" <> value },
    on_create_max_depth_changed: fn(value) { "create-depth:" <> value },
    on_create_healthy_pool_limit_changed: fn(value) { "create-limit:" <> value },
    on_create_depth_singular_changed: fn(depth, value) {
      "create-depth-singular:" <> int.to_string(depth) <> ":" <> value
    },
    on_create_depth_plural_changed: fn(depth, value) {
      "create-depth-plural:" <> int.to_string(depth) <> ":" <> value
    },
    on_edit_dialog_opened: fn(id, name, _healthy_pool_limit, _depth_names) {
      "edit-open:" <> int.to_string(id) <> ":" <> name
    },
    on_edit_dialog_closed: "edit-close",
    on_edit_submitted: "edit-submit",
    on_edit_name_changed: fn(value) { "edit-name:" <> value },
    on_edit_max_depth_changed: fn(value) { "edit-depth:" <> value },
    on_edit_healthy_pool_limit_changed: fn(value) { "edit-limit:" <> value },
    on_edit_depth_singular_changed: fn(depth, value) {
      "edit-depth-singular:" <> int.to_string(depth) <> ":" <> value
    },
    on_edit_depth_plural_changed: fn(depth, value) {
      "edit-depth-plural:" <> int.to_string(depth) <> ":" <> value
    },
    on_edit_depth_reduction_review_clicked: "edit-depth-review",
    on_edit_depth_reduction_confirmed: "edit-depth-confirm",
    on_delete_confirm_opened: fn(id, name) {
      "delete-open:" <> int.to_string(id) <> ":" <> name
    },
    on_delete_confirm_closed: "delete-close",
    on_delete_submitted: "delete-submit",
  )
}

pub fn projects_view_loaded_projects_uses_config_data_test() {
  let html =
    projects_view.view_projects(config(remote.Loaded([project()])))
    |> render_assertions.html

  render_assertions.contains(html, "Projects")
  render_assertions.contains(html, "Project Alpha")
  render_assertions.contains(html, "Members")
  render_assertions.contains(html, "3")
  render_assertions.contains(html, "manager")
}

pub fn projects_view_delete_dialog_uses_shared_danger_button_test() {
  let dialog =
    projects_state.Model(projects_dialog: DialogOpen(
      form: projects_state.ProjectDialogDelete(id: 7, name: "Project Alpha"),
      operation: InFlight,
    ))

  let html =
    projects_view.view_project_dialogs(
      projects_view.Config(
        ..config(remote.Loaded([project()])),
        project_dialog: dialog,
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "Delete project")
  render_assertions.contains(html, "Deleting")
  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.not_contains(html, "class=\"btn-danger\"")
}

pub fn projects_create_dialog_explains_structure_and_pool_limit_test() {
  let dialog =
    projects_state.Model(projects_dialog: DialogOpen(
      form: projects_state.ProjectDialogCreate(
        step: projects_state.ProjectCreateStructurePool,
        name: "Project Alpha",
        max_depth: "3",
        healthy_pool_limit: "20",
        card_depth_names: [
          ProjectDepthName(1, "Hito", "Hitos"),
          ProjectDepthName(2, "Entrega", "Entregas"),
          ProjectDepthName(3, "Historia", "Historias"),
        ],
      ),
      operation: InFlight,
    ))

  let html =
    projects_view.view_project_dialogs(
      projects_view.Config(
        ..config(remote.Loaded([project()])),
        locale: locale.Es,
        project_dialog: dialog,
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"project-structure-settings\"")
  render_assertions.contains(html, "Elige cuánta profundidad")
  render_assertions.contains(html, "Ejemplos: Tarjeta -&gt; Tarea")
  render_assertions.contains(html, "Este límite nunca bloquea")
  render_assertions.contains(html, "aria-label=\"Profundidad maxima\"")
  render_assertions.contains(html, "aria-label=\"Limite blando del Pool\"")
}

pub fn projects_create_dialog_general_step_hides_structure_test() {
  let dialog =
    projects_state.Model(projects_dialog: DialogOpen(
      form: projects_state.ProjectDialogCreate(
        step: projects_state.ProjectCreateGeneral,
        name: "",
        max_depth: "3",
        healthy_pool_limit: "20",
        card_depth_names: [
          ProjectDepthName(1, "Hito", "Hitos"),
          ProjectDepthName(2, "Entrega", "Entregas"),
          ProjectDepthName(3, "Historia", "Historias"),
        ],
      ),
      operation: InFlight,
    ))

  let html =
    projects_view.view_project_dialogs(
      projects_view.Config(
        ..config(remote.Loaded([project()])),
        project_dialog: dialog,
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "Step 1 of 5")
  render_assertions.contains(html, "General")
  render_assertions.contains(html, "Continue")
  render_assertions.contains(html, "aria-label=\"Name\"")
  render_assertions.not_contains(
    html,
    "data-testid=\"project-structure-settings\"",
  )
}

pub fn projects_create_dialog_review_step_summarizes_configuration_test() {
  let dialog =
    projects_state.Model(projects_dialog: DialogOpen(
      form: projects_state.ProjectDialogCreate(
        step: projects_state.ProjectCreateReview,
        name: "Project Alpha",
        max_depth: "3",
        healthy_pool_limit: "20",
        card_depth_names: [
          ProjectDepthName(1, "Hito", "Hitos"),
          ProjectDepthName(2, "Entrega", "Entregas"),
          ProjectDepthName(3, "Historia", "Historias"),
        ],
      ),
      operation: InFlight,
    ))

  let html =
    projects_view.view_project_dialogs(
      projects_view.Config(
        ..config(remote.Loaded([project()])),
        project_dialog: dialog,
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "Step 5 of 5")
  render_assertions.contains(html, "Review")
  render_assertions.contains(html, "Project Alpha")
  render_assertions.contains(html, "Hito / Hitos")
  render_assertions.contains(html, "Configured after creation")
  render_assertions.contains(html, "Creating")
  render_assertions.contains(html, "Back")
}

pub fn projects_edit_dialog_renders_editable_structure_and_pool_settings_test() {
  let dialog =
    projects_state.Model(projects_dialog: DialogOpen(
      form: projects_state.ProjectDialogEdit(
        id: 7,
        name: "Project Alpha",
        max_depth: "2",
        healthy_pool_limit: "12",
        card_depth_names: [
          ProjectDepthName(1, "Hito", "Hitos"),
          ProjectDepthName(2, "Entrega", "Entregas"),
        ],
        depth_reduction: projects_state.NoDepthReduction,
      ),
      operation: InFlight,
    ))

  let html =
    projects_view.view_project_dialogs(
      projects_view.Config(
        ..config(remote.Loaded([project()])),
        project_dialog: dialog,
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"project-structure-settings\"")
  render_assertions.contains(html, "Pool soft limit")
  render_assertions.contains(html, "value=\"12\"")
  render_assertions.contains(html, "value=\"Hito\"")
  render_assertions.contains(html, "value=\"Entregas\"")
  render_assertions.contains(html, "aria-label=\"Maximum depth\"")
  render_assertions.contains(html, "aria-label=\"Pool soft limit\"")
  render_assertions.contains(
    html,
    "data-testid=\"project-depth-reduction-confirmation\"",
  )
}

pub fn projects_edit_dialog_localizes_structure_settings_to_spanish_test() {
  let dialog =
    projects_state.Model(projects_dialog: DialogOpen(
      form: projects_state.ProjectDialogEdit(
        id: 7,
        name: "Project Alpha",
        max_depth: "2",
        healthy_pool_limit: "12",
        card_depth_names: [
          ProjectDepthName(1, "Hito", "Hitos"),
          ProjectDepthName(2, "Entrega", "Entregas"),
        ],
        depth_reduction: projects_state.NoDepthReduction,
      ),
      operation: InFlight,
    ))

  let html =
    projects_view.view_project_dialogs(
      projects_view.Config(
        ..config(remote.Loaded([project()])),
        locale: locale.Es,
        project_dialog: dialog,
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "Estructura y Pool")
  render_assertions.contains(html, "Profundidad maxima")
  render_assertions.contains(html, "Limite blando del Pool")
  render_assertions.contains(html, "Este límite nunca bloquea")
  render_assertions.contains(html, "Nivel 1")
  render_assertions.contains(html, "aria-label=\"Nombre singular del nivel 1\"")
  render_assertions.not_contains(html, "Structure and Pool")
  render_assertions.not_contains(html, "Pool soft limit")
}

pub fn projects_depth_reduction_ready_uses_reviewed_confirmation_copy_test() {
  let dialog =
    projects_state.Model(projects_dialog: DialogOpen(
      form: projects_state.ProjectDialogEdit(
        id: 7,
        name: "Project Alpha",
        max_depth: "1",
        healthy_pool_limit: "12",
        card_depth_names: [
          ProjectDepthName(1, "Hito", "Hitos"),
          ProjectDepthName(2, "Entrega", "Entregas"),
        ],
        depth_reduction: projects_state.DepthReductionReady(
          1,
          api_projects.DepthReductionImpact(
            affected_cards_count: 4,
            available_tasks_count: 3,
            claimed_tasks_count: 0,
            blocked: False,
            affected_cards: [
              api_projects.DepthReductionAffectedCard(
                id: 42,
                title: "Historia profunda",
                depth: 3,
              ),
            ],
          ),
        ),
      ),
      operation: InFlight,
    ))

  let html =
    projects_view.view_project_dialogs(
      projects_view.Config(
        ..config(remote.Loaded([project()])),
        locale: locale.Es,
        project_dialog: dialog,
      ),
    )
    |> render_assertions.html

  render_assertions.contains(
    html,
    "data-testid=\"project-depth-reduction-confirmation\"",
  )
  render_assertions.contains(html, "4 tarjetas y 3 tareas disponibles")
  render_assertions.contains(html, "Tarjetas afectadas")
  render_assertions.contains(html, "Historia profunda")
  render_assertions.contains(html, "Nivel 3")
  render_assertions.contains(html, "Confirmar reducción de profundidad")
  render_assertions.contains(html, "btn-danger")
  render_assertions.not_contains(html, "Confirm depth reduction")
}
