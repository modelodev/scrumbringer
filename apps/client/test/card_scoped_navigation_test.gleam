import support/domain_fixtures

import domain/card.{type Card}
import scrumbringer_client/features/cards/scoped_navigation

fn sample_card() -> Card {
  domain_fixtures.card(42, 6, "API Cleanup")
}

pub fn plan_url_uses_card_work_scope_test() {
  let assert "/app?project=6&view=cards&work_scope=card&card=42" =
    scoped_navigation.plan_url(sample_card())
}

pub fn kanban_url_uses_card_work_scope_and_plan_mode_test() {
  let assert "/app?project=6&view=cards&plan_mode=kanban&work_scope=card&card=42" =
    scoped_navigation.kanban_url(sample_card())
}

pub fn capabilities_url_uses_card_work_scope_test() {
  let assert "/app?project=6&view=capabilities&work_scope=card&card=42" =
    scoped_navigation.capabilities_url(sample_card())
}

pub fn people_url_uses_card_work_scope_test() {
  let assert "/app?project=6&view=people&work_scope=card&card=42" =
    scoped_navigation.people_url(sample_card())
}
