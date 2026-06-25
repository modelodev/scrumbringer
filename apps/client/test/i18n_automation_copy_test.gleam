import gleam/list
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

pub fn automation_navigation_copy_uses_engine_vocabulary_test() {
  let en_title = i18n.t(locale.En, text.AutomationEnginesProjectTitle("Core"))
  let es_title = i18n.t(locale.Es, text.AutomationEnginesProjectTitle("Core"))
  let en_rules = i18n.t(locale.En, text.RulesTitle("Release automation"))
  let es_rules = i18n.t(locale.Es, text.RulesTitle("Release automation"))
  let en_back = i18n.t(locale.En, text.BackToAutomations)
  let es_back = i18n.t(locale.Es, text.BackToAutomations)

  let assert "Engines - Core" = en_title
  let assert "Motores - Core" = es_title
  let assert "Rules - Release automation" = en_rules
  let assert "Reglas - Release automation" = es_rules
  let assert True = string.contains(en_back, "Automations")
  let assert True = string.contains(es_back, "Automatizaciones")

  [en_title, es_title, en_rules, es_rules, en_back, es_back]
  |> list.each(fn(copy) {
    let assert False = string.contains(copy, "workflow")
    let assert False = string.contains(copy, "Workflow")
  })
}

pub fn automation_task_close_copy_uses_closed_lifecycle_terms_test() {
  let en_event = i18n.t(locale.En, text.RuleBuilderTaskCompletedEvent)
  let en_preview =
    i18n.t(locale.En, text.RulePreviewTaskCompleted("a Bug task"))
  let en_trigger = i18n.t(locale.En, text.RuleTriggerTaskCompletedWord)
  let es_event = i18n.t(locale.Es, text.RuleBuilderTaskCompletedEvent)
  let es_preview =
    i18n.t(locale.Es, text.RulePreviewTaskCompleted("una tarea Bug"))
  let es_trigger = i18n.t(locale.Es, text.RuleTriggerTaskCompletedWord)

  let assert "is closed" = en_event
  let assert True = string.contains(en_preview, "is closed")
  let assert "closed" = en_trigger
  let assert "se cierra" = es_event
  let assert True = string.contains(es_preview, "se cierre")
  let assert "cerrada" = es_trigger

  [en_event, en_preview, en_trigger, es_event, es_preview, es_trigger]
  |> list.each(fn(copy) {
    let assert False = string.contains(copy, "completed")
    let assert False = string.contains(copy, "complet")
  })
}
