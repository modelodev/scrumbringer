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
import scrumbringer_client/capability_scope

/// Contexto de parsing/format de query params.
pub type QueryContext {
  Member
  Config
  Org
  OrgTeam
}

/// Parametro de vista soportado por la URL.
pub type ViewParam {
  MemberView(view_mode.ViewMode)
  AssignmentsView(assignments_view_mode.AssignmentsViewMode)
}

/// Display mode supported by the Plan surface URL state.
pub type PlanModeParam {
  PlanStructureParam
  PlanKanbanParam
}

/// Work scope supported by primary member surfaces.
pub type WorkScopeParam {
  CardWorkScopeParam
}

/// Entity show supported by member routes.
pub type ShowParam {
  CardShowParam(card_id: Int)
  TaskShowParam(task_id: Int)
}

/// Estado de URL - solo se puede crear mediante parse().
pub opaque type UrlState {
  UrlState(
    project: option.Option(Int),
    view: option.Option(ViewParam),
    plan_mode: option.Option(PlanModeParam),
    work_scope: option.Option(WorkScopeParam),
    capability_scope: capability_scope.CapabilityScope,
    type_filter: option.Option(Int),
    capability_filter: option.Option(Int),
    search: option.Option(String),
    expanded_card: option.Option(Int),
    card_depth: option.Option(Int),
    show: option.Option(ShowParam),
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
    plan_mode: option.Option(PlanModeParam),
    work_scope: option.Option(WorkScopeParam),
    capability_scope: capability_scope.CapabilityScope,
    type_filter: option.Option(Int),
    capability_filter: option.Option(Int),
    search: option.Option(String),
    expanded_card: option.Option(Int),
    card_depth: option.Option(Int),
    show: option.Option(ShowParam),
  )
}

type QueryError {
  InvalidEncoding(String)
  InvalidProject(String)
  InvalidView(String)
  InvalidPlanMode(String)
  InvalidScope(String)
  InvalidType(String)
  InvalidCapability(String)
  InvalidCard(String)
  InvalidTask(String)
  InvalidShow(String)
  InvalidDepth(String)
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
    plan_mode: option.None,
    work_scope: option.None,
    capability_scope: capability_scope.default(),
    type_filter: option.None,
    capability_filter: option.None,
    search: option.None,
    expanded_card: option.None,
    card_depth: option.None,
    show: option.None,
  )
}

/// Parsea una URI y crea un UrlState válido según el contexto.
///
/// Este es el punto de entrada principal para crear UrlState.
pub fn parse(uri: Uri, context: QueryContext) -> QueryParseResult {
  let query = uri_query_string(uri)
  parse_query(query, context)
}

