# Refactor Backlog (Global)

This backlog lists top refactor targets based on function length (>100 lines) and module scope. It complements `docs/refactor-plan.md` and should be used to sequence work.

## Client Targets (by size)
- `apps/client/src/scrumbringer_client.gleam::update` (2782 lines)
- `apps/client/src/scrumbringer_client/i18n/es.gleam::translate` (299 lines)
- `apps/client/src/scrumbringer_client/i18n/en.gleam::translate` (294 lines)
- `apps/client/src/scrumbringer_client.gleam::rect_contains_point` (283 lines)
- `apps/client/src/scrumbringer_client.gleam::hydrate_model` (259 lines)
- `apps/client/src/scrumbringer_client.gleam::view_metrics` (220 lines)
- `apps/client/src/scrumbringer_client.gleam::init` (208 lines)
- `apps/client/src/scrumbringer_client.gleam::view_member_task_card` (204 lines)
- `apps/client/src/scrumbringer_client.gleam::view_member_filters` (173 lines)
- `apps/client/src/scrumbringer_client/hydration.gleam::plan` (159 lines)
- `apps/client/src/scrumbringer_client.gleam::view_member_bar_task_row` (131 lines)
- `apps/client/src/scrumbringer_client/api.gleam::task_status_to_string` (131 lines)
- `apps/client/src/scrumbringer_client/styles.gleam::base_css` (122 lines)
- `apps/client/src/scrumbringer_client.gleam::member_refresh` (104 lines)

## Server Targets (by size)
- `apps/server/src/scrumbringer_server/sql.gleam::metrics_project_tasks` (149 lines) [Generated]
- `apps/server/src/scrumbringer_server/sql.gleam::tasks_list` (135 lines) [Generated]
- `apps/server/src/scrumbringer_server/sql.gleam::tasks_create` (133 lines) [Generated]
- `apps/server/src/scrumbringer_server/http/org_metrics.gleam::overview_as_admin` (127 lines)
- `apps/server/src/scrumbringer_server/sql.gleam::tasks_get_for_user` (126 lines) [Generated]
- `apps/server/src/scrumbringer_server/http/tasks.gleam::handle_task_patch` (122 lines)
- `apps/server/src/scrumbringer_server/sql.gleam::tasks_complete` (122 lines) [Generated]
- `apps/server/src/scrumbringer_server/sql.gleam::tasks_release` (122 lines) [Generated]
- `apps/server/src/scrumbringer_server/sql.gleam::tasks_claim` (121 lines) [Generated]
- `apps/server/src/scrumbringer_server/http/tasks.gleam::handle_tasks_create` (115 lines)
- `apps/server/src/scrumbringer_server/http/password_resets.gleam::handle_consume_post` (113 lines)
- `apps/server/src/scrumbringer_server/sql.gleam::tasks_update` (113 lines) [Generated]

## Notes
- `sql.gleam` is generated; refactor via generator or by wrapping in smaller service helpers.
- `scrumbringer_client.gleam` is the primary monolith and should be split first in Phase 2.
- `i18n/en|es.gleam::translate` are large because of exhaustive mapping; consider splitting by domain or using data maps.
