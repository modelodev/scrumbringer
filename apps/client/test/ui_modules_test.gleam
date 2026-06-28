//// Tests for shared UI modules.

import support/assertions.{assert_equal}

import support/render_assertions

import scrumbringer_client/permissions
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header

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
    |> render_assertions.html

  render_assertions.contains(html, "<h2")
  render_assertions.contains(html, "admin-section-title")
  render_assertions.contains(html, "Members")
}