fn uri_query_string(uri: Uri) -> String {
  case uri.query {
    option.None -> ""
    option.Some(query) -> query
  }
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

/// Builder: actualiza el modo de vista de miembro.
pub fn with_view(state: UrlState, mode: view_mode.ViewMode) -> UrlState {
  case mode {
    view_mode.Cards -> UrlState(..state, view: option.Some(MemberView(mode)))
    _ ->
      UrlState(
        ..state,
        view: option.Some(MemberView(mode)),
        plan_mode: option.None,
        card_depth: option.None,
      )
  }
}

/// Builder: updates the Plan display mode.
pub fn with_plan_mode(state: UrlState, mode: PlanModeParam) -> UrlState {
  UrlState(
    ..state,
    view: option.Some(MemberView(view_mode.Cards)),
    plan_mode: option.Some(mode),
  )
}

/// Builder: scopes work surfaces to a single card.
pub fn with_card_work_scope(state: UrlState, card_id: Int) -> UrlState {
  UrlState(
    ..state,
    work_scope: option.Some(CardWorkScopeParam),
    expanded_card: option.Some(card_id),
  )
}

/// Builder: opens Card Show without changing the primary view scope.
pub fn with_card_show(state: UrlState, card_id: Int) -> UrlState {
  UrlState(..state, show: option.Some(CardShowParam(card_id)))
}

/// Builder: opens Task Show without changing the primary view scope.
pub fn with_task_show(state: UrlState, task_id: Int) -> UrlState {
  UrlState(..state, show: option.Some(TaskShowParam(task_id)))
}

/// Builder: actualiza el modo de vista de assignments.
pub fn with_assignments_view(
  state: UrlState,
  mode: assignments_view_mode.AssignmentsViewMode,
) -> UrlState {
  UrlState(
    ..state,
    view: option.Some(AssignmentsView(mode)),
    plan_mode: option.None,
    card_depth: option.None,
  )
}

/// Builder: actualiza el filtro de tipo.
pub fn with_type_filter(
  state: UrlState,
  type_id: option.Option(Int),
) -> UrlState {
  UrlState(..state, type_filter: type_id)
}

pub fn with_capability_scope(
  state: UrlState,
  scope: capability_scope.CapabilityScope,
) -> UrlState {
  UrlState(..state, capability_scope: scope)
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

/// Builder: actualiza la profundidad de tarjetas seleccionada.
pub fn with_card_depth(state: UrlState, depth: option.Option(Int)) -> UrlState {
  UrlState(..state, card_depth: depth)
}

/// Builder: limpia todos los filtros.
pub fn clear_filters(state: UrlState) -> UrlState {
  UrlState(
    ..state,
    capability_scope: capability_scope.default(),
    type_filter: option.None,
    capability_filter: option.None,
    search: option.None,
    expanded_card: option.None,
    card_depth: option.None,
    work_scope: option.None,
    show: option.None,
    plan_mode: case view_param(state) {
      option.Some(view_mode.Cards) -> state.plan_mode
      _ -> option.None
    },
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
  |> member_view_or_default
}

/// Provides Plan mode (default Structure).
pub fn plan_mode(state: UrlState) -> PlanModeParam {
  case view_param(state), state.plan_mode {
    option.Some(view_mode.Cards), option.Some(mode) -> mode
    _, _ -> PlanStructureParam
  }
}

fn member_view_or_default(
  view: option.Option(view_mode.ViewMode),
) -> view_mode.ViewMode {
  case view {
    option.None -> view_mode.Pool
    option.Some(mode) -> mode
  }
}

/// Provides type filter.
///
/// Example:
///   type_filter(...)
pub fn type_filter(state: UrlState) -> option.Option(Int) {
  state.type_filter
}

pub fn capability_scope(state: UrlState) -> capability_scope.CapabilityScope {
  state.capability_scope
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

/// Provides the scoped card id when the URL explicitly uses work_scope=card.
pub fn card_work_scope(state: UrlState) -> option.Option(Int) {
  case state.work_scope, state.expanded_card {
    option.Some(CardWorkScopeParam), option.Some(card_id) ->
      option.Some(card_id)
    _, _ -> option.None
  }
}

/// Provides selected card hierarchy depth.
pub fn card_depth(state: UrlState) -> option.Option(Int) {
  case view_param(state) {
    option.Some(view_mode.Cards) -> state.card_depth
    _ -> option.None
  }
}

/// Provides the currently open Card Show id, if present.
pub fn card_show(state: UrlState) -> option.Option(Int) {
  case state.show {
    option.Some(CardShowParam(card_id)) -> option.Some(card_id)
    _ -> option.None
  }
}

/// Provides the currently open Task Show id, if present.
pub fn task_show(state: UrlState) -> option.Option(Int) {
  case state.show {
    option.Some(TaskShowParam(task_id)) -> option.Some(task_id)
    _ -> option.None
  }
}

pub fn show(state: UrlState) -> option.Option(ShowParam) {
  state.show
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
      plan_mode_query_param(state),
      work_scope_query_param(state),
      case capability_scope.is_default(state.capability_scope) {
        True -> option.None
        False ->
          option.Some(
            "scope=" <> capability_scope.to_string(state.capability_scope),
          )
      },
      state.type_filter |> option.map(fn(t) { "type=" <> int.to_string(t) }),
      state.capability_filter
        |> option.map(fn(c) { "cap=" <> int.to_string(c) }),
      state.search |> option.map(fn(s) { "search=" <> uri.percent_encode(s) }),
      state.expanded_card |> option.map(fn(c) { "card=" <> int.to_string(c) }),
      card_depth(state) |> option.map(fn(d) { "depth=" <> int.to_string(d) }),
      show_kind_query_param(state),
      show_card_query_param(state),
      show_task_query_param(state),
    ]

    Config -> [
      state.project |> option.map(fn(p) { "project=" <> int.to_string(p) }),
    ]

    OrgTeam -> [
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
    plan_mode: params.plan_mode,
    work_scope: case params.work_scope, params.expanded_card {
      option.Some(CardWorkScopeParam), option.Some(_) -> params.work_scope
      _, _ -> option.None
    },
    capability_scope: params.capability_scope,
    type_filter: params.type_filter,
    capability_filter: params.capability_filter,
    search: params.search,
    expanded_card: params.expanded_card,
    card_depth: params.card_depth,
    show: params.show,
  )
}

fn plan_mode_query_param(state: UrlState) -> option.Option(String) {
  case view_param(state), state.plan_mode {
    option.Some(view_mode.Cards), option.Some(PlanKanbanParam) ->
      option.Some("plan_mode=kanban")
    _, _ -> option.None
  }
}

fn work_scope_query_param(state: UrlState) -> option.Option(String) {
  case card_work_scope(state) {
    option.Some(_) -> option.Some("work_scope=card")
    option.None -> option.None
  }
}

fn show_kind_query_param(state: UrlState) -> option.Option(String) {
  case state.show {
    option.Some(CardShowParam(_)) -> option.Some("show=card")
    option.Some(TaskShowParam(_)) -> option.Some("show=task")
    option.None -> option.None
  }
}

fn show_card_query_param(state: UrlState) -> option.Option(String) {
  case state.show {
    option.Some(CardShowParam(card_id)) ->
      option.Some("show_card=" <> int.to_string(card_id))
    _ -> option.None
  }
}

fn show_task_query_param(state: UrlState) -> option.Option(String) {
  case state.show {
    option.Some(TaskShowParam(task_id)) ->
      option.Some("task=" <> int.to_string(task_id))
    _ -> option.None
  }
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
  let view_is_cards = case params.view {
    option.Some(MemberView(view_mode.Cards)) -> True
    _ -> False
  }
  let has_plan_mode = has("plan_mode")
  let has_work_scope_without_card = has("work_scope") && !has("card")
  let has_show_card_without_show = has("show_card") && !has("show")
  let has_task_without_show = has("task") && !has("show")

  case context {
    Member ->
      list.filter_map(
        [
          #(has("mode"), "mode"),
          #(has("engine"), "engine"),
          #(has("rule"), "rule"),
          #(has("template"), "template"),
          #(has("execution"), "execution"),
          #(has("view") && !view_is_member, "view"),
          #(has("depth") && !view_is_cards, "depth"),
          #(has_plan_mode && !view_is_cards, "plan_mode"),
          #(has_work_scope_without_card, "work_scope"),
          #(has_show_card_without_show, "show_card"),
          #(has_task_without_show, "task"),
        ],
        fn(entry) {
          case entry.0 {
            True -> Ok(UnexpectedParam(entry.1))
            False -> Error(Nil)
          }
        },
      )

    Config ->
      list.filter_map(
        [
          #(has("view"), "view"),
          #(has("scope"), "scope"),
          #(has("type"), "type"),
          #(has("cap"), "cap"),
          #(has("search"), "search"),
          #(has("card"), "card"),
          #(has("depth"), "depth"),
          #(has("plan_mode"), "plan_mode"),
          #(has("work_scope"), "work_scope"),
          #(has("show"), "show"),
          #(has("show_card"), "show_card"),
          #(has("task"), "task"),
        ],
        fn(entry) {
          case entry.0 {
            True -> Ok(UnexpectedParam(entry.1))
            False -> Error(Nil)
          }
        },
      )

    OrgTeam ->
      list.filter_map(
        [
          #(has("mode"), "mode"),
          #(has("engine"), "engine"),
          #(has("rule"), "rule"),
          #(has("template"), "template"),
          #(has("execution"), "execution"),
          #(has("project"), "project"),
          #(has("scope"), "scope"),
          #(has("type"), "type"),
          #(has("cap"), "cap"),
          #(has("search"), "search"),
          #(has("card"), "card"),
          #(has("depth"), "depth"),
          #(has("plan_mode"), "plan_mode"),
          #(has("work_scope"), "work_scope"),
          #(has("show"), "show"),
          #(has("show_card"), "show_card"),
          #(has("task"), "task"),
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
          #(has("mode"), "mode"),
          #(has("engine"), "engine"),
          #(has("rule"), "rule"),
          #(has("template"), "template"),
          #(has("execution"), "execution"),
          #(has("project"), "project"),
          #(has("view"), "view"),
          #(has("scope"), "scope"),
          #(has("type"), "type"),
          #(has("cap"), "cap"),
          #(has("search"), "search"),
          #(has("card"), "card"),
          #(has("depth"), "depth"),
          #(has("plan_mode"), "plan_mode"),
          #(has("work_scope"), "work_scope"),
          #(has("show"), "show"),
          #(has("show_card"), "show_card"),
          #(has("task"), "task"),
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
  let #(params, pair_errors) = parse_query_pairs(query)
  let present_keys = params |> list.map(fn(p) { p.0 })

  let #(project, project_error) =
    parse_optional_int_param(params, "project", InvalidProject)
  let #(view, view_error) = parse_optional_view_param(params, "view")
  let #(plan_mode, plan_mode_error) =
    parse_optional_plan_mode_param(params, "plan_mode")
  let #(work_scope, work_scope_error) =
    parse_optional_work_scope_param(params, "work_scope")
  let #(capability_scope, scope_error) =
    parse_optional_capability_scope(params, "scope")
  let #(type_filter, type_error) =
    parse_optional_int_param(params, "type", InvalidType)
  let #(capability_filter, cap_error) =
    parse_optional_int_param(params, "cap", InvalidCapability)
  let search = get_string(params, "search")
  let #(expanded_card, card_error) =
    parse_optional_int_param(params, "card", InvalidCard)
  let #(card_depth, depth_error) =
    parse_optional_int_param(params, "depth", InvalidDepth)
  let #(show, show_error) = parse_optional_show_param(params)

  let known_keys = [
    "project",
    "view",
    "plan_mode",
    "work_scope",
    "scope",
    "type",
    "cap",
    "search",
    "card",
    "depth",
    "show",
    "show_card",
    "task",
    "mode",
    "engine",
    "rule",
    "template",
    "execution",
  ]
  let unknown_keys =
    present_keys
    |> list.filter(fn(key) { !list.contains(known_keys, key) })
    |> list.map(UnexpectedParam)

  let query_params =
    UrlQueryParams(
      project: project,
      view: view,
      plan_mode: plan_mode,
      work_scope: work_scope,
      capability_scope: capability_scope,
      type_filter: type_filter,
      capability_filter: capability_filter,
      search: search,
      expanded_card: expanded_card,
      card_depth: card_depth,
      show: show,
    )

  let errors =
    [
      project_error,
      view_error,
      plan_mode_error,
      work_scope_error,
      scope_error,
      type_error,
      cap_error,
      card_error,
      depth_error,
      show_error,
    ]
    |> list.filter_map(fn(err) { option.to_result(err, Nil) })

  ParsedParams(
    query_params,
    present_keys,
    list.append(list.append(pair_errors, errors), unknown_keys),
  )
}

fn parse_query_pairs(
  query: String,
) -> #(List(#(String, String)), List(QueryError)) {
  case query {
    "" -> #([], [])
    _ -> {
      let #(pairs, errors) =
        query
        |> string.split("&")
        |> list.fold(#([], []), fn(acc, pair) {
          let #(pairs, errors) = acc
          case pair {
            "" -> #(pairs, errors)
            _ ->
              case parse_query_pair(pair) {
                Ok(parsed_pair) -> #([parsed_pair, ..pairs], errors)
                Error(error) -> #(pairs, [error, ..errors])
              }
          }
        })

      #(list.reverse(pairs), list.reverse(errors))
    }
  }
}

fn parse_query_pair(pair: String) -> Result(#(String, String), QueryError) {
  case string.split(pair, "=") {
    [raw_key, raw_value] ->
      case uri.percent_decode(raw_key), uri.percent_decode(raw_value) {
        Ok(key), Ok(value) -> Ok(#(key, value))
        _, _ -> Error(InvalidEncoding(pair))
      }
    _ -> Error(UnexpectedParam(pair))
  }
}

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

fn parse_optional_plan_mode_param(
  params: List(#(String, String)),
  key: String,
) -> #(option.Option(PlanModeParam), option.Option(QueryError)) {
  case get_string(params, key) {
    option.None -> #(option.None, option.None)
    option.Some(raw) ->
      case plan_mode_param_from_raw(raw) {
        option.Some(mode) -> #(option.Some(mode), option.None)
        option.None -> #(option.None, option.Some(InvalidPlanMode(raw)))
      }
  }
}

fn parse_optional_work_scope_param(
  params: List(#(String, String)),
  key: String,
) -> #(option.Option(WorkScopeParam), option.Option(QueryError)) {
  case get_string(params, key) {
    option.None -> #(option.None, option.None)
    option.Some(raw) ->
      case raw {
        "card" -> #(option.Some(CardWorkScopeParam), option.None)
        _ -> #(option.None, option.Some(InvalidScope(raw)))
      }
  }
}

fn parse_optional_show_param(
  params: List(#(String, String)),
) -> #(option.Option(ShowParam), option.Option(QueryError)) {
  case get_string(params, "show") {
    option.None -> #(option.None, option.None)
    option.Some(raw) ->
      case raw {
        "card" ->
          parse_show_id(params, "show_card", InvalidCard)
          |> show_id_to_card_show
        "task" ->
          parse_show_id(params, "task", InvalidTask)
          |> show_id_to_task_show
        _ -> #(option.None, option.Some(InvalidShow(raw)))
      }
  }
}

fn parse_show_id(
  params: List(#(String, String)),
  key: String,
  err: fn(String) -> QueryError,
) -> #(option.Option(Int), option.Option(QueryError)) {
  case get_string(params, key) {
    option.None -> #(option.None, option.Some(err("")))
    option.Some(raw) ->
      case int.parse(raw) {
        Ok(value) -> #(option.Some(value), option.None)
        Error(_) -> #(option.None, option.Some(err(raw)))
      }
  }
}

fn show_id_to_card_show(
  parsed: #(option.Option(Int), option.Option(QueryError)),
) -> #(option.Option(ShowParam), option.Option(QueryError)) {
  let #(id, error) = parsed
  case id {
    option.Some(card_id) -> #(option.Some(CardShowParam(card_id)), error)
    option.None -> #(option.None, error)
  }
}

fn show_id_to_task_show(
  parsed: #(option.Option(Int), option.Option(QueryError)),
) -> #(option.Option(ShowParam), option.Option(QueryError)) {
  let #(id, error) = parsed
  case id {
    option.Some(task_id) -> #(option.Some(TaskShowParam(task_id)), error)
    option.None -> #(option.None, error)
  }
}

fn parse_optional_capability_scope(
  params: List(#(String, String)),
  key: String,
) -> #(capability_scope.CapabilityScope, option.Option(QueryError)) {
  case get_string(params, key) {
    option.None -> #(capability_scope.default(), option.None)
    option.Some(raw) ->
      case capability_scope.parse(raw) {
        Ok(scope) -> #(scope, option.None)
        Error(_) -> #(
          capability_scope.default(),
          option.Some(InvalidScope(raw)),
        )
      }
  }
}

fn view_param_from_raw(raw: String) -> option.Option(ViewParam) {
  case view_mode.parse(raw) {
    Ok(mode) -> option.Some(MemberView(mode))
    Error(_) ->
      case assignments_view_mode.parse(raw) {
        Ok(mode) -> option.Some(AssignmentsView(mode))
        Error(_) -> option.None
      }
  }
}

fn plan_mode_param_from_raw(raw: String) -> option.Option(PlanModeParam) {
  case raw {
    "structure" -> option.Some(PlanStructureParam)
    "kanban" -> option.Some(PlanKanbanParam)
    _ -> option.None
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
