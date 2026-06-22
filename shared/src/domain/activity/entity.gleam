//// Shared activity feed event entity.

import gleam/option.{type Option}

import domain/activity/id as activity_id
import domain/activity/kind.{type ActivityKind}
import domain/activity/subject.{type ActivitySubject}
import domain/project/id as project_id
import domain/user/id as user_id

pub type ActivityEvent {
  ActivityEvent(
    id: activity_id.ActivityId,
    project_id: project_id.ProjectId,
    subject: ActivitySubject,
    kind: ActivityKind,
    actor_user_id: user_id.UserId,
    actor_label: String,
    summary: String,
    related_subject: Option(ActivitySubject),
    created_at: String,
  )
}
