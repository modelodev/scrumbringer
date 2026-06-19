import gleam/string

@external(erlang, "final_cleanup_ht12_ffi", "violations")
fn violations(check: String) -> List(String)

pub fn legacy_terms_do_not_exist_in_active_shared_server_client_code_test() {
  expect_gate("legacy_terms_do_not_exist_in_active_shared_server_client_code")
}

pub fn active_code_respects_final_architecture_boundaries_test() {
  expect_gate("active_code_respects_final_architecture_boundaries")
}

pub fn domain_types_are_not_duplicated_in_server_or_client_test() {
  expect_gate("domain_types_are_not_duplicated_in_server_or_client")
}

pub fn api_contracts_live_under_shared_api_test() {
  expect_gate("api_contracts_live_under_shared_api")
}

pub fn use_cases_do_not_live_in_generic_services_test() {
  expect_gate("use_cases_do_not_live_in_generic_services")
}

pub fn codecs_use_aspect_or_contract_codec_suffix_test() {
  expect_gate("codecs_use_aspect_or_contract_codec_suffix")
}

pub fn mutating_use_cases_persist_state_and_audit_event_atomically_test() {
  expect_gate("mutating_use_cases_persist_state_and_audit_event_atomically")
}

pub fn mutating_use_cases_do_not_emit_audit_event_on_conflict_test() {
  expect_gate("mutating_use_cases_do_not_emit_audit_event_on_conflict")
}

pub fn lustre_mutations_update_model_from_api_response_test() {
  expect_gate("lustre_mutations_update_model_from_api_response")
}

pub fn lustre_update_does_not_reimplement_server_transaction_rules_test() {
  expect_gate("lustre_update_does_not_reimplement_server_transaction_rules")
}

pub fn legacy_milestone_routes_are_absent_test() {
  expect_gate("legacy_milestone_routes_are_absent")
}

pub fn schema_final_has_no_milestone_tables_or_columns_test() {
  expect_gate("schema_final_has_no_milestone_tables_or_columns")
}

pub fn seed_data_uses_card_tree_and_root_pool_tasks_test() {
  expect_gate("seed_data_uses_card_tree_and_root_pool_tasks")
}

pub fn seed_data_covers_card_profiles_due_dates_and_closed_outcomes_test() {
  expect_gate("seed_data_covers_card_profiles_due_dates_and_closed_outcomes")
}

pub fn ui_validation_covers_main_flows_and_responsive_states_test() {
  expect_gate("ui_validation_covers_main_flows_and_responsive_states")
}

pub fn seed_data_covers_roles_permissions_and_capabilities_test() {
  expect_gate("seed_data_covers_roles_permissions_and_capabilities")
}

pub fn seed_data_covers_healthy_and_saturated_pool_limits_test() {
  expect_gate("seed_data_covers_healthy_and_saturated_pool_limits")
}

pub fn full_flow_smoke_test_for_manager_and_member_test() {
  expect_gate("full_flow_smoke_test_for_manager_and_member")
}

pub fn docs_and_i18n_do_not_expose_legacy_concepts_test() {
  expect_gate("docs_and_i18n_do_not_expose_legacy_concepts")
}

pub fn audit_events_replace_task_events_as_live_model_test() {
  expect_gate("audit_events_replace_task_events_as_live_model")
}

pub fn audit_event_kind_codec_roundtrip_test() {
  expect_gate("audit_event_kind_codec_roundtrip")
}

pub fn metrics_are_derived_from_audit_events_not_task_events_test() {
  expect_gate("metrics_are_derived_from_audit_events_not_task_events")
}

pub fn milestone_metrics_are_removed_or_replaced_by_card_rollup_metrics_test() {
  expect_gate(
    "milestone_metrics_are_removed_or_replaced_by_card_rollup_metrics",
  )
}

pub fn final_full_refactor_review_has_no_required_changes_left_test() {
  expect_gate("final_full_refactor_review_has_no_required_changes_left")
}

pub fn final_cleanup_removes_obsolete_unnecessary_and_incompatible_code_test() {
  expect_gate(
    "final_cleanup_removes_obsolete_unnecessary_and_incompatible_code",
  )
}

fn expect_gate(check: String) -> Nil {
  case violations(check) {
    [] -> Nil
    failures ->
      panic as { check <> " violations:\n" <> string.join(failures, "\n") }
  }
}
