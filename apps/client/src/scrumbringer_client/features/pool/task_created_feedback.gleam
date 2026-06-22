//// Feedback decision for newly created tasks.

import domain/task as domain_task

import scrumbringer_client/features/pool/available_tasks
import scrumbringer_client/features/pool/visibility.{type PoolVisibility}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/toast

pub type Config {
  Config(
    locale: Locale,
    visibility: PoolVisibility,
    work_filters: available_tasks.Config,
  )
}

pub fn view(
  config: Config,
  task: domain_task.Task,
) -> #(String, toast.ToastVariant, toast.ToastAction) {
  case is_visible(config, task) {
    True -> #(
      i18n.t(config.locale, i18n_text.TaskCreated),
      toast.Success,
      toast.ToastAction(
        label: i18n.t(config.locale, i18n_text.View),
        kind: toast.ViewTask(task.id),
      ),
    )

    False -> #(
      i18n.t(config.locale, i18n_text.TaskCreatedNotVisibleByFilters),
      toast.Info,
      toast.ToastAction(
        label: i18n.t(config.locale, i18n_text.ClearFilters),
        kind: toast.ClearPoolFilters,
      ),
    )
  }
}

fn is_visible(config: Config, task: domain_task.Task) -> Bool {
  available_tasks.matches_visibility(config.visibility, task)
  && available_tasks.matches_work_filters(config.work_filters, task)
}
