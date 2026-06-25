import domain/view_mode
import gleam/option.{type Option, None, Some}
import gleam/uri
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/capability_scope
import scrumbringer_client/url_state

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

fn assert_not_equal(actual: a, unexpected: a) {
  let assert False = actual == unexpected
}

fn assert_none(value: Option(a)) {
  let assert None = value
}

// =============================================================================
// parse tests
// =============================================================================

pub fn parse_empty_url_test() {
  let assert Ok(uri) = uri.parse("/app")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.project |> assert_none
  state |> url_state.view |> assert_equal(view_mode.Pool)
  state
  |> url_state.capability_scope
  |> assert_equal(capability_scope.AllCapabilities)
  state |> url_state.type_filter |> assert_none
  state |> url_state.capability_filter |> assert_none
  state |> url_state.search |> assert_none
  state |> url_state.expanded_card |> assert_none
  state |> url_state.card_depth |> assert_none
  state |> url_state.plan_mode |> assert_equal(url_state.PlanStructureParam)
}

pub fn parse_project_only_test() {
  let assert Ok(uri) = uri.parse("/app?project=8")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.project |> assert_equal(Some(8))
  state |> url_state.view |> assert_equal(view_mode.Pool)
}

pub fn parse_view_mode_removed_tracking_redirects_to_pool_test() {
  let assert Ok(uri) = uri.parse("/app?view=hierarchies")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.view |> assert_equal(view_mode.Pool)
}

pub fn parse_view_mode_cards_test() {
  let assert Ok(uri) = uri.parse("/app?view=cards")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.view |> assert_equal(view_mode.Cards)
}

pub fn parse_cards_depth_test() {
  let assert Ok(uri) = uri.parse("/app?view=cards&depth=2")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.view |> assert_equal(view_mode.Cards)
  state |> url_state.card_depth |> assert_equal(Some(2))
}

pub fn parse_cards_kanban_mode_test() {
  let assert Ok(uri) = uri.parse("/app?view=cards&plan_mode=kanban")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.view |> assert_equal(view_mode.Cards)
  state |> url_state.plan_mode |> assert_equal(url_state.PlanKanbanParam)
}

pub fn parse_cards_structure_mode_test() {
  let assert Ok(uri) = uri.parse("/app?view=cards&plan_mode=structure")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.view |> assert_equal(view_mode.Cards)
  state |> url_state.plan_mode |> assert_equal(url_state.PlanStructureParam)
}

pub fn parse_view_mode_capabilities_test() {
  let assert Ok(uri) = uri.parse("/app?view=capabilities")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.view |> assert_equal(view_mode.Capabilities)
}

pub fn parse_view_mode_people_test() {
  let assert Ok(uri) = uri.parse("/app?view=people")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.view |> assert_equal(view_mode.People)
}

pub fn parse_full_url_test() {
  let assert Ok(uri) =
    uri.parse(
      "/app?project=8&view=cards&scope=mine&type=2&cap=3&search=bug&card=15",
    )
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.project |> assert_equal(Some(8))
  state |> url_state.view |> assert_equal(view_mode.Cards)
  state
  |> url_state.capability_scope
  |> assert_equal(capability_scope.MyCapabilities)
  state |> url_state.type_filter |> assert_equal(Some(2))
  state |> url_state.capability_filter |> assert_equal(Some(3))
  state |> url_state.search |> assert_equal(Some("bug"))
  state |> url_state.expanded_card |> assert_equal(Some(15))
  state |> url_state.card_depth |> assert_none
}

pub fn parse_card_work_scope_test() {
  let assert Ok(uri) =
    uri.parse("/app?project=8&view=people&work_scope=card&card=15")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.project |> assert_equal(Some(8))
  state |> url_state.view |> assert_equal(view_mode.People)
  state |> url_state.card_work_scope |> assert_equal(Some(15))
  state |> url_state.expanded_card |> assert_equal(Some(15))
}

