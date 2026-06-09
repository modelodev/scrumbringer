import domain/milestone.{Active, Completed, Ready}
import domain/task_status.{
  Available, Claimed, Completed as TaskCompleted, Ongoing,
}
import scrumbringer_client/features/milestones/labels
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/badge

pub fn milestones_labels_translate_milestone_states_without_root_model_test() {
  let assert "Ready" = labels.milestone_state_label(locale.En, Ready)
  let assert "Activo" = labels.milestone_state_label(locale.Es, Active)
  let assert "Completed" = labels.milestone_state_label(locale.En, Completed)
}

pub fn milestones_labels_map_milestone_state_variants_test() {
  let assert True = labels.milestone_state_variant(Ready) == badge.Warning
  let assert True = labels.milestone_state_variant(Active) == badge.Primary
  let assert True = labels.milestone_state_variant(Completed) == badge.Success
}

pub fn milestones_labels_translate_task_status_without_root_model_test() {
  let assert "available" = labels.task_status_to_short(locale.En, Available)
  let assert "reclamada" =
    labels.task_status_to_short(locale.Es, Claimed(Ongoing))
  let assert "completed" = labels.task_status_to_short(locale.En, TaskCompleted)
}
