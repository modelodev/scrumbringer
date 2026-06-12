//// Tests for UI modules: css_class, icons, empty_state, info_callout.

import gleam/string
import lustre/element

import scrumbringer_client/permissions
import scrumbringer_client/ui/css_class as css
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

// =============================================================================
// css_class Tests
// =============================================================================

pub fn css_to_string_returns_class_name_test() {
  css.nav_item()
  |> css.to_string
  |> assert_equal("nav-item")
}

pub fn css_join_single_class_test() {
  [css.nav_item()]
  |> css.join
  |> assert_equal("nav-item")
}

pub fn css_join_multiple_classes_test() {
  [css.nav_item(), css.active()]
  |> css.join
  |> assert_equal("nav-item active")
}

pub fn css_join_empty_list_test() {
  []
  |> css.join
  |> assert_equal("")
}

pub fn css_when_true_includes_class_test() {
  css.when(css.active(), True)
  |> assert_equal([css.active()])
}

pub fn css_when_false_excludes_class_test() {
  css.when(css.active(), False)
  |> assert_equal([])
}

pub fn css_join_with_conditional_test() {
  let is_active = True
  [css.nav_item(), ..css.when(css.active(), is_active)]
  |> css.join
  |> assert_equal("nav-item active")
}

pub fn css_join_with_conditional_false_test() {
  let is_active = False
  [css.nav_item(), ..css.when(css.active(), is_active)]
  |> css.join
  |> assert_equal("nav-item")
}

// =============================================================================
// icons Tests
// =============================================================================

pub fn heroicon_name_envelope_test() {
  icons.heroicon_name(icons.Envelope)
  |> assert_equal("envelope")
}

pub fn heroicon_name_building_office_test() {
  icons.heroicon_name(icons.BuildingOffice)
  |> assert_equal("building-office")
}

pub fn heroicon_typed_url_test() {
  icons.heroicon_typed_url(icons.Envelope)
  |> assert_equal(
    "https://cdn.jsdelivr.net/npm/heroicons@2.2.0/24/outline/envelope.svg",
  )
}

pub fn section_icon_invites_test() {
  icons.section_icon(permissions.Invites)
  |> assert_equal(icons.Envelope)
}

pub fn section_icon_projects_test() {
  icons.section_icon(permissions.Projects)
  |> assert_equal(icons.Folder)
}

pub fn section_icon_members_test() {
  icons.section_icon(permissions.Members)
  |> assert_equal(icons.Users)
}

pub fn section_icon_workflows_test() {
  icons.section_icon(permissions.Workflows)
  |> assert_equal(icons.Cog6Tooth)
}

pub fn section_header_title_is_semantic_heading_test() {
  let html =
    section_header.view(icons.OrgUsers, "Members")
    |> element.to_document_string

  assert_contains(html, "<h2")
  assert_contains(html, "admin-section-title")
  assert_contains(html, "Members")
}
