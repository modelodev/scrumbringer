import scrumbringer_client/ui/skeleton
import support/render_assertions

pub fn skeleton_line_has_skeleton_class_test() {
  let rendered = skeleton.skeleton_line("100%", "16px")
  rendered |> render_assertions.view_contains("skeleton")
}

pub fn skeleton_line_has_dimensions_test() {
  let rendered = skeleton.skeleton_line("200px", "20px")
  let html = render_assertions.html(rendered)

  render_assertions.contains(html, "200px")
  render_assertions.contains(html, "20px")
}