pub fn parse_card_show_does_not_activate_card_work_scope_test() {
  let assert Ok(uri) =
    uri.parse("/app?project=8&view=cards&show=card&show_card=42")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.project |> assert_equal(Some(8))
  state |> url_state.view |> assert_equal(view_mode.Cards)
  state |> url_state.card_work_scope |> assert_none
  state |> url_state.card_show |> assert_equal(Some(42))
  state |> url_state.task_show |> assert_none
}

pub fn parse_task_show_test() {
  let assert Ok(uri) = uri.parse("/app?project=8&show=task&task=825")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.project |> assert_equal(Some(8))
  state |> url_state.task_show |> assert_equal(Some(825))
  state |> url_state.card_show |> assert_none
}

pub fn parse_card_work_scope_and_card_show_keep_separate_ids_test() {
  let assert Ok(uri) =
    uri.parse(
      "/app?project=8&view=people&work_scope=card&card=15&show=card&show_card=42",
    )
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.card_work_scope |> assert_equal(Some(15))
  state |> url_state.expanded_card |> assert_equal(Some(15))
  state |> url_state.card_show |> assert_equal(Some(42))
}

pub fn parse_card_work_scope_without_card_redirects_and_clears_scope_test() {
  let assert Ok(uri) = uri.parse("/app?view=people&work_scope=card")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.view |> assert_equal(view_mode.People)
  state |> url_state.card_work_scope |> assert_none
}

pub fn parse_depth_without_cards_redirects_and_clears_depth_test() {
  let assert Ok(uri) = uri.parse("/app?view=people&depth=2")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.view |> assert_equal(view_mode.People)
  state |> url_state.card_depth |> assert_none
}

pub fn parse_plan_mode_without_cards_redirects_to_structure_test() {
  let assert Ok(uri) = uri.parse("/app?view=people&plan_mode=kanban")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.view |> assert_equal(view_mode.People)
  state |> url_state.plan_mode |> assert_equal(url_state.PlanStructureParam)
}

pub fn parse_invalid_plan_mode_redirects_to_structure_test() {
  let assert Ok(uri) = uri.parse("/app?view=cards&plan_mode=grid")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.view |> assert_equal(view_mode.Cards)
  state |> url_state.plan_mode |> assert_equal(url_state.PlanStructureParam)
}

pub fn parse_query_string_directly_test() {
  let state =
    unwrap_parse(url_state.parse_query("project=5&view=cards", url_state.Member))

  state |> url_state.project |> assert_equal(Some(5))
  state |> url_state.view |> assert_equal(view_mode.Cards)
}

pub fn parse_invalid_view_defaults_to_pool_test() {
  let assert Ok(uri) = uri.parse("/app?view=unknown")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.view |> assert_equal(view_mode.Pool)
}

pub fn parse_removed_list_view_is_invalid_and_redirects_to_pool_test() {
  let assert Ok(uri) = uri.parse("/app?view=list")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.view |> assert_equal(view_mode.Pool)
}

pub fn to_query_string_never_emits_view_list_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.to_query_string

  query |> assert_not_equal("project=8&view=list")
}

pub fn parse_invalid_project_drops_project_test() {
  let assert Ok(uri) = uri.parse("/app?project=nope")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.project |> assert_none
}

pub fn parse_invalid_capability_scope_redirects_to_default_test() {
  let assert Ok(uri) = uri.parse("/app?scope=unknown")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state
  |> url_state.capability_scope
  |> assert_equal(capability_scope.AllCapabilities)
}

pub fn parse_invalid_work_scope_redirects_to_default_test() {
  let assert Ok(uri) = uri.parse("/app?work_scope=team&card=15")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.card_work_scope |> assert_none
  state |> url_state.expanded_card |> assert_equal(Some(15))
}

pub fn parse_card_show_without_show_card_redirects_and_clears_show_test() {
  let assert Ok(uri) = uri.parse("/app?show=card")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.card_show |> assert_none
  state |> url_state.task_show |> assert_none
}

