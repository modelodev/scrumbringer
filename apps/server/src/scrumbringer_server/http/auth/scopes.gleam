//// Bearer scope mapping for supported API routes.

import domain/api_token_scope.{type Scope}
import gleam/http

pub type ScopeRouteError {
  RouteNotAllowed
}

pub fn required_scope(
  method: http.Method,
  segments: List(String),
) -> Result(Scope, ScopeRouteError) {
  case method, segments {
    http.Get, ["api", "v1", "projects"] -> read(api_token_scope.Projects)

    http.Get, ["api", "v1", "projects", _, "tasks"] ->
      read(api_token_scope.Tasks)
    http.Get, ["api", "v1", "tasks", _] -> read(api_token_scope.Tasks)
    http.Get, ["api", "v1", "tasks", _, "activity"] ->
      read(api_token_scope.Tasks)
    http.Post, ["api", "v1", "projects", _, "tasks"] ->
      write(api_token_scope.Tasks)
    http.Patch, ["api", "v1", "tasks", _] -> write(api_token_scope.Tasks)
    http.Delete, ["api", "v1", "tasks", _] -> write(api_token_scope.Tasks)
    http.Post, ["api", "v1", "tasks", _, "claim"] ->
      write(api_token_scope.Tasks)
    http.Post, ["api", "v1", "tasks", _, "release"] ->
      write(api_token_scope.Tasks)
    http.Post, ["api", "v1", "tasks", _, "complete"] ->
      write(api_token_scope.Tasks)

    http.Get, ["api", "v1", "projects", _, "cards"] ->
      read(api_token_scope.Cards)
    http.Get, ["api", "v1", "cards", _] -> read(api_token_scope.Cards)
    http.Get, ["api", "v1", "cards", _, "activity"] ->
      read(api_token_scope.Cards)
    http.Post, ["api", "v1", "projects", _, "cards"] ->
      write(api_token_scope.Cards)
    http.Patch, ["api", "v1", "cards", _] -> write(api_token_scope.Cards)
    http.Delete, ["api", "v1", "cards", _] -> write(api_token_scope.Cards)

    http.Get, ["api", "v1", "tasks", _, "notes"] -> read(api_token_scope.Notes)
    http.Post, ["api", "v1", "tasks", _, "notes"] ->
      write(api_token_scope.Notes)
    http.Post, ["api", "v1", "tasks", _, "notes", _, "pin"] ->
      write(api_token_scope.Notes)
    http.Delete, ["api", "v1", "tasks", _, "notes", _, "pin"] ->
      write(api_token_scope.Notes)
    http.Get, ["api", "v1", "cards", _, "notes"] -> read(api_token_scope.Notes)
    http.Post, ["api", "v1", "cards", _, "notes"] ->
      write(api_token_scope.Notes)
    http.Post, ["api", "v1", "cards", _, "notes", _, "pin"] ->
      write(api_token_scope.Notes)
    http.Delete, ["api", "v1", "cards", _, "notes", _, "pin"] ->
      write(api_token_scope.Notes)
    http.Delete, ["api", "v1", "cards", _, "notes", _] ->
      write(api_token_scope.Notes)

    _, _ -> Error(RouteNotAllowed)
  }
}

fn read(resource) {
  api_token_scope.from_parts(resource, api_token_scope.Read)
  |> map_scope_error
}

fn write(resource) {
  api_token_scope.from_parts(resource, api_token_scope.Write)
  |> map_scope_error
}

fn map_scope_error(
  result: Result(Scope, api_token_scope.ParseError),
) -> Result(Scope, ScopeRouteError) {
  case result {
    Ok(scope) -> Ok(scope)
    Error(_) -> Error(RouteNotAllowed)
  }
}
