//// Safe note content renderer.

import domain/link_detection.{
  type DetectedLink, type TextSegment, DetectedLink, GenericUrl, GitHubCommit,
  GitHubIssue, GitHubPR, Link, PlainText,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html.{a, span, text}

import scrumbringer_client/ui/icons

pub fn view(content: String, url: Option(String)) -> List(Element(msg)) {
  let content_segments =
    content
    |> link_detection.detect_links
    |> list.map(render_segment)

  case url {
    None -> content_segments
    Some("") -> content_segments
    Some(note_url) ->
      list.append(content_segments, [
        text(" "),
        a(link_attrs(note_url), [text(note_url)]),
      ])
  }
}

fn render_segment(segment: TextSegment) -> Element(msg) {
  case segment {
    PlainText(content) -> text(content)
    Link(link) -> render_link(link)
  }
}

fn render_link(link: DetectedLink) -> Element(msg) {
  let DetectedLink(
    url: url,
    link_type: link_type,
    display_text: display_text,
    ..,
  ) = link

  let attrs = link_attrs(url)

  case link_type {
    GitHubPR(..) | GitHubIssue(..) | GitHubCommit(..) ->
      span([attribute.class("github-link")], [
        icons.nav_icon(icons.GitHub, icons.XSmall),
        a(attrs, [text(display_text)]),
      ])
    GenericUrl -> a(attrs, [text(display_text)])
  }
}

fn link_attrs(url: String) -> List(Attribute(msg)) {
  [
    attribute.href(url),
    attribute.target("_blank"),
    attribute.rel("noopener noreferrer"),
    attribute.class("note-link"),
  ]
}
