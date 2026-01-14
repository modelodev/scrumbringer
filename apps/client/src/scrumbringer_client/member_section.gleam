pub type MemberSection {
  Pool
  MyBar
  MySkills
}

pub fn from_slug(slug: String) -> MemberSection {
  case slug {
    "my-bar" -> MyBar
    "my-skills" -> MySkills
    "pool" -> Pool
    _ -> Pool
  }
}

pub fn to_slug(section: MemberSection) -> String {
  case section {
    Pool -> "pool"
    MyBar -> "my-bar"
    MySkills -> "my-skills"
  }
}
