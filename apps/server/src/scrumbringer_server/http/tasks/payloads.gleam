//// JSON payload decoders for task HTTP endpoints.

import domain/field_update
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import scrumbringer_server/services/workflows/types as workflow_types

pub type CreateTaskPayload {
  CreateTaskPayload(
    title: String,
    description: String,
    priority: Int,
    type_id: Int,
    card_id: Option(Int),
    milestone_id: Option(Int),
  )
}

pub type UpdateTaskPayload {
  UpdateTaskPayload(version: Int, updates: workflow_types.TaskUpdates)
}

pub type VersionPayload {
  VersionPayload(version: Int)
}

pub type DependencyPayload {
  DependencyPayload(depends_on_task_id: Int)
}

pub type TaskTypePayload {
  TaskTypePayload(name: String, icon: String, capability_id: Option(Int))
}

pub type DecodeError {
  InvalidJson
}

pub fn decode_create_task(
  data: Dynamic,
) -> Result(CreateTaskPayload, DecodeError) {
  let decoder = {
    use title <- decode.field("title", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use priority <- decode.field("priority", decode.int)
    use type_id <- decode.field("type_id", decode.int)
    use card_id <- decode.optional_field(
      "card_id",
      None,
      decode.optional(decode.int),
    )
    use milestone_id <- decode.optional_field(
      "milestone_id",
      None,
      decode.optional(decode.int),
    )
    decode.success(CreateTaskPayload(
      title: title,
      description: description,
      priority: priority,
      type_id: type_id,
      card_id: normalize_optional_id(card_id),
      milestone_id: normalize_optional_id(milestone_id),
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { InvalidJson })
}

pub fn decode_update_task(
  data: Dynamic,
) -> Result(UpdateTaskPayload, DecodeError) {
  let decoder = {
    use version <- decode.field("version", decode.int)
    use title <- decode.optional_field(
      "title",
      None,
      decode.optional(decode.string),
    )
    use description <- decode.optional_field(
      "description",
      None,
      decode.optional(decode.string),
    )
    use priority <- decode.optional_field(
      "priority",
      None,
      decode.optional(decode.int),
    )
    use type_id <- decode.optional_field(
      "type_id",
      None,
      decode.optional(decode.int),
    )
    decode.success(#(version, title, description, priority, type_id))
  }

  use payload <- result.try(
    decode.run(data, decoder)
    |> result.map_error(fn(_) { InvalidJson }),
  )
  use milestone_update <- result.try(decode_milestone_update(data))
  use card_update <- result.try(decode_card_update(data))

  let #(version, title, description, priority, type_id) = payload
  Ok(UpdateTaskPayload(
    version: version,
    updates: workflow_types.TaskUpdates(
      title: field_update.from_option(title),
      description: field_update.from_option(description),
      priority: field_update.from_option(priority),
      type_id: field_update.from_option(type_id),
      milestone_id: milestone_update,
      card_id: card_update,
    ),
  ))
}

pub fn decode_version(data: Dynamic) -> Result(VersionPayload, DecodeError) {
  let decoder = {
    use version <- decode.field("version", decode.int)
    decode.success(VersionPayload(version: version))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { InvalidJson })
}

pub fn decode_dependency(
  data: Dynamic,
) -> Result(DependencyPayload, DecodeError) {
  let decoder = {
    use depends_on_task_id <- decode.field("depends_on_task_id", decode.int)
    decode.success(DependencyPayload(depends_on_task_id: depends_on_task_id))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { InvalidJson })
}

pub fn decode_task_type(data: Dynamic) -> Result(TaskTypePayload, DecodeError) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use icon <- decode.field("icon", decode.string)
    use capability_id <- decode.optional_field("capability_id", 0, decode.int)
    decode.success(#(name, icon, capability_id))
  }

  use payload <- result.try(
    decode.run(data, decoder)
    |> result.map_error(fn(_) { InvalidJson }),
  )
  let #(name, icon, capability_id) = payload

  Ok(
    TaskTypePayload(name: name, icon: icon, capability_id: case capability_id {
      0 -> None
      id -> Some(id)
    }),
  )
}

fn decode_milestone_update(
  data: Dynamic,
) -> Result(field_update.FieldUpdate(Option(Int)), DecodeError) {
  decode_optional_id_update(data, "milestone_id")
  |> result.map(fn(update) { field_update.map(update, normalize_milestone_id) })
}

fn decode_card_update(
  data: Dynamic,
) -> Result(field_update.FieldUpdate(Option(Int)), DecodeError) {
  decode_optional_id_update(data, "card_id")
  |> result.map(fn(update) { field_update.map(update, normalize_optional_id) })
}

fn decode_optional_id_update(
  data: Dynamic,
  field_name: String,
) -> Result(field_update.FieldUpdate(Option(Int)), DecodeError) {
  case
    decode.run(data, decode.field(field_name, decode.dynamic, decode.success))
  {
    Error(_) -> Ok(field_update.unchanged())
    Ok(raw) ->
      decode.run(raw, decode.optional(decode.int))
      |> result.map(normalize_optional_id)
      |> result.map(field_update.set)
      |> result.map_error(fn(_) { InvalidJson })
  }
}

fn normalize_milestone_id(value: Option(Int)) -> Option(Int) {
  normalize_optional_id(value)
}

fn normalize_optional_id(value: Option(Int)) -> Option(Int) {
  case value {
    Some(id) if id <= 0 -> None
    _ -> value
  }
}
