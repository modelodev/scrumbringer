# HT-12 UI Validation

- Desktop browser pass: opened `http://127.0.0.1:19191/` at `1440x900`.
  The authenticated manager shell rendered the Pool, task cards, project
  selector, admin navigation, and work navigation without a blank page or
  runtime error.
- Legacy navigation label check: the running dev database initially contained
  old depth-2 delivery labels. Those local validation rows were updated to
  `Initiative/Initiatives`, and the desktop snapshot then rendered `Cards`,
  `Initiatives`, and `Task groups` with no removed label.
- Mobile browser pass: opened the same app at `390x844`. The compact shell
  rendered the Pool content, top navigation buttons, bottom activity control,
  and mobile navigation drawer. The drawer also showed `Initiatives` instead
  of the removed legacy label.
- API-backed task cards remained visible after the cleanup, including claim
  actions and task detail open controls.
