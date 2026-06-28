import gleam/option as opt
import support/domain_fixtures
import support/render_assertions

import domain/card.{Card}
import domain/project.{Project}
import domain/remote.{Loaded}
import scrumbringer_client/client_state.{
  type Model, default_model, update_admin, update_member,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/features/admin/view as admin_view

fn base_model() -> Model {
  default_model()
}

fn sample_project() {
  Project(..domain_fixtures.project(1, "Project Alpha"), members_count: 2)
}

fn sample_card() {
  Card(..domain_fixtures.card(1, 1, "Playwright Card"), task_count: 1)
}

pub fn cards_view_renders_detail_button_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(..cards, cards: Loaded([sample_card()])),
      )
    })

  let html =
    admin_view.view_cards(model, opt.Some(sample_project()))
    |> render_assertions.html

  render_assertions.contains(html, "section admin-surface")
  render_assertions.contains(html, "admin-surface-filters")
  render_assertions.contains(html, "admin-surface-content")
  render_assertions.contains(html, "data-testid=\"cards-filters\"")
  render_assertions.contains(html, "card-title-button")
  render_assertions.contains(html, "card-show-open")
}

pub fn cards_view_blocks_delete_for_cards_with_tasks_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(..cards, cards: Loaded([sample_card()])),
      )
    })

  let html =
    admin_view.view_cards(model, opt.Some(sample_project()))
    |> render_assertions.html

  render_assertions.contains(html, "card-delete-btn")
  render_assertions.contains(html, "btn-delete-blocked")
  render_assertions.contains(html, "data-tooltip=\"Cannot delete: has tasks\"")
  render_assertions.contains(html, "aria-disabled=\"true\"")
}

pub fn cards_view_keeps_delete_available_for_empty_cards_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(
          ..cards,
          cards: Loaded([Card(..sample_card(), task_count: 0)]),
          cards_show_empty: True,
        ),
      )
    })

  let html =
    admin_view.view_cards(model, opt.Some(sample_project()))
    |> render_assertions.html

  render_assertions.contains(html, "card-delete-btn")
  render_assertions.contains(html, "aria-label=\"Delete Card\"")
}

pub fn card_crud_dialog_passes_parent_card_for_child_creation_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(
          ..cards,
          cards_dialog_mode: opt.Some(
            admin_cards.CardDialogCreate(opt.Some(42)),
          ),
        ),
      )
    })

  let html =
    admin_view.view_card_crud_dialog(model, 1)
    |> render_assertions.html

  render_assertions.contains(html, "mode=\"create\"")
  render_assertions.contains(html, "parent-card-id=\"42\"")
}

pub fn cards_view_renders_detail_modal_when_open_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(..cards, cards: Loaded([sample_card()])),
      )
    })
    |> update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: pool,
        card_show_open: opt.Some(1),
      )
    })

  let html =
    admin_view.view_cards(model, opt.Some(sample_project()))
    |> render_assertions.html

  render_assertions.contains(html, "card-show")
}

pub fn cards_view_does_not_render_local_crud_dialog_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(
          ..cards,
          cards: Loaded([sample_card()]),
          cards_dialog_mode: opt.Some(admin_cards.CardDialogDelete(1)),
        ),
      )
    })

  let html =
    admin_view.view_cards(model, opt.Some(sample_project()))
    |> render_assertions.html

  render_assertions.not_contains(html, "card-crud-dialog")
}
