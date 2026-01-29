//// Reusable modal header component.
////
//// ## Mission
////
//// Provides a consistent, configurable header for modals and detail views.
//// Supports: title, optional icon, badges list, metadata row, progress bar,
//// and a close button.
////
//// ## When to Use
////
//// - **New modals**: Use `view()` or `view_simple()` for new modal implementations
//// - **Existing modals with custom CSS**: Use `view_extended()` with `ExtendedConfig`
//// - **Quick prototypes**: Use `view_simple(title, on_close)` for minimal headers
////
//// ## Existing Modals (Not Using This Component)
////
//// - `card_detail_modal.gleam`: Uses custom header with progress bar
//// - `pool/dialogs.gleam`: Uses custom headers for task detail/creation
////
//// These use `modal_close_button` directly but have their own header structure.
////
//// ## Usage
////
//// ```gleam
//// // Simple header with title only
//// modal_header.view_simple("My Modal", CloseClicked)
////
//// // Full header with all options
//// modal_header.view(modal_header.Config(
////   title: card.title,
////   icon: None,
////   badges: [badge.view("Pendiente", badge.Warning)],
////   meta: Some(text("2/10 completadas")),
////   progress: Some(progress_bar.view(0.2)),
////   on_close: CloseClicked,
//// ))
////
//// // Extended with custom CSS classes (for integration with existing CSS)
//// modal_header.view_extended(modal_header.ExtendedConfig(
////   title: "Task Details",
////   icon: None,
////   badges: [],
////   meta: Some(meta_row),
////   progress: None,
////   on_close: CloseClicked,
////   header_class: "task-detail-header",
////   title_row_class: "task-detail-title-row",
////   title_class: "task-detail-title",
////   title_id: "task-detail-title",
////   close_button_class: "modal-close btn-icon",
//// ))
//// ```

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h2, text}

import scrumbringer_client/ui/modal_close_button

// =============================================================================
// Types
// =============================================================================

/// Configuration for the modal header.
pub type Config(msg) {
  Config(
    /// The main title text
    title: String,
    /// Optional icon element to display before title
    icon: Option(Element(msg)),
    /// List of badge elements to display (e.g., status badges)
    badges: List(Element(msg)),
    /// Optional metadata element (e.g., "2/10 completadas")
    meta: Option(Element(msg)),
    /// Optional progress indicator element
    progress: Option(Element(msg)),
    /// Message to emit when close button is clicked
    on_close: msg,
  )
}

/// Extended configuration with customizable CSS classes and title ID.
/// Use this when integrating with existing CSS that uses different class names.
pub type ExtendedConfig(msg) {
  ExtendedConfig(
    /// The main title text
    title: String,
    /// Optional icon element to display before title
    icon: Option(Element(msg)),
    /// List of badge elements to display (e.g., status badges)
    badges: List(Element(msg)),
    /// Optional metadata element (e.g., "2/10 completadas")
    meta: Option(Element(msg)),
    /// Optional progress indicator element
    progress: Option(Element(msg)),
    /// Message to emit when close button is clicked
    on_close: msg,
    /// CSS class for the header container (default: "modal-header")
    header_class: String,
    /// CSS class for the title row (default: "modal-header-title-row")
    title_row_class: String,
    /// CSS class for the title element (default: "modal-header-title")
    title_class: String,
    /// ID for the title element for aria-labelledby (default: "modal-title")
    title_id: String,
    /// CSS class for the close button (default: "btn-icon modal-close")
    close_button_class: String,
  )
}

// =============================================================================
// View
// =============================================================================

/// Render a modal header with all configured elements.
pub fn view(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("modal-header"),
      attribute.attribute("role", "banner"),
    ],
    [
      // Title row: icon + title + close button
      view_title_row(config),
      // Optional badges row
      view_badges(config.badges),
      // Optional meta/progress row
      view_meta_row(config),
    ],
  )
}

/// Render a simple header with just title and close button.
pub fn view_simple(title: String, on_close: msg) -> Element(msg) {
  view(Config(
    title: title,
    icon: None,
    badges: [],
    meta: None,
    progress: None,
    on_close: on_close,
  ))
}

/// Render a modal header with custom CSS classes.
/// Use this when integrating with existing CSS patterns.
pub fn view_extended(config: ExtendedConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class(config.header_class),
      attribute.attribute("role", "banner"),
    ],
    [
      // Title row: close button + icon + title
      div([attribute.class(config.title_row_class)], [
        modal_close_button.view_with_class(
          config.close_button_class,
          config.on_close,
        ),
        div([attribute.class(config.title_class)], [
          case config.icon {
            Some(icon) -> div([attribute.class("modal-header-icon")], [icon])
            None -> element.none()
          },
          h2([attribute.id(config.title_id)], [text(config.title)]),
        ]),
      ]),
      // Optional badges row
      view_badges(config.badges),
      // Optional meta/progress row
      view_meta_row_extended(config),
    ],
  )
}

/// Create default extended config from basic config.
pub fn extend(config: Config(msg)) -> ExtendedConfig(msg) {
  ExtendedConfig(
    title: config.title,
    icon: config.icon,
    badges: config.badges,
    meta: config.meta,
    progress: config.progress,
    on_close: config.on_close,
    header_class: "modal-header",
    title_row_class: "modal-header-title-row",
    title_class: "modal-header-title",
    title_id: "modal-title",
    close_button_class: "btn-icon modal-close",
  )
}

// =============================================================================
// Internal
// =============================================================================

fn view_title_row(config: Config(msg)) -> Element(msg) {
  div([attribute.class("modal-header-title-row")], [
    div([attribute.class("modal-header-title")], [
      case config.icon {
        Some(icon) -> div([attribute.class("modal-header-icon")], [icon])
        None -> element.none()
      },
      h2([attribute.id("modal-title")], [text(config.title)]),
    ]),
    modal_close_button.view(config.on_close),
  ])
}

fn view_badges(badges: List(Element(msg))) -> Element(msg) {
  case badges {
    [] -> element.none()
    _ -> div([attribute.class("modal-header-badges")], badges)
  }
}

fn view_meta_row(config: Config(msg)) -> Element(msg) {
  case config.meta, config.progress {
    None, None -> element.none()
    _, _ ->
      div([attribute.class("modal-header-meta")], [
        case config.meta {
          Some(m) -> m
          None -> element.none()
        },
        case config.progress {
          Some(p) -> div([attribute.class("modal-header-progress")], [p])
          None -> element.none()
        },
      ])
  }
}

fn view_meta_row_extended(config: ExtendedConfig(msg)) -> Element(msg) {
  case config.meta, config.progress {
    None, None -> element.none()
    _, _ ->
      div([attribute.class("modal-header-meta")], [
        case config.meta {
          Some(m) -> m
          None -> element.none()
        },
        case config.progress {
          Some(p) -> div([attribute.class("modal-header-progress")], [p])
          None -> element.none()
        },
      ])
  }
}
