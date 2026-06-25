//// Project settings used by card hierarchy execution decisions.

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

pub fn healthy_pool_limit_from_int(
  value: Int,
) -> Result(HealthyPoolLimit, HealthyPoolLimitError) {
  case value > 0 {
    True -> Ok(HealthyPoolLimit(value))
    False -> Error(InvalidHealthyPoolLimit(value))
  }
}

pub fn healthy_pool_limit_unchecked(value: Int) -> HealthyPoolLimit {
  HealthyPoolLimit(value)
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

pub fn valid_card_depth_names(card_depth_names: List(ProjectDepthName)) -> Bool {
  case validate_card_depth_names(card_depth_names) {
    Ok(_) -> True
    Error(_) -> False
  }
}

pub fn valid_project_settings(
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
) -> Bool {
  case healthy_pool_limit_from_int(healthy_pool_limit) {
    Error(_) -> False
    Ok(_) -> valid_card_depth_names(card_depth_names)
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
