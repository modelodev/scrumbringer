import gleam/option as opt
import gleam/string
import lustre/element

import domain/card.{Card, Draft}
import domain/project.{Project}
import domain/project_role.{Manager}
import domain/remote.{Loaded}
import scrumbringer_client/client_state.{
  type Model, default_model, update_admin, update_member,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/admin/view as admin_view

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

fn base_model() -> Model {
  default_model()
}

fn sample_project() {
  Project(
    id: 1,
    name: "Project Alpha",
    my_role: Manager,
    created_at: "2026-01-01",
    members_count: 2,
    card_depth_names: [],
  )
}

fn sample_card() {
  Card(
    id: 1,
    project_id: 1,
    parent_card_id: opt.None,
    title: "Playwright Card",
    description: "",
    color: opt.None,
    state: Draft,
    task_count: 1,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    has_new_notes: False,
  )
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
    |> element.to_document_string

  assert_contains(html, "section admin-surface")
  assert_contains(html, "admin-surface-filters")
  assert_contains(html, "admin-surface-content")
  assert_contains(html, "data-testid=\"cards-filters\"")
  assert_contains(html, "card-title-button")
  assert_contains(html, "card-show-open")
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
    |> element.to_document_string

  assert_contains(html, "card-delete-btn")
  assert_contains(html, "btn-delete-blocked")
  assert_contains(html, "data-tooltip=\"Cannot delete: has tasks\"")
  assert_contains(html, "aria-disabled=\"true\"")
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
    |> element.to_document_string

  assert_contains(html, "card-delete-btn")
  assert_contains(html, "aria-label=\"Delete Card\"")
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
    |> element.to_document_string

  assert_contains(html, "mode=\"create\"")
  assert_contains(html, "parent-card-id=\"42\"")
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
        pool: member_pool.Model(..pool, card_show_open: opt.Some(1)),
      )
    })

  let html =
    admin_view.view_cards(model, opt.Some(sample_project()))
    |> element.to_document_string

  assert_contains(html, "card-show")
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
    |> element.to_document_string

  assert_not_contains(html, "card-crud-dialog")
}
