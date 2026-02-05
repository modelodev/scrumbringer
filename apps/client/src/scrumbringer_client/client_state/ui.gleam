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
