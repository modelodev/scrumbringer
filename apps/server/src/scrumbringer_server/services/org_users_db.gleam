import gleam/list
import gleam/result
import pog
import scrumbringer_server/sql

pub type OrgUser {
  OrgUser(id: Int, email: String, org_role: String, created_at: String)
}

pub fn list_org_users(
  db: pog.Connection,
  org_id: Int,
  q: String,
) -> Result(List(OrgUser), pog.QueryError) {
  use returned <- result.try(sql.org_users_list(db, org_id, q))

  returned.rows
  |> list.map(fn(row) {
    OrgUser(
      id: row.id,
      email: row.email,
      org_role: row.org_role,
      created_at: row.created_at,
    )
  })
  |> Ok
}
