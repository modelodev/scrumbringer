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

import domain/view_mode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import scrumbringer_client/assignments_view_mode

/// Contexto de parsing/format de query params.
pub type QueryContext {
  Member
  Config
  Org
  OrgAssignments
}

/// Parametro de vista soportado por la URL.
pub type ViewParam {
  MemberView(view_mode.ViewMode)
  AssignmentsView(assignments_view_mode.AssignmentsViewMode)
}

/// Estado de URL - solo se puede crear mediante parse().
pub opaque type UrlState {
  UrlState(
    project: option.Option(Int),
    view: option.Option(ViewParam),
    type_filter: option.Option(Int),
    capability_filter: option.Option(Int),
    search: option.Option(String),
    expanded_card: option.Option(Int),
  )
}

/// Resultado de parseo de query params.
pub type QueryParseResult {
  Parsed(UrlState)
  Redirect(UrlState)
}

type UrlQueryParams {
  UrlQueryParams(
    project: option.Option(Int),
    view: option.Option(ViewParam),
    type_filter: option.Option(Int),
    capability_filter: option.Option(Int),
    search: option.Option(String),
    expanded_card: option.Option(Int),
  )
}

type QueryError {
  InvalidProject(String)
  InvalidView(String)
  InvalidType(String)
  InvalidCapability(String)
  InvalidCard(String)
  UnexpectedParam(String)
}

type ParsedParams {
  ParsedParams(
    params: UrlQueryParams,
    present_keys: List(String),
    errors: List(QueryError),
  )
}

/// Crea un UrlState vacío (sin proyecto, sin view explicita)
pub fn empty() -> UrlState {
  UrlState(
    project: option.None,
    view: option.None,
    type_filter: option.None,
    capability_filter: option.None,
    search: option.None,
    expanded_card: option.None,
  )
}

/// Parsea una URI y crea un UrlState válido según el contexto.
///
/// Este es el punto de entrada principal para crear UrlState.
pub fn parse(uri: Uri, context: QueryContext) -> QueryParseResult {
  let query = uri.query |> option.unwrap("")
  parse_query(query, context)
}

/// Parsea un query string directamente según el contexto.
pub fn parse_query(query: String, context: QueryContext) -> QueryParseResult {
  let ParsedParams(params: params, present_keys: present, errors: errors) =
    parse_query_params(query)
  let errors = list.append(errors, context_errors(context, params, present))
  let state = to_state(params)
  case errors {
    [] -> Parsed(state)
    _ -> Redirect(state)
  }
}

// =============================================================================
// Builders (inmutables)
// =============================================================================

/// Builder: actualiza el proyecto seleccionado.
pub fn with_project(state: UrlState, project_id: Int) -> UrlState {
  UrlState(..state, project: option.Some(project_id))
}

/// Builder: limpia el proyecto seleccionado.
pub fn without_project(state: UrlState) -> UrlState {
  UrlState(..state, project: option.None)
}

/// Builder: actualiza el modo de vista de miembro.
pub fn with_view(state: UrlState, mode: view_mode.ViewMode) -> UrlState {
  UrlState(..state, view: option.Some(MemberView(mode)))
}

/// Builder: actualiza el modo de vista de assignments.
pub fn with_assignments_view(
  state: UrlState,
  mode: assignments_view_mode.AssignmentsViewMode,
) -> UrlState {
  UrlState(..state, view: option.Some(AssignmentsView(mode)))
}

/// Builder: limpia la vista explicita.
pub fn without_view(state: UrlState) -> UrlState {
  UrlState(..state, view: option.None)
}

/// Builder: actualiza el filtro de tipo.
pub fn with_type_filter(
  state: UrlState,
  type_id: option.Option(Int),
) -> UrlState {
  UrlState(..state, type_filter: type_id)
}

/// Builder: actualiza el filtro de capacidad.
pub fn with_capability_filter(
  state: UrlState,
  cap_id: option.Option(Int),
) -> UrlState {
  UrlState(..state, capability_filter: cap_id)
}

/// Builder: actualiza la busqueda.
pub fn with_search(state: UrlState, term: option.Option(String)) -> UrlState {
  UrlState(..state, search: term)
}

/// Builder: actualiza la ficha expandida.
pub fn with_expanded_card(
  state: UrlState,
  card_id: option.Option(Int),
) -> UrlState {
  UrlState(..state, expanded_card: card_id)
}

