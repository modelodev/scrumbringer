//// Decoder tests for workflows, rules, and task templates.

import gleam/dynamic/decode
import gleam/json
import gleeunit/should
import scrumbringer_client/api/workflows as api_workflows

pub fn workflow_payload_decoder_decodes_enveloped_workflow_test() {
  let body =
    "{\"data\":{\"workflow\":{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Auto QA\",\"description\":\"Automated QA workflow\",\"active\":true,\"rule_count\":2,\"created_by\":1,\"created_at\":\"2026-01-15T10:00:00Z\"}}}"

  let decoder =
    decode.field("data", api_workflows.workflow_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn workflow_payload_decoder_decodes_with_project_id_test() {
  let body =
    "{\"data\":{\"workflow\":{\"id\":2,\"org_id\":1,\"project_id\":5,\"name\":\"Project Workflow\",\"description\":null,\"active\":false,\"rule_count\":0,\"created_by\":2,\"created_at\":\"2026-01-16T12:00:00Z\"}}}"

  let decoder =
    decode.field("data", api_workflows.workflow_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn workflows_payload_decoder_decodes_list_test() {
  let body =
    "{\"data\":{\"workflows\":[{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Workflow A\",\"description\":\"First\",\"active\":true,\"rule_count\":1,\"created_by\":1,\"created_at\":\"2026-01-15T10:00:00Z\"},{\"id\":2,\"org_id\":1,\"project_id\":3,\"name\":\"Workflow B\",\"description\":null,\"active\":false,\"rule_count\":0,\"created_by\":1,\"created_at\":\"2026-01-15T11:00:00Z\"}]}}"

  let decoder =
    decode.field("data", api_workflows.workflows_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn rule_payload_decoder_decodes_enveloped_rule_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":1,\"workflow_id\":1,\"name\":\"Task Completed\",\"goal\":\"Auto review\",\"resource_type\":\"task\",\"task_type_id\":5,\"to_state\":\"completed\",\"active\":true,\"created_at\":\"2026-01-15T10:30:00Z\"}}}"

  let decoder =
    decode.field("data", api_workflows.rule_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn rule_payload_decoder_decodes_with_null_task_type_id_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":2,\"workflow_id\":1,\"name\":\"Any Task\",\"goal\":null,\"resource_type\":\"task\",\"task_type_id\":null,\"to_state\":\"done\",\"active\":false,\"created_at\":\"2026-01-15T11:00:00Z\"}}}"

  let decoder =
    decode.field("data", api_workflows.rule_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn rule_payload_decoder_decodes_card_resource_type_test() {
  let body =
    "{\"data\":{\"rule\":{\"id\":3,\"workflow_id\":2,\"name\":\"Card Closed\",\"goal\":\"Notify\",\"resource_type\":\"card\",\"task_type_id\":null,\"to_state\":\"closed\",\"active\":true,\"created_at\":\"2026-01-15T12:00:00Z\"}}}"

  let decoder =
    decode.field("data", api_workflows.rule_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn rules_payload_decoder_decodes_list_test() {
  let body =
    "{\"data\":{\"rules\":[{\"id\":1,\"workflow_id\":1,\"name\":\"Rule A\",\"goal\":\"Goal A\",\"resource_type\":\"task\",\"task_type_id\":1,\"to_state\":\"completed\",\"active\":true,\"created_at\":\"2026-01-15T10:00:00Z\"},{\"id\":2,\"workflow_id\":1,\"name\":\"Rule B\",\"goal\":null,\"resource_type\":\"card\",\"task_type_id\":null,\"to_state\":\"closed\",\"active\":false,\"created_at\":\"2026-01-15T11:00:00Z\"}]}}"

  let decoder =
    decode.field("data", api_workflows.rules_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn template_payload_decoder_decodes_enveloped_template_test() {
  let body =
    "{\"data\":{\"template\":{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Review {{father}}\",\"description\":\"Auto-created review task\",\"type_id\":2,\"type_name\":\"Review\",\"priority\":3,\"created_by\":1,\"created_at\":\"2026-01-15T14:00:00Z\"}}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.task_template_payload_decoder(),
      decode.success,
    )

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn template_payload_decoder_decodes_with_project_id_test() {
  let body =
    "{\"data\":{\"template\":{\"id\":2,\"org_id\":1,\"project_id\":5,\"name\":\"QA Check\",\"description\":null,\"type_id\":3,\"type_name\":\"QA\",\"priority\":2,\"created_by\":2,\"created_at\":\"2026-01-15T15:00:00Z\"}}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.task_template_payload_decoder(),
      decode.success,
    )

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn templates_payload_decoder_decodes_list_test() {
  let body =
    "{\"data\":{\"templates\":[{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Template A\",\"description\":\"First\",\"type_id\":1,\"type_name\":\"Bug\",\"priority\":3,\"created_by\":1,\"created_at\":\"2026-01-15T14:00:00Z\"},{\"id\":2,\"org_id\":1,\"project_id\":3,\"name\":\"Template B\",\"description\":null,\"type_id\":2,\"type_name\":\"Feature\",\"priority\":2,\"created_by\":1,\"created_at\":\"2026-01-15T15:00:00Z\"}]}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.task_templates_payload_decoder(),
      decode.success,
    )

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn rule_templates_payload_decoder_decodes_list_test() {
  let body =
    "{\"data\":{\"templates\":[{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Review {{father}}\",\"description\":\"Auto review\",\"type_id\":2,\"type_name\":\"Review\",\"priority\":3,\"created_by\":1,\"created_at\":\"2026-01-15T14:00:00Z\",\"execution_order\":1},{\"id\":2,\"org_id\":1,\"project_id\":null,\"name\":\"QA Check\",\"description\":null,\"type_id\":3,\"type_name\":\"QA\",\"priority\":2,\"created_by\":1,\"created_at\":\"2026-01-15T15:00:00Z\",\"execution_order\":2}]}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.rule_templates_payload_decoder(),
      decode.success,
    )

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn workflows_payload_decoder_decodes_empty_list_test() {
  let body = "{\"data\":{\"workflows\":[]}}"

  let decoder =
    decode.field("data", api_workflows.workflows_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn rules_payload_decoder_decodes_empty_list_test() {
  let body = "{\"data\":{\"rules\":[]}}"

  let decoder =
    decode.field("data", api_workflows.rules_payload_decoder(), decode.success)

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn templates_payload_decoder_decodes_empty_list_test() {
  let body = "{\"data\":{\"templates\":[]}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.task_templates_payload_decoder(),
      decode.success,
    )

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

// =============================================================================
// Rule Metrics Decoders
// =============================================================================

pub fn workflow_metrics_decoder_decodes_with_rules_test() {
  let body =
    "{\"workflow_id\":1,\"workflow_name\":\"Auto QA\",\"rules\":[{\"rule_id\":1,\"rule_name\":\"Task Completed\",\"evaluated_count\":100,\"applied_count\":80,\"suppressed_count\":20},{\"rule_id\":2,\"rule_name\":\"Card Closed\",\"evaluated_count\":50,\"applied_count\":45,\"suppressed_count\":5}]}"

  let result = json.parse(from: body, using: api_workflows.workflow_metrics_decoder())

  result |> should.be_ok
}

pub fn workflow_metrics_decoder_decodes_empty_rules_test() {
  let body =
    "{\"workflow_id\":1,\"workflow_name\":\"Empty Workflow\",\"rules\":[]}"

  let result = json.parse(from: body, using: api_workflows.workflow_metrics_decoder())

  result |> should.be_ok
}

pub fn org_workflow_metrics_summary_decoder_decodes_test() {
  let body =
    "{\"workflow_id\":1,\"workflow_name\":\"Auto QA\",\"project_id\":5,\"rule_count\":3,\"evaluated_count\":150,\"applied_count\":120,\"suppressed_count\":30}"

  let result =
    json.parse(from: body, using: api_workflows.org_workflow_metrics_summary_decoder())

  result |> should.be_ok
}

pub fn rule_metrics_detailed_decoder_decodes_with_breakdown_test() {
  let body =
    "{\"rule_id\":1,\"rule_name\":\"Task Completed\",\"evaluated_count\":100,\"applied_count\":80,\"suppressed_count\":20,\"suppression_breakdown\":{\"idempotent\":10,\"not_user_triggered\":5,\"not_matching\":3,\"inactive\":2}}"

  let result =
    json.parse(from: body, using: api_workflows.rule_metrics_detailed_decoder())

  result |> should.be_ok
}

pub fn rule_metrics_detailed_decoder_decodes_zero_counts_test() {
  let body =
    "{\"rule_id\":2,\"rule_name\":\"New Rule\",\"evaluated_count\":0,\"applied_count\":0,\"suppressed_count\":0,\"suppression_breakdown\":{\"idempotent\":0,\"not_user_triggered\":0,\"not_matching\":0,\"inactive\":0}}"

  let result =
    json.parse(from: body, using: api_workflows.rule_metrics_detailed_decoder())

  result |> should.be_ok
}

pub fn rule_executions_response_decoder_decodes_with_executions_test() {
  let body =
    "{\"rule_id\":1,\"executions\":[{\"id\":1,\"origin_type\":\"task\",\"origin_id\":100,\"outcome\":\"applied\",\"user_id\":5,\"user_email\":\"user@example.com\",\"created_at\":\"2026-01-19T10:00:00Z\"},{\"id\":2,\"origin_type\":\"task\",\"origin_id\":101,\"outcome\":\"suppressed\",\"suppression_reason\":\"idempotent\",\"user_id\":6,\"user_email\":\"other@example.com\",\"created_at\":\"2026-01-19T11:00:00Z\"}],\"pagination\":{\"limit\":20,\"offset\":0,\"total\":2}}"

  let result =
    json.parse(from: body, using: api_workflows.rule_executions_response_decoder())

  result |> should.be_ok
}

pub fn rule_executions_response_decoder_decodes_empty_executions_test() {
  let body =
    "{\"rule_id\":1,\"executions\":[],\"pagination\":{\"limit\":20,\"offset\":0,\"total\":0}}"

  let result =
    json.parse(from: body, using: api_workflows.rule_executions_response_decoder())

  result |> should.be_ok
}

pub fn rule_executions_response_decoder_decodes_optional_fields_test() {
  // Test that optional fields (suppression_reason, user_id, user_email) default correctly
  let body =
    "{\"rule_id\":1,\"executions\":[{\"id\":1,\"origin_type\":\"card\",\"origin_id\":50,\"outcome\":\"applied\",\"created_at\":\"2026-01-19T12:00:00Z\"}],\"pagination\":{\"limit\":20,\"offset\":0,\"total\":1}}"

  let result =
    json.parse(from: body, using: api_workflows.rule_executions_response_decoder())

  result |> should.be_ok
}
