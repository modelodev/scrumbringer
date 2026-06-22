import domain/view_mode
import gleam/option as opt
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/client_update
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/url_state

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

pub fn navigate_to_closes_mobile_drawers_test() {
  let model =
    client_state.default_model()
    |> client_state.update_ui(fn(ui) {
      ui_state.UiModel(..ui, mobile_drawer: ui_state.DrawerLeftOpen)
    })

  let #(next_model, _) =
    client_update.update(
      model,
      client_state.NavigateTo(
        router.Org(permissions.Invites),
        client_state.Push,
      ),
    )

  next_model.ui.mobile_drawer
  |> assert_equal(ui_state.DrawerClosed)
}

pub fn navigate_to_member_depth_updates_cards_view_and_depth_test() {
  let route =
    url_state.empty()
    |> url_state.with_project(7)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_card_depth(opt.Some(2))
    |> router.Member

  let #(next_model, _) =
    client_update.update(
      client_state.default_model(),
      client_state.NavigateTo(route, client_state.Push),
    )

  next_model.core.page |> assert_equal(client_state.Member)
  next_model.core.selected_project_id |> assert_equal(opt.Some(7))
  next_model.member.pool.view_mode |> assert_equal(view_mode.Cards)
  next_model.member.pool.member_card_depth_filter |> assert_equal(opt.Some(2))
}

pub fn navigate_from_depth_to_cards_route_clears_depth_test() {
  let depth_route =
    url_state.empty()
    |> url_state.with_project(7)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_card_depth(opt.Some(2))
    |> router.Member
  let cards_route =
    url_state.empty()
    |> url_state.with_project(7)
    |> url_state.with_view(view_mode.Cards)
    |> router.Member

  let #(depth_model, _) =
    client_update.update(
      client_state.default_model(),
      client_state.NavigateTo(depth_route, client_state.Push),
    )
  let #(next_model, _) =
    client_update.update(
      depth_model,
      client_state.NavigateTo(cards_route, client_state.Push),
    )

  next_model.member.pool.view_mode |> assert_equal(view_mode.Cards)
  next_model.member.pool.member_card_depth_filter |> assert_equal(opt.None)
}

pub fn navigate_to_card_work_scope_sets_plan_scope_card_test() {
  let route =
    url_state.empty()
    |> url_state.with_project(7)
    |> url_state.with_view(view_mode.People)
    |> url_state.with_card_work_scope(42)
    |> router.Member

  let #(next_model, _) =
    client_update.update(
      client_state.default_model(),
      client_state.NavigateTo(route, client_state.Push),
    )

  next_model.core.page |> assert_equal(client_state.Member)
  next_model.core.selected_project_id |> assert_equal(opt.Some(7))
  next_model.member.pool.view_mode |> assert_equal(view_mode.People)
  next_model.member.pool.member_plan_scope_kind
  |> assert_equal(member_pool.PlanScopeCard)
  next_model.member.pool.member_plan_scope_card_id |> assert_equal(opt.Some(42))
}
