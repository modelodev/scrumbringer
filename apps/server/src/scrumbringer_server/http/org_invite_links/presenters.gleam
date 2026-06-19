//// JSON presenters for organization invite links.

import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/use_case/org_invite_links_db

pub fn links(links: List(org_invite_links_db.OrgInviteLink)) -> json.Json {
  json.array(links, of: link)
}

pub fn links_response(
  values: List(org_invite_links_db.OrgInviteLink),
) -> json.Json {
  json.object([#("invite_links", links(values))])
}

pub fn link(link: org_invite_links_db.OrgInviteLink) -> json.Json {
  let org_invite_links_db.OrgInviteLink(
    email: email,
    token: token,
    lifecycle: lifecycle,
  ) = link
  let created_at = org_invite_links_db.lifecycle_created_at(lifecycle)
  let used_at = org_invite_links_db.lifecycle_used_at(lifecycle)
  let invalidated_at = org_invite_links_db.lifecycle_invalidated_at(lifecycle)

  json.object([
    #("email", json.string(email)),
    #("token", json.string(token)),
    #("url_path", json.string(org_invite_links_db.url_path(token))),
    #(
      "state",
      json.string(org_invite_links_db.lifecycle_state_to_string(lifecycle)),
    ),
    #("created_at", json.string(created_at)),
    #("used_at", json_helpers.option_string_json(used_at)),
    #("invalidated_at", json_helpers.option_string_json(invalidated_at)),
  ])
}

pub fn link_response(value: org_invite_links_db.OrgInviteLink) -> json.Json {
  json.object([#("invite_link", link(value))])
}
