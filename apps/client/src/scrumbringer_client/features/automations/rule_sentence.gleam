//// Human-readable automation rule sentence.
////
//// Receives typed workflow/automation domain data and renders the cause/effect
//// phrase used by the automations console. It does not decide permissions or
//// trigger actions.

import gleam/int
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
  supported_trigger_sentence(locale, rule.trigger, task_type_name)
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
  case rule.status, rule.template {
    automation.Active, opt.Some(_) ->
      badge.new_unchecked(active_label(locale), badge.Success)
      |> badge.view_with_class("automation-rule-sentence__badge")
    automation.Paused, opt.Some(_) ->
      badge.new_unchecked(paused_label(locale), badge.Neutral)
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
    automation.CardActivated(scope) ->
      case locale {
        En -> "When " <> card_scope_sentence_en(scope) <> " is activated"
        Es -> "Cuando " <> card_scope_sentence_es(scope) <> " se active"
      }
    automation.CardClosed(scope) ->
      case locale {
        En -> "When " <> card_scope_sentence_en(scope) <> " is closed"
        Es -> "Cuando " <> card_scope_sentence_es(scope) <> " se cierre"
      }
  }
}

fn card_scope_sentence_en(scope: automation.CardAutomationScope) -> String {
  case scope {
    automation.AnyCard -> "any card"
    automation.AtDepth(depth) ->
      "a card at level " <> int.to_string(automation.card_depth_to_int(depth))
  }
}

fn card_scope_sentence_es(scope: automation.CardAutomationScope) -> String {
  case scope {
    automation.AnyCard -> "cualquier card"
    automation.AtDepth(depth) ->
      "una card de nivel " <> int.to_string(automation.card_depth_to_int(depth))
  }
}

fn task_trigger_sentence(
  locale: Locale,
  task_type_name: opt.Option(String),
  en_event: String,
  es_event: String,
) -> String {
  case locale, task_type_name {
    En, opt.Some(name) -> "When a " <> name <> " task is " <> en_event
    En, opt.None -> "When any task is " <> en_event
    Es, opt.Some(name) -> "Cuando una task " <> name <> " sea " <> es_event
    Es, opt.None -> "Cuando cualquier task sea " <> es_event
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

fn paused_label(locale: Locale) -> String {
  case locale {
    En -> "Paused"
    Es -> "Pausada"
  }
}
