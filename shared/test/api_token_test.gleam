import domain/api_token
import gleam/option.{None, Some}

pub fn project_grant_from_option_maps_none_to_all_projects_test() {
  let assert api_token.AllProjects = api_token.project_grant_from_option(None)
}

pub fn project_grant_from_option_maps_project_id_to_project_only_test() {
  let assert api_token.ProjectOnly(7) =
    api_token.project_grant_from_option(Some(7))
}

pub fn project_grant_to_option_maps_all_projects_to_none_test() {
  let assert None = api_token.project_grant_to_option(api_token.AllProjects)
}

pub fn project_grant_to_option_maps_project_only_to_project_id_test() {
  let assert Some(7) =
    api_token.project_grant_to_option(api_token.ProjectOnly(7))
}