pub fn parse_show_card_without_show_redirects_and_clears_show_test() {
  let assert Ok(uri) = uri.parse("/app?show_card=42")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.card_show |> assert_none
}

pub fn parse_task_show_without_task_redirects_and_clears_show_test() {
  let assert Ok(uri) = uri.parse("/app?show=task")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.task_show |> assert_none
}

pub fn config_context_rejects_capability_scope_test() {
  let assert url_state.Redirect(state) =
    url_state.parse_query("project=8&scope=mine", url_state.Config)

  state |> url_state.project |> assert_equal(Some(8))
}

pub fn org_team_accepts_users_view_test() {
  let assert url_state.Parsed(state) =
    url_state.parse_query("view=users", url_state.OrgTeam)

  state
  |> url_state.assignments_view
  |> assert_equal(assignments_view_mode.ByUser)
}

pub fn member_context_rejects_assignments_view_test() {
  let assert url_state.Redirect(state) =
    url_state.parse_query("view=users", url_state.Member)

  state |> url_state.view |> assert_equal(view_mode.Pool)
}

pub fn parse_invalid_percent_encoded_value_redirects_test() {
  let assert url_state.Redirect(state) =
    url_state.parse_query("project=8&search=%ZZ", url_state.Member)

  state |> url_state.project |> assert_equal(Some(8))
  state |> url_state.search |> assert_none
}

pub fn parse_malformed_query_pair_redirects_test() {
  let assert url_state.Redirect(state) =
    url_state.parse_query("project=8&search", url_state.Member)

  state |> url_state.project |> assert_equal(Some(8))
  state |> url_state.search |> assert_none
}

// =============================================================================
// builder tests
// =============================================================================

pub fn with_project_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(8)

  state |> url_state.project |> assert_equal(Some(8))
}

pub fn without_project_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.without_project

  state |> url_state.project |> assert_none
}

pub fn with_view_test() {
  let state =
    url_state.empty()
    |> url_state.with_view(view_mode.Cards)

  state |> url_state.view |> assert_equal(view_mode.Cards)
}

pub fn with_type_filter_test() {
  let state =
    url_state.empty()
    |> url_state.with_type_filter(Some(2))

  state |> url_state.type_filter |> assert_equal(Some(2))
}

pub fn with_capability_scope_test() {
  let state =
    url_state.empty()
    |> url_state.with_capability_scope(capability_scope.MyCapabilities)

  state
  |> url_state.capability_scope
  |> assert_equal(capability_scope.MyCapabilities)
}

pub fn with_capability_filter_test() {
  let state =
    url_state.empty()
    |> url_state.with_capability_filter(Some(3))

  state |> url_state.capability_filter |> assert_equal(Some(3))
}

pub fn with_search_test() {
  let state =
    url_state.empty()
    |> url_state.with_search(Some("test query"))

  state |> url_state.search |> assert_equal(Some("test query"))
}

pub fn with_expanded_card_test() {
  let state =
    url_state.empty()
    |> url_state.with_expanded_card(Some(15))

  state |> url_state.expanded_card |> assert_equal(Some(15))
}

pub fn builder_chain_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_capability_scope(capability_scope.MyCapabilities)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_type_filter(Some(2))
    |> url_state.with_search(Some("bug"))

  state |> url_state.project |> assert_equal(Some(8))
  state |> url_state.view |> assert_equal(view_mode.Cards)
  state
  |> url_state.capability_scope
  |> assert_equal(capability_scope.MyCapabilities)
  state |> url_state.type_filter |> assert_equal(Some(2))
  state |> url_state.search |> assert_equal(Some("bug"))
}

