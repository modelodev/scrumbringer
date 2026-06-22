import scrumbringer_client/api/activity

pub fn task_activity_url_includes_limit_and_offset_test() {
  let assert "/api/v1/tasks/42/activity?limit=30&offset=0" =
    activity.task_activity_url(42, 30, 0)
}

pub fn card_activity_url_includes_limit_and_offset_test() {
  let assert "/api/v1/cards/7/activity?limit=20&offset=40" =
    activity.card_activity_url(7, 20, 40)
}
