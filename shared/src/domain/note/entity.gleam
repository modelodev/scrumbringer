//// Shared note entity.

import gleam/option.{type Option}

import domain/note/id as note_id
import domain/note/subject.{type NoteSubject}
import domain/org_role.{type OrgRole}
import domain/project/id as project_id
import domain/project_role.{type ProjectRole}
import domain/user/id as user_id

pub type Note {
  Note(
    id: note_id.NoteId,
    project_id: project_id.ProjectId,
    subject: NoteSubject,
    user_id: user_id.UserId,
    content: String,
    url: Option(String),
    pinned: Bool,
    created_at: String,
    updated_at: String,
    author_email: String,
    author_project_role: Option(ProjectRole),
    author_org_role: OrgRole,
  )
}
