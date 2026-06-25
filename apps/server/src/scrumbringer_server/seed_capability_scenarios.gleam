//// Capability seed scenarios.
////
//// Creates project capabilities, task types linked to those capabilities, and
//// member capability assignments for people/capability validation surfaces.

import gleam/list
import gleam/option.{Some}
import gleam/result
import pog
import scrumbringer_server/seed_db
import scrumbringer_server/seed_pools

pub type Context {
  Context(
    active_project_ids: List(Int),
    project_member_ids: List(#(Int, List(Int))),
  )
}

pub type CapabilityResult {
  CapabilityResult(
    capability_ids: List(#(Int, Int, Int, Int)),
    task_type_ids: List(#(Int, Int, Int, Int)),
  )
}

pub fn build(
  db: pog.Connection,
  context: Context,
) -> Result(CapabilityResult, String) {
  use capability_ids <- result.try(build_capabilities(db, context))
  use task_type_ids <- result.try(build_task_types(db, capability_ids))
  use _ <- result.try(build_member_capabilities(db, context, capability_ids))

  Ok(CapabilityResult(
    capability_ids: capability_ids,
    task_type_ids: task_type_ids,
  ))
}

fn build_capabilities(
  db: pog.Connection,
  context: Context,
) -> Result(List(#(Int, Int, Int, Int)), String) {
  let names = seed_pools.capability_names()

  list.index_map(context.active_project_ids, fn(project_id, proj_idx) {
    let bug_name = list_at(names, proj_idx, "Engineering")
    let feature_name = list_at(names, proj_idx + 1, "Product")
    let task_name = list_at(names, proj_idx + 2, "Operations")

    use bug_cap <- result.try(seed_db.insert_capability(
      db,
      project_id,
      bug_name,
    ))
    use feature_cap <- result.try(seed_db.insert_capability(
      db,
      project_id,
      feature_name,
    ))
    use task_cap <- result.try(seed_db.insert_capability(
      db,
      project_id,
      task_name,
    ))
    Ok(#(project_id, bug_cap, feature_cap, task_cap))
  })
  |> result.all
}

fn build_task_types(
  db: pog.Connection,
  capability_ids: List(#(Int, Int, Int, Int)),
) -> Result(List(#(Int, Int, Int, Int)), String) {
  list.try_map(capability_ids, fn(caps) {
    let #(project_id, bug_cap, feature_cap, task_cap) = caps
    use bug_id <- result.try(seed_db.insert_task_type_with_capability(
      db,
      project_id,
      "Bug",
      "bug-ant",
      Some(bug_cap),
    ))
    use feature_id <- result.try(seed_db.insert_task_type_with_capability(
      db,
      project_id,
      "Feature",
      "sparkles",
      Some(feature_cap),
    ))
    use task_id <- result.try(seed_db.insert_task_type_with_capability(
      db,
      project_id,
      "Task",
      "clipboard-document-check",
      Some(task_cap),
    ))
    Ok(#(project_id, bug_id, feature_id, task_id))
  })
}

fn build_member_capabilities(
  db: pog.Connection,
  context: Context,
  capability_ids: List(#(Int, Int, Int, Int)),
) -> Result(Nil, String) {
  use _ <- result.try(
    list.try_map(capability_ids, fn(caps) {
      let #(project_id, bug_cap, feature_cap, task_cap) = caps
      let members = members_for_project(context.project_member_ids, project_id)

      case members {
        [] -> Ok(Nil)
        _ ->
          list.index_map(members, fn(user_id, idx) {
            let cap_id = case idx % 3 {
              0 -> bug_cap
              1 -> feature_cap
              _ -> task_cap
            }
            seed_db.insert_project_member_capability(
              db,
              project_id,
              user_id,
              cap_id,
            )
          })
          |> result.all
          |> result.map(fn(_) { Nil })
      }
    }),
  )

  Ok(Nil)
}

fn members_for_project(
  project_member_ids: List(#(Int, List(Int))),
  project_id: Int,
) -> List(Int) {
  case
    list.find(project_member_ids, fn(pair) {
      let #(pid, _members) = pair
      pid == project_id
    })
  {
    Ok(#(_pid, members)) -> members
    Error(_) -> []
  }
}

fn list_at(items: List(String), idx: Int, default: String) -> String {
  list_at_helper(items, idx, default)
}

fn list_at_helper(items: List(a), idx: Int, default: a) -> a {
  case idx, items {
    _, [] -> default
    0, [first, ..] -> first
    n, [_, ..rest] -> list_at_helper(rest, n - 1, default)
  }
}
