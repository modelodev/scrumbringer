//// ViewMode - Modos de visualización del contenido principal
////
//// Mission: Define los modos de vista disponibles en el panel central
//// de la aplicación. Usado para URL routing y UI state.
////
//// Responsibilities:
//// - Definir el ADT ViewMode (Pool | Cards | Capabilities | People)
//// - Conversión desde/hacia strings para URLs
//// - Determinar capacidades por modo (ej: drag & drop)
////
//// Non-responsibilities:
//// - Lógica de renderizado de cada modo
//// - Estado del contenido mostrado

/// Modos de visualización del contenido principal
pub type ViewMode {
  /// Canvas de tareas disponibles (drag & drop)
  Pool
  /// Kanban de fichas (Draft -> En Curso -> Closed)
  Cards
  /// Tareas activas agrupadas por capacidad
  Capabilities
  /// Disponibilidad por personas del proyecto
  People
}

pub type ViewModeParseError {
  UnknownViewMode(String)
}

/// Parsea string de URL a ViewMode.
pub fn parse(s: String) -> Result(ViewMode, ViewModeParseError) {
  case s {
    "pool" -> Ok(Pool)
    "cards" -> Ok(Cards)
    "capabilities" -> Ok(Capabilities)
    "people" -> Ok(People)
    other -> Error(UnknownViewMode(other))
  }
}

/// Convierte ViewMode a string para URL
pub fn to_string(mode: ViewMode) -> String {
  case mode {
    Pool -> "pool"
    Cards -> "cards"
    Capabilities -> "capabilities"
    People -> "people"
  }
}

/// Determina si el modo soporta drag & drop
pub fn supports_drag_drop(mode: ViewMode) -> Bool {
  case mode {
    Pool -> True
    Cards -> False
    Capabilities -> False
    People -> False
  }
}

/// Devuelve el label i18n key para el modo
pub fn label_key(mode: ViewMode) -> String {
  case mode {
    Pool -> "ViewModePool"
    Cards -> "ViewModeCards"
    Capabilities -> "ViewModeCapabilities"
    People -> "ViewModePeople"
  }
}