/// Builder: limpia todos los filtros.
pub fn clear_filters(state: UrlState) -> UrlState {
  UrlState(
    ..state,
    type_filter: option.None,
    capability_filter: option.None,
    search: option.None,
    expanded_card: option.None,
  )
}

// =============================================================================
// Accessors (read-only)
// =============================================================================

/// Provides project.
///
/// Example:
///   project(...)
pub fn project(state: UrlState) -> option.Option(Int) {
  state.project
}

/// Provides view param for member routes.
pub fn view_param(state: UrlState) -> option.Option(view_mode.ViewMode) {
  case state.view {
    option.Some(MemberView(mode)) -> option.Some(mode)
    _ -> option.None
  }
}

/// Provides view param for assignments.
pub fn assignments_view_param(
  state: UrlState,
) -> option.Option(assignments_view_mode.AssignmentsViewMode) {
  case state.view {
    option.Some(AssignmentsView(mode)) -> option.Some(mode)
    _ -> option.None
  }
}

/// Provides view (default Pool).
///
/// Example:
///   view(...)
pub fn view(state: UrlState) -> view_mode.ViewMode {
  view_param(state)
  |> option.unwrap(view_mode.Pool)
}

/// Provides assignments view (default ByProject).
pub fn assignments_view(
  state: UrlState,
) -> assignments_view_mode.AssignmentsViewMode {
  assignments_view_param(state)
  |> option.unwrap(assignments_view_mode.ByProject)
}

/// Provides type filter.
///
/// Example:
///   type_filter(...)
pub fn type_filter(state: UrlState) -> option.Option(Int) {
  state.type_filter
}

/// Provides capability filter.
///
/// Example:
///   capability_filter(...)
pub fn capability_filter(state: UrlState) -> option.Option(Int) {
  state.capability_filter
}

/// Provides search.
///
/// Example:
///   search(...)
pub fn search(state: UrlState) -> option.Option(String) {
  state.search
}

/// Provides expanded card.
///
/// Example:
///   expanded_card(...)
pub fn expanded_card(state: UrlState) -> option.Option(Int) {
  state.expanded_card
}

// =============================================================================
// Serialización
// =============================================================================

/// Serializa a query string para pushState (contexto Member).
pub fn to_query_string(state: UrlState) -> String {
  to_query_string_for(Member, state)
}

/// Serializa a query string para el contexto indicado.
pub fn to_query_string_for(context: QueryContext, state: UrlState) -> String {
  let params = case context {
    Member -> [
      state.project |> option.map(fn(p) { "project=" <> int.to_string(p) }),
      view_param(state)
        |> option.map(fn(v) { "view=" <> view_mode.to_string(v) }),
      state.type_filter |> option.map(fn(t) { "type=" <> int.to_string(t) }),
      state.capability_filter
        |> option.map(fn(c) { "cap=" <> int.to_string(c) }),
      state.search |> option.map(fn(s) { "search=" <> uri.percent_encode(s) }),
      state.expanded_card |> option.map(fn(c) { "card=" <> int.to_string(c) }),
    ]

    Config -> [
      state.project |> option.map(fn(p) { "project=" <> int.to_string(p) }),
    ]

    OrgAssignments -> [
      assignments_view_param(state)
      |> option.map(fn(v) { "view=" <> assignments_view_mode.to_param(v) }),
    ]

    Org -> []
  }

  params
  |> list.filter_map(option.to_result(_, Nil))
  |> string.join("&")
}

/// Construye la URL completa para /app.
pub fn to_app_url(state: UrlState) -> String {
  let query = to_query_string_for(Member, state)
  case query {
    "" -> "/app"
    q -> "/app?" <> q
  }
}

// =============================================================================
// Helpers privados
// =============================================================================

fn to_state(params: UrlQueryParams) -> UrlState {
  UrlState(
    project: params.project,
    view: params.view,
    type_filter: params.type_filter,
    capability_filter: params.capability_filter,
    search: params.search,
    expanded_card: params.expanded_card,
  )
}

