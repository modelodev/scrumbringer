import gleam/option as opt
import gleam/string
import gleeunit/should
import lustre/element

import domain/card.{Card, Pendiente}
import domain/milestone.{Milestone, MilestoneProgress, Ready}
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
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/view as admin_view

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
  )
}

fn sample_card() {
  Card(
    id: 1,
    project_id: 1,
    milestone_id: opt.None,
    title: "Playwright Card",
    description: "",
    color: opt.None,
    state: Pendiente,
    task_count: 1,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    has_new_notes: False,
  )
}

fn sample_milestone_progress() {
  MilestoneProgress(
    milestone: Milestone(
      id: 89,
      project_id: 1,
      name: "Milestone 89",
      description: opt.None,
      state: Ready,
      position: 1,
      created_by: 1,
      created_at: "2026-01-01",
      activated_at: opt.None,
      completed_at: opt.None,
    ),
    cards_total: 0,
    cards_completed: 0,
    tasks_total: 0,
    tasks_completed: 0,
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

  string.contains(html, "card-title-button") |> should.be_true
  string.contains(html, "card-detail-open") |> should.be_true
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
        pool: member_pool.Model(..pool, card_detail_open: opt.Some(1)),
      )
    })

  let html =
    admin_view.view_cards(model, opt.Some(sample_project()))
    |> element.to_document_string

  string.contains(html, "card-detail-modal") |> should.be_true
}

pub fn cards_view_passes_milestone_context_to_dialog_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(
          ..cards,
          cards_dialog_mode: opt.Some(state_types.CardDialogCreate),
          cards_create_milestone_id: opt.Some(89),
        ),
      )
    })
    |> update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones: Loaded([sample_milestone_progress()]),
        ),
      )
    })

  let html =
    admin_view.view_card_crud_dialog(model, 1)
    |> element.to_document_string

  string.contains(html, "milestone-id=\"89\"") |> should.be_true
  string.contains(html, "milestone-name=\"Milestone 89\"") |> should.be_true
}

pub fn cards_view_without_context_keeps_milestone_attributes_empty_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(
          ..cards,
          cards_dialog_mode: opt.Some(state_types.CardDialogCreate),
          cards_create_milestone_id: opt.None,
        ),
      )
    })

  let html =
    admin_view.view_card_crud_dialog(model, 1)
    |> element.to_document_string

  string.contains(html, "milestone-id=\"89\"") |> should.be_false
  string.contains(html, "milestone-name=\"Milestone 89\"") |> should.be_false
}