pub fn clear_filters_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_capability_scope(capability_scope.MyCapabilities)
    |> url_state.with_type_filter(Some(2))
    |> url_state.with_capability_filter(Some(3))
    |> url_state.with_search(Some("test"))
    |> url_state.with_expanded_card(Some(15))
    |> url_state.with_card_work_scope(15)
    |> url_state.clear_filters

  // Project should remain
  state |> url_state.project |> assert_equal(Some(8))
  // View should remain at default
  state |> url_state.view |> assert_equal(view_mode.Pool)
  state
  |> url_state.capability_scope
  |> assert_equal(capability_scope.AllCapabilities)
  // Filters should be cleared
  state |> url_state.type_filter |> assert_none
  state |> url_state.capability_filter |> assert_none
  state |> url_state.search |> assert_none
  state |> url_state.expanded_card |> assert_none
  state |> url_state.card_work_scope |> assert_none
}

// =============================================================================
// to_query_string tests
// =============================================================================

pub fn to_query_string_empty_test() {
  let query =
    url_state.empty()
    |> url_state.to_query_string

  query |> assert_equal("")
}

pub fn to_query_string_with_project_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.to_query_string

  query |> assert_equal("project=8")
}

pub fn to_query_string_with_scope_test() {
  let query =
    url_state.empty()
    |> url_state.with_capability_scope(capability_scope.MyCapabilities)
    |> url_state.to_query_string

  query |> assert_equal("scope=mine")
}

pub fn to_query_string_full_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_type_filter(Some(2))
    |> url_state.with_capability_filter(Some(3))
    |> url_state.with_search(Some("bug"))
    |> url_state.with_expanded_card(Some(15))
    |> url_state.with_card_depth(Some(2))
    |> url_state.to_query_string

  query
  |> assert_equal(
    "project=8&view=cards&type=2&cap=3&search=bug&card=15&depth=2",
  )
}

pub fn to_query_string_omits_depth_outside_cards_test() {
  let query =
    url_state.empty()
    |> url_state.with_view(view_mode.People)
    |> url_state.with_card_depth(Some(2))
    |> url_state.to_query_string

  query |> assert_equal("view=people")
}

pub fn to_query_string_people_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.People)
    |> url_state.to_query_string

  query |> assert_equal("project=8&view=people")
}

pub fn to_query_string_capabilities_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Capabilities)
    |> url_state.to_query_string

  query |> assert_equal("project=8&view=capabilities")
}

pub fn to_query_string_cards_kanban_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_plan_mode(url_state.PlanKanbanParam)
    |> url_state.to_query_string

  query |> assert_equal("project=8&view=cards&plan_mode=kanban")
}

pub fn to_query_string_cards_structure_omits_default_plan_mode_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_plan_mode(url_state.PlanStructureParam)
    |> url_state.to_query_string

  query |> assert_equal("project=8&view=cards")
}

pub fn to_query_string_card_work_scope_people_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.People)
    |> url_state.with_card_work_scope(15)
    |> url_state.to_query_string

  query |> assert_equal("project=8&view=people&work_scope=card&card=15")
}

pub fn to_query_string_card_work_scope_capabilities_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Capabilities)
    |> url_state.with_card_work_scope(15)
    |> url_state.to_query_string

  query |> assert_equal("project=8&view=capabilities&work_scope=card&card=15")
}

pub fn to_query_string_card_work_scope_plan_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_card_work_scope(15)
    |> url_state.to_query_string

  query |> assert_equal("project=8&view=cards&work_scope=card&card=15")
}

pub fn to_query_string_card_work_scope_kanban_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_plan_mode(url_state.PlanKanbanParam)
    |> url_state.with_card_work_scope(15)
    |> url_state.to_query_string

  query
  |> assert_equal(
    "project=8&view=cards&plan_mode=kanban&work_scope=card&card=15",
  )
}

pub fn to_query_string_card_show_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_card_show(42)
    |> url_state.to_query_string

  query |> assert_equal("project=8&show=card&show_card=42")
}

pub fn to_query_string_task_show_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_task_show(825)
    |> url_state.to_query_string

  query |> assert_equal("project=8&show=task&task=825")
}

