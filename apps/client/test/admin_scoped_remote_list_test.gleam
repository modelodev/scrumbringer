import gleam/option as opt

import domain/remote.{Loaded, Loading}
import scrumbringer_client/features/admin/scoped_remote_list

pub fn prepend_for_scope_updates_project_when_project_id_exists_test() {
  let org = Loaded([#(1, "Org")])
  let project = Loaded([#(2, "Project")])

  let #(next_org, next_project) =
    scoped_remote_list.prepend_for_scope(org, project, opt.Some(7), #(
      3,
      "Created",
    ))

  let assert Loaded([#(1, "Org")]) = next_org
  let assert Loaded([#(3, "Created"), #(2, "Project")]) = next_project
}

pub fn prepend_for_scope_updates_org_when_project_id_is_absent_test() {
  let org = Loaded([#(1, "Org")])
  let project = Loaded([#(2, "Project")])

  let #(next_org, next_project) =
    scoped_remote_list.prepend_for_scope(org, project, opt.None, #(3, "Created"))

  let assert Loaded([#(3, "Created"), #(1, "Org")]) = next_org
  let assert Loaded([#(2, "Project")]) = next_project
}

pub fn replace_by_id_replaces_loaded_item_and_preserves_other_states_test() {
  let loaded = Loaded([#(1, "Old"), #(2, "Kept")])

  let assert Loaded([#(1, "Updated"), #(2, "Kept")]) =
    scoped_remote_list.replace_by_id(loaded, #(1, "Updated"), first)
  let assert Loading =
    scoped_remote_list.replace_by_id(Loading, #(1, "Updated"), first)
}

pub fn remove_by_id_removes_loaded_item_and_preserves_other_states_test() {
  let loaded = Loaded([#(1, "Deleted"), #(2, "Kept")])

  let assert Loaded([#(2, "Kept")]) =
    scoped_remote_list.remove_by_id(loaded, 1, first)
  let assert Loading = scoped_remote_list.remove_by_id(Loading, 1, first)
}

fn first(item: #(Int, String)) -> Int {
  let #(id, _) = item
  id
}
