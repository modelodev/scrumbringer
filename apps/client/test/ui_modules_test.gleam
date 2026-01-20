//// Tests for UI modules: css_class, icons, empty_state, info_callout.

import gleeunit/should

import scrumbringer_client/permissions
import scrumbringer_client/ui/css_class as css
import scrumbringer_client/ui/icons

// =============================================================================
// css_class Tests
// =============================================================================

pub fn css_to_string_returns_class_name_test() {
  css.nav_item()
  |> css.to_string
  |> should.equal("nav-item")
}

pub fn css_join_single_class_test() {
  [css.nav_item()]
  |> css.join
  |> should.equal("nav-item")
}

pub fn css_join_multiple_classes_test() {
  [css.nav_item(), css.active()]
  |> css.join
  |> should.equal("nav-item active")
}

pub fn css_join_empty_list_test() {
  []
  |> css.join
  |> should.equal("")
}

pub fn css_when_true_includes_class_test() {
  css.when(css.active(), True)
  |> should.equal([css.active()])
}

pub fn css_when_false_excludes_class_test() {
  css.when(css.active(), False)
  |> should.equal([])
}

pub fn css_join_with_conditional_test() {
  let is_active = True
  [css.nav_item(), ..css.when(css.active(), is_active)]
  |> css.join
  |> should.equal("nav-item active")
}

pub fn css_join_with_conditional_false_test() {
  let is_active = False
  [css.nav_item(), ..css.when(css.active(), is_active)]
  |> css.join
  |> should.equal("nav-item")
}

// =============================================================================
// icons Tests
// =============================================================================

pub fn emoji_target_test() {
  icons.emoji_to_string(icons.Target)
  |> should.equal("🎯")
}

pub fn emoji_search_test() {
  icons.emoji_to_string(icons.Search)
  |> should.equal("🔍")
}

pub fn emoji_hand_test() {
  icons.emoji_to_string(icons.Hand)
  |> should.equal("✋")
}

pub fn emoji_lightbulb_test() {
  icons.emoji_to_string(icons.Lightbulb)
  |> should.equal("💡")
}

pub fn heroicon_name_envelope_test() {
  icons.heroicon_name(icons.Envelope)
  |> should.equal("envelope")
}

pub fn heroicon_name_building_office_test() {
  icons.heroicon_name(icons.BuildingOffice)
  |> should.equal("building-office")
}

pub fn heroicon_typed_url_test() {
  icons.heroicon_typed_url(icons.Envelope)
  |> should.equal(
    "https://cdn.jsdelivr.net/npm/heroicons@2.2.0/24/outline/envelope.svg",
  )
}

pub fn section_icon_invites_test() {
  icons.section_icon(permissions.Invites)
  |> should.equal(icons.Envelope)
}

pub fn section_icon_projects_test() {
  icons.section_icon(permissions.Projects)
  |> should.equal(icons.Folder)
}

pub fn section_icon_members_test() {
  icons.section_icon(permissions.Members)
  |> should.equal(icons.Users)
}

pub fn section_icon_workflows_test() {
  icons.section_icon(permissions.Workflows)
  |> should.equal(icons.Cog6Tooth)
}
