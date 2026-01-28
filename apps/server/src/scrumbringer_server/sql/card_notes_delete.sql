-- name: card_notes_delete
delete from card_notes
where card_id = $1
  and id = $2
returning id;
