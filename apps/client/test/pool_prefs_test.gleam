import gleam/option.{None, Some}
import scrumbringer_client/pool_prefs

pub fn decode_filters_visibility_rejects_empty_test() {
  let assert None = pool_prefs.decode_filters_visibility("")
}

pub fn decode_filters_visibility_parses_true_false_test() {
  let assert Some(pool_prefs.FiltersVisible) =
    pool_prefs.decode_filters_visibility("true")
  let assert Some(pool_prefs.FiltersHidden) =
    pool_prefs.decode_filters_visibility("false")
}

pub fn view_mode_storage_roundtrip_test() {
  let assert pool_prefs.ViewModeStored(pool_prefs.Canvas) =
    pool_prefs.decode_view_mode_storage(pool_prefs.encode_view_mode_storage(
      pool_prefs.Canvas,
    ))

  let assert pool_prefs.ViewModeStored(pool_prefs.List) =
    pool_prefs.decode_view_mode_storage(pool_prefs.encode_view_mode_storage(
      pool_prefs.List,
    ))
}

pub fn decode_view_mode_storage_rejects_unknown_test() {
  let assert pool_prefs.ViewModeInvalid("unknown") =
    pool_prefs.decode_view_mode_storage("unknown")
}

pub fn shortcut_action_ignores_when_editing_or_modal_test() {
  let assert pool_prefs.NoAction =
    pool_prefs.shortcut_action(pool_prefs.KeyEvent(
      "f",
      False,
      False,
      False,
      True,
      False,
    ))

  let assert pool_prefs.NoAction =
    pool_prefs.shortcut_action(pool_prefs.KeyEvent(
      "n",
      False,
      False,
      False,
      False,
      True,
    ))
}

pub fn shortcut_action_maps_core_shortcuts_test() {
  let assert pool_prefs.ToggleFilters =
    pool_prefs.shortcut_action(pool_prefs.KeyEvent(
      "f",
      False,
      False,
      False,
      False,
      False,
    ))

  let assert pool_prefs.FocusSearch =
    pool_prefs.shortcut_action(pool_prefs.KeyEvent(
      "/",
      False,
      False,
      False,
      False,
      False,
    ))

  let assert pool_prefs.OpenCreate =
    pool_prefs.shortcut_action(pool_prefs.KeyEvent(
      "n",
      False,
      False,
      False,
      False,
      False,
    ))

  let assert pool_prefs.CloseDialog =
    pool_prefs.shortcut_action(pool_prefs.KeyEvent(
      "Escape",
      False,
      False,
      False,
      False,
      False,
    ))
}

pub fn shortcut_action_ignores_keys_with_modifiers_test() {
  let assert pool_prefs.NoAction =
    pool_prefs.shortcut_action(pool_prefs.KeyEvent(
      "n",
      True,
      False,
      False,
      False,
      False,
    ))

  let assert pool_prefs.NoAction =
    pool_prefs.shortcut_action(pool_prefs.KeyEvent(
      "f",
      False,
      True,
      False,
      False,
      False,
    ))

  let assert pool_prefs.NoAction =
    pool_prefs.shortcut_action(pool_prefs.KeyEvent(
      "/",
      False,
      False,
      True,
      False,
      False,
    ))
}
