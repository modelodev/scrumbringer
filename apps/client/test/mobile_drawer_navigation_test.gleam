import domain/view_mode
import gleam/option as opt
import lustre/effect
import scrumbringer_client/capability_scope
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/client_update
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/url_state
import support/assertions.{assert_equal}

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

pub fn navigate_to_plan_structure_ignores_inherited_work_search_test() {
  let route =
    url_state.empty()
    |> url_state.with_project(7)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_plan_mode(url_state.PlanStructureParam)
    |> url_state.with_search(opt.Some("rollout"))
    |> router.Member

  let #(next_model, _) =
    client_update.update(
      client_state.default_model(),
      client_state.NavigateTo(route, client_state.Push),
    )

  next_model.member.pool.view_mode |> assert_equal(view_mode.Cards)
  next_model.member.pool.member_plan_mode
  |> assert_equal(member_pool.PlanStructure)
  next_model.member.pool.member_filters_q |> assert_equal("")
}

pub fn navigate_to_plan_kanban_preserves_visible_work_search_test() {
  let route =
    url_state.empty()
    |> url_state.with_project(7)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_plan_mode(url_state.PlanKanbanParam)
    |> url_state.with_capability_scope(capability_scope.MyCapabilities)
    |> url_state.with_search(opt.Some("rollout"))
    |> router.Member

  let #(next_model, _) =
    client_update.update(
      client_state.default_model(),
      client_state.NavigateTo(route, client_state.Push),
    )

  next_model.member.pool.view_mode |> assert_equal(view_mode.Cards)
  next_model.member.pool.member_plan_mode
  |> assert_equal(member_pool.PlanKanban)
  next_model.member.pool.member_capability_scope
  |> assert_equal(capability_scope.MyCapabilities)
  next_model.member.pool.member_filters_q |> assert_equal("rollout")
}

pub fn plan_structure_clean_route_matches_current_route_test() {
  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(
        ..core,
        page: client_state.Member,
        selected_project_id: opt.Some(7),
      )
    })
    |> client_state.update_member(fn(member) {
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..member.pool,
          view_mode: view_mode.Cards,
          member_plan_mode: member_pool.PlanStructure,
          member_capability_scope: capability_scope.MyCapabilities,
          member_filters_type_id: opt.Some(2),
          member_filters_capability_id: opt.Some(3),
          member_filters_q: "rollout",
        ),
      )
    })
    |> client_state.update_ui(fn(ui) {
      ui_state.UiModel(..ui, mobile_drawer: ui_state.DrawerLeftOpen)
    })
  let route =
    url_state.empty()
    |> url_state.with_project(7)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_plan_mode(url_state.PlanStructureParam)
    |> router.Member

  let #(next_model, fx) =
    client_update.update(
      model,
      client_state.NavigateTo(route, client_state.Push),
    )

  next_model.ui.mobile_drawer |> assert_equal(ui_state.DrawerLeftOpen)
  let assert True = fx == effect.none()
}

pub fn navigate_to_current_route_is_noop_test() {
  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(
        ..core,
        page: client_state.Member,
        selected_project_id: opt.Some(7),
      )
    })
    |> client_state.update_member(fn(member) {
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..member.pool,
          view_mode: view_mode.People,
          member_plan_scope_kind: member_pool.PlanScopeCard,
          member_plan_scope_card_id: opt.Some(42),
        ),
      )
    })
    |> client_state.update_ui(fn(ui) {
      ui_state.UiModel(..ui, mobile_drawer: ui_state.DrawerLeftOpen)
    })
  let route =
    url_state.empty()
    |> url_state.with_project(7)
    |> url_state.with_view(view_mode.People)
    |> url_state.with_card_work_scope(42)
    |> router.Member

  let #(next_model, fx) =
    client_update.update(
      model,
      client_state.NavigateTo(route, client_state.Push),
    )

  next_model.ui.mobile_drawer |> assert_equal(ui_state.DrawerLeftOpen)
  next_model.member.pool.member_plan_scope_card_id
  |> assert_equal(opt.Some(42))
  let assert True = fx == effect.none()
}
