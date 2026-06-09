import gleam/list

import scrumbringer_client/client_state/ui as ui_state

pub fn toggle_left_drawer_opens_when_closed_test() {
  let state = ui_state.DrawerClosed
  let new_state = ui_state.toggle_left_drawer(state)
  let assert ui_state.DrawerLeftOpen = new_state
}

pub fn toggle_left_drawer_closes_when_open_test() {
  let state = ui_state.DrawerLeftOpen
  let new_state = ui_state.toggle_left_drawer(state)
  let assert ui_state.DrawerClosed = new_state
}

pub fn toggle_right_drawer_opens_when_closed_test() {
  let state = ui_state.DrawerClosed
  let new_state = ui_state.toggle_right_drawer(state)
  let assert ui_state.DrawerRightOpen = new_state
}

pub fn close_drawers_closes_left_test() {
  let state = ui_state.DrawerLeftOpen
  let new_state = ui_state.close_drawers(state)
  let assert ui_state.DrawerClosed = new_state
}

pub fn close_drawers_closes_right_test() {
  let state = ui_state.DrawerRightOpen
  let new_state = ui_state.close_drawers(state)
  let assert ui_state.DrawerClosed = new_state
}

pub fn toggle_left_closes_right_first_test() {
  let state = ui_state.DrawerRightOpen
  let new_state = ui_state.toggle_left_drawer(state)
  let assert ui_state.DrawerLeftOpen = new_state
}

pub fn toggle_right_closes_left_first_test() {
  let state = ui_state.DrawerLeftOpen
  let new_state = ui_state.toggle_right_drawer(state)
  let assert ui_state.DrawerRightOpen = new_state
}

pub fn close_drawers_on_already_closed_is_idempotent_test() {
  let state = ui_state.DrawerClosed
  let new_state = ui_state.close_drawers(state)
  let assert ui_state.DrawerClosed = new_state
}

pub fn drawer_state_enum_is_exhaustive_test() {
  let states = [
    ui_state.DrawerClosed,
    ui_state.DrawerLeftOpen,
    ui_state.DrawerRightOpen,
  ]

  let assert 3 = list.length(states)
}
