import lustre/element.{type Element}

import scrumbringer_client/client_state/member/positions as positions_state
import scrumbringer_client/features/pool/position_edit_dialog
import scrumbringer_client/i18n/locale.{type Locale}

pub fn view(
  locale: Locale,
  positions: positions_state.Model,
  on_close: msg,
  on_x_changed: fn(String) -> msg,
  on_y_changed: fn(String) -> msg,
  on_submit: msg,
) -> Element(msg) {
  position_edit_dialog.view(from_state(
    locale,
    positions,
    on_close,
    on_x_changed,
    on_y_changed,
    on_submit,
  ))
}

pub fn from_state(
  locale: Locale,
  positions: positions_state.Model,
  on_close: msg,
  on_x_changed: fn(String) -> msg,
  on_y_changed: fn(String) -> msg,
  on_submit: msg,
) -> position_edit_dialog.Config(msg) {
  position_edit_dialog.Config(
    locale: locale,
    x: positions.member_position_edit_x,
    y: positions.member_position_edit_y,
    error: positions.member_position_edit_error,
    in_flight: positions.member_position_edit_in_flight,
    on_close: on_close,
    on_x_changed: on_x_changed,
    on_y_changed: on_y_changed,
    on_submit: on_submit,
  )
}
