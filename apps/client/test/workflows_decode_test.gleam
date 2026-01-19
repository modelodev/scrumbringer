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

pub fn task_template_payload_decoder_decodes_enveloped_template_test() {
  let body =
    "{\"data\":{\"task_template\":{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Review {{father}}\",\"description\":\"Auto-created review task\",\"type_id\":2,\"type_name\":\"Review\",\"priority\":3,\"created_by\":1,\"created_at\":\"2026-01-15T14:00:00Z\"}}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.task_template_payload_decoder(),
      decode.success,
    )

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn task_template_payload_decoder_decodes_with_project_id_test() {
  let body =
    "{\"data\":{\"task_template\":{\"id\":2,\"org_id\":1,\"project_id\":5,\"name\":\"QA Check\",\"description\":null,\"type_id\":3,\"type_name\":\"QA\",\"priority\":2,\"created_by\":2,\"created_at\":\"2026-01-15T15:00:00Z\"}}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.task_template_payload_decoder(),
      decode.success,
    )

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}

pub fn task_templates_payload_decoder_decodes_list_test() {
  let body =
    "{\"data\":{\"task_templates\":[{\"id\":1,\"org_id\":1,\"project_id\":null,\"name\":\"Template A\",\"description\":\"First\",\"type_id\":1,\"type_name\":\"Bug\",\"priority\":3,\"created_by\":1,\"created_at\":\"2026-01-15T14:00:00Z\"},{\"id\":2,\"org_id\":1,\"project_id\":3,\"name\":\"Template B\",\"description\":null,\"type_id\":2,\"type_name\":\"Feature\",\"priority\":2,\"created_by\":1,\"created_at\":\"2026-01-15T15:00:00Z\"}]}}"

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

pub fn task_templates_payload_decoder_decodes_empty_list_test() {
  let body = "{\"data\":{\"task_templates\":[]}}"

  let decoder =
    decode.field(
      "data",
      api_workflows.task_templates_payload_decoder(),
      decode.success,
    )

  let result = json.parse(from: body, using: decoder)

  result |> should.be_ok
}
