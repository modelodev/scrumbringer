//// JSON presenters for capability endpoints.

import gleam/json
import scrumbringer_server/use_case/capabilities_db

pub fn capabilities(capabilities: List(capabilities_db.Capability)) -> json.Json {
  json.array(capabilities, of: capability)
}

pub fn capabilities_response(
  values: List(capabilities_db.Capability),
) -> json.Json {
  json.object([#("capabilities", capabilities(values))])
}

pub fn capability(capability: capabilities_db.Capability) -> json.Json {
  let capabilities_db.Capability(
    id: id,
    project_id: project_id,
    name: name,
    created_at: created_at,
  ) = capability

  json.object([
    #("id", json.int(id)),
    #("project_id", json.int(project_id)),
    #("name", json.string(name)),
    #("created_at", json.string(created_at)),
  ])
}

pub fn capability_response(value: capabilities_db.Capability) -> json.Json {
  json.object([#("capability", capability(value))])
}

pub fn deleted_response(capability_id: Int) -> json.Json {
  json.object([#("id", json.int(capability_id))])
}

pub fn capability_ids_response(values: List(Int)) -> json.Json {
  json.object([#("capability_ids", ids(values))])
}

pub fn user_ids_response(values: List(Int)) -> json.Json {
  json.object([#("user_ids", ids(values))])
}

pub fn ids(values: List(Int)) -> json.Json {
  json.array(values, of: json.int)
}
