# API tokens Bearer

ScrumBringer permite que sistemas externos usen tokens Bearer para consultar y
operar sobre proyectos, tasks, cards, notes y milestones sin depender de la
sesion web del navegador.

## Modelo

- Un token pertenece siempre a una integracion tecnica interna.
- La UI crea o reutiliza esa integracion al crear el token.
- Los usuarios de integracion no pueden iniciar sesion en la UI.
- Un token puede limitarse a un proyecto concreto.
- Si el token no tiene proyecto asignado, puede operar en todos los proyectos
  actuales y futuros de la organizacion.
- El acceso de proyecto deriva del grant activo del token; ScrumBringer no crea
  membresias artificiales en `project_members` para las integraciones.
- El token completo se muestra una sola vez al crearlo.
- La base de datos guarda solo el hash del token.
- Los tokens no expiran por defecto; `expires_at` es opcional.
- Los tokens se pueden revocar.

## Formato

Enviar el token en la cabecera `Authorization`:

```http
Authorization: Bearer sbt_<public_id>_<secret>
```

Un Bearer invalido devuelve `401` y no hace fallback a cookies de sesion. Un
Bearer valido sin scope suficiente, sin acceso al proyecto, o usado contra una
ruta no soportada por Bearer devuelve `403`.

## Scopes

Scopes disponibles:

- `projects:read`
- `tasks:read`
- `tasks:write`
- `cards:read`
- `cards:write`
- `notes:read`
- `notes:write`
- `milestones:read`
- `milestones:write`

Administracion y workflows no estan disponibles mediante Bearer en la primera
version.

## Crear y revocar

Desde la UI de administracion:

1. Entra como admin de organizacion.
2. Abre `Organizacion -> Tokens API`.
3. Crea un token.
4. Indica el nombre de la integracion o sistema externo.
5. Selecciona proyecto, permisos y expiracion opcional.
6. Copia el secreto completo en ese momento.
7. Revoca el token cuando deje de usarse.

Si la integracion indicada ya existe en la organizacion se reutiliza; si no
existe, ScrumBringer la crea automaticamente como identidad tecnica interna.
Para integraciones de agentes, selecciona un proyecto concreto si quieres
limitar el alcance. Selecciona todos los proyectos si el agente debe descubrir y
operar sobre todos los proyectos de la organizacion, actuales y futuros.

Crear y revocar tokens sigue usando sesion web y CSRF. No se permite administrar
tokens usando otro Bearer en esta version.

## Ejemplos

Define variables comunes:

```bash
BASE_URL="https://scrumbringer.example.com"
TOKEN="sbt_public_secret"
PROJECT_ID="1"
TASK_ID="10"
CARD_ID="20"
MILESTONE_ID="30"
```

Listar proyectos:

```bash
curl -fsS \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/projects"
```

Si devuelve `{"projects":[]}` aunque existan proyectos en la organizacion,
comprueba que el token incluye `projects:read`, que se creo en la instancia
correcta y que no esta limitado a otro proyecto.

Listar tasks de un proyecto:

```bash
curl -fsS \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/tasks"
```

Crear una task:

```bash
curl -fsS \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Sync external task","description":"Created from integration","priority":3}' \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/tasks"
```

Listar cards:

```bash
curl -fsS \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/cards"
```

Crear una note en una task:

```bash
curl -fsS \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content":"External update received"}' \
  "$BASE_URL/api/v1/tasks/$TASK_ID/notes"
```

Listar milestones:

```bash
curl -fsS \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/projects/$PROJECT_ID/milestones"
```

## Auditoria

Cada uso Bearer registra, cuando es posible:

- token;
- fecha;
- IP;
- metodo;
- endpoint;
- status HTTP.

La auditoria sirve para trazabilidad operativa, no como mecanismo de permisos.

## Recomendaciones

- Usa una integracion por sistema externo.
- Da solo los scopes necesarios.
- Asigna proyecto cuando la integracion no necesite operar sobre toda la
  organizacion.
- Rota y revoca tokens cuando cambie el sistema consumidor o se sospeche una
  exposicion.
- No guardes tokens en clientes web ni en repositorios.
