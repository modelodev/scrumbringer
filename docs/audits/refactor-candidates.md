# Refactor candidates

These candidates are generated from the inventory and then curated with manual architectural judgement. They are not implementation instructions until converted into work packages.

## P0/P1 mechanically detected signals

- Client API shapes without exact router shape: 0
- Gleam modules >= 700 lines: 52
- Public modules with no static consumers: 17
- Tests importing deprecated should: 0
- Tests with private-helper coupling signals: 10
- Basenames duplicated across packages: 23

## Curated candidates

Resolved: no client API shape currently lacks an exact router shape, so the previous card-tasks mismatch is no longer an actionable P0.

| ID | Priority | Title | Target owner | Code/API to remove |
| --- | --- | --- | --- | --- |
| AUD-WP-01 | P1 | Unificar superficies Task/Card notes | Un contrato compartido de note + presenters/decoders comunes, manteniendo handlers por recurso si la autorizacion difiere. | Helpers, fixtures y render fragments duplicados tras extraer note_content/notes_list y contrato comun. |
| AUD-WP-02 | P2 | Endurecer resource views de tasks/cards | `http/resource_views.gleam` como flujo HTTP comun; `task_views` y `card_views` conservan autorizacion/carga de proyecto especifica. | No introducir ADT ni helpers nuevos si `resource_views` ya cubre el caso; retirar solo duplicacion residual de tests o mapeos. |
| AUD-WP-03 | P1 | Cerrar ownership de Card Show y Task Show | Features `cards/show` y `tasks/show` para estado/producto; `ui/inspector_*` solo primitivas visuales testeadas. | Configuracion local, acciones sueltas y tests que fuerzan public API de componentes internos. |
| AUD-WP-04 | P2 | Consolidar metricas visuales de task/card | Primitivas UI semanticas para metricas con icono, tooltip, label accesible y tests comunes. | Markup local de badges/texto y tests duplicados por feature. |
| AUD-WP-05 | P2 | Privatizar API publica accidental usada solo por tests | Entradas publicas de produccion: route/update/handler HTTP; helpers puros privados salvo consumidores reales. | Exports publicos accidentales y tests de implementacion. |
| AUD-WP-06 | P2 | Revisar modulos grandes por responsabilidad real | Cortes locales por responsabilidad de producto, no por patron generico. | Ramas repetidas y helpers privados movidos solo si el nuevo owner elimina conocimiento del root. |

## Client API shapes needing manual verification

No exact-shape mismatches detected.

## Large modules

