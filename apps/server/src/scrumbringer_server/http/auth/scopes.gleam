//// Bearer scope mapping for supported API routes.

import gleam/http
import scrumbringer_server/services/api_tokens.{
  type Scope, Cards, Milestones, Notes, Projects, Read, Scope, Tasks, Write,
}

pub type ScopeRouteError {
  RouteNotAllowed
}

pub fn required_scope(
  method: http.Method,
  segments: List(String),
) -> Result(Scope, ScopeRouteError) {
  case method, segments {
    http.Get, ["api", "v1", "projects"] -> read(Projects)

    http.Get, ["api", "v1", "projects", _, "tasks"] -> read(Tasks)
    http.Get, ["api", "v1", "tasks", _] -> read(Tasks)
    http.Post, ["api", "v1", "projects", _, "tasks"] -> write(Tasks)
    http.Patch, ["api", "v1", "tasks", _] -> write(Tasks)
    http.Post, ["api", "v1", "tasks", _, "claim"] -> write(Tasks)
    http.Post, ["api", "v1", "tasks", _, "release"] -> write(Tasks)
    http.Post, ["api", "v1", "tasks", _, "complete"] -> write(Tasks)

    http.Get, ["api", "v1", "projects", _, "cards"] -> read(Cards)
    http.Get, ["api", "v1", "cards", _] -> read(Cards)
    http.Post, ["api", "v1", "projects", _, "cards"] -> write(Cards)
    http.Patch, ["api", "v1", "cards", _] -> write(Cards)
    http.Delete, ["api", "v1", "cards", _] -> write(Cards)

    http.Get, ["api", "v1", "tasks", _, "notes"] -> read(Notes)
    http.Post, ["api", "v1", "tasks", _, "notes"] -> write(Notes)
    http.Get, ["api", "v1", "cards", _, "notes"] -> read(Notes)
    http.Post, ["api", "v1", "cards", _, "notes"] -> write(Notes)
    http.Delete, ["api", "v1", "cards", _, "notes", _] -> write(Notes)

    http.Get, ["api", "v1", "projects", _, "milestones"] -> read(Milestones)
    http.Get, ["api", "v1", "milestones", _] -> read(Milestones)
    http.Post, ["api", "v1", "projects", _, "milestones"] -> write(Milestones)
    http.Patch, ["api", "v1", "milestones", _] -> write(Milestones)
    http.Delete, ["api", "v1", "milestones", _] -> write(Milestones)

    _, _ -> Error(RouteNotAllowed)
  }
}

fn read(resource) {
  Ok(Scope(resource: resource, access: Read))
}

fn write(resource) {
  Ok(Scope(resource: resource, access: Write))
}
