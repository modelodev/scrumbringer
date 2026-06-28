import gleam/json

import scrumbringer_client/api/activity

pub fn task_activity_url_includes_limit_and_offset_test() {
  let assert "/api/v1/tasks/42/activity?limit=30&offset=0" =
    activity.task_activity_url(42, 30, 0)
}

pub fn card_activity_url_includes_limit_and_offset_test() {
  let assert "/api/v1/cards/7/activity?limit=20&offset=40" =
    activity.card_activity_url(7, 20, 40)
}

pub fn activity_page_decoder_reads_activity_and_pagination_test() {
  let body =
    "{\"activity\":[{\"id\":1,\"project_id\":2,\"subject_type\":\"task\",\"subject_id\":42,\"kind\":\"task_claimed\",\"actor_user_id\":7,\"actor_label\":\"admin@example.com\",\"summary\":\"Task claimed\",\"related_subject_type\":null,\"related_subject_id\":null,\"created_at\":\"2026-06-22T10:30:00Z\"}],\"pagination\":{\"limit\":30,\"offset\":0,\"total\":45}}"

  let assert Ok(activity.ActivityPage(activity: events, pagination: pagination)) =
    json.parse(body, activity.activity_page_decoder())

  let assert [event] = events
  let assert "Task claimed" = event.summary
  let assert activity.Pagination(limit: 30, offset: 0, total: 45) = pagination
}