| Path | Lines | Kind | Domain | Public symbols |
| --- | --- | --- | --- | --- |
| apps/client/src/scrumbringer_client/client_update.gleam | 2462 | module | cross_cutting | 6 |
| apps/client/src/scrumbringer_client/client_view.gleam | 2170 | lustre_view | cross_cutting | 3 |
| apps/client/src/scrumbringer_client/components/card_crud_dialog.gleam | 1032 | lustre_component | card | 8 |
| apps/client/src/scrumbringer_client/components/task_type_crud_dialog.gleam | 925 | lustre_component | task | 7 |
| apps/client/src/scrumbringer_client/features/admin/rule_metrics.gleam | 773 | module | rule | 5 |
| apps/client/src/scrumbringer_client/features/admin/workflows.gleam | 1148 | module | workflows | 9 |
| apps/client/src/scrumbringer_client/features/assignments/update.gleam | 880 | lustre_update | assignments | 7 |
| apps/client/src/scrumbringer_client/features/automations/execution_history.gleam | 912 | lustre_view | automations | 3 |
| apps/client/src/scrumbringer_client/features/automations/rule_list.gleam | 1274 | lustre_view | rule | 4 |
| apps/client/src/scrumbringer_client/features/capability_board/view.gleam | 1336 | lustre_view | capability | 2 |
| apps/client/src/scrumbringer_client/features/cards/show.gleam | 1634 | lustre_view | cards | 9 |
| apps/client/src/scrumbringer_client/features/hydration/update.gleam | 764 | lustre_update | cross_cutting | 2 |
| apps/client/src/scrumbringer_client/features/people/view.gleam | 1347 | lustre_view | people | 2 |
| apps/client/src/scrumbringer_client/features/plan/structure_view.gleam | 1596 | lustre_view | plan | 2 |
| apps/client/src/scrumbringer_client/features/pool/task_route.gleam | 728 | lustre_route | task | 2 |
| apps/client/src/scrumbringer_client/features/pool/update.gleam | 1195 | lustre_update | pool | 3 |
| apps/client/src/scrumbringer_client/features/projects/update.gleam | 1609 | lustre_update | projects | 7 |
| apps/client/src/scrumbringer_client/features/projects/view.gleam | 1072 | lustre_view | projects | 3 |
| apps/client/src/scrumbringer_client/features/views/kanban_board.gleam | 743 | lustre_view | cross_cutting | 3 |
| apps/client/src/scrumbringer_client/i18n/en.gleam | 1410 | module | i18n | 1 |
| apps/client/src/scrumbringer_client/i18n/es.gleam | 1445 | module | i18n | 1 |
| apps/client/src/scrumbringer_client/i18n/text.gleam | 1174 | module | i18n | 1 |
| apps/client/src/scrumbringer_client/router.gleam | 736 | module | cross_cutting | 12 |
| apps/client/src/scrumbringer_client/styles/ux.gleam | 719 | module | cross_cutting | 1 |
| apps/client/src/scrumbringer_client/url_state.gleam | 992 | lustre_view | cross_cutting | 47 |
| apps/client/test/admin_workflows_update_test.gleam | 704 | test | workflows | 22 |
| apps/client/test/capabilities_update_test.gleam | 718 | test | capabilities | 23 |
| apps/client/test/people_view_test.gleam | 1251 | test | people | 27 |
| apps/client/test/projects_update_test.gleam | 722 | test | projects | 25 |
| apps/client/test/url_state_test.gleam | 747 | test | cross_cutting | 68 |
| apps/server/src/scrumbringer_server/http/cards.gleam | 712 | endpoint_handler | cards | 5 |
| apps/server/src/scrumbringer_server/http/projects.gleam | 759 | endpoint_handler | projects | 7 |
| apps/server/src/scrumbringer_server/http/rules.gleam | 792 | endpoint_handler | rules | 2 |
| apps/server/src/scrumbringer_server/seed_db.gleam | 1783 | module | cross_cutting | 49 |
| apps/server/src/scrumbringer_server/sql.gleam | 9577 | module | cross_cutting | 226 |
| apps/server/src/scrumbringer_server/use_case/api_tokens.gleam | 737 | use_case | api_tokens | 21 |
| apps/server/src/scrumbringer_server/use_case/cards_db.gleam | 1169 | use_case | cards | 11 |
| apps/server/src/scrumbringer_server/use_case/projects_db.gleam | 1106 | use_case | projects | 27 |
| apps/server/src/scrumbringer_server/use_case/rules_engine.gleam | 971 | use_case | rules | 7 |
| apps/server/src/scrumbringer_server/use_case/workflows/handlers.gleam | 1122 | use_case | workflows | 1 |
| apps/server/test/api_tokens_http_test.gleam | 967 | test | api_tokens | 14 |
| apps/server/test/cards_http_test.gleam | 1021 | test | cards | 32 |
| apps/server/test/fixtures.gleam | 1566 | test | cross_cutting | 60 |
| apps/server/test/integration/rules_trigger_on_close_test.gleam | 1089 | test | rules | 10 |
| apps/server/test/notes_and_positions_http_test.gleam | 2022 | test | notes | 14 |
| apps/server/test/org_users_http_test.gleam | 792 | test | org | 13 |
| apps/server/test/projects_http_test.gleam | 1548 | test | projects | 21 |
| apps/server/test/rules_engine_test.gleam | 1729 | test | rules | 24 |
| apps/server/test/rules_http_test.gleam | 1144 | test | rules | 7 |
| apps/server/test/task_templates_http_test.gleam | 1005 | test | task | 6 |
| apps/server/test/tasks_http_test.gleam | 3854 | test | tasks | 49 |
| apps/server/test/workflows_http_test.gleam | 826 | test | workflows | 7 |

## Duplicate module basenames across packages

