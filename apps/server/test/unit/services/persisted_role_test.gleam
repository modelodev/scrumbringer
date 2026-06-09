import gleam/option
import scrumbringer_server/services/persisted_role
import scrumbringer_server/services/service_error

pub fn org_role_service_error_includes_invalid_value_test() {
  let assert Error(service_error.Unexpected("Invalid persisted org role: owner")) =
    persisted_role.org_role_service_error("owner", "Invalid persisted org role")
}

pub fn optional_project_role_service_error_keeps_blank_as_absent_test() {
  let assert Ok(option.None) =
    persisted_role.optional_project_role_service_error(
      "",
      "Invalid persisted project role",
    )
}

pub fn optional_project_role_service_error_includes_invalid_value_test() {
  let assert Error(service_error.Unexpected(
    "Invalid persisted project role: owner",
  )) =
    persisted_role.optional_project_role_service_error(
      "owner",
      "Invalid persisted project role",
    )
}
