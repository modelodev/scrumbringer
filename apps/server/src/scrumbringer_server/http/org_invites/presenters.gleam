//// JSON presenters for organization invites.

import gleam/json
import scrumbringer_server/services/org_invites_db

pub fn invite(invite: org_invites_db.OrgInvite) -> json.Json {
  let org_invites_db.OrgInvite(
    code: code,
    created_at: created_at,
    expires_at: expires_at,
  ) = invite

  json.object([
    #("code", json.string(code)),
    #("created_at", json.string(created_at)),
    #("expires_at", json.string(expires_at)),
  ])
}

pub fn invite_response(value: org_invites_db.OrgInvite) -> json.Json {
  json.object([#("invite", invite(value))])
}
