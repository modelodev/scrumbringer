import gleam/option as opt
import gleam/string
import lustre/element

import domain/automation
import domain/workflow.{type Rule, type RuleTemplate, Rule, RuleTemplate}
import scrumbringer_client/features/automations/rule_sentence
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn template(name: String, id: Int) -> RuleTemplate {
  RuleTemplate(
    id: id,
    org_id: 1,
    project_id: opt.Some(7),
    name: name,
    description: opt.None,
    type_id: 5,
    type_name: "Bug",
    priority: 2,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    execution_order: 1,
  )
}

fn rule(
  trigger: automation.AutomationTrigger,
  templates: List(RuleTemplate),
) -> Rule {
  let template = case templates {
    [] -> opt.None
    [template, ..] -> opt.Some(template)
  }

  Rule(
    id: 9,
    workflow_id: 3,
    name: "Complete bug workflow",
    goal: opt.None,
    trigger: trigger,
    action: option_action(template),
    status: rule_status(template),
    created_at: "2026-01-01T00:00:00Z",
    template: template,
  )
}

fn option_action(
  template: opt.Option(RuleTemplate),
) -> opt.Option(automation.AutomationAction) {
  case template {
    opt.Some(template) -> opt.Some(automation.CreateTask(template.id))
    opt.None -> opt.None
  }
}

fn rule_status(
  template: opt.Option(RuleTemplate),
) -> automation.AutomationRuleStatus {
  case template {
    opt.Some(_) -> automation.Active
    opt.None -> automation.RequiresReview(automation.TemplateMissing)
  }
}

pub fn rule_sentence_renders_task_completed_cause_and_effect_test() {
  let html =
    rule_sentence.view(
      locale.En,
      rule(automation.TaskCompleted(opt.Some(5)), [
        template("Bug triage", 11),
      ]),
      opt.Some("Bug"),
    )
    |> element.to_document_string

  assert_contains(html, "When a Bug task is completed")
  assert_contains(html, "-&gt; Create Bug triage in the Pool")
}

pub fn rule_sentence_renders_task_created_without_available_ambiguity_test() {
  let html =
    rule_sentence.view(
      locale.En,
      rule(automation.TaskCreated(opt.None), [
        template("Follow-up", 11),
      ]),
      opt.None,
    )
    |> element.to_document_string

  assert_contains(html, "When any task is created")
}

pub fn rule_sentence_renders_task_claimed_cause_test() {
  let html =
    rule_sentence.view(
      locale.En,
      rule(automation.TaskClaimed(opt.Some(5)), [
        template("Follow-up", 11),
      ]),
      opt.Some("Bug"),
    )
    |> element.to_document_string

  assert_contains(html, "When a Bug task is claimed")
  assert_contains(html, "-&gt; Create Follow-up in the Pool")
}

pub fn rule_sentence_renders_task_released_cause_test() {
  let html =
    rule_sentence.view(
      locale.En,
      rule(automation.TaskReleased(opt.None), [
        template("Pool review", 11),
      ]),
      opt.None,
    )
    |> element.to_document_string

  assert_contains(html, "When any task is released")
  assert_contains(html, "-&gt; Create Pool review in the Pool")
}

pub fn rule_sentence_marks_missing_template_for_review_test() {
  let sentence =
    rule_sentence.effect_sentence(
      locale.En,
      rule(automation.CardClosed(automation.AnyCard), []),
    )

  let assert "Requires review: add one template" = sentence
}

pub fn rule_sentence_renders_card_activation_scope_test() {
  let html =
    rule_sentence.view(
      locale.En,
      rule(automation.CardActivated(automation.AnyCard), [
        template("Activation review", 11),
      ]),
      opt.None,
    )
    |> element.to_document_string

  assert_contains(html, "When any card is activated")
  assert_contains(html, "-&gt; Create Activation review in the Pool")
}

pub fn rule_sentence_renders_card_depth_scope_test() {
  let assert Ok(depth) = automation.card_depth_from_int(2)

  let html =
    rule_sentence.view(
      locale.En,
      rule(automation.CardClosed(automation.AtDepth(depth)), [
        template("Delivery review", 11),
      ]),
      opt.None,
    )
    |> element.to_document_string

  assert_contains(html, "When a card at level 2 is closed")
  assert_contains(html, "-&gt; Create Delivery review in the Pool")
}
