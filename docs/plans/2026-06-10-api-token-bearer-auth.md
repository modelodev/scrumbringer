# Plan de implementación: API tokens Bearer

## Objetivo

Permitir que sistemas externos se conecten con ScrumBringer mediante tokens
Bearer para consultar y operar sobre proyectos, tasks, cards, notes y
milestones sin depender de sesiones web, cookies ni CSRF.

La implementación debe reutilizar autorización y servicios existentes, mantener
la app Lustre funcionando con cookie + CSRF, y evitar crear un sistema paralelo
de permisos.

## Decisiones cerradas

- Los tokens pertenecen a usuarios de integración explícitos en el modelo.
- En la UI principal, el administrador crea tokens indicando la integración; el
  usuario de integración se crea o reutiliza de forma transparente.
- Un token puede quedar limitado a un proyecto concreto.
- Si el token no tiene proyecto asignado, puede operar en todos los proyectos a
  los que tenga acceso su usuario de integración.
- Los tokens se pueden crear y revocar.
- `expires_at` es opcional y no hay expiración por defecto.
- El nombre del token es obligatorio.
- El token completo se muestra una sola vez al crearlo.
- Un Bearer inválido devuelve `401` y no hace fallback a cookie.
- Crear/revocar tokens requiere sesión web + CSRF.
- La primera versión incluye UI Lustre de administración.
- La primera versión incluye guía para integraciones externas con ejemplos
  `curl`.
- La auditoría mínima registra token, fecha, IP, método, endpoint y status.

## Principios de diseño

- Usar tokens opacos, no JWT de larga duración.
- Guardar en base de datos solo el hash del token, nunca el secreto completo.
- Modelar usuarios de integración de forma explícita en dominio y auditoría; no
  esconderlos como tokens sueltos ni como usuarios humanos ficticios.
- No obligar al usuario final a crear la identidad técnica como paso previo si
  el caso de uso de creación de token puede hacerlo de forma transaccional.
- Aplicar permisos efectivos como intersección entre:
  - permisos/membresías del usuario de integración;
  - proyecto opcional asignado al token;
  - scopes del token.
- Mantener CSRF obligatorio para sesión web por cookies.
- No exigir CSRF para Bearer, porque `Authorization` no es una credencial
  enviada automáticamente por el navegador como una cookie.
- Centralizar el mapa de scopes y la restricción de proyecto para evitar checks
  duplicados en handlers.
- Denegar por defecto cualquier ruta Bearer no contemplada.
- Preferir tipos Gleam explícitos a strings sueltos en la lógica de dominio.
- Documentar contrato público y decisiones de seguridad, no código evidente.

## Contrato HTTP

Formato de autenticación:

```http
Authorization: Bearer sbt_<public_id>_<secret>
```

Respuesta esperada:

- `401 UNAUTHORIZED`: token ausente cuando la ruta lo requiere, token inválido,
  revocado o expirado.
- `403 FORBIDDEN`: token válido sin scope suficiente, sin acceso al proyecto o
  ruta no habilitada para Bearer.

Rutas no soportadas con Bearer deben devolver `403 FORBIDDEN`, aunque el token
sea válido.

## Usuarios de integración

El usuario de integración es la identidad operativa real del sistema externo.
Debe existir como entidad explícita en dominio, permisos y auditoría. En la UI
principal no se gestiona como paso separado: el formulario de token recibe la
integración y el servicio crea o reutiliza la identidad técnica en la misma
transacción.

Modelo recomendado:

- Añadir `user_kind` a `users`: `human` o `integration`.
- Permitir que `password_hash` sea `NULL` solo para usuarios de integración.
- Impedir login web con usuarios `integration`.
- Reutilizar membresías de organización/proyecto existentes para controlar el
  acceso base.
- Crear tokens únicamente para usuarios `integration`.

Constraint recomendada:

```sql
ALTER TABLE users
ADD COLUMN user_kind TEXT NOT NULL DEFAULT 'human',
ALTER COLUMN password_hash DROP NOT NULL,
ADD CONSTRAINT users_user_kind_check
  CHECK (user_kind IN ('human', 'integration')),
ADD CONSTRAINT users_password_for_humans_check
  CHECK (
    (user_kind = 'human' AND password_hash IS NOT NULL)
    OR user_kind = 'integration'
  );
```

