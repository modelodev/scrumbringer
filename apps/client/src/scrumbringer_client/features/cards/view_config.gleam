//// Root-state adapter for member cards views.

import gleam/option

import domain/card.{type Card}
import domain/project.{type Project}
import domain/task.{type Task}
import domain/user.{type User}

import scrumbringer_client/client_state/member/pool as pool_state
import scrumbringer_client/features/cards/detail_modal_entry
import scrumbringer_client/features/cards/view
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/permissions
import scrumbringer_client/state/normalized_store

pub fn from_state(
  locale: Locale,
  cards: List(Card),
  pool: pool_state.Model,
  detail_card: option.Option(Card),
  current_user: option.Option(User),
  selected_project: option.Option(Project),
  on_card_opened: fn(Int) -> msg,
  on_create_task_in_card: fn(Int) -> msg,
  on_detail_closed: msg,
) -> view.Config(msg) {
  view.Config(
    locale: locale,
    cards: cards,
    pending_count: normalized_store.pending(pool.member_cards_store),
    detail_card: detail_card,
    detail_tasks: selected_detail_card_tasks(pool),
    current_user_id: current_user |> option.map(fn(user) { user.id }),
    can_manage_notes: can_manage_notes(current_user, selected_project),
    on_card_opened: on_card_opened,
    on_create_task_in_card: on_create_task_in_card,
    on_detail_closed: on_detail_closed,
  )
}

fn can_manage_notes(
  current_user: option.Option(User),
  selected_project: option.Option(Project),
) -> Bool {
  is_org_admin(current_user) || is_project_manager(selected_project)
}

fn is_org_admin(current_user: option.Option(User)) -> Bool {
  case current_user {
    option.Some(user) -> permissions.is_org_admin(user.org_role)
    option.None -> False
  }
}

fn is_project_manager(selected_project: option.Option(Project)) -> Bool {
  case selected_project {
    option.Some(project) -> permissions.is_project_manager(project)
    option.None -> False
  }
}

fn selected_detail_card_tasks(pool: pool_state.Model) -> List(Task) {
  case pool.card_detail_open {
    option.Some(card_id) ->
      detail_modal_entry.tasks_for_card(pool.member_tasks, card_id)
    option.None -> []
  }
}
