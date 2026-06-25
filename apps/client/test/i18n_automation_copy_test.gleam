import gleam/string
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

pub fn template_variable_help_uses_trigger_vocabulary_test() {
  let en = i18n.t(locale.En, text.TaskTemplateVariablesHelp)
  let es = i18n.t(locale.Es, text.TaskTemplateVariablesHelp)

  let assert True = string.contains(en, "automation trigger")
  let assert True = string.contains(en, "task-triggered automations")
  let assert False = string.contains(en, "task " <> "events")
  let assert True = string.contains(es, "trigger de automatización")
  let assert False = string.contains(es, "eventos de " <> "task")
}
