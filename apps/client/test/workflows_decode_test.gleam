//// Decoder tests for workflows, rules, and task templates.

import domain/automation
import domain/workflow
import gleam/dynamic/decode
import gleam/json
import gleam/option
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/api/workflows/rules as api_rules
import scrumbringer_client/api/workflows/task_templates as api_task_templates

fn assert_error(result: Result(a, b)) {
  let assert Error(_) = result
}

pub fn workflow_payload_decoder_decodes_enveloped_workflow_test() {
  let body =
    "{\"data\":{\"workflow\":{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Auto QA\",\"description\":\"Automated QA workflow\",\"active\":true,\"rule_count\":2,\"created_by\":1,\"created_at\":\"2026-01-15T10:00:00Z\"}}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.workflow_payload_decoder(),
      decode.success,
    )

  let assert Ok(workflow) = json.parse(from: body, using: decoder)
  let assert 1 = workflow.id
  let assert "Auto QA" = workflow.name
  let assert True = workflow.active
  let assert 2 = workflow.rule_count
}

pub fn workflow_payload_decoder_decodes_with_project_id_test() {
  let body =
    "{\"data\":{\"workflow\":{\"id\":2,\"org_id\":1,\"project_id\":5,\"name\":\"Project Workflow\",\"description\":null,\"active\":false,\"rule_count\":0,\"created_by\":2,\"created_at\":\"2026-01-16T12:00:00Z\"}}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.workflow_payload_decoder(),
      decode.success,
    )

  let assert Ok(workflow) = json.parse(from: body, using: decoder)
  let assert 2 = workflow.id
  let assert option.Some(5) = workflow.project_id
  let assert False = workflow.active
}

pub fn workflows_payload_decoder_decodes_list_test() {
  let body =
    "{\"data\":{\"workflows\":[{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Workflow A\",\"description\":\"First\",\"active\":true,\"rule_count\":1,\"created_by\":1,\"created_at\":\"2026-01-15T10:00:00Z\"},{\"id\":2,\"org_id\":1,\"project_id\":3,\"name\":\"Workflow B\",\"description\":null,\"active\":false,\"rule_count\":0,\"created_by\":1,\"created_at\":\"2026-01-15T11:00:00Z\"}]}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.workflows_payload_decoder(),
      decode.success,
    )

  let assert Ok(workflows) = json.parse(from: body, using: decoder)
  let assert [workflow_a, workflow_b] = workflows
  let assert "Workflow A" = workflow_a.name
  let assert "Workflow B" = workflow_b.name
}

pub fn rule_payload_decoder_decodes_enveloped_rule_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":1,\"workflow_id\":1,\"name\":\"Task Done\",\"goal\":\"Auto review\",\"trigger\":{\"type\":\"task_completed\",\"task_type_id\":5},\"action\":{\"type\":\"create_task\",\"template_id\":11},\"status\":{\"type\":\"active\"},\"created_at\":\"2026-01-15T10:30:00Z\",\"template\":{\"id\":11,\"org_id\":1,\"project_id\":null,\"name\":\"Review {{origin}}\",\"description\":\"Auto review\",\"type_id\":2,\"type_name\":\"Review\",\"priority\":3,\"created_by\":1,\"created_at\":\"2026-01-15T14:00:00Z\",\"execution_order\":1}}}}"

  let decoder =
    decode.field("data", api_rules.rule_payload_decoder(), decode.success)

  let assert Ok(rule) = json.parse(from: body, using: decoder)
  let assert option.Some(5) = workflow.rule_task_type_id(rule)
  let assert automation.TaskCompleted(option.Some(5)) = rule.trigger
  let assert option.Some(template) = rule.template
  let assert "Review {{origin}}" = template.name
}

pub fn rule_payload_decoder_decodes_with_null_task_type_id_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":2,\"workflow_id\":1,\"name\":\"Any Task\",\"goal\":null,\"trigger\":{\"type\":\"task_claimed\",\"task_type_id\":null},\"action\":{\"type\":\"create_task\",\"template_id\":11},\"status\":{\"type\":\"paused\"},\"created_at\":\"2026-01-15T11:00:00Z\",\"template\":null}}}"

  let decoder =
    decode.field("data", api_rules.rule_payload_decoder(), decode.success)

  let assert Ok(rule) = json.parse(from: body, using: decoder)
  let assert automation.TaskClaimed(option.None) = rule.trigger
}