Si la migración exacta choca con el esquema actual, mantener el mismo principio:
el tipo de usuario debe ser consultable y el login web debe excluir
integraciones de forma explícita.

## Scopes

Scopes iniciales:

- `projects:read`
- `tasks:read`
- `tasks:write`
- `cards:read`
- `cards:write`
- `notes:read`
- `notes:write`
- `milestones:read`
- `milestones:write`

No se añade `pool:read` en la versión definitiva. El pool se autoriza mediante
los scopes de los recursos que expone. Esto evita un scope especial que duplique
conceptos y mantiene la regla "read/write por tipo de recurso".

## Rutas Bearer soportadas

Projects:

- `GET /api/v1/projects` -> `projects:read`

Tasks:

- `GET /api/v1/projects/:project_id/tasks` -> `tasks:read`
- `GET /api/v1/tasks/:task_id` -> `tasks:read`
- `POST /api/v1/projects/:project_id/tasks` -> `tasks:write`
- `PATCH /api/v1/tasks/:task_id` -> `tasks:write`
- `POST /api/v1/tasks/:task_id/claim` -> `tasks:write`
- `POST /api/v1/tasks/:task_id/release` -> `tasks:write`
- `POST /api/v1/tasks/:task_id/complete` -> `tasks:write`

Cards:

- `GET /api/v1/projects/:project_id/cards` -> `cards:read`
- `GET /api/v1/cards/:card_id` -> `cards:read`
- `POST /api/v1/projects/:project_id/cards` -> `cards:write`
- `PATCH /api/v1/cards/:card_id` -> `cards:write`
- `DELETE /api/v1/cards/:card_id` -> `cards:write`

Notes:

- `GET /api/v1/tasks/:task_id/notes` -> `notes:read`
- `POST /api/v1/tasks/:task_id/notes` -> `notes:write`
- `GET /api/v1/cards/:card_id/notes` -> `notes:read`
- `POST /api/v1/cards/:card_id/notes` -> `notes:write`
- `PATCH /api/v1/notes/:note_id` -> `notes:write`
- `DELETE /api/v1/notes/:note_id` -> `notes:write`

Milestones:

- `GET /api/v1/projects/:project_id/milestones` -> `milestones:read`
- `GET /api/v1/milestones/:milestone_id` -> `milestones:read`
- `POST /api/v1/projects/:project_id/milestones` -> `milestones:write`
- `PATCH /api/v1/milestones/:milestone_id` -> `milestones:write`
- `DELETE /api/v1/milestones/:milestone_id` -> `milestones:write`

Administración y workflows quedan fuera de la primera versión Bearer.

## Fase 1: Modelo de base de datos

Crear una migración para:

- `users.user_kind` y la exclusión de login web para integraciones.
- `api_tokens`
- `api_token_scopes`
- `api_token_audit_log`

Modelo propuesto:

```sql
CREATE TABLE api_tokens (
  id BIGSERIAL PRIMARY KEY,
  org_id BIGINT NOT NULL REFERENCES organizations(id),
  integration_user_id BIGINT NOT NULL REFERENCES users(id),
  project_id BIGINT REFERENCES projects(id),
  created_by BIGINT NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  public_id TEXT NOT NULL UNIQUE,
  token_hash TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  CHECK (length(trim(name)) > 0)
);

CREATE TABLE api_token_scopes (
  token_id BIGINT NOT NULL REFERENCES api_tokens(id) ON DELETE CASCADE,
  scope TEXT NOT NULL,
  PRIMARY KEY (token_id, scope),
  CHECK (
    scope IN (
      'projects:read',
      'tasks:read',
      'tasks:write',
      'cards:read',
      'cards:write',
      'notes:read',
      'notes:write',
      'milestones:read',
      'milestones:write'
    )
  )
);

CREATE TABLE api_token_audit_log (
  id BIGSERIAL PRIMARY KEY,
  token_id BIGINT REFERENCES api_tokens(id),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip TEXT,
  method TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  status INT NOT NULL
);
```

Notas:

- `project_id NULL` significa "todos los proyectos accesibles por el usuario de
  integración".
