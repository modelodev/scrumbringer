import gleam/option.{None, Some}
import scrumbringer_server/use_case/rule_metrics_db
import support/assertions as expect

pub fn applied_execution_outcome_ignores_empty_suppression_reason_test() {
  let outcome = rule_metrics_db.rule_execution_outcome_from_db("applied", "")

  let assert rule_metrics_db.AppliedRuleExecution = outcome
  outcome
  |> rule_metrics_db.rule_execution_outcome_name
  |> expect.equal("applied")
  outcome
  |> rule_metrics_db.rule_execution_suppression_reason_name
  |> expect.equal(None)
}

pub fn suppressed_execution_outcome_keeps_known_reason_test() {
  let outcome =
    rule_metrics_db.rule_execution_outcome_from_db("suppressed", "idempotent")

  let assert rule_metrics_db.SuppressedRuleExecution(Some(
    rule_metrics_db.IdempotentSuppression,
  )) = outcome
  outcome
  |> rule_metrics_db.rule_execution_outcome_name
  |> expect.equal("suppressed")
  outcome
  |> rule_metrics_db.rule_execution_suppression_reason_name
  |> expect.equal(Some("idempotent"))
}

pub fn suppressed_execution_outcome_allows_missing_reason_test() {
  let outcome = rule_metrics_db.rule_execution_outcome_from_db("suppressed", "")

  let assert rule_metrics_db.SuppressedRuleExecution(None) = outcome
  outcome
  |> rule_metrics_db.rule_execution_outcome_name
  |> expect.equal("suppressed")
  outcome
  |> rule_metrics_db.rule_execution_suppression_reason_name
  |> expect.equal(None)
}

pub fn unknown_execution_outcome_preserves_raw_values_test() {
  let outcome =
    rule_metrics_db.rule_execution_outcome_from_db("queued", "manual")

  let assert rule_metrics_db.UnknownRuleExecutionOutcome(
    raw: "queued",
    suppression_reason: Some(rule_metrics_db.UnknownSuppressionReason("manual")),
  ) = outcome
  outcome
  |> rule_metrics_db.rule_execution_outcome_name
  |> expect.equal("queued")
  outcome
  |> rule_metrics_db.rule_execution_suppression_reason_name
  |> expect.equal(Some("manual"))
}
