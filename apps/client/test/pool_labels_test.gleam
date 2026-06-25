import scrumbringer_client/features/pool/labels
import scrumbringer_client/i18n/locale

pub fn pool_labels_translate_task_actions_without_root_model_test() {
  let assert "Claim" = labels.claim(locale.En)
  let assert "Release" = labels.release(locale.En)
  let assert "Drag" = labels.drag(locale.En)
}

pub fn pool_labels_translate_hover_labels_without_root_model_test() {
  let assert "Card" = labels.parent_card(locale.En)
  let assert "Age" = labels.age(locale.En)
  let assert "Description" = labels.description(locale.En)
  let assert "Open task" = labels.open_task(locale.En)
  let assert "Recent notes" = labels.recent_notes(locale.En)
}

pub fn pool_labels_translate_parameterized_labels_without_root_model_test() {
  let assert "Blocked by 2 tasks" = labels.blocked_by_tasks(locale.En, 2)
  let assert "You" = labels.current_user(locale.En)
  let assert "User #7" = labels.user_number(locale.En, 7)
}