- `project_id NOT NULL` limita el token a ese proyecto aunque el usuario de
  integración tenga acceso a otros.
- La restricción de proyecto se valida también en servicio para evitar confiar
  solo en rutas que ya traen `project_id`.
- Los scopes van en tabla normalizada, no arrays ni JSON.
- Añadir SQL en `apps/server/src/scrumbringer_server/sql/`.
- Regenerar `apps/server/src/scrumbringer_server/sql.gleam` con Squirrel.

## Fase 2: Servicio de usuarios de integración

Crear o ampliar servicio existente de usuarios con funciones explícitas:

```text
apps/server/src/scrumbringer_server/services/integration_users.gleam
```

Funciones públicas:

- `create(...) -> Result(IntegrationUser, IntegrationUserError)`
- `list_for_org(...) -> Result(List(IntegrationUser), IntegrationUserError)`
- `get(...) -> Result(IntegrationUser, IntegrationUserError)`
- `ensure_can_receive_token(...) -> Result(Nil, IntegrationUserError)`

Reglas:

- Solo admins pueden crear usuarios de integración desde UI/API admin.
- No tienen login web.
- Se reutilizan membresías existentes para decidir a qué proyectos puede acceder
  la integración.
- No crear una capa de permisos nueva si las membresías actuales bastan.

## Fase 3: Servicio de tokens

Crear:

```text
apps/server/src/scrumbringer_server/services/api_tokens.gleam
```

Tipos principales:

```gleam
pub type Resource {
  Projects
  Tasks
  Cards
  Notes
  Milestones
}

pub type Access {
  Read
  Write
}

pub type Scope {
  Scope(resource: Resource, access: Access)
}

pub type ApiToken {
  ApiToken(
    id: Int,
    org_id: Int,
    integration_user_id: Int,
    project_id: Option(Int),
    name: String,
    public_id: String,
    scopes: List(Scope),
    created_at: String,
    last_used_at: Option(String),
    expires_at: Option(String),
    revoked_at: Option(String),
  )
}

pub type VerifiedToken {
  VerifiedToken(
    token_id: Int,
    integration_user_id: Int,
    org_id: Int,
    project_id: Option(Int),
    scopes: List(Scope),
  )
}
```

Funciones públicas:

- `create(...) -> Result(CreatedToken, ApiTokenError)`
- `verify_bearer(...) -> Result(VerifiedToken, ApiTokenError)`
- `list_for_org(...) -> Result(List(ApiToken), ApiTokenError)`
- `revoke(...) -> Result(Nil, ApiTokenError)`
- `record_use(...) -> Result(Nil, ApiTokenError)`
- `record_audit(...) -> Result(Nil, ApiTokenError)`
- `has_scope(VerifiedToken, Scope) -> Bool`
- `scope_to_string(Scope) -> String`
- `parse_scope(String) -> Result(Scope, ApiTokenError)`

Criptografía:

- Generar secretos con `gleam_crypto.strong_random_bytes`.
- Hashear con `gleam_crypto.hash(Sha256, ...)`.
- Comparar hashes con `gleam_crypto.secure_compare`.
- No usar Argon2 para tokens opacos de alta entropía.

## Fase 4: Integración de autenticación

Modificar:

```text
apps/server/src/scrumbringer_server/http/auth.gleam
```

Añadir un modelo de principal:

```gleam
pub type AuthSource {
  WebSession
  ApiToken(token: api_tokens.VerifiedToken)
}

pub type Principal {
  Principal(user: StoredUser, source: AuthSource)
}
```

Flujo:

1. Si existe `Authorization: Bearer ...`, validar Bearer.
2. Si el Bearer es inválido, devolver `401`; no hacer fallback a cookie.
3. Si no hay Bearer, usar la cookie `sb_session` como ahora.
4. Para Bearer, validar scope requerido por ruta y método.
5. Para Bearer, validar restricción de proyecto.
6. Mantener wrappers compatibles para no reescribir todos los handlers de golpe.

## Fase 5: Autorización Bearer centralizada

Crear:

```text
apps/server/src/scrumbringer_server/http/auth/scopes.gleam
apps/server/src/scrumbringer_server/http/auth/resource_access.gleam
```

