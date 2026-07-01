-- migrate:up

alter table cards
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by integer references users(id) on delete set null;

alter table tasks
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by integer references users(id) on delete set null;

create index if not exists idx_cards_project_not_deleted
  on cards(project_id, created_at desc)
  where deleted_at is null;

create index if not exists idx_cards_parent_not_deleted
  on cards(parent_card_id)
  where deleted_at is null;

create index if not exists idx_tasks_project_not_deleted
  on tasks(project_id, created_at desc)
  where deleted_at is null;

create index if not exists idx_tasks_card_not_deleted
  on tasks(card_id)
  where deleted_at is null;

-- migrate:down

drop index if exists idx_tasks_card_not_deleted;
drop index if exists idx_tasks_project_not_deleted;
drop index if exists idx_cards_parent_not_deleted;
drop index if exists idx_cards_project_not_deleted;

alter table tasks
  drop column if exists deleted_by,
  drop column if exists deleted_at;

alter table cards
  drop column if exists deleted_by,
  drop column if exists deleted_at;
