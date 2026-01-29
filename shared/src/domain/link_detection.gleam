//// Link detection and URL parsing for notes.
////
//// ## Mission
////
//// Detect URLs in text and categorize them, with special handling for GitHub URLs.
//// Must be deterministic for SSR/hydration compatibility.
////
//// ## AC Coverage
////
//// - AC1: Detect URLs in text, make them clickable
//// - AC2: GitHub links (PR, Issue, Commit) show icon and short path
//// - AC3: Notes with PR links are highlighted

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type Match}
import gleam/result
import gleam/string

// =============================================================================
// Types
// =============================================================================

/// A detected link with its metadata.
pub type DetectedLink {
  DetectedLink(
    url: String,
    start: Int,
    end: Int,
    link_type: LinkType,
    display_text: String,
  )
}

/// The type of link detected.
pub type LinkType {
  /// A GitHub Pull Request link
  GitHubPR(owner: String, repo: String, number: String)
  /// A GitHub Issue link
  GitHubIssue(owner: String, repo: String, number: String)
  /// A GitHub Commit link
  GitHubCommit(owner: String, repo: String, sha: String)
  /// A generic URL
  GenericUrl
}

/// A segment of text - either plain text or a link.
pub type TextSegment {
  PlainText(content: String)
  Link(link: DetectedLink)
}

// =============================================================================
// Public API
// =============================================================================

/// Detect all links in a text string.
/// Returns a list of segments (plain text or links) in order.
pub fn detect_links(text: String) -> List(TextSegment) {
  let assert Ok(url_regex) =
    regexp.from_string("https?://[^\\s<>\"'\\[\\]\\(\\)]+")

  let matches = regexp.scan(url_regex, text)

  case matches {
    [] -> [PlainText(text)]
    _ -> build_segments(text, matches, 0, [])
  }
}

/// Check if any detected link is a PR (for AC3 highlight logic).
pub fn has_pr_link(segments: List(TextSegment)) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      Link(DetectedLink(link_type: GitHubPR(..), ..)) -> True
      _ -> False
    }
  })
}

/// Get the short display text for a GitHub link.
pub fn github_short_path(link_type: LinkType) -> Option(String) {
  case link_type {
    GitHubPR(owner, repo, number) -> Some(owner <> "/" <> repo <> "#" <> number)
    GitHubIssue(owner, repo, number) ->
      Some(owner <> "/" <> repo <> "#" <> number)
    GitHubCommit(owner, repo, sha) ->
      Some(owner <> "/" <> repo <> "@" <> string.slice(sha, 0, 7))
    GenericUrl -> None
  }
}

// =============================================================================
// Private Functions
// =============================================================================

fn build_segments(
  text: String,
  matches: List(Match),
  current_pos: Int,
  acc: List(TextSegment),
) -> List(TextSegment) {
  case matches {
    [] -> {
      // Add remaining text if any
      let remaining = string.drop_start(text, current_pos)
      case remaining {
        "" -> list.reverse(acc)
        _ -> list.reverse([PlainText(remaining), ..acc])
      }
    }
    [regexp.Match(content: content, ..), ..rest] -> {
      let start = find_match_start(text, content, current_pos)
      let end = start + string.length(content)

      // Add plain text before this match if any
      let before = string.slice(text, current_pos, start - current_pos)
      let acc = case before {
        "" -> acc
        _ -> [PlainText(before), ..acc]
      }

      // Categorize and add the link
      let link = categorize_url(content, start, end)
      let acc = [Link(link), ..acc]

      build_segments(text, rest, end, acc)
    }
  }
}

fn find_match_start(text: String, match_content: String, from: Int) -> Int {
  let search_text = string.drop_start(text, from)
  case string.split_once(search_text, match_content) {
    Ok(#(before, _)) -> from + string.length(before)
    Error(_) -> from
  }
}

fn categorize_url(url: String, start: Int, end: Int) -> DetectedLink {
  let link_type = parse_github_url(url) |> result.unwrap(GenericUrl)
  let display_text = case github_short_path(link_type) {
    Some(short) -> short
    None -> url
  }

  DetectedLink(
    url: url,
    start: start,
    end: end,
    link_type: link_type,
    display_text: display_text,
  )
}

fn parse_github_url(url: String) -> Result(LinkType, Nil) {
  // Pattern: https://github.com/owner/repo/pull/123
  // Pattern: https://github.com/owner/repo/issues/123
  // Pattern: https://github.com/owner/repo/commit/sha
  case string.starts_with(url, "https://github.com/") {
    False -> Error(Nil)
    True -> {
      let path =
        url
        |> string.drop_start(19)
        // Remove "https://github.com/"
        |> string.split("/")

      case path {
        [owner, repo, "pull", number, ..] -> Ok(GitHubPR(owner, repo, number))
        [owner, repo, "issues", number, ..] ->
          Ok(GitHubIssue(owner, repo, number))
        [owner, repo, "commit", sha, ..] -> Ok(GitHubCommit(owner, repo, sha))
        _ -> Error(Nil)
      }
    }
  }
}
