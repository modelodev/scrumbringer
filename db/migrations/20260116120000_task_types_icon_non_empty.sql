-- migrate:up
alter table task_types
  add constraint task_types_icon_non_empty check (trim(icon) <> '');