`scopes.gleam`:

- Mapea `method + path_segments` a `Scope`.
- Devuelve error explícito cuando la ruta no está autorizada para Bearer.
- No conoce SQL ni servicios de dominio.

`resource_access.gleam`:

- Resuelve el proyecto efectivo de la petición.
- Valida que `token.project_id` permite operar sobre ese proyecto.
- Para rutas con `project_id`, usa el path.
- Para rutas con IDs directos, resuelve el proyecto del recurso:
  - `task_id` -> proyecto de task.
  - `card_id` -> proyecto de card.
  - `note_id` -> proyecto de la entidad propietaria.
  - `milestone_id` -> proyecto de milestone.

Este patrón hace el código DRY sin introducir un framework de permisos: una
tabla de decisión pura para scopes y un helper de proyecto efectivo para los
casos que no pueden validarse solo con el path.

## Fase 6: CSRF

Modificar:

```text
apps/server/src/scrumbringer_server/http/csrf.gleam
```

Regla:

- Si la request trae `Authorization: Bearer ...`, `require_csrf` devuelve
  `Ok(Nil)`.
- Si no trae Bearer, se mantiene el double-submit cookie actual.
- Si trae Bearer inválido, el flujo de auth responde `401` y no se evalúa cookie.

Justificación:

- CSRF protege frente a credenciales que el navegador adjunta automáticamente.
- Un Bearer en `Authorization` debe ser añadido explícitamente por el cliente.
- La seguridad Bearer se apoya en HTTPS, no almacenamiento en navegador,
  revocación, scopes, CORS conservador y auditoría.

## Fase 7: Endpoints admin

Crear:

```text
apps/server/src/scrumbringer_server/http/integration_users.gleam
apps/server/src/scrumbringer_server/http/api_tokens.gleam
apps/server/src/scrumbringer_server/http/api_tokens/payloads.gleam
apps/server/src/scrumbringer_server/http/api_tokens/presenters.gleam
```

Endpoints:

- `GET /api/v1/integration-users`
- `POST /api/v1/integration-users`
- `GET /api/v1/api-tokens`
- `POST /api/v1/api-tokens`
- `DELETE /api/v1/api-tokens/:id`

Payload de creación de token:

```json
{
  "name": "ci-runner",
  "integration_user_id": 42,
  "project_id": 7,
  "scopes": ["tasks:read", "tasks:write"],
  "expires_at": null
}
```

Reglas:

- Solo `org_role.Admin`.
- Crear y revocar tokens solo mediante sesión web + CSRF.
- No permitir crear tokens usando Bearer en la primera versión.
- `project_id` es opcional.
- `expires_at` es opcional.
- El token completo se devuelve únicamente en la respuesta de creación.

Patrón obligatorio en handlers:

1. Parse.
2. Process.
3. Present.

## Fase 8: Lustre

La autenticación del cliente existente sigue usando cookie + CSRF desde
`scrumbringer_client/api/core.gleam`.

Añadir UI de administración pequeña y aislada:

- Listado de tokens.
- Crear token:
  - nombre obligatorio;
  - integración o sistema externo;
  - proyecto opcional, con opción "todos los proyectos permitidos";
  - scopes soportados mediante matriz de permisos;
  - expiración opcional.
- El listado o creación explícita de usuarios de integración queda fuera del
  flujo principal. Puede conservarse como soporte administrativo si resulta
  necesario, pero no debe competir con la acción principal de crear token.
- Mostrar token completo una sola vez.
- Revocar token.

Arquitectura Lustre:

- Crear feature específica si encaja con el patrón actual.
- Mantener `client_view.gleam` y `client_update.gleam` como enroutadores mínimos.
- No mezclar esta UI con la reducción pendiente de `client_view` y
  `client_update`; si se tocan, que sea solo para montar la feature.

## Fase 9: Tests

Unit tests:

- `parse_scope`.
- `scope_to_string`.
- generación de token con prefijo `sbt_`.
- el hash no contiene el secreto.
- verify token válido.
- verify token revocado.
- verify token expirado.
- verify token con hash incorrecto.
- usuario de integración no puede hacer login web.
- token no se puede crear para usuario humano.

HTTP tests Bearer:

