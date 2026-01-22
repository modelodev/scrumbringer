//// UrlState - Estado de URL como tipo opaco
////
//// Mission: Representar el estado de navegación de la aplicación
//// de forma type-safe, garantizando que solo estados válidos existan.
////
//// Responsibilities:
//// - Parsear URLs a UrlState (único punto de entrada)
//// - Proveer builders inmutables para modificaciones
//// - Serializar a query string para pushState/replaceState
////
//// Non-responsibilities:
//// - Ejecutar pushState/replaceState (eso es responsabilidad del router)
//// - Validar permisos de acceso a proyectos

import domain/view_mode.{type ViewMode}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri}

/// Estado de URL - solo se puede crear mediante parse()
pub opaque type UrlState {
  UrlState(
    project: Option(Int),
    view: ViewMode,
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search: Option(String),
    expanded_card: Option(Int),
  )
}

/// Crea un UrlState vacío (sin proyecto, vista Pool)
pub fn empty() -> UrlState {
  UrlState(
    project: None,
    view: view_mode.Pool,
    type_filter: None,
    capability_filter: None,
    search: None,
    expanded_card: None,
  )
}

/// Parsea una URI y crea un UrlState válido
/// Este es el punto de entrada principal para crear UrlState
pub fn parse(uri: Uri) -> UrlState {
  let query = uri.query |> option.unwrap("")
  let params = parse_query_params(query)

  UrlState(
    project: params |> get_int("project"),
    view: params
      |> get_string("view")
      |> option.map(view_mode.from_string)
      |> option.unwrap(view_mode.Pool),
    type_filter: params |> get_int("type"),
    capability_filter: params |> get_int("cap"),
    search: params |> get_string("search"),
    expanded_card: params |> get_int("card"),
  )
}

/// Parsea un query string directamente
pub fn parse_query(query: String) -> UrlState {
  let params = parse_query_params(query)

  UrlState(
    project: params |> get_int("project"),
    view: params
      |> get_string("view")
      |> option.map(view_mode.from_string)
      |> option.unwrap(view_mode.Pool),
    type_filter: params |> get_int("type"),
    capability_filter: params |> get_int("cap"),
    search: params |> get_string("search"),
    expanded_card: params |> get_int("card"),
  )
}

// =============================================================================
// Builders (inmutables)
// =============================================================================

/// Builder: actualiza el proyecto seleccionado
pub fn with_project(state: UrlState, project_id: Int) -> UrlState {
  UrlState(..state, project: Some(project_id))
}

/// Builder: limpia el proyecto seleccionado
pub fn without_project(state: UrlState) -> UrlState {
  UrlState(..state, project: None)
}

/// Builder: actualiza el modo de vista
pub fn with_view(state: UrlState, mode: ViewMode) -> UrlState {
  UrlState(..state, view: mode)
}

/// Builder: actualiza el filtro de tipo
pub fn with_type_filter(state: UrlState, type_id: Option(Int)) -> UrlState {
  UrlState(..state, type_filter: type_id)
}

/// Builder: actualiza el filtro de capacidad
pub fn with_capability_filter(state: UrlState, cap_id: Option(Int)) -> UrlState {
  UrlState(..state, capability_filter: cap_id)
}

/// Builder: actualiza la búsqueda
pub fn with_search(state: UrlState, term: Option(String)) -> UrlState {
  UrlState(..state, search: term)
}

/// Builder: actualiza la ficha expandida
pub fn with_expanded_card(state: UrlState, card_id: Option(Int)) -> UrlState {
  UrlState(..state, expanded_card: card_id)
}

/// Builder: limpia todos los filtros
pub fn clear_filters(state: UrlState) -> UrlState {
  UrlState(
    ..state,
    type_filter: None,
    capability_filter: None,
    search: None,
    expanded_card: None,
  )
}

// =============================================================================
// Accessors (read-only)
// =============================================================================

pub fn project(state: UrlState) -> Option(Int) {
  state.project
}

pub fn view(state: UrlState) -> ViewMode {
  state.view
}

pub fn type_filter(state: UrlState) -> Option(Int) {
  state.type_filter
}

pub fn capability_filter(state: UrlState) -> Option(Int) {
  state.capability_filter
}

pub fn search(state: UrlState) -> Option(String) {
  state.search
}

pub fn expanded_card(state: UrlState) -> Option(Int) {
  state.expanded_card
}

// =============================================================================
// Serialización
// =============================================================================

/// Serializa a query string para pushState
pub fn to_query_string(state: UrlState) -> String {
  [
    state.project |> option.map(fn(p) { "project=" <> int.to_string(p) }),
    Some("view=" <> view_mode.to_string(state.view)),
    state.type_filter |> option.map(fn(t) { "type=" <> int.to_string(t) }),
    state.capability_filter
      |> option.map(fn(c) { "cap=" <> int.to_string(c) }),
    state.search |> option.map(fn(s) { "search=" <> uri.percent_encode(s) }),
    state.expanded_card |> option.map(fn(c) { "card=" <> int.to_string(c) }),
  ]
  |> list.filter_map(option.to_result(_, Nil))
  |> string.join("&")
}

/// Construye la URL completa para /app
pub fn to_app_url(state: UrlState) -> String {
  let query = to_query_string(state)
  case query {
    "" -> "/app"
    q -> "/app?" <> q
  }
}

// =============================================================================
// Helpers privados
// =============================================================================

fn parse_query_params(query: String) -> List(#(String, String)) {
  query
  |> string.split("&")
  |> list.filter_map(fn(pair) {
    case string.split(pair, "=") {
      [key, value] ->
        Ok(#(key, uri.percent_decode(value) |> result.unwrap(value)))
      _ -> Error(Nil)
    }
  })
}

fn get_string(params: List(#(String, String)), key: String) -> Option(String) {
  params
  |> list.find(fn(p) { p.0 == key })
  |> result.map(fn(p) { p.1 })
  |> option.from_result
}

fn get_int(params: List(#(String, String)), key: String) -> Option(Int) {
  params
  |> get_string(key)
  |> option.then(fn(s) { int.parse(s) |> option.from_result })
}
