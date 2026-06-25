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

pub fn rule_builder_spanish_copy_uses_localized_domain_terms_test() {
  let assert "Crear trabajo desde" =
    i18n.t(locale.Es, text.RuleBuilderCreateTaskFrom)
  let assert "Alcance de automatización de tarjeta" =
    i18n.t(locale.Es, text.RuleBuilderCardScope)
  let assert "Cualquier tarjeta" = i18n.t(locale.Es, text.RuleBuilderAnyCard)
  let assert "Cualquier tipo de tarea" =
    i18n.t(locale.Es, text.RuleBuilderAnyTaskType)
  let assert "Plantilla de tarea de la regla" =
    i18n.t(locale.Es, text.RuleBuilderTaskTemplate)

  let noise_warning =
    i18n.t(locale.Es, text.RulePreviewCardActivationNoiseWarning)
  let assert False = string.contains(noise_warning, "card")
  let assert False = string.contains(noise_warning, "task")
}
