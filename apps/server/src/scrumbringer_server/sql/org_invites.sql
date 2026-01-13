-- name: create_org_invite
-- Insert a new org invite and return the API-facing fields.
insert into org_invites (code, org_id, created_by, expires_at)
values ($1, $2, $3, now() + (($4::int) * interval '1 hour'))
returning
  code,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  to_char(expires_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as expires_at;
