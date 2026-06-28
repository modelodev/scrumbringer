delete from notes n
using card_notes cn
where cn.note_id = n.id
  and cn.card_id = $1
  and n.id = $2
returning n.id;
