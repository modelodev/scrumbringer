import gleeunit/should

import scrumbringer_client/pool_prefs

pub fn deserialize_bool_defaults_when_empty_test() {
  pool_prefs.deserialize_bool("", True)
  |> should.equal(True)

  pool_prefs.deserialize_bool("", False)
  |> should.equal(False)
}

pub fn deserialize_bool_parses_true_false_test() {
  pool_prefs.deserialize_bool("true", False)
  |> should.equal(True)

  pool_prefs.deserialize_bool("false", True)
  |> should.equal(False)
}

pub fn view_mode_roundtrip_test() {
  pool_prefs.deserialize_view_mode(pool_prefs.serialize_view_mode(
    pool_prefs.Canvas,
  ))
  |> should.equal(pool_prefs.Canvas)

  pool_prefs.deserialize_view_mode(pool_prefs.serialize_view_mode(
    pool_prefs.List,
  ))
  |> should.equal(pool_prefs.List)
}

pub fn shortcut_action_ignores_when_editing_or_modal_test() {
  // f should be ignored when editing
  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "f",
    False,
    False,
    False,
    True,
    False,
  ))
  |> should.equal(pool_prefs.NoAction)

  // n should be ignored when modal is open
  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "n",
    False,
    False,
    False,
    False,
    True,
  ))
  |> should.equal(pool_prefs.NoAction)
}

pub fn shortcut_action_maps_core_shortcuts_test() {
  // f -> ToggleFilters (AC40)
  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "f",
    False,
    False,
    False,
    False,
    False,
  ))
  |> should.equal(pool_prefs.ToggleFilters)

  // / -> FocusSearch (AC40)
  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "/",
    False,
    False,
    False,
    False,
    False,
  ))
  |> should.equal(pool_prefs.FocusSearch)

  // n -> OpenCreate (AC40)
  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "n",
    False,
    False,
    False,
    False,
    False,
  ))
  |> should.equal(pool_prefs.OpenCreate)

  // Escape -> CloseDialog (AC40)
  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "Escape",
    False,
    False,
    False,
    False,
    False,
  ))
  |> should.equal(pool_prefs.CloseDialog)
}

pub fn shortcut_action_ignores_keys_with_modifiers_test() {
  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "n",
    True,
    False,
    False,
    False,
    False,
  ))
  |> should.equal(pool_prefs.NoAction)

  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "f",
    False,
    True,
    False,
    False,
    False,
  ))
  |> should.equal(pool_prefs.NoAction)

  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "/",
    False,
    False,
    True,
    False,
    False,
  ))
  |> should.equal(pool_prefs.NoAction)
}
