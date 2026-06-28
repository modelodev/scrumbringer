delete from notes n
using task_notes tn
where tn.note_id = n.id
  and tn.task_id = $1
  and n.id = $2
returning n.id;
