//// UI-specific client state model.

import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme
import scrumbringer_client/ui/toast

/// Represents UiModel.
pub type UiModel {
  UiModel(
    is_mobile: Bool,
    toast_state: toast.ToastState,
    theme: theme.Theme,
    locale: i18n_locale.Locale,
    mobile_drawer: MobileDrawerState,
    sidebar_collapse: SidebarCollapse,
    preferences_popup_open: Bool,
  )
}

/// Represents MobileDrawerState.
pub type MobileDrawerState {
  DrawerClosed
  DrawerLeftOpen
  DrawerRightOpen
}

/// Represents SidebarCollapse.
pub type SidebarCollapse {
  NoneCollapsed
  ConfigCollapsed
  OrgCollapsed
  BothCollapsed
}

/// Provides default UI model state.
pub fn default_model() -> UiModel {
  UiModel(
    is_mobile: False,
    toast_state: toast.init(),
    theme: theme.Default,
    locale: i18n_locale.En,
    mobile_drawer: DrawerClosed,
    sidebar_collapse: BothCollapsed,
    preferences_popup_open: False,
  )
}

pub fn sidebar_collapse_from_bools(config: Bool, org: Bool) -> SidebarCollapse {
  case config, org {
    True, True -> BothCollapsed
    True, False -> ConfigCollapsed
    False, True -> OrgCollapsed
    False, False -> NoneCollapsed
  }
}

pub fn sidebar_collapse_to_bools(state: SidebarCollapse) -> #(Bool, Bool) {
  case state {
    NoneCollapsed -> #(False, False)
    ConfigCollapsed -> #(True, False)
    OrgCollapsed -> #(False, True)
    BothCollapsed -> #(True, True)
  }
}

pub fn sidebar_config_collapsed(state: SidebarCollapse) -> Bool {
  let #(config, _org) = sidebar_collapse_to_bools(state)
  config
}

pub fn sidebar_org_collapsed(state: SidebarCollapse) -> Bool {
  let #(_config, org) = sidebar_collapse_to_bools(state)
  org
}

pub fn toggle_sidebar_config(state: SidebarCollapse) -> SidebarCollapse {
  let #(config, org) = sidebar_collapse_to_bools(state)
  sidebar_collapse_from_bools(!config, org)
}

pub fn toggle_sidebar_org(state: SidebarCollapse) -> SidebarCollapse {
  let #(config, org) = sidebar_collapse_to_bools(state)
  sidebar_collapse_from_bools(config, !org)
}

pub fn mobile_drawer_left_open(state: MobileDrawerState) -> Bool {
  case state {
    DrawerLeftOpen -> True
    _ -> False
  }
}

pub fn mobile_drawer_right_open(state: MobileDrawerState) -> Bool {
  case state {
    DrawerRightOpen -> True
    _ -> False
  }
}

pub fn toggle_left_drawer(state: MobileDrawerState) -> MobileDrawerState {
  case state {
    DrawerLeftOpen -> DrawerClosed
    _ -> DrawerLeftOpen
  }
}

pub fn toggle_right_drawer(state: MobileDrawerState) -> MobileDrawerState {
  case state {
    DrawerRightOpen -> DrawerClosed
    _ -> DrawerRightOpen
  }
}

pub fn close_drawers(_state: MobileDrawerState) -> MobileDrawerState {
  DrawerClosed
}
