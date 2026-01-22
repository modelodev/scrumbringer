//// WorkspaceState - Máquina de estados para el workspace del proyecto
////
//// Mission: Modelar el ciclo de vida del workspace de forma type-safe,
//// haciendo transiciones inválidas imposibles de representar.
////
//// Responsibilities:
//// - Definir estados: NoProject | LoadingWorkspace | Ready | WorkspaceError
//// - Proveer transiciones válidas entre estados
//// - Exponer queries de estado (is_ready, is_loading, etc.)
////
//// Non-responsibilities:
//// - Cargar datos del servidor (eso es responsabilidad de effects)
//// - Renderizar UI (eso es responsabilidad de view)

import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/project.{type ProjectMember}
import domain/task.{type Task}
import domain/task_type.{type TaskType}
import gleam/option.{type Option, None, Some}

// =============================================================================
// Types
// =============================================================================

/// Datos del workspace cargado
pub type Workspace {
  Workspace(
    project_id: Int,
    project_name: String,
    tasks: List(Task),
    cards: List(Card),
    members: List(ProjectMember),
    capabilities: List(Capability),
    task_types: List(TaskType),
  )
}

/// Estados posibles del workspace - máquina de estados
pub type WorkspaceState {
  /// Sin proyecto seleccionado
  NoProject
  /// Cargando datos del proyecto
  LoadingWorkspace(project_id: Int)
  /// Workspace listo para trabajar
  Ready(workspace: Workspace)
  /// Error al cargar (permite reintentar)
  WorkspaceError(project_id: Int, message: String)
}

// =============================================================================
// Constructors
// =============================================================================

/// Estado inicial: sin proyecto
pub fn init() -> WorkspaceState {
  NoProject
}

// =============================================================================
// Transiciones
// =============================================================================

/// Transición: seleccionar un proyecto
/// Desde cualquier estado, pasa a LoadingWorkspace
pub fn select_project(state: WorkspaceState, project_id: Int) -> WorkspaceState {
  case state {
    NoProject -> LoadingWorkspace(project_id)
    LoadingWorkspace(_) -> LoadingWorkspace(project_id)
    Ready(_) -> LoadingWorkspace(project_id)
    WorkspaceError(_, _) -> LoadingWorkspace(project_id)
  }
}

/// Transición: workspace cargado exitosamente
/// Solo tiene efecto si estamos esperando este proyecto
pub fn workspace_loaded(
  state: WorkspaceState,
  workspace: Workspace,
) -> WorkspaceState {
  case state {
    LoadingWorkspace(pid) if pid == workspace.project_id -> Ready(workspace)
    _ -> state
  }
}

/// Transición: error al cargar
/// Solo tiene efecto si estamos en LoadingWorkspace
pub fn workspace_failed(
  state: WorkspaceState,
  message: String,
) -> WorkspaceState {
  case state {
    LoadingWorkspace(pid) -> WorkspaceError(pid, message)
    _ -> state
  }
}

/// Transición: limpiar proyecto (logout, cambio de org)
pub fn clear_project(_state: WorkspaceState) -> WorkspaceState {
  NoProject
}

/// Transición: actualizar workspace con nuevos datos
/// Solo tiene efecto si estamos en Ready
pub fn update_workspace(
  state: WorkspaceState,
  updater: fn(Workspace) -> Workspace,
) -> WorkspaceState {
  case state {
    Ready(ws) -> Ready(updater(ws))
    _ -> state
  }
}

// =============================================================================
// Queries
// =============================================================================

/// ¿Está listo para mostrar contenido?
pub fn is_ready(state: WorkspaceState) -> Bool {
  case state {
    Ready(_) -> True
    _ -> False
  }
}

/// Obtener workspace si está listo
pub fn get_workspace(state: WorkspaceState) -> Option(Workspace) {
  case state {
    Ready(ws) -> Some(ws)
    _ -> None
  }
}

/// ¿Está cargando?
pub fn is_loading(state: WorkspaceState) -> Bool {
  case state {
    LoadingWorkspace(_) -> True
    _ -> False
  }
}

/// Obtener el project_id que está cargando
pub fn loading_project_id(state: WorkspaceState) -> Option(Int) {
  case state {
    LoadingWorkspace(pid) -> Some(pid)
    _ -> None
  }
}

/// ¿Hay un error?
pub fn has_error(state: WorkspaceState) -> Bool {
  case state {
    WorkspaceError(_, _) -> True
    _ -> False
  }
}

/// Obtener mensaje de error si hay
pub fn error_message(state: WorkspaceState) -> Option(String) {
  case state {
    WorkspaceError(_, msg) -> Some(msg)
    _ -> None
  }
}

/// Obtener project_id del error
pub fn error_project_id(state: WorkspaceState) -> Option(Int) {
  case state {
    WorkspaceError(pid, _) -> Some(pid)
    _ -> None
  }
}

/// Obtener el project_id actual (de cualquier estado excepto NoProject)
pub fn current_project_id(state: WorkspaceState) -> Option(Int) {
  case state {
    NoProject -> None
    LoadingWorkspace(pid) -> Some(pid)
    Ready(ws) -> Some(ws.project_id)
    WorkspaceError(pid, _) -> Some(pid)
  }
}
