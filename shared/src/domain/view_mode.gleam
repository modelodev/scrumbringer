//// ViewMode - Modos de visualización del contenido principal
////
//// Mission: Define los modos de vista disponibles en el panel central
//// de la aplicación. Usado para URL routing y UI state.
////
//// Responsibilities:
//// - Definir el ADT ViewMode (Pool | List | Cards)
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
  /// Lista agrupada por ficha con secciones colapsables
  List
  /// Kanban de fichas (Pendiente -> En Curso -> Cerrada)
  Cards
}

/// Convierte string de URL a ViewMode
/// Devuelve Pool como default para strings no reconocidos
pub fn from_string(s: String) -> ViewMode {
  case s {
    "list" -> List
    "cards" -> Cards
    _ -> Pool
  }
}

/// Convierte ViewMode a string para URL
pub fn to_string(mode: ViewMode) -> String {
  case mode {
    Pool -> "pool"
    List -> "list"
    Cards -> "cards"
  }
}

/// Determina si el modo soporta drag & drop
pub fn supports_drag_drop(mode: ViewMode) -> Bool {
  case mode {
    Pool -> True
    List -> False
    Cards -> True
  }
}

/// Devuelve el label i18n key para el modo
pub fn label_key(mode: ViewMode) -> String {
  case mode {
    Pool -> "ViewModePool"
    List -> "ViewModeList"
    Cards -> "ViewModeCards"
  }
}
