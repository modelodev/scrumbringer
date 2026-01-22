//// TruncatedText component for displaying text with tooltip on truncation.
////
//// Shows truncated text with "..." and displays full text in a tooltip
//// when the text exceeds the specified maximum length.
////
//// ## Usage
////
//// ```gleam
//// truncated_text.view("Very long text here", 20)
//// // Renders: "Very long text here..." with tooltip showing full text
//// ```

import lustre/attribute.{attribute, class}
import lustre/element.{type Element}
import lustre/element/html.{span, text}

import scrumbringer_client/utils/text as text_utils

// =============================================================================
// Public API
// =============================================================================

/// Render text that truncates at max_len with tooltip showing full text.
///
/// If the text is shorter than max_len, renders without tooltip.
/// If truncated, adds a data-tooltip attribute with the full text.
pub fn view(content: String, max_len: Int) -> Element(msg) {
  let #(truncated, was_truncated) = text_utils.truncate_with_info(content, max_len)

  case was_truncated {
    True ->
      span(
        [
          class("truncated-text"),
          attribute("data-tooltip", content),
          attribute("title", content),
        ],
        [text(truncated)],
      )
    False -> span([class("truncated-text")], [text(content)])
  }
}

/// Render URL text that truncates at max_len with full URL in tooltip.
///
/// Same as view but uses URL-specific styling.
pub fn url(content: String, max_len: Int) -> Element(msg) {
  let #(truncated, was_truncated) = text_utils.truncate_with_info(content, max_len)

  case was_truncated {
    True ->
      span(
        [
          class("truncated-text truncated-url"),
          attribute("data-tooltip", content),
          attribute("title", content),
        ],
        [text(truncated)],
      )
    False -> span([class("truncated-text truncated-url")], [text(content)])
  }
}

/// Render text that truncates with custom CSS class.
pub fn with_class(
  content: String,
  max_len: Int,
  extra_class: String,
) -> Element(msg) {
  let #(truncated, was_truncated) = text_utils.truncate_with_info(content, max_len)

  case was_truncated {
    True ->
      span(
        [
          class("truncated-text " <> extra_class),
          attribute("data-tooltip", content),
          attribute("title", content),
        ],
        [text(truncated)],
      )
    False -> span([class("truncated-text " <> extra_class)], [text(content)])
  }
}
