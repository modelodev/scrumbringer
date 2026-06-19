//// Shared API token scope domain.
////
//// Scopes are persisted and serialized as strings, but application code should
//// use this ADT so unsupported resource/access combinations are rejected at
//// boundaries.

import gleam/dynamic/decode
import gleam/list

pub type Resource {
  Projects
  Tasks
  Cards
  CardTrees
  Notes
}

pub type Access {
  Read
  Write
}

pub type Scope {
  ProjectsRead
  TasksRead
  TasksWrite
  CardsRead
  CardsWrite
  CardTreesRead
  NotesRead
  NotesWrite
}

pub type ParseError {
  InvalidScope(String)
}

pub fn parse(value: String) -> Result(Scope, ParseError) {
  case value {
    "projects:read" -> Ok(ProjectsRead)
    "tasks:read" -> Ok(TasksRead)
    "tasks:write" -> Ok(TasksWrite)
    "cards:read" -> Ok(CardsRead)
    "cards:write" -> Ok(CardsWrite)
    "card_trees:read" -> Ok(CardTreesRead)
    "notes:read" -> Ok(NotesRead)
    "notes:write" -> Ok(NotesWrite)
    _ -> Error(InvalidScope(value))
  }
}

pub fn decoder() -> decode.Decoder(Scope) {
  use raw <- decode.then(decode.string)
  case parse(raw) {
    Ok(scope) -> decode.success(scope)
    Error(_) -> decode.failure(ProjectsRead, "ApiTokenScope")
  }
}

pub fn supported() -> List(Scope) {
  [
    ProjectsRead,
    TasksRead,
    TasksWrite,
    CardsRead,
    CardsWrite,
    CardTreesRead,
    NotesRead,
    NotesWrite,
  ]
}

pub fn supported_strings() -> List(String) {
  supported()
  |> list.map(to_string)
}

pub fn to_string(scope: Scope) -> String {
  resource_to_string(resource(scope)) <> ":" <> access_to_string(access(scope))
}

pub fn from_parts(
  resource: Resource,
  access: Access,
) -> Result(Scope, ParseError) {
  case resource, access {
    Projects, Read -> Ok(ProjectsRead)
    Tasks, Read -> Ok(TasksRead)
    Tasks, Write -> Ok(TasksWrite)
    Cards, Read -> Ok(CardsRead)
    Cards, Write -> Ok(CardsWrite)
    CardTrees, Read -> Ok(CardTreesRead)
    Notes, Read -> Ok(NotesRead)
    Notes, Write -> Ok(NotesWrite)
    _, _ ->
      Error(InvalidScope(
        resource_to_string(resource) <> ":" <> access_to_string(access),
      ))
  }
}

pub fn resource(scope: Scope) -> Resource {
  case scope {
    ProjectsRead -> Projects
    TasksRead | TasksWrite -> Tasks
    CardsRead | CardsWrite -> Cards
    CardTreesRead -> CardTrees
    NotesRead | NotesWrite -> Notes
  }
}

pub fn access(scope: Scope) -> Access {
  case scope {
    ProjectsRead | TasksRead | CardsRead | CardTreesRead | NotesRead -> Read
    TasksWrite | CardsWrite | NotesWrite -> Write
  }
}

pub fn resource_to_string(resource: Resource) -> String {
  case resource {
    Projects -> "projects"
    Tasks -> "tasks"
    Cards -> "cards"
    CardTrees -> "card_trees"
    Notes -> "notes"
  }
}

pub fn access_to_string(access: Access) -> String {
  case access {
    Read -> "read"
    Write -> "write"
  }
}
