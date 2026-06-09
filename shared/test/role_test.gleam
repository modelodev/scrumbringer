import domain/org_role
import domain/project_role

pub fn org_role_parse_accepts_known_values_test() {
  let assert Ok(org_role.Admin) = org_role.parse("admin")
  let assert Ok(org_role.Member) = org_role.parse("member")
}

pub fn org_role_parse_rejects_unknown_values_test() {
  let assert Error(org_role.UnknownOrgRole("owner")) = org_role.parse("owner")
  let assert Error(org_role.UnknownOrgRole("")) = org_role.parse("")
}

pub fn project_role_parse_accepts_known_values_test() {
  let assert Ok(project_role.Manager) = project_role.parse("manager")
  let assert Ok(project_role.Member) = project_role.parse("member")
}

pub fn project_role_parse_rejects_unknown_values_test() {
  let assert Error(project_role.UnknownProjectRole("admin")) =
    project_role.parse("admin")
  let assert Error(project_role.UnknownProjectRole("")) = project_role.parse("")
}