| Basename | Files |
| --- | --- |
| types | apps/client/src/scrumbringer_client/client_state/types.gleam, apps/client/src/scrumbringer_client/features/capabilities/types.gleam, apps/client/src/scrumbringer_client/features/metrics/types.gleam, apps/client/src/scrumbringer_client/features/plan/types.gleam, apps/client/src/scrumbringer_client/ui/tooltips/types.gleam, apps/server/src/scrumbringer_server/use_case/workflows/types.gleam |
| api_tokens | apps/client/src/scrumbringer_client/api/api_tokens.gleam, apps/client/src/scrumbringer_client/client_state/admin/api_tokens.gleam, apps/server/src/scrumbringer_server/http/api_tokens.gleam, apps/server/src/scrumbringer_server/use_case/api_tokens.gleam |
| cards | apps/client/src/scrumbringer_client/api/cards.gleam, apps/client/src/scrumbringer_client/client_state/admin/cards.gleam, apps/client/src/scrumbringer_client/features/admin/cards.gleam, apps/server/src/scrumbringer_server/http/cards.gleam |
| task_templates | apps/client/src/scrumbringer_client/api/workflows/task_templates.gleam, apps/client/src/scrumbringer_client/client_state/admin/task_templates.gleam, apps/client/src/scrumbringer_client/features/admin/task_templates.gleam, apps/server/src/scrumbringer_server/http/task_templates.gleam |
| workflows | apps/client/src/scrumbringer_client/api/workflows.gleam, apps/client/src/scrumbringer_client/client_state/admin/workflows.gleam, apps/client/src/scrumbringer_client/features/admin/workflows.gleam, apps/server/src/scrumbringer_server/http/workflows.gleam |
| auth | apps/client/src/scrumbringer_client/api/auth.gleam, apps/client/src/scrumbringer_client/client_state/auth.gleam, apps/server/src/scrumbringer_server/http/auth.gleam |
| metrics | apps/client/src/scrumbringer_client/client_state/admin/metrics.gleam, apps/client/src/scrumbringer_client/client_state/member/metrics.gleam, shared/src/domain/metrics.gleam |
| projects | apps/client/src/scrumbringer_client/api/projects.gleam, apps/client/src/scrumbringer_client/client_state/admin/projects.gleam, apps/server/src/scrumbringer_server/http/projects.gleam |
| queries | apps/client/src/scrumbringer_client/features/work_scope/queries.gleam, apps/server/src/scrumbringer_server/repository/auth/queries.gleam, apps/server/src/scrumbringer_server/repository/tasks/queries.gleam |
| rule_metrics | apps/client/src/scrumbringer_client/api/workflows/rule_metrics.gleam, apps/client/src/scrumbringer_client/features/admin/rule_metrics.gleam, apps/server/src/scrumbringer_server/http/rule_metrics.gleam |
| rules | apps/client/src/scrumbringer_client/api/workflows/rules.gleam, apps/client/src/scrumbringer_client/client_state/admin/rules.gleam, apps/server/src/scrumbringer_server/http/rules.gleam |
| state | apps/client/src/scrumbringer_client/features/people/state.gleam, shared/src/domain/card/state.gleam, shared/src/domain/task/state.gleam |
| activity | apps/client/src/scrumbringer_client/api/activity.gleam, apps/server/src/scrumbringer_server/http/activity.gleam |
| capabilities | apps/client/src/scrumbringer_client/client_state/admin/capabilities.gleam, apps/server/src/scrumbringer_server/http/capabilities.gleam |
| claimability | apps/client/src/scrumbringer_client/features/tasks/claimability.gleam, shared/src/domain/task/claimability.gleam |
| filters | apps/client/src/scrumbringer_client/features/pool/filters.gleam, apps/server/src/scrumbringer_server/http/tasks/filters.gleam |
| org | apps/client/src/scrumbringer_client/api/org.gleam, shared/src/domain/org.gleam |
| permissions | apps/client/src/scrumbringer_client/permissions.gleam, shared/src/domain/project/permissions.gleam |
| remote | apps/client/src/scrumbringer_client/ui/remote.gleam, shared/src/domain/remote.gleam |
| router | apps/client/src/scrumbringer_client/router.gleam, apps/server/src/scrumbringer_server/web/router.gleam |
| task_dependencies | apps/client/src/scrumbringer_client/features/pool/task_dependencies.gleam, apps/server/src/scrumbringer_server/http/tasks/task_dependencies.gleam |
| task_notes | apps/client/src/scrumbringer_client/features/pool/task_notes.gleam, apps/server/src/scrumbringer_server/http/task_notes.gleam |
| time | apps/client/src/scrumbringer_client/helpers/time.gleam, apps/server/src/scrumbringer_server/use_case/time.gleam |
