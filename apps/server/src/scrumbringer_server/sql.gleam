//// This module contains the code to run the sql queries defined in
//// `./src/scrumbringer_server/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import pog

/// A row you get from running the `org_invites` query
/// defined in `./src/scrumbringer_server/sql/org_invites.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInvitesRow {
  OrgInvitesRow(code: String, created_at: String, expires_at: String)
}

/// name: create_org_invite
/// Insert a new org invite and return the API-facing fields.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invites(
  db: pog.Connection,
  arg_1: String,
  arg_2: Int,
  arg_3: Int,
  arg_4: Int,
) -> Result(pog.Returned(OrgInvitesRow), pog.QueryError) {
  let decoder = {
    use code <- decode.field(0, decode.string)
    use created_at <- decode.field(1, decode.string)
    use expires_at <- decode.field(2, decode.string)
    decode.success(OrgInvitesRow(code:, created_at:, expires_at:))
  }

  "-- name: create_org_invite
-- Insert a new org invite and return the API-facing fields.
insert into org_invites (code, org_id, created_by, expires_at)
values ($1, $2, $3, now() + (($4::int) * interval '1 hour'))
returning
  code,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  to_char(expires_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as expires_at;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `ping` query
/// defined in `./src/scrumbringer_server/sql/ping.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PingRow {
  PingRow(ok: Int)
}

/// Simple query used to verify Squirrel generation
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn ping(
  db: pog.Connection,
) -> Result(pog.Returned(PingRow), pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.int)
    decode.success(PingRow(ok:))
  }

  "-- Simple query used to verify Squirrel generation
select 1 as ok;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}
