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
//// - **CRUD dialogs**: Use `view_dialog(title, icon, on_close)` for simple dialog headers
//// - **Detail modals**: Use `view_detail()` for modals with meta/progress
//// - **New modals**: Use `view()` or `view_simple()` for standard headers
//// - **Existing modals with custom CSS**: Use `view_extended()` with `ExtendedConfig`
////
//// ## Convenience Functions
////
//// - `view_simple(title, on_close)` - Minimal header with title only
//// - `view_dialog(title, icon, on_close)` - CRUD dialog style, flat structure
//// - `view_dialog_with_icon(title, icon, on_close)` - CRUD dialog with icon in title wrapper
//// - `view_detail(config)` - Detail modal style with meta row and progress
////
//// ## Adoption
////
//// - `task_type_crud_dialog.gleam` - uses `view_dialog()`
//// - `workflow_crud_dialog.gleam` - uses `view_dialog_with_icon()`
//// - `rule_crud_dialog.gleam` - uses `view_dialog_with_icon()`
//// - `task_template_crud_dialog.gleam` - uses `view_dialog_with_icon()`
//// - `card_crud_dialog.gleam` - uses `view_dialog_with_icon()`
////
//// ## Usage
////
//// ```gleam
//// // CRUD dialog header (h3, close button after title)
//// modal_header.view_dialog("Create Task", Some(icons.add()), CloseClicked)
////
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
//// // Detail modal with custom CSS classes
//// modal_header.view_extended(modal_header.ExtendedConfig(
////   title: "Task Details",
////   title_element: TitleSpan,
////   close_position: CloseBeforeTitle,
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
import lustre/element/html.{div, h2, h3, span, text}

import scrumbringer_client/ui/modal_close_button

// =============================================================================
// Types
// =============================================================================

/// Title element type - controls which HTML tag wraps the title.
pub type TitleElement {
  /// Use h2 for main modal headers (default for view/view_simple)
  TitleH2
  /// Use h3 for dialog headers (CRUD modals, smaller dialogs)
  TitleH3
  /// Use span for detail modals where title is part of a larger heading
  TitleSpan
}

/// Close button position relative to title.
pub type ClosePosition {
  /// Close button after title: [Title] [X] (default for view/view_simple)
  CloseAfterTitle
  /// Close button before title: [X] [Title] (common in dialogs)
  CloseBeforeTitle
}

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
    /// Title element type (h2, h3, or span)
    title_element: TitleElement,
    /// Close button position (before or after title)
    close_position: ClosePosition,
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
  let close_button =
    modal_close_button.view_with_class(
      config.close_button_class,
      config.on_close,
    )

  let title_content = [
    case config.icon {
      Some(icon) -> div([attribute.class("modal-header-icon")], [icon])
      None -> element.none()
    },
    render_title_element(config.title_element, config.title_id, config.title),
  ]

  let title_row_children = case config.close_position {
    CloseBeforeTitle -> [
      close_button,
      div([attribute.class(config.title_class)], title_content),
    ]
    CloseAfterTitle -> [
      div([attribute.class(config.title_class)], title_content),
      close_button,
    ]
  }

  div(
    [
      attribute.class(config.header_class),
      attribute.attribute("role", "banner"),
    ],
    [
      // Title row with configurable close button position
      div([attribute.class(config.title_row_class)], title_row_children),
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
    title_element: TitleH2,
    close_position: CloseAfterTitle,
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

/// Render a CRUD dialog header with h3 title and close button after title.
/// Uses flat structure: div.dialog-header > [h3, button] (no nested wrapper).
/// Use this for simple dialogs like task_type_crud_dialog.
pub fn view_dialog(
  title: String,
  icon: Option(Element(msg)),
  on_close: msg,
) -> Element(msg) {
  div(
    [
      attribute.class("dialog-header"),
      attribute.attribute("role", "banner"),
    ],
    [
      case icon {
        Some(i) -> div([attribute.class("modal-header-icon")], [i])
        None -> element.none()
      },
      h3([attribute.id("dialog-title")], [text(title)]),
      modal_close_button.view_with_class("dialog-close", on_close),
    ],
  )
}

/// Render a CRUD dialog header with icon wrapped in dialog-title div.
/// Structure: div.dialog-header > [div.dialog-title > [span.dialog-icon, h3], button]
/// Use this for workflow_crud_dialog, rule_crud_dialog, task_template_crud_dialog, card_crud_dialog.
pub fn view_dialog_with_icon(
  title: String,
  icon: Element(msg),
  on_close: msg,
) -> Element(msg) {
  div(
    [
      attribute.class("dialog-header"),
      attribute.attribute("role", "banner"),
    ],
    [
      div([attribute.class("dialog-title")], [
        span([attribute.class("dialog-icon")], [icon]),
        h3([attribute.id("dialog-title")], [text(title)]),
      ]),
      modal_close_button.view_with_class("btn-icon dialog-close", on_close),
    ],
  )
}

/// Configuration for detail modal headers.
pub type DetailConfig(msg) {
  DetailConfig(
    /// The main title text
    title: String,
    /// Optional icon element
    icon: Option(Element(msg)),
    /// Optional metadata element (e.g., "2/10 completadas")
    meta: Option(Element(msg)),
    /// Optional progress indicator element
    progress: Option(Element(msg)),
    /// Message to emit when close button is clicked
    on_close: msg,
    /// CSS class prefix for all elements (e.g., "task-detail" or "card-detail")
    class_prefix: String,
  )
}

/// Render a detail modal header with meta row and optional progress.
/// Use this for card_detail_modal and task detail views.
pub fn view_detail(config: DetailConfig(msg)) -> Element(msg) {
  view_extended(ExtendedConfig(
    title: config.title,
    title_element: TitleSpan,
    close_position: CloseBeforeTitle,
    icon: config.icon,
    badges: [],
    meta: config.meta,
    progress: config.progress,
    on_close: config.on_close,
    header_class: config.class_prefix <> "-header",
    title_row_class: config.class_prefix <> "-title-row",
    title_class: config.class_prefix <> "-title",
    title_id: config.class_prefix <> "-title",
    close_button_class: "modal-close btn-icon",
  ))
}

// =============================================================================
// Internal
// =============================================================================

fn render_title_element(
  element_type: TitleElement,
  id: String,
  title: String,
) -> Element(msg) {
  case element_type {
    TitleH2 -> h2([attribute.id(id)], [text(title)])
    TitleH3 -> h3([attribute.id(id)], [text(title)])
    TitleSpan -> span([attribute.id(id)], [text(title)])
  }
}

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