pub fn to_query_string_scope_and_show_keep_separate_ids_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.People)
    |> url_state.with_card_work_scope(15)
    |> url_state.with_card_show(42)
    |> url_state.to_query_string

  query
  |> assert_equal(
    "project=8&view=people&work_scope=card&card=15&show=card&show_card=42",
  )
}

// =============================================================================
// to_app_url tests
// =============================================================================

pub fn to_app_url_empty_test() {
  let url =
    url_state.empty()
    |> url_state.to_app_url

  url |> assert_equal("/app")
}

pub fn to_app_url_with_project_test() {
  let url =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.to_app_url

  url |> assert_equal("/app?project=8&view=cards")
}

// =============================================================================
// roundtrip tests
// =============================================================================

pub fn roundtrip_test() {
  let original =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_type_filter(Some(2))
    |> url_state.with_card_depth(Some(2))

  let query = url_state.to_query_string(original)
  let reparsed = unwrap_parse(url_state.parse_query(query, url_state.Member))

  reparsed |> url_state.project |> assert_equal(Some(8))
  reparsed |> url_state.view |> assert_equal(view_mode.Cards)
  reparsed |> url_state.plan_mode |> assert_equal(url_state.PlanStructureParam)
  reparsed |> url_state.type_filter |> assert_equal(Some(2))
  reparsed |> url_state.card_depth |> assert_equal(Some(2))
}

pub fn roundtrip_cards_kanban_test() {
  let original =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_plan_mode(url_state.PlanKanbanParam)

  let query = url_state.to_query_string(original)
  let reparsed = unwrap_parse(url_state.parse_query(query, url_state.Member))

  reparsed |> url_state.project |> assert_equal(Some(8))
  reparsed |> url_state.view |> assert_equal(view_mode.Cards)
  reparsed |> url_state.plan_mode |> assert_equal(url_state.PlanKanbanParam)
}

pub fn roundtrip_card_work_scope_people_test() {
  let original =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.People)
    |> url_state.with_card_work_scope(15)

  let query = url_state.to_query_string(original)
  let reparsed = unwrap_parse(url_state.parse_query(query, url_state.Member))

  reparsed |> url_state.project |> assert_equal(Some(8))
  reparsed |> url_state.view |> assert_equal(view_mode.People)
  reparsed |> url_state.card_work_scope |> assert_equal(Some(15))
}

pub fn roundtrip_card_work_scope_plan_kanban_test() {
  let original =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_plan_mode(url_state.PlanKanbanParam)
    |> url_state.with_card_work_scope(15)

  let query = url_state.to_query_string(original)
  let reparsed = unwrap_parse(url_state.parse_query(query, url_state.Member))

  reparsed |> url_state.project |> assert_equal(Some(8))
  reparsed |> url_state.view |> assert_equal(view_mode.Cards)
  reparsed |> url_state.plan_mode |> assert_equal(url_state.PlanKanbanParam)
  reparsed |> url_state.card_work_scope |> assert_equal(Some(15))
}

pub fn roundtrip_scope_and_card_show_test() {
  let original =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.People)
    |> url_state.with_card_work_scope(15)
    |> url_state.with_card_show(42)

  let query = url_state.to_query_string(original)
  let reparsed = unwrap_parse(url_state.parse_query(query, url_state.Member))

  reparsed |> url_state.card_work_scope |> assert_equal(Some(15))
  reparsed |> url_state.card_show |> assert_equal(Some(42))
}

pub fn roundtrip_with_encoded_search_test() {
  let original =
    url_state.empty()
    |> url_state.with_search(Some("test query"))

  let query = url_state.to_query_string(original)
  let reparsed = unwrap_parse(url_state.parse_query(query, url_state.Member))

  reparsed |> url_state.search |> assert_equal(Some("test query"))
}

fn unwrap_parse(result: url_state.QueryParseResult) -> url_state.UrlState {
  case result {
    url_state.Parsed(state) -> state
    url_state.Redirect(state) -> state
  }
}
