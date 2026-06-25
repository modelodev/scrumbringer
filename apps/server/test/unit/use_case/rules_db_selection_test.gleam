import domain/workflow
import gleam/option.{None, Some}
import scrumbringer_server/use_case/rules_db
import scrumbringer_server/use_case/service_error
import support/assertions as expect

pub fn selected_rule_template_from_list_allows_no_template_test() {
  rules_db.selected_rule_template_from_list([])
  |> expect.equal(Ok(None))
}

pub fn selected_rule_template_from_list_returns_single_template_test() {
  let selected = template(1, "QA")

  rules_db.selected_rule_template_from_list([selected])
  |> expect.equal(Ok(Some(selected)))
}

pub fn selected_rule_template_from_list_rejects_multiple_templates_test() {
  case
    rules_db.selected_rule_template_from_list([
      template(1, "QA"),
      template(2, "Deploy"),
    ])
  {
    Ok(_) -> expect.fail()
    Error(service_error.Unexpected(message)) ->
      message
      |> expect.equal("rule has multiple selected task templates")
    Error(_) -> expect.fail()
  }
}

fn template(id: Int, name: String) -> workflow.RuleTemplate {
  workflow.RuleTemplate(
    id: id,
    org_id: 1,
    project_id: Some(1),
    name: name,
    description: None,
    type_id: 2,
    type_name: "Review",
    priority: 3,
    created_by: 4,
    created_at: "2026-06-23T10:00:00Z",
    execution_order: 1,
  )
}