fn context_errors(
  context: QueryContext,
  params: UrlQueryParams,
  present: List(String),
) -> List(QueryError) {
  let has = fn(key: String) { list.any(present, fn(k) { k == key }) }
  let view_is_member = case params.view {
    option.Some(MemberView(_)) -> True
    _ -> False
  }
  let view_is_assignments = case params.view {
    option.Some(AssignmentsView(_)) -> True
    _ -> False
  }

  case context {
    Member ->
      case has("view") && !view_is_member {
        True -> [UnexpectedParam("view")]
        False -> []
      }

    Config ->
      list.filter_map(
        [
          #(has("view"), "view"),
          #(has("type"), "type"),
          #(has("cap"), "cap"),
          #(has("search"), "search"),
          #(has("card"), "card"),
        ],
        fn(entry) {
          case entry.0 {
            True -> Ok(UnexpectedParam(entry.1))
            False -> Error(Nil)
          }
        },
      )

    OrgAssignments ->
      list.filter_map(
        [
          #(has("project"), "project"),
          #(has("type"), "type"),
          #(has("cap"), "cap"),
          #(has("search"), "search"),
          #(has("card"), "card"),
          #(has("view") && !view_is_assignments, "view"),
        ],
        fn(entry) {
          case entry.0 {
            True -> Ok(UnexpectedParam(entry.1))
            False -> Error(Nil)
          }
        },
      )

    Org ->
      list.filter_map(
        [
          #(has("project"), "project"),
          #(has("view"), "view"),
          #(has("type"), "type"),
          #(has("cap"), "cap"),
          #(has("search"), "search"),
          #(has("card"), "card"),
        ],
        fn(entry) {
          case entry.0 {
            True -> Ok(UnexpectedParam(entry.1))
            False -> Error(Nil)
          }
        },
      )
  }
}

fn parse_query_params(query: String) -> ParsedParams {
  let params = parse_query_pairs(query)
  let present_keys = params |> list.map(fn(p) { p.0 })

  let #(project, project_error) =
    parse_optional_int_param(params, "project", InvalidProject)
  let #(view, view_error) = parse_optional_view_param(params, "view")
  let #(type_filter, type_error) =
    parse_optional_int_param(params, "type", InvalidType)
  let #(capability_filter, cap_error) =
    parse_optional_int_param(params, "cap", InvalidCapability)
  let search = get_string(params, "search")
  let #(expanded_card, card_error) =
    parse_optional_int_param(params, "card", InvalidCard)

  let known_keys = ["project", "view", "type", "cap", "search", "card"]
  let unknown_keys =
    present_keys
    |> list.filter(fn(key) { !list.contains(known_keys, key) })
    |> list.map(UnexpectedParam)

  let query_params =
    UrlQueryParams(
      project: project,
      view: view,
      type_filter: type_filter,
      capability_filter: capability_filter,
      search: search,
      expanded_card: expanded_card,
    )

  let errors =
    [project_error, view_error, type_error, cap_error, card_error]
    |> list.filter_map(fn(err) { option.to_result(err, Nil) })

  ParsedParams(query_params, present_keys, list.append(errors, unknown_keys))
}

fn parse_query_pairs(query: String) -> List(#(String, String)) {
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

// Justification: nested case improves clarity for branching logic.
fn parse_optional_int_param(
  params: List(#(String, String)),
  key: String,
  err: fn(String) -> QueryError,
) -> #(option.Option(Int), option.Option(QueryError)) {
  case get_string(params, key) {
    option.None -> #(option.None, option.None)
    option.Some(raw) ->
      case int.parse(raw) {
        Ok(value) -> #(option.Some(value), option.None)
        Error(_) -> #(option.None, option.Some(err(raw)))
      }
  }
}

// Justification: nested case improves clarity for branching logic.
fn parse_optional_view_param(
  params: List(#(String, String)),
  key: String,
) -> #(option.Option(ViewParam), option.Option(QueryError)) {
  case get_string(params, key) {
    option.None -> #(option.None, option.None)
    option.Some(raw) ->
      case view_param_from_raw(raw) {
        option.Some(mode) -> #(option.Some(mode), option.None)
        option.None -> #(option.None, option.Some(InvalidView(raw)))
      }
  }
}

fn view_param_from_raw(raw: String) -> option.Option(ViewParam) {
  case raw {
    "pool" -> option.Some(MemberView(view_mode.Pool))
    "list" -> option.Some(MemberView(view_mode.List))
    "cards" -> option.Some(MemberView(view_mode.Cards))
    "people" -> option.Some(MemberView(view_mode.People))
    _ ->
      assignments_view_mode.from_param(raw)
      |> option.map(AssignmentsView)
  }
}

fn get_string(
  params: List(#(String, String)),
  key: String,
) -> option.Option(String) {
  params
  |> list.find(fn(p) { p.0 == key })
  |> result.map(fn(p) { p.1 })
  |> option.from_result
}
