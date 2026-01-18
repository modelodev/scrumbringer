//// Shared layout components for page structure.
////
//// ## Mission
////
//// Provides reusable layout primitives for consistent page structure
//// across the application.
////
//// ## Responsibilities
////
//// - Page wrapper with consistent styling
//// - Section containers for content grouping
//// - Theme/locale switcher components
////
//// ## Non-responsibilities
////
//// - Feature-specific layouts (admin topbar, member nav)
//// - Content rendering (see features/*/view.gleam)
////
//// ## Relations
////
//// - **features/*/view.gleam**: Feature views use these layout helpers
//// - **theme.gleam**: Provides theme types and serialization
//// - **i18n/**: Provides locale types and text translations

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, label, option, select, text}
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme

/// Renders a theme selector dropdown.
///
/// ## Parameters
///
/// - `locale`: Current locale for labels
/// - `current_theme`: Currently selected theme
/// - `on_change`: Message to emit when theme changes
pub fn theme_switch(
  locale: i18n_locale.Locale,
  current_theme: theme.Theme,
  on_change: fn(String) -> msg,
) -> Element(msg) {
  let current = theme.serialize(current_theme)

  label([attribute.class("theme-switch")], [
    text(i18n.t(locale, i18n_text.ThemeLabel)),
    select([attribute.value(current), event.on_input(on_change)], [
      option(
        [attribute.value("default")],
        i18n.t(locale, i18n_text.ThemeDefault),
      ),
      option([attribute.value("dark")], i18n.t(locale, i18n_text.ThemeDark)),
    ]),
  ])
}

/// Renders a locale selector dropdown.
///
/// ## Parameters
///
/// - `locale`: Current locale for labels and selection
/// - `on_change`: Message to emit when locale changes
pub fn locale_switch(
  locale: i18n_locale.Locale,
  on_change: fn(String) -> msg,
) -> Element(msg) {
  let current = i18n_locale.serialize(locale)

  label([attribute.class("theme-switch")], [
    text(i18n.t(locale, i18n_text.LanguageLabel)),
    select([attribute.value(current), event.on_input(on_change)], [
      option([attribute.value("es")], i18n.t(locale, i18n_text.LanguageEs)),
      option([attribute.value("en")], i18n.t(locale, i18n_text.LanguageEn)),
    ]),
  ])
}

/// Renders an empty placeholder div.
///
/// Useful for conditional rendering where an empty element is needed.
pub fn empty() -> Element(msg) {
  element.none()
}

/// Renders a section container with optional title.
///
/// ## Parameters
///
/// - `class`: CSS class for the section
/// - `children`: Child elements to render
pub fn section(class: String, children: List(Element(msg))) -> Element(msg) {
  div([attribute.class(class)], children)
}
