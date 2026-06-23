//// Human-readable automation rule sentence.
////
//// Receives typed workflow/automation domain data and renders the cause/effect
//// phrase used by the automations console. It does not decide permissions or
//// trigger actions.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import domain/automation
import domain/workflow
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/ui/badge

pub fn view(
  locale: Locale,
  rule: workflow.Rule,
  task_type_name: opt.Option(String),
) -> Element(msg) {
  div([attribute.class("automation-rule-sentence")], [
    span([attribute.class("automation-rule-sentence__when")], [
      text(trigger_sentence(locale, rule, task_type_name)),
    ]),
    span([attribute.class("automation-rule-sentence__effect")], [
      text(effect_sentence(locale, rule)),
    ]),
  ])
}

pub fn trigger_sentence(
  locale: Locale,
  rule: workflow.Rule,
  task_type_name: opt.Option(String),
) -> String {
  case workflow.rule_target_to_automation_trigger(rule.target) {
    Ok(trigger) -> supported_trigger_sentence(locale, trigger, task_type_name)
    Error(workflow.AmbiguousTaskAvailableTrigger) ->
      needs_review_sentence(
        locale,
        en: "choose TaskCreated or TaskReleased",
        es: "elige TaskCreated o TaskReleased",
      )
    Error(workflow.UnsupportedCardDraftTrigger) ->
      needs_review_sentence(
        locale,
        en: "draft cards are not automation triggers",
        es: "las cards draft no son triggers de automatizacion",
      )
  }
}

pub fn effect_sentence(locale: Locale, rule: workflow.Rule) -> String {
  case rule.template {
    opt.None ->
      needs_review_sentence(
        locale,
        en: "add one template",
        es: "anade una plantilla",
      )
    opt.Some(template) ->
      case locale {
        En -> "-> Create " <> template.name <> " in the Pool"
        Es -> "-> Crear " <> template.name <> " en el Pool"
      }
  }
}

pub fn status_badge(locale: Locale, rule: workflow.Rule) -> Element(msg) {
  case workflow.rule_target_to_automation_trigger(rule.target), rule.template {
    Ok(_), opt.Some(_) ->
      badge.new_unchecked(active_label(locale), badge.Success)
      |> badge.view_with_class("automation-rule-sentence__badge")
    _, _ ->
      badge.new_unchecked(review_label(locale), badge.Warning)
      |> badge.view_with_class("automation-rule-sentence__badge")
  }
}

fn supported_trigger_sentence(
  locale: Locale,
  trigger: automation.AutomationTrigger,
  task_type_name: opt.Option(String),
) -> String {
  case trigger {
    automation.TaskClaimed(_) ->
      task_trigger_sentence(locale, task_type_name, "claimed", "reclamada")
    automation.TaskCompleted(_) ->
      task_trigger_sentence(locale, task_type_name, "completed", "completada")
    automation.TaskCreated(_) ->
      task_trigger_sentence(locale, task_type_name, "created", "creada")
    automation.TaskReleased(_) ->
      task_trigger_sentence(locale, task_type_name, "released", "liberada")
    automation.CardActivated(_) ->
      case locale {
        En -> "When any card is activated"
        Es -> "Cuando cualquier card se active"
      }
    automation.CardClosed(_) ->
      case locale {
        En -> "When any card is closed"
        Es -> "Cuando cualquier card se cierre"
      }
  }
}

fn task_trigger_sentence(
  locale: Locale,
  task_type_name: opt.Option(String),
  en_event: String,
  es_event: String,
) -> String {
  let type_label = case task_type_name {
    opt.Some(name) -> name
    opt.None ->
      case locale {
        En -> "any"
        Es -> "cualquier"
      }
  }

  case locale {
    En -> "When a " <> type_label <> " task is " <> en_event
    Es -> "Cuando una task " <> type_label <> " sea " <> es_event
  }
}

fn needs_review_sentence(locale: Locale, en en: String, es es: String) -> String {
  case locale {
    En -> "Requires review: " <> en
    Es -> "Requiere revision: " <> es
  }
}

fn active_label(locale: Locale) -> String {
  case locale {
    En -> "Active"
    Es -> "Activa"
  }
}

fn review_label(locale: Locale) -> String {
  case locale {
    En -> "Requires review"
    Es -> "Requiere revision"
  }
}