pub fn rule_payload_decoder_decodes_card_resource_type_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":3,\"workflow_id\":2,\"name\":\"Card Closed\",\"goal\":\"Notify\",\"trigger\":{\"type\":\"card_closed\",\"scope\":{\"type\":\"any_card\"}},\"action\":null,\"status\":{\"type\":\"requires_review\",\"reason\":\"template_missing\"},\"created_at\":\"2026-01-15T12:00:00Z\",\"template\":null}}}"

  let decoder =
    decode.field("data", api_rules.rule_payload_decoder(), decode.success)

  let assert Ok(rule) = json.parse(from: body, using: decoder)
  let assert automation.CardClosed(automation.AnyCard) = rule.trigger
}

pub fn rule_payload_decoder_rejects_missing_trigger_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":4,\"workflow_id\":2,\"name\":\"Missing\",\"goal\":\"Notify\",\"action\":null,\"status\":{\"type\":\"active\"},\"created_at\":\"2026-01-15T12:00:00Z\",\"template\":null}}}"

  let decoder =
    decode.field("data", api_rules.rule_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  assert_error(result)
}

pub fn rules_payload_decoder_decodes_list_test() {
  let body =
    "{\"data\":{\"rules\":[{\"id\":1,\"workflow_id\":1,\"name\":\"Rule A\",\"goal\":\"Goal A\",\"trigger\":{\"type\":\"task_completed\",\"task_type_id\":1},\"action\":{\"type\":\"create_task\",\"template_id\":11},\"status\":{\"type\":\"active\"},\"created_at\":\"2026-01-15T10:00:00Z\",\"template\":null},{\"id\":2,\"workflow_id\":1,\"name\":\"Rule B\",\"goal\":null,\"trigger\":{\"type\":\"card_closed\",\"scope\":{\"type\":\"any_card\"}},\"action\":{\"type\":\"create_task\",\"template_id\":12},\"status\":{\"type\":\"paused\"},\"created_at\":\"2026-01-15T11:00:00Z\",\"template\":null}]}}"

  let decoder =
    decode.field("data", api_rules.rules_payload_decoder(), decode.success)

  let assert Ok(rules) = json.parse(from: body, using: decoder)
  let assert [rule_a, rule_b] = rules
  let assert "Rule A" = rule_a.name
  let assert automation.TaskCompleted(option.Some(1)) = rule_a.trigger
  let assert "Rule B" = rule_b.name
  let assert automation.CardClosed(automation.AnyCard) = rule_b.trigger
}

pub fn rule_payload_decoder_rejects_unsupported_trigger_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":5,\"workflow_id\":1,\"name\":\"Bad Task\",\"goal\":null,\"trigger\":{\"type\":\"task_blocked\",\"task_type_id\":null},\"action\":null,\"status\":{\"type\":\"active\"},\"created_at\":\"2026-01-15T10:00:00Z\",\"template\":null}}}"

  let decoder =
    decode.field("data", api_rules.rule_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  assert_error(result)
}

pub fn rule_payload_decoder_rejects_invalid_card_scope_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":6,\"workflow_id\":1,\"name\":\"Bad Card\",\"goal\":null,\"trigger\":{\"type\":\"card_closed\",\"scope\":{\"type\":\"subtree\"}},\"action\":null,\"status\":{\"type\":\"active\"},\"created_at\":\"2026-01-15T10:00:00Z\",\"template\":null}}}"

  let decoder =
    decode.field("data", api_rules.rule_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  assert_error(result)
}

pub fn rule_payload_decoder_rejects_card_depth_zero_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":7,\"workflow_id\":1,\"name\":\"Bad Card Type\",\"goal\":null,\"trigger\":{\"type\":\"card_closed\",\"scope\":{\"type\":\"at_depth\",\"depth\":0}},\"action\":null,\"status\":{\"type\":\"active\"},\"created_at\":\"2026-01-15T10:00:00Z\",\"template\":null}}}"

  let decoder =
    decode.field("data", api_rules.rule_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  assert_error(result)
}

pub fn template_payload_decoder_decodes_enveloped_template_test() {
  let body =
    "{\"data\":{\"template\":{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Review {{origin}}\",\"description\":\"Auto-created review task\",\"type_id\":2,\"type_name\":\"Review\",\"priority\":3,\"created_by\":1,\"created_at\":\"2026-01-15T14:00:00Z\"}}}"

  let decoder =
    decode.field(
      "data",
      api_task_templates.task_template_payload_decoder(),
      decode.success,
    )

  let assert Ok(template) = json.parse(from: body, using: decoder)
  let assert 1 = template.id
  let assert "Review {{origin}}" = template.name
  let assert 2 = template.type_id
  let assert 3 = template.priority
}

