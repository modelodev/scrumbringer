import gleam/option.{None, Some}
import support/domain_fixtures

import domain/project.{type Project, Project}
import domain/remote.{Loaded, Loading}
import scrumbringer_client/features/projects/project_list

pub fn prepend_or_single_adds_to_loaded_projects_test() {
  let first = sample_project(1, "First")
  let second = sample_project(2, "Second")

  let assert True =
    project_list.prepend_or_single(Loaded([first]), second)
    == Loaded([second, first])
}

pub fn prepend_or_single_starts_loaded_list_when_not_loaded_test() {
  let project = sample_project(1, "First")

  let assert True =
    project_list.prepend_or_single(Loading, project) == Loaded([project])
}

pub fn update_name_changes_only_matching_project_test() {
  let first = sample_project(1, "First")
  let second = sample_project(2, "Second")
  let updated = sample_project(2, "Renamed")

  let assert True =
    project_list.update_name(Loaded([first, second]), updated)
    == Loaded([first, Project(..second, name: "Renamed")])
}

pub fn update_name_keeps_existing_behavior_for_not_loaded_projects_test() {
  let updated = sample_project(2, "Renamed")

  let assert Loaded([]) = project_list.update_name(Loading, updated)
}

pub fn remove_filters_deleted_project_and_preserves_missing_delete_id_test() {
  let first = sample_project(1, "First")
  let second = sample_project(2, "Second")

  let assert True =
    project_list.remove(Loaded([first, second]), Some(1)) == Loaded([second])
  let assert True =
    project_list.remove(Loaded([first, second]), None)
    == Loaded([first, second])
}

pub fn selected_after_delete_clears_only_deleted_selection_test() {
  let assert None = project_list.selected_after_delete(Some(1), Some(1))
  let assert Some(2) = project_list.selected_after_delete(Some(2), Some(1))
  let assert Some(2) = project_list.selected_after_delete(Some(2), None)
}

fn sample_project(id: Int, name: String) -> Project {
  domain_fixtures.project(id, name)
}
