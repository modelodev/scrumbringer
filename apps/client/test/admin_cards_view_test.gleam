import gleam/json
import gleam/list
import gleam/option as opt
import gleam/string
import support/domain_fixtures
import support/render_assertions

import domain/card.{Card}
import domain/project.{Project}
import domain/remote.{Loaded}
import lustre/element.{type Element}
import lustre/vdom/vattr
import lustre/vdom/vnode
import scrumbringer_client/client_state.{
  type Model, CoreModel, default_model, update_admin, update_core, update_member,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/state/normalized_store

fn base_model() -> Model {
  default_model()
  |> update_core(fn(core) {
    CoreModel(..core, selected_project_id: opt.Some(1))
  })
}

fn sample_project() {
  Project(..domain_fixtures.project(1, "Project Alpha"), members_count: 2)
}

fn sample_card() {
  Card(..domain_fixtures.card(1, 1, "Playwright Card"), task_count: 1)
}

fn card_crud_dialog_has_card_property(view: Element(msg), title: String) -> Bool {
  case view {
    vnode.Element(tag: "card-crud-dialog", attributes:, ..) ->
      list.any(attributes, fn(attribute) {
        case attribute {
          vattr.Property(name: "card", value:, ..) ->
            json.to_string(value)
            |> string.contains("\"title\":\"" <> title <> "\"")
          _ -> False
        }
      })
    vnode.Map(child:, ..) -> card_crud_dialog_has_card_property(child, title)
    _ -> False
  }
}

fn card_crud_dialog_has_attribute(
  view: Element(msg),
  name: String,
  value: String,
) -> Bool {
  case view {
    vnode.Element(tag: "card-crud-dialog", attributes:, ..) ->
      list.any(attributes, fn(attribute) {
        case attribute {
          vattr.Attribute(name: attr_name, value: attr_value, ..) ->
            attr_name == name && attr_value == value
          _ -> False
        }
      })
    vnode.Map(child:, ..) -> card_crud_dialog_has_attribute(child, name, value)
    _ -> False
  }
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

pub fn cards_view_keeps_delete_available_for_cards_with_tasks_test() {
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
  render_assertions.contains(html, "aria-label=\"Delete Card\"")
  render_assertions.not_contains(html, "btn-delete-blocked")
  render_assertions.not_contains(html, "aria-disabled=\"true\"")
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

pub fn card_crud_delete_dialog_uses_member_card_cache_when_admin_cards_are_not_loaded_test() {
  let card = Card(..sample_card(), task_count: 0)
  let store =
    normalized_store.new()
    |> normalized_store.upsert(1, [card], domain_fixtures.card_id)

  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(
          ..cards,
          cards_dialog_mode: opt.Some(admin_cards.CardDialogDelete(1)),
        ),
      )
    })
    |> update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_cards_store: store),
      )
    })

  let view = admin_view.view_card_crud_dialog(model, 1)
  let html = render_assertions.html(view)

  render_assertions.contains(html, "card-crud-dialog")
  render_assertions.contains(html, "mode=\"delete\"")
  let assert True = card_crud_dialog_has_card_property(view, "Playwright Card")
}

pub fn card_crud_delete_dialog_passes_delete_impact_counts_test() {
  let parent = Card(..sample_card(), task_count: 3)
  let child =
    Card(
      ..domain_fixtures.card(2, 1, "Child Card"),
      parent_card_id: opt.Some(parent.id),
      task_count: 4,
    )
  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(
          ..cards,
          cards: Loaded([parent, child]),
          cards_dialog_mode: opt.Some(admin_cards.CardDialogDelete(parent.id)),
        ),
      )
    })

  let html = admin_view.view_card_crud_dialog(model, 1)

  let assert True =
    card_crud_dialog_has_attribute(html, "delete-task-count", "7")
  let assert True =
    card_crud_dialog_has_attribute(html, "delete-subcard-count", "1")
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
