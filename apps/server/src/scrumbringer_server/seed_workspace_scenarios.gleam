//// Workspace seed scenarios.
////
//// Creates users, validation projects, memberships, empty-project coverage, and
//// healthy/stress pool settings used by product validation.

import domain/org_role
import domain/project_role
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_db
import scrumbringer_server/seed_pools

pub type Context {
  Context(
    org_id: Int,
    admin_id: Int,
    user_count: Int,
    inactive_user_count: Int,
    project_count: Int,
    empty_project_count: Int,
    date_range_days: Int,
  )
}

pub type WorkspaceResult {
  WorkspaceResult(
    user_ids: List(Int),
    project_ids: List(Int),
    empty_project_ids: List(Int),
    project_member_ids: List(#(Int, List(Int))),
  )
}

pub fn build(
  db: pog.Connection,
  context: Context,
) -> Result(WorkspaceResult, String) {
  use user_ids <- result.try(build_users(db, context))
  build_projects(db, context, user_ids)
}

fn build_users(
  db: pog.Connection,
  context: Context,
) -> Result(List(Int), String) {
  let emails = list.take(seed_pools.user_emails(), context.user_count - 1)
  let active_count = context.user_count - 1 - context.inactive_user_count

  use user_ids <- result.try(
    list.index_map(emails, fn(email, idx) {
      let first_login = case idx < active_count {
        True -> Some(days_ago_timestamp(context.date_range_days / 2))
        False -> None
      }
      seed_db.insert_user(
        db,
        seed_db.UserInsertOptions(
          org_id: context.org_id,
          email: email,
          org_role: org_role.Member,
          first_login_at: first_login,
          created_at: Some(days_ago_timestamp(context.date_range_days)),
        ),
      )
    })
    |> result.all,
  )

  Ok([context.admin_id, ..user_ids])
}

fn build_projects(
  db: pog.Connection,
  context: Context,
  user_ids: List(Int),
) -> Result(WorkspaceResult, String) {
  use default_project_id <- result.try(seed_db.project_id_by_name(
    db,
    context.org_id,
    "Default",
  ))
  let project_names = [
    "Healthy Validation Project",
    "Stress Validation Project",
    "Project Gamma",
  ]
  let names = list.take(project_names, context.project_count)
  let empty_start = int.max(0, list.length(names) - context.empty_project_count)
  let assignable_users = list.drop(user_ids, 1)
  let default_project_members = [context.admin_id, ..assignable_users]

  use _ <- result.try(
    list.try_map(default_project_members, fn(user_id) {
      let role = case user_id == context.admin_id {
        True -> project_role.Manager
        False -> project_role.Member
      }
      seed_db.insert_member(db, default_project_id, user_id, role)
    }),
  )

  use project_results <- result.try(
    list.index_map(names, fn(name, idx) {
      let is_empty = idx >= empty_start
      let days_ago = context.date_range_days - { idx * 5 }
      use project_id <- result.try(seed_db.insert_project(
        db,
        context.org_id,
        name,
        Some(days_ago_timestamp(days_ago)),
      ))

      case is_empty {
        True -> Ok(#(project_id, True))
        False -> {
          use _ <- result.try(seed_db.insert_member(
            db,
            project_id,
            context.admin_id,
            project_role.Manager,
          ))

          use _ <- result.try(
            list.try_map(assignable_users, fn(user_id) {
              seed_db.insert_member(
                db,
                project_id,
                user_id,
                project_role.Member,
              )
            }),
          )

          Ok(#(project_id, False))
        }
      }
    })
    |> result.all,
  )

  let project_ids = [
    default_project_id,
    ..list.map(project_results, fn(pair) {
      let #(id, _) = pair
      id
    })
  ]

  use _ <- result.try(
    list.index_map(project_ids, fn(project_id, idx) {
      seed_db.upsert_project_settings(
        db,
        project_id,
        seeded_healthy_pool_limit(idx),
      )
    })
    |> result.all,
  )

  let empty_project_ids = empty_project_ids_from(project_results)
  let project_member_ids =
    list.map(project_ids, fn(project_id) {
      case project_id == default_project_id {
        True -> #(project_id, default_project_members)
        False ->
          case list.contains(empty_project_ids, project_id) {
            True -> #(project_id, [])
            False -> #(project_id, [context.admin_id, ..assignable_users])
          }
      }
    })

  Ok(WorkspaceResult(
    user_ids: user_ids,
    project_ids: project_ids,
    empty_project_ids: empty_project_ids,
    project_member_ids: project_member_ids,
  ))
}

fn empty_project_ids_from(project_results: List(#(Int, Bool))) -> List(Int) {
  project_results
  |> list.fold([], fn(acc, pair) {
    let #(id, is_empty) = pair
    case is_empty {
      True -> [id, ..acc]
      False -> acc
    }
  })
  |> list.reverse
}

fn seeded_healthy_pool_limit(project_index: Int) -> Int {
  case project_index {
    1 -> 40
    2 -> 6
    _ -> 20
  }
}

fn days_ago_timestamp(days: Int) -> String {
  "NOW() - INTERVAL '" <> int.to_string(days) <> " days'"
}
