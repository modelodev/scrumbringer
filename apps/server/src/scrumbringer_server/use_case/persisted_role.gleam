//// Helpers for validating role values read from repository.

import domain/org_role.{type OrgRole}
import domain/project_role.{type ProjectRole}
import gleam/option.{type Option, None, Some}
import pog
import scrumbringer_server/use_case/service_error.{type ServiceError, Unexpected}

pub fn org_role(value: String) -> Result(OrgRole, pog.QueryError) {
  case org_role.parse(value) {
    Ok(role) -> Ok(role)
    Error(_) -> Error(invalid_role_error("Invalid org role: " <> value))
  }
}

pub fn project_role(value: String) -> Result(ProjectRole, pog.QueryError) {
  case project_role.parse(value) {
    Ok(role) -> Ok(role)
    Error(_) -> Error(invalid_role_error("Invalid project role: " <> value))
  }
}

pub fn org_role_service_error(
  value: String,
  message: String,
) -> Result(OrgRole, ServiceError) {
  case org_role.parse(value) {
    Ok(role) -> Ok(role)
    Error(_) -> Error(Unexpected(message <> ": " <> value))
  }
}

pub fn optional_project_role_service_error(
  value: String,
  message: String,
) -> Result(Option(ProjectRole), ServiceError) {
  case value {
    "" -> Ok(None)
    other ->
      case project_role.parse(other) {
        Ok(role) -> Ok(Some(role))
        Error(_) -> Error(Unexpected(message <> ": " <> other))
      }
  }
}

fn invalid_role_error(message: String) -> pog.QueryError {
  pog.PostgresqlError(
    code: "INVALID_ROLE",
    name: "invalid_role",
    message: message,
  )
}
