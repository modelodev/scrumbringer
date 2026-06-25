import domain/project.{ProjectDepthName}
import domain/project/settings

pub fn default_card_depth_names_include_three_operational_levels_test() {
  let assert [first, second, third] = settings.default_card_depth_names()

  let assert 1 = first.depth
  let assert "Initiatives" = first.plural_name
  let assert 2 = second.depth
  let assert "Features" = second.plural_name
  let assert 3 = third.depth
  let assert "Task group" = third.singular_name
  let assert "Task groups" = third.plural_name
}

pub fn default_healthy_pool_limit_is_positive_test() {
  let assert 20 = settings.default_healthy_pool_limit()
  let assert Ok(_) =
    settings.healthy_pool_limit_from_int(settings.default_healthy_pool_limit())
}

pub fn healthy_pool_limit_accepts_positive_values_test() {
  let assert Ok(limit) = settings.healthy_pool_limit_from_int(20)
  let assert 20 = settings.healthy_pool_limit_to_int(limit)
}

pub fn healthy_pool_limit_rejects_non_positive_values_test() {
  let assert Error(settings.InvalidHealthyPoolLimit(0)) =
    settings.healthy_pool_limit_from_int(0)
  let assert Error(settings.InvalidHealthyPoolLimit(-1)) =
    settings.healthy_pool_limit_from_int(-1)
}

pub fn card_depth_names_accepts_sequential_nonblank_names_test() {
  let depth_names = [
    ProjectDepthName(1, "Initiative", "Initiatives"),
    ProjectDepthName(2, "Feature", "Features"),
  ]

  let assert Ok(depth_names) = settings.validate_card_depth_names(depth_names)
  let assert True = settings.valid_card_depth_names(depth_names)
}

pub fn card_depth_names_rejects_empty_list_test() {
  let assert Error(settings.EmptyCardDepthNames) =
    settings.validate_card_depth_names([])
  let assert False = settings.valid_card_depth_names([])
}

pub fn card_depth_names_rejects_nonsequential_depths_test() {
  let depth_names = [
    ProjectDepthName(1, "Initiative", "Initiatives"),
    ProjectDepthName(3, "Task group", "Task groups"),
  ]

  let assert Error(settings.NonSequentialCardDepth(depth: 3, expected: 2)) =
    settings.validate_card_depth_names(depth_names)
}

pub fn card_depth_names_rejects_blank_labels_test() {
  let depth_names = [
    ProjectDepthName(1, "Initiative", "Initiatives"),
    ProjectDepthName(2, " ", "Features"),
  ]

  let assert Error(settings.BlankCardDepthName(2)) =
    settings.validate_card_depth_names(depth_names)
}

pub fn project_settings_require_positive_limit_and_valid_depths_test() {
  let depth_names = [
    ProjectDepthName(1, "Initiative", "Initiatives"),
    ProjectDepthName(2, "Feature", "Features"),
  ]

  let assert True = settings.valid_project_settings(20, depth_names)
  let assert False = settings.valid_project_settings(0, depth_names)
  let assert False = settings.valid_project_settings(20, [])
}
