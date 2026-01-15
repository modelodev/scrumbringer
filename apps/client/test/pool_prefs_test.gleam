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
  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "k",
    False,
    True,
    False,
    True,
    False,
  ))
  |> should.equal(pool_prefs.NoAction)

  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "k",
    False,
    True,
    False,
    False,
    True,
  ))
  |> should.equal(pool_prefs.NoAction)
}

pub fn shortcut_action_maps_core_shortcuts_test() {
  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "F",
    True,
    False,
    True,
    False,
    False,
  ))
  |> should.equal(pool_prefs.ToggleFilters)

  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "k",
    False,
    True,
    False,
    False,
    False,
  ))
  |> should.equal(pool_prefs.FocusSearch)

  pool_prefs.shortcut_action(pool_prefs.KeyEvent(
    "n",
    False,
    False,
    False,
    False,
    False,
  ))
  |> should.equal(pool_prefs.OpenCreate)
}
