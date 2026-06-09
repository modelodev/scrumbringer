import gleam/option

import domain/project.{type Project}
import domain/user.{type User}
import scrumbringer_client/permissions

pub fn can_manage(
  user: option.Option(User),
  selected_project: option.Option(Project),
) -> Bool {
  case user {
    option.Some(user) ->
      case permissions.is_org_admin(user.org_role) {
        True -> True
        False ->
          case selected_project {
            option.Some(project) -> permissions.is_project_manager(project)
            option.None -> False
          }
      }
    option.None -> False
  }
}
