import domain/view_mode
import gleam/option.{Some}
import gleam/uri
import gleeunit/should
import scrumbringer_client/url_state

// =============================================================================
// parse tests
// =============================================================================

pub fn parse_empty_url_test() {
  let assert Ok(uri) = uri.parse("/app")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.project |> should.be_none
  state |> url_state.view |> should.equal(view_mode.Pool)
  state |> url_state.type_filter |> should.be_none
  state |> url_state.capability_filter |> should.be_none
  state |> url_state.search |> should.be_none
  state |> url_state.expanded_card |> should.be_none
}

pub fn parse_project_only_test() {
  let assert Ok(uri) = uri.parse("/app?project=8")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.project |> should.equal(Some(8))
  state |> url_state.view |> should.equal(view_mode.Pool)
}

pub fn parse_view_mode_milestones_test() {
  let assert Ok(uri) = uri.parse("/app?view=milestones")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.view |> should.equal(view_mode.Milestones)
}

pub fn parse_view_mode_cards_test() {
  let assert Ok(uri) = uri.parse("/app?view=cards")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.view |> should.equal(view_mode.Cards)
}

pub fn parse_view_mode_people_test() {
  let assert Ok(uri) = uri.parse("/app?view=people")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.view |> should.equal(view_mode.People)
}

pub fn parse_full_url_test() {
  let assert Ok(uri) =
    uri.parse("/app?project=8&view=milestones&type=2&cap=3&search=bug&card=15")
  let state = unwrap_parse(url_state.parse(uri, url_state.Member))

  state |> url_state.project |> should.equal(Some(8))
  state |> url_state.view |> should.equal(view_mode.Milestones)
  state |> url_state.type_filter |> should.equal(Some(2))
  state |> url_state.capability_filter |> should.equal(Some(3))
  state |> url_state.search |> should.equal(Some("bug"))
  state |> url_state.expanded_card |> should.equal(Some(15))
}

pub fn parse_query_string_directly_test() {
  let state =
    unwrap_parse(url_state.parse_query("project=5&view=cards", url_state.Member))

  state |> url_state.project |> should.equal(Some(5))
  state |> url_state.view |> should.equal(view_mode.Cards)
}

pub fn parse_invalid_view_defaults_to_pool_test() {
  let assert Ok(uri) = uri.parse("/app?view=unknown")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.view |> should.equal(view_mode.Pool)
}

pub fn parse_legacy_list_view_is_invalid_and_redirects_to_pool_test() {
  let assert Ok(uri) = uri.parse("/app?view=list")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.view |> should.equal(view_mode.Pool)
}

pub fn parse_invalid_project_drops_project_test() {
  let assert Ok(uri) = uri.parse("/app?project=nope")
  let assert url_state.Redirect(state) = url_state.parse(uri, url_state.Member)

  state |> url_state.project |> should.be_none
}

// =============================================================================
// builder tests
// =============================================================================

pub fn with_project_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(8)

  state |> url_state.project |> should.equal(Some(8))
}

pub fn without_project_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.without_project

  state |> url_state.project |> should.be_none
}

pub fn with_view_test() {
  let state =
    url_state.empty()
    |> url_state.with_view(view_mode.Cards)

  state |> url_state.view |> should.equal(view_mode.Cards)
}

pub fn with_type_filter_test() {
  let state =
    url_state.empty()
    |> url_state.with_type_filter(Some(2))

  state |> url_state.type_filter |> should.equal(Some(2))
}

pub fn with_capability_filter_test() {
  let state =
    url_state.empty()
    |> url_state.with_capability_filter(Some(3))

  state |> url_state.capability_filter |> should.equal(Some(3))
}

pub fn with_search_test() {
  let state =
    url_state.empty()
    |> url_state.with_search(Some("test query"))

  state |> url_state.search |> should.equal(Some("test query"))
}

pub fn with_expanded_card_test() {
  let state =
    url_state.empty()
    |> url_state.with_expanded_card(Some(15))

  state |> url_state.expanded_card |> should.equal(Some(15))
}

pub fn builder_chain_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_type_filter(Some(2))
    |> url_state.with_search(Some("bug"))

  state |> url_state.project |> should.equal(Some(8))
  state |> url_state.view |> should.equal(view_mode.Cards)
  state |> url_state.type_filter |> should.equal(Some(2))
  state |> url_state.search |> should.equal(Some("bug"))
}

pub fn clear_filters_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_type_filter(Some(2))
    |> url_state.with_capability_filter(Some(3))
    |> url_state.with_search(Some("test"))
    |> url_state.with_expanded_card(Some(15))
    |> url_state.clear_filters

  // Project should remain
  state |> url_state.project |> should.equal(Some(8))
  // View should remain at default
  state |> url_state.view |> should.equal(view_mode.Pool)
  // Filters should be cleared
  state |> url_state.type_filter |> should.be_none
  state |> url_state.capability_filter |> should.be_none
  state |> url_state.search |> should.be_none
  state |> url_state.expanded_card |> should.be_none
}

// =============================================================================
// to_query_string tests
// =============================================================================

pub fn to_query_string_empty_test() {
  let query =
    url_state.empty()
    |> url_state.to_query_string

  query |> should.equal("")
}

pub fn to_query_string_with_project_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.to_query_string

  query |> should.equal("project=8")
}

pub fn to_query_string_full_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Milestones)
    |> url_state.with_type_filter(Some(2))
    |> url_state.with_capability_filter(Some(3))
    |> url_state.with_search(Some("bug"))
    |> url_state.with_expanded_card(Some(15))
    |> url_state.to_query_string

  query
  |> should.equal("project=8&view=milestones&type=2&cap=3&search=bug&card=15")
}

pub fn to_query_string_people_test() {
  let query =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.People)
    |> url_state.to_query_string

  query |> should.equal("project=8&view=people")
}

// =============================================================================
// to_app_url tests
// =============================================================================

pub fn to_app_url_empty_test() {
  let url =
    url_state.empty()
    |> url_state.to_app_url

  url |> should.equal("/app")
}

pub fn to_app_url_with_project_test() {
  let url =
    url_state.empty()
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.to_app_url

  url |> should.equal("/app?project=8&view=cards")
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

  let query = url_state.to_query_string(original)
  let reparsed = unwrap_parse(url_state.parse_query(query, url_state.Member))

  reparsed |> url_state.project |> should.equal(Some(8))
  reparsed |> url_state.view |> should.equal(view_mode.Cards)
  reparsed |> url_state.type_filter |> should.equal(Some(2))
}

pub fn roundtrip_with_encoded_search_test() {
  let original =
    url_state.empty()
    |> url_state.with_search(Some("test query"))

  let query = url_state.to_query_string(original)
  let reparsed = unwrap_parse(url_state.parse_query(query, url_state.Member))

  reparsed |> url_state.search |> should.equal(Some("test query"))
}

fn unwrap_parse(result: url_state.QueryParseResult) -> url_state.UrlState {
  case result {
    url_state.Parsed(state) -> state
    url_state.Redirect(state) -> state
  }
}