- Bearer válido lista proyectos.
- Bearer válido lista tasks.
- Bearer válido crea/actualiza task sin CSRF.
- Bearer válido ejecuta claim/release/complete sin CSRF.
- Bearer válido lista/crea/actualiza/elimina cards según scope.
- Bearer válido lista/crea/actualiza/elimina notes según scope.
- Bearer válido lista/crea/actualiza/elimina milestones según scope.
- Bearer sin scope devuelve `403`.
- Bearer inválido devuelve `401`.
- Bearer revocado devuelve `401`.
- Bearer expirado devuelve `401`.
- Bearer limitado a proyecto A no puede leer ni escribir recursos del proyecto B.
- Bearer sin `project_id` puede operar en proyectos permitidos por su usuario de
  integración.
- Ruta Bearer no contemplada devuelve `403`.
- Cookie web sigue exigiendo CSRF en mutaciones.
- Cookie web sigue funcionando sin cambios.
- Uso Bearer registra auditoría con fecha, endpoint, IP y status.

Lustre tests:

- Decoders/encoders de payloads de tokens.
- Estado de creación con token visible una sola vez.
- Revocación elimina o marca el token en la lista.
- Validación de nombre obligatorio y scopes seleccionados.

Normas:

- Usar `let assert`.
- Usar helpers de `support/assertions`.
- Usar fixtures tipadas.
- No usar `result.unwrap` cuando el valor sea imprescindible.

## Fase 10: Documentación

Crear o ampliar:

```text
docs/api-tokens.md
```

Contenido mínimo:

- Qué es un usuario de integración.
- Cómo crear un usuario de integración.
- Cómo crear y revocar tokens.
- Formato Bearer.
- Proyecto asignado vs todos los proyectos permitidos.
- Scopes disponibles.
- Ejemplos `curl`:
  - listar proyectos;
  - listar tasks;
  - crear task;
  - listar cards;
  - crear note;
  - listar milestones.
- Códigos de error `401` y `403`.
- Nota de seguridad: el token completo solo se muestra una vez.
- Recomendación de rotación y revocación.

Docstrings en código:

- Tipos públicos.
- Funciones públicas.
- Decisiones de seguridad no obvias:
  - no fallback de Bearer a cookie;
  - default deny de scopes;
  - almacenamiento hash-only;
  - `project_id NULL` significa todos los proyectos permitidos, no todos los
    proyectos de la base de datos.

## Fase 11: Validación

Comandos:

```bash
cd apps/server && gleam format src test
cd apps/server && DATABASE_URL="..." gleam test
cd apps/client && gleam test
bash scripts/build-prod.sh
```

Si cambia `sql.gleam`:

```bash
make squirrel DATABASE_URL="..."
```

Si hay migración:

```bash
make migrate DATABASE_URL="..."
```

## Orden de commits recomendado

1. `feat: model integration users for api tokens`
2. `feat: add api token storage and verification`
3. `feat: enforce bearer scopes and project limits`
4. `feat: expose integration user and token admin endpoints`
5. `feat: add api token admin UI`
6. `test: cover bearer token auth flows`
7. `docs: document api token usage`

## Criterios de cierre

- Las integraciones externas pueden usar Bearer para projects, tasks, cards,
  notes y milestones.
- La sesión web sigue usando cookie + CSRF sin cambios funcionales.
- Los tokens solo se crean para usuarios de integración.
- Los usuarios de integración no pueden hacer login web.
- Los tokens son revocables.
- Los tokens expirados o revocados devuelven `401`.
- Los tokens válidos sin scope suficiente devuelven `403`.
- Un Bearer inválido no hace fallback a cookie.
- Un token limitado a proyecto no puede operar fuera de ese proyecto.
- Un token sin proyecto queda limitado por las membresías del usuario de
  integración.
- Los scopes están definidos en un único módulo.
- La restricción de proyecto está centralizada.
- El token completo nunca se guarda en base de datos.
- La auditoría registra IP, endpoint y fecha.
- La UI permite crear/revocar tokens y muestra el secreto una sola vez.
- La documentación incluye guía de integración y ejemplos `curl`.
- Los tests cubren happy path, error paths y regresión de CSRF web.
- El build de producción no emite warnings nuevos.
