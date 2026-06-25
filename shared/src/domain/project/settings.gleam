//// Project settings used by card hierarchy execution decisions.

import gleam/int
import gleam/list
import gleam/result
import gleam/string

import domain/project.{type ProjectDepthName, ProjectDepthName}

pub opaque type HealthyPoolLimit {
  HealthyPoolLimit(Int)
}

pub type HealthyPoolLimitError {
  InvalidHealthyPoolLimit(Int)
}

pub type CardDepthNamesError {
  EmptyCardDepthNames
  NonSequentialCardDepth(depth: Int, expected: Int)
  BlankCardDepthName(depth: Int)
}

pub fn default_card_depth_names() -> List(ProjectDepthName) {
  [
    ProjectDepthName(1, "Initiative", "Initiatives"),
    ProjectDepthName(2, "Feature", "Features"),
    ProjectDepthName(3, "Task group", "Task groups"),
  ]
}

pub fn default_healthy_pool_limit() -> Int {
  20
}

pub fn normalize_card_depth_names(
  card_depth_names: List(ProjectDepthName),
) -> List(ProjectDepthName) {
  case card_depth_names {
    [] -> default_card_depth_names()
    _ -> card_depth_names
  }
}

pub fn card_depth_names_for_count(
  card_depth_names: List(ProjectDepthName),
  count: Int,
) -> List(ProjectDepthName) {
  let normalized = normalize_card_depth_names(card_depth_names)
  case count <= 0, count <= list.length(normalized) {
    True, _ -> []
    _, True -> list.take(normalized, count)
    _, False ->
      card_depth_names_for_count(
        list.append(normalized, [
          default_card_depth_name(list.length(normalized) + 1),
        ]),
        count,
      )
  }
}

pub fn default_card_depth_name(depth: Int) -> ProjectDepthName {
  case
    default_card_depth_names()
    |> list.find(fn(depth_name) {
      let ProjectDepthName(depth: candidate_depth, ..) = depth_name
      candidate_depth == depth
    })
  {
    Ok(depth_name) -> depth_name
    Error(Nil) ->
      ProjectDepthName(
        depth: depth,
        singular_name: "Level " <> int.to_string(depth),
        plural_name: "Level " <> int.to_string(depth) <> "s",
      )
  }
}

pub fn update_card_depth_name(
  card_depth_names: List(ProjectDepthName),
  target_depth: Int,
  update_depth_name: fn(ProjectDepthName) -> ProjectDepthName,
) -> List(ProjectDepthName) {
  normalize_card_depth_names(card_depth_names)
  |> list.map(fn(depth_name) {
    let ProjectDepthName(depth: depth, ..) = depth_name
    case depth == target_depth {
      True -> update_depth_name(depth_name)
      False -> depth_name
    }
  })
}

pub fn healthy_pool_limit_from_int(
  value: Int,
) -> Result(HealthyPoolLimit, HealthyPoolLimitError) {
  case value > 0 {
    True -> Ok(HealthyPoolLimit(value))
    False -> Error(InvalidHealthyPoolLimit(value))
  }
}

pub fn healthy_pool_limit_to_int(limit: HealthyPoolLimit) -> Int {
  let HealthyPoolLimit(value) = limit
  value
}

pub fn validate_card_depth_names(
  card_depth_names: List(ProjectDepthName),
) -> Result(List(ProjectDepthName), CardDepthNamesError) {
  case card_depth_names {
    [] -> Error(EmptyCardDepthNames)
    _ -> validate_card_depth_names_loop(card_depth_names, 1)
  }
}

fn validate_card_depth_names_loop(
  card_depth_names: List(ProjectDepthName),
  expected_depth: Int,
) -> Result(List(ProjectDepthName), CardDepthNamesError) {
  case card_depth_names {
    [] -> Ok([])
    [depth_name, ..rest] -> {
      let ProjectDepthName(
        depth: depth,
        singular_name: singular,
        plural_name: plural,
      ) = depth_name
      case depth == expected_depth, string.trim(singular), string.trim(plural) {
        False, _, _ ->
          Error(NonSequentialCardDepth(depth: depth, expected: expected_depth))
        _, "", _ -> Error(BlankCardDepthName(depth))
        _, _, "" -> Error(BlankCardDepthName(depth))
        True, _, _ -> {
          use validated_rest <- result.try(validate_card_depth_names_loop(
            rest,
            expected_depth + 1,
          ))
          Ok([depth_name, ..validated_rest])
        }
      }
    }
  }
}