pub fn template_payload_decoder_decodes_with_project_id_test() {
  let body =
    "{\"data\":{\"template\":{\"id\":2,\"org_id\":1,\"project_id\":5,\"name\":\"QA Check\",\"description\":null,\"type_id\":3,\"type_name\":\"QA\",\"priority\":2,\"created_by\":2,\"created_at\":\"2026-01-15T15:00:00Z\"}}}"

  let decoder =
    decode.field(
      "data",
      api_task_templates.task_template_payload_decoder(),
      decode.success,
    )

  let assert Ok(template) = json.parse(from: body, using: decoder)
  let assert 2 = template.id
  let assert option.Some(5) = template.project_id
  let assert "QA" = template.type_name
}

pub fn templates_payload_decoder_decodes_list_test() {
  let body =
    "{\"data\":{\"templates\":[{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Template A\",\"description\":\"First\",\"type_id\":1,\"type_name\":\"Bug\",\"priority\":3,\"created_by\":1,\"created_at\":\"2026-01-15T14:00:00Z\"},{\"id\":2,\"org_id\":1,\"project_id\":3,\"name\":\"Template B\",\"description\":null,\"type_id\":2,\"type_name\":\"Feature\",\"priority\":2,\"created_by\":1,\"created_at\":\"2026-01-15T15:00:00Z\"}]}}"

  let decoder =
    decode.field(
      "data",
      api_task_templates.task_templates_payload_decoder(),
      decode.success,
    )

  let assert Ok(templates) = json.parse(from: body, using: decoder)
  let assert [template_a, template_b] = templates
  let assert "Template A" = template_a.name
  let assert "Template B" = template_b.name
  let assert option.Some(3) = template_b.project_id
}

pub fn workflows_payload_decoder_decodes_empty_list_test() {
  let body = "{\"data\":{\"workflows\":[]}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.workflows_payload_decoder(),
      decode.success,
    )

  let assert Ok([]) = json.parse(from: body, using: decoder)
}

pub fn rules_payload_decoder_decodes_empty_list_test() {
  let body = "{\"data\":{\"rules\":[]}}"

  let decoder =
    decode.field("data", api_rules.rules_payload_decoder(), decode.success)

  let assert Ok([]) = json.parse(from: body, using: decoder)
}

pub fn templates_payload_decoder_decodes_empty_list_test() {
  let body = "{\"data\":{\"templates\":[]}}"

  let decoder =
    decode.field(
      "data",
      api_task_templates.task_templates_payload_decoder(),
      decode.success,
    )

  let assert Ok([]) = json.parse(from: body, using: decoder)
}

// =============================================================================
// Rule Metrics Decoders
// =============================================================================

pub fn workflow_metrics_decoder_decodes_with_rules_test() {
  let body =
    "{\"workflow_id\":1,\"workflow_name\":\"Auto QA\",\"rules\":[{\"rule_id\":1,\"rule_name\":\"Task Done\",\"evaluated_count\":100,\"applied_count\":80,\"suppressed_count\":20},{\"rule_id\":2,\"rule_name\":\"Card Closed\",\"evaluated_count\":50,\"applied_count\":45,\"suppressed_count\":5}]}"

  let assert Ok(metrics) =
    json.parse(from: body, using: api_rule_metrics.workflow_metrics_decoder())
  let assert 1 = metrics.workflow_id
  let assert "Auto QA" = metrics.workflow_name
  let assert [rule_a, rule_b] = metrics.rules
  let assert 80 = rule_a.applied_count
  let assert 5 = rule_b.suppressed_count
}

pub fn workflow_metrics_decoder_decodes_empty_rules_test() {
  let body =
    "{\"workflow_id\":1,\"workflow_name\":\"Empty Workflow\",\"rules\":[]}"

  let assert Ok(metrics) =
    json.parse(from: body, using: api_rule_metrics.workflow_metrics_decoder())
  let assert "Empty Workflow" = metrics.workflow_name
  let assert [] = metrics.rules
}

