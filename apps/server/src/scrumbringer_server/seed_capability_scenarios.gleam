//// Capability seed scenarios.
////
//// Creates project capabilities, task types linked to those capabilities, and
//// member capability assignments for people/capability validation surfaces.

import gleam/int
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
    capability_ids: List(#(Int, List(Int))),
    task_type_ids: List(#(Int, List(Int))),
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
) -> Result(List(#(Int, List(Int))), String) {
  let names = seed_pools.capability_names()

  list.index_map(context.active_project_ids, fn(project_id, proj_idx) {
    use capability_ids <- result.try(
      list.range(0, 5)
      |> list.try_map(fn(idx) {
        seed_db.insert_capability(
          db,
          project_id,
          seed_pools.list_at(
            names,
            proj_idx + idx,
            "Capability " <> int.to_string(idx + 1),
          ),
        )
      }),
    )

    Ok(#(project_id, capability_ids))
  })
  |> result.all
}

fn build_task_types(
  db: pog.Connection,
  capability_ids: List(#(Int, List(Int))),
) -> Result(List(#(Int, List(Int))), String) {
  list.try_map(capability_ids, fn(caps) {
    let #(project_id, caps_for_project) = caps
    use task_type_ids <- result.try(
      task_type_definitions()
      |> list.index_map(fn(definition, idx) {
        let #(name, icon) = definition
        seed_db.insert_task_type_with_capability(
          db,
          project_id,
          name,
          icon,
          Some(seed_pools.list_at(caps_for_project, idx, 0)),
        )
      })
      |> result.all,
    )

    Ok(#(project_id, task_type_ids))
  })
}

fn build_member_capabilities(
  db: pog.Connection,
  context: Context,
  capability_ids: List(#(Int, List(Int))),
) -> Result(Nil, String) {
  use _ <- result.try(
    list.try_map(capability_ids, fn(caps) {
      let #(project_id, caps_for_project) = caps
      let members = members_for_project(context.project_member_ids, project_id)

      case members {
        [] -> Ok(Nil)
        _ ->
          list.index_map(members, fn(user_id, idx) {
            let cap_id =
              seed_pools.list_at(
                caps_for_project,
                idx % list.length(caps_for_project),
                0,
              )
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

fn task_type_definitions() -> List(#(String, String)) {
  [
    #("Requirement", "clipboard-document-check"),
    #("UX/UI Design", "pencil-square"),
    #("Markup", "globe-alt"),
    #("Frontend", "code-bracket"),
    #("Backend", "server"),
    #("QA", "check-circle"),
  ]
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
