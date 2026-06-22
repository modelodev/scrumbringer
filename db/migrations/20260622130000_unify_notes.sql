-- migrate:up

ALTER TABLE card_notes RENAME TO card_notes_legacy;
ALTER INDEX IF EXISTS idx_card_notes_card RENAME TO idx_card_notes_legacy_card;

ALTER TABLE task_notes RENAME TO task_notes_legacy;
ALTER INDEX IF EXISTS idx_task_notes_task RENAME TO idx_task_notes_legacy_task;

CREATE TABLE notes (
  id BIGSERIAL PRIMARY KEY,
  project_id BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,
  url TEXT,
  pinned BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE card_notes (
  note_id BIGINT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  card_id BIGINT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  PRIMARY KEY (note_id, card_id)
);

CREATE TABLE task_notes (
  note_id BIGINT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  PRIMARY KEY (note_id, task_id)
);

CREATE INDEX idx_notes_project ON notes(project_id);
CREATE INDEX idx_notes_user ON notes(user_id);
CREATE INDEX idx_notes_pinned ON notes(project_id, pinned);
CREATE INDEX idx_card_notes_card ON card_notes(card_id);
CREATE INDEX idx_task_notes_task ON task_notes(task_id);

DO $$
DECLARE
  legacy_card_note RECORD;
  inserted_note_id BIGINT;
BEGIN
  FOR legacy_card_note IN
    SELECT cn.*, c.project_id
    FROM card_notes_legacy cn
    JOIN cards c ON c.id = cn.card_id
    ORDER BY cn.id
  LOOP
    INSERT INTO notes (
      project_id,
      user_id,
      content,
      url,
      pinned,
      created_at,
      updated_at
    )
    VALUES (
      legacy_card_note.project_id,
      legacy_card_note.user_id,
      legacy_card_note.content,
      NULL,
      FALSE,
      legacy_card_note.created_at,
      legacy_card_note.created_at
    )
    RETURNING id INTO inserted_note_id;

    INSERT INTO card_notes (note_id, card_id)
    VALUES (inserted_note_id, legacy_card_note.card_id);
  END LOOP;
END;
$$;

DO $$
DECLARE
  legacy_task_note RECORD;
  inserted_note_id BIGINT;
BEGIN
  FOR legacy_task_note IN
    SELECT tn.*, t.project_id
    FROM task_notes_legacy tn
    JOIN tasks t ON t.id = tn.task_id
    ORDER BY tn.id
  LOOP
    INSERT INTO notes (
      project_id,
      user_id,
      content,
      url,
      pinned,
      created_at,
      updated_at
    )
    VALUES (
      legacy_task_note.project_id,
      legacy_task_note.user_id,
      legacy_task_note.content,
      NULL,
      FALSE,
      legacy_task_note.created_at,
      legacy_task_note.created_at
    )
    RETURNING id INTO inserted_note_id;

    INSERT INTO task_notes (note_id, task_id)
    VALUES (inserted_note_id, legacy_task_note.task_id);
  END LOOP;
END;
$$;

DROP TABLE card_notes_legacy;
DROP TABLE task_notes_legacy;

-- migrate:down

CREATE TABLE card_notes_legacy (
  id BIGSERIAL PRIMARY KEY,
  card_id BIGINT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE task_notes_legacy (
  id BIGSERIAL PRIMARY KEY,
  task_id BIGINT NOT NULL REFERENCES tasks(id),
  user_id BIGINT NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO card_notes_legacy (card_id, user_id, content, created_at)
SELECT cn.card_id, n.user_id, n.content, n.created_at
FROM card_notes cn
JOIN notes n ON n.id = cn.note_id
ORDER BY n.created_at, n.id;

INSERT INTO task_notes_legacy (task_id, user_id, content, created_at)
SELECT tn.task_id, n.user_id, n.content, n.created_at
FROM task_notes tn
JOIN notes n ON n.id = tn.note_id
ORDER BY n.created_at, n.id;

DROP INDEX idx_task_notes_task;
DROP INDEX idx_card_notes_card;
DROP INDEX idx_notes_pinned;
DROP INDEX idx_notes_user;
DROP INDEX idx_notes_project;

DROP TABLE task_notes;
DROP TABLE card_notes;
DROP TABLE notes;

ALTER TABLE card_notes_legacy RENAME TO card_notes;
ALTER INDEX IF EXISTS card_notes_legacy_pkey RENAME TO card_notes_pkey;
ALTER TABLE task_notes_legacy RENAME TO task_notes;
ALTER INDEX IF EXISTS task_notes_legacy_pkey RENAME TO task_notes_pkey;

CREATE INDEX idx_card_notes_card ON card_notes(card_id);
CREATE INDEX idx_task_notes_task ON task_notes(task_id);
