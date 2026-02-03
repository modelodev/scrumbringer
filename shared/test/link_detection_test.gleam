import domain/link_detection.{
  DetectedLink, GenericUrl, GitHubCommit, GitHubIssue, GitHubPR, Link, PlainText,
}
import gleam/option.{None, Some}
import gleeunit/should

// =============================================================================
// AC1: Detect URLs and make them clickable
// =============================================================================

pub fn detect_no_links_test() {
  let result = link_detection.detect_links("Just plain text without links")

  result
  |> should.equal([PlainText("Just plain text without links")])
}

pub fn detect_single_url_test() {
  let result = link_detection.detect_links("Check out https://example.com here")

  result
  |> should.equal([
    PlainText("Check out "),
    Link(DetectedLink(
      url: "https://example.com",
      start: 10,
      end: 29,
      link_type: GenericUrl,
      display_text: "https://example.com",
    )),
    PlainText(" here"),
  ])
}

pub fn detect_multiple_urls_test() {
  let result =
    link_detection.detect_links("Visit https://a.com and https://b.com today")

  result
  |> should.equal([
    PlainText("Visit "),
    Link(DetectedLink(
      url: "https://a.com",
      start: 6,
      end: 19,
      link_type: GenericUrl,
      display_text: "https://a.com",
    )),
    PlainText(" and "),
    Link(DetectedLink(
      url: "https://b.com",
      start: 24,
      end: 37,
      link_type: GenericUrl,
      display_text: "https://b.com",
    )),
    PlainText(" today"),
  ])
}

pub fn detect_url_at_start_test() {
  let result = link_detection.detect_links("https://start.com is the URL")

  result
  |> should.equal([
    Link(DetectedLink(
      url: "https://start.com",
      start: 0,
      end: 17,
      link_type: GenericUrl,
      display_text: "https://start.com",
    )),
    PlainText(" is the URL"),
  ])
}

pub fn detect_url_at_end_test() {
  let result = link_detection.detect_links("The URL is https://end.com")

  result
  |> should.equal([
    PlainText("The URL is "),
    Link(DetectedLink(
      url: "https://end.com",
      start: 11,
      end: 26,
      link_type: GenericUrl,
      display_text: "https://end.com",
    )),
  ])
}

// =============================================================================
// AC2: GitHub links show icon and short path
// =============================================================================

pub fn detect_github_pr_test() {
  let result =
    link_detection.detect_links("PR: https://github.com/owner/repo/pull/123")

  result
  |> should.equal([
    PlainText("PR: "),
    Link(DetectedLink(
      url: "https://github.com/owner/repo/pull/123",
      start: 4,
      end: 42,
      link_type: GitHubPR("owner", "repo", "123"),
      display_text: "owner/repo#123",
    )),
  ])
}

pub fn detect_github_issue_test() {
  let result =
    link_detection.detect_links("Issue: https://github.com/foo/bar/issues/456")

  result
  |> should.equal([
    PlainText("Issue: "),
    Link(DetectedLink(
      url: "https://github.com/foo/bar/issues/456",
      start: 7,
      end: 44,
      link_type: GitHubIssue("foo", "bar", "456"),
      display_text: "foo/bar#456",
    )),
  ])
}

pub fn detect_github_commit_test() {
  let result =
    link_detection.detect_links(
      "Commit: https://github.com/org/project/commit/abc1234567890",
    )

  result
  |> should.equal([
    PlainText("Commit: "),
    Link(DetectedLink(
      url: "https://github.com/org/project/commit/abc1234567890",
      start: 8,
      end: 59,
      link_type: GitHubCommit("org", "project", "abc1234567890"),
      display_text: "org/project@abc1234",
    )),
  ])
}

pub fn github_short_path_pr_test() {
  let link_type = GitHubPR("owner", "repo", "123")

  link_detection.github_short_path(link_type)
  |> should.equal(Some("owner/repo#123"))
}

pub fn github_short_path_issue_test() {
  let link_type = GitHubIssue("org", "lib", "789")

  link_detection.github_short_path(link_type)
  |> should.equal(Some("org/lib#789"))
}

pub fn github_short_path_commit_test() {
  let link_type = GitHubCommit("team", "app", "deadbeef123456")

  link_detection.github_short_path(link_type)
  |> should.equal(Some("team/app@deadbee"))
}

pub fn github_short_path_generic_test() {
  link_detection.github_short_path(GenericUrl)
  |> should.equal(None)
}

// =============================================================================
// AC3: Notes with PR links are highlighted
// =============================================================================

pub fn has_pr_link_true_test() {
  let segments =
    link_detection.detect_links("PR: https://github.com/a/b/pull/1")

  link_detection.has_pr_link(segments)
  |> should.be_true()
}

pub fn has_pr_link_false_generic_test() {
  let segments = link_detection.detect_links("Link: https://example.com")

  link_detection.has_pr_link(segments)
  |> should.be_false()
}

pub fn has_pr_link_false_issue_test() {
  let segments =
    link_detection.detect_links("Issue: https://github.com/a/b/issues/1")

  link_detection.has_pr_link(segments)
  |> should.be_false()
}

pub fn has_pr_link_false_no_links_test() {
  let segments = link_detection.detect_links("No links here")

  link_detection.has_pr_link(segments)
  |> should.be_false()
}

pub fn has_pr_link_multiple_with_pr_test() {
  let segments =
    link_detection.detect_links(
      "See https://example.com and https://github.com/x/y/pull/99",
    )

  link_detection.has_pr_link(segments)
  |> should.be_true()
}

// =============================================================================
// Edge Cases
// =============================================================================

pub fn empty_text_test() {
  let result = link_detection.detect_links("")

  result
  |> should.equal([PlainText("")])
}

pub fn url_only_test() {
  let result = link_detection.detect_links("https://solo.com")

  result
  |> should.equal([
    Link(DetectedLink(
      url: "https://solo.com",
      start: 0,
      end: 16,
      link_type: GenericUrl,
      display_text: "https://solo.com",
    )),
  ])
}

pub fn github_pr_with_extra_path_test() {
  // PR URLs sometimes have /files or /commits suffix
  let result =
    link_detection.detect_links("https://github.com/a/b/pull/123/files")

  result
  |> should.equal([
    Link(DetectedLink(
      url: "https://github.com/a/b/pull/123/files",
      start: 0,
      end: 37,
      link_type: GitHubPR("a", "b", "123"),
      display_text: "a/b#123",
    )),
  ])
}