pub fn org_workflow_metrics_summary_decoder_decodes_test() {
  let body =
    "{\"workflow_id\":1,\"workflow_name\":\"Auto QA\",\"project_id\":5,\"rule_count\":3,\"evaluated_count\":150,\"applied_count\":120,\"suppressed_count\":30}"

  let assert Ok(summary) =
    json.parse(
      from: body,
      using: api_rule_metrics.org_workflow_metrics_summary_decoder(),
    )
  let assert 1 = summary.workflow_id
  let assert 5 = summary.project_id
  let assert 120 = summary.applied_count
}

pub fn rule_metrics_detailed_decoder_decodes_with_breakdown_test() {
  let body =
    "{\"rule_id\":1,\"rule_name\":\"Task Done\",\"evaluated_count\":100,\"applied_count\":80,\"suppressed_count\":20,\"suppression_breakdown\":{\"idempotent\":10,\"not_user_triggered\":5,\"not_matching\":3,\"inactive\":2}}"

  let assert Ok(metrics) =
    json.parse(
      from: body,
      using: api_rule_metrics.rule_metrics_detailed_decoder(),
    )
  let assert 1 = metrics.rule_id
  let assert 20 = metrics.suppressed_count
  let assert 10 = metrics.suppression_breakdown.idempotent
}

pub fn rule_metrics_detailed_decoder_decodes_zero_counts_test() {
  let body =
    "{\"rule_id\":2,\"rule_name\":\"New Rule\",\"evaluated_count\":0,\"applied_count\":0,\"suppressed_count\":0,\"suppression_breakdown\":{\"idempotent\":0,\"not_user_triggered\":0,\"not_matching\":0,\"inactive\":0}}"

  let assert Ok(metrics) =
    json.parse(
      from: body,
      using: api_rule_metrics.rule_metrics_detailed_decoder(),
    )
  let assert 2 = metrics.rule_id
  let assert 0 = metrics.evaluated_count
  let assert 0 = metrics.suppression_breakdown.inactive
}

pub fn rule_executions_response_decoder_decodes_with_executions_test() {
  let body =
    "{\"rule_id\":1,\"executions\":[{\"id\":1,\"task_id\":100,\"outcome\":\"applied\",\"user_id\":5,\"user_email\":\"user@example.com\",\"template_id\":12,\"template_version\":3,\"created_task_id\":102,\"created_at\":\"2026-01-19T10:00:00Z\"},{\"id\":2,\"task_id\":101,\"outcome\":\"suppressed\",\"suppression_reason\":\"idempotent\",\"user_id\":6,\"user_email\":\"other@example.com\",\"created_at\":\"2026-01-19T11:00:00Z\"}],\"pagination\":{\"limit\":20,\"offset\":0,\"total\":2}}"

  let assert Ok(response) =
    json.parse(
      from: body,
      using: api_rule_metrics.rule_executions_response_decoder(),
    )
  let assert 1 = response.rule_id
  let assert [execution_a, execution_b] = response.executions
  let assert option.Some(100) = execution_a.task_id
  let assert api_rule_metrics.CreatedExecution = execution_a.outcome
  let assert option.Some(12) = execution_a.template_id
  let assert option.Some(3) = execution_a.template_version
  let assert option.Some(102) = execution_a.created_task_id
  let assert api_rule_metrics.IgnoredExecution("idempotent") =
    execution_b.outcome
  let assert 2 = response.pagination.total
}

pub fn rule_executions_response_decoder_decodes_empty_executions_test() {
  let body =
    "{\"rule_id\":1,\"executions\":[],\"pagination\":{\"limit\":20,\"offset\":0,\"total\":0}}"

  let assert Ok(response) =
    json.parse(
      from: body,
      using: api_rule_metrics.rule_executions_response_decoder(),
    )
  let assert [] = response.executions
  let assert 0 = response.pagination.total
}

pub fn rule_executions_response_decoder_decodes_optional_fields_test() {
  // Test that optional fields (target, suppression_reason, user_id, user_email) default correctly
  let body =
    "{\"rule_id\":1,\"executions\":[{\"id\":1,\"card_id\":50,\"outcome\":\"applied\",\"created_at\":\"2026-01-19T12:00:00Z\"}],\"pagination\":{\"limit\":20,\"offset\":0,\"total\":1}}"

  let assert Ok(response) =
    json.parse(
      from: body,
      using: api_rule_metrics.rule_executions_response_decoder(),
    )
  let assert [execution] = response.executions
  let assert option.None = execution.task_id
  let assert option.Some(50) = execution.card_id
  let assert api_rule_metrics.CreatedExecution = execution.outcome
  let assert 0 = execution.user_id
  let assert "" = execution.user_email
}
