# Plan de mejora UI/UX: API tokens

## Objetivo

Simplificar la experiencia de administracion de tokens API sin perder las
garantias tecnicas ya incorporadas: auditoria, revocacion, scopes, limite por
proyecto y usuarios de integracion como identidad interna.

La interfaz debe presentar una accion principal clara: crear y gestionar tokens
para sistemas externos. El concepto de usuario de integracion debe mantenerse en
el modelo, pero no convertirse en un paso operativo visible salvo que aporte
valor administrativo.

## Principios

- Una accion principal: `Crear token API`.
- Modelo interno explicito: los tokens siguen perteneciendo a usuarios de
  integracion para auditoria y rotacion.
- UX simple: el usuario trabaja con `Integracion` o `Sistema externo`, no con
  "crear usuario de integracion".
- Scopes definidos de forma explicita; no generados como combinacion automatica
  de recurso y permiso.
- Denegar por defecto scopes y rutas no soportadas.
- Evitar sobreingenieria: no crear un subsistema nuevo si el caso de uso puede
  vivir en los servicios actuales con tipos claros y tests.
- Mantener textos visibles breves y operativos; documentar decisiones y contrato
  en `docs/api-tokens.md`, no dentro de la pantalla.

## Alcance

Incluido:

- Redisenar la pantalla `Tokens API`.
- Hacer transparente la creacion/reutilizacion de usuarios de integracion.
- Corregir el catalogo de scopes soportados.
- Mejorar selector de permisos, estado visual, revocacion y secreto creado.
- Validar desktop y movil con agent-browser.
- Actualizar tests y documentacion.

Fuera de alcance:

- Administracion Bearer de workflows.
- Escritura de proyectos mediante Bearer.
- Gestion avanzada independiente de usuarios de integracion.
- Busqueda, filtros y ordenacion avanzada salvo que sean necesarios para no
  romper responsive.

## Decisiones funcionales

### Usuario de integracion

El usuario de integracion se mantiene como identidad tecnica interna. Permite:

- agrupar varios tokens del mismo sistema externo;
- revocar o rotar un token sin borrar la identidad;
- auditar acciones por sistema;
- aplicar membresias y permisos base existentes.

La UI no debe exigir crear esa identidad como paso previo. El formulario de
creacion de token debe aceptar un campo `Integracion` o `Sistema externo`.

Regla:

1. Si la integracion existe en la organizacion, se reutiliza.
2. Si no existe, se crea automaticamente como usuario de integracion.
3. El token se crea asociado a esa identidad.

### Scopes soportados

Catalogo inicial:

- `projects:read`
- `tasks:read`
- `tasks:write`
- `cards:read`
- `cards:write`
- `notes:read`
- `notes:write`
- `milestones:read`
- `milestones:write`

`projects:write` no debe ofrecerse ni aceptarse mientras no haya rutas Bearer de
escritura de proyectos.

## Paquete de cambios

### 1. Catalogo unico de scopes

Problema actual: la UI genera `read` y `write` para todos los recursos, pero la
base de datos solo permite `projects:read` y el router Bearer no define escritura
de proyectos.

Cambios:

- Definir una lista explicita de scopes soportados.
- Usar esa lista para validar entrada HTTP y construir la UI.
- Evitar derivar scopes con `resource x access`.
- Rechazar scopes no soportados con error de validacion, no con error de base de
  datos.

Resultado esperado:

- `projects:write` no aparece en la UI.
- `projects:write` devuelve `422` o error de validacion equivalente en API de
  administracion.
- La migracion, el parser y las rutas Bearer quedan alineados.

### 2. Flujo unico de creacion

Cambios:

- Quitar el CTA principal `Crear usuario de integracion`.
- Mantener un unico CTA visible: `Crear token API`.
- En el dialogo de token, sustituir el selector obligatorio de usuario por un
  campo `Integracion`.
- Permitir elegir una integracion existente o escribir una nueva.
- Crear/reutilizar la identidad de integracion en el mismo caso de uso que crea
  el token.

Contrato recomendado para el caso de uso:

```json
{
  "name": "n8n produccion",
  "integration": "n8n",
  "project_id": 1,
  "scopes": ["tasks:read", "tasks:write"],
  "expires_at": null
}
```

Implementacion recomendada:

- Mantener endpoints internos de usuarios de integracion si ya existen y son
  utiles para la pantalla.
- Anadir una funcion de servicio tipo `create_for_integration(...)` que:
  1. normaliza la integracion;
  2. busca usuario de integracion por organizacion;
  3. lo crea si no existe;
  4. crea el token y sus scopes en transaccion;
  5. devuelve el secreto una sola vez.

### 3. Pantalla principal

Cambios:

- Centrar la vista en una tabla principal de tokens.
- Ocultar la tabla de usuarios de integracion de la vista principal o moverla a
  una seccion secundaria si hace falta conservarla para diagnostico.
- Reducir el peso visual de contenedores grandes cuando solo envuelven tablas.

Columnas recomendadas:

- Nombre
- Integracion
- Proyecto
- Permisos
- Ultimo uso
- Estado
- Acciones

Estados:

- `Activo`
- `Revocado`
- `Expirado`

Deben mostrarse como badges, no como texto plano.

### 4. Selector de permisos

Cambios:

- Reemplazar checkboxes con strings tecnicos por una matriz de permisos.
- Usar etiquetas humanas en UI.
- Mantener strings tecnicos solo en API, persistencia, tests y documentacion.

Formato recomendado:

```text
Recurso       Leer    Escribir
Proyectos     x       -
Tareas        x       x
Tarjetas      x       x
Notas         x       x
Hitos         x       x
```

En movil:

- Mantener filas por recurso.
- Evitar que labels y checkboxes se desalineen.
- No partir scopes tecnicos en varias lineas porque no deberian ser el texto
  principal.

### 5. Secreto creado

Cambios:

- Mostrar el Bearer completo una sola vez tras crear token.
- Usar campo monospace de solo lectura.
- Anadir boton de copiar.
- Mostrar estado `Copiado` tras la accion.
- Mantener una accion clara para cerrar el aviso.

Validacion funcional:

- El secreto completo no aparece en listados posteriores.
- La tabla solo muestra metadatos seguros.

### 6. Revocacion

Cambios:

- El dialogo de revocacion debe incluir el nombre del token.
- Mantener accion destructiva visualmente diferenciada.
- Tras revocar, actualizar estado en tabla sin perder contexto.

### 7. Sidebar y responsive

Cambios:

- Autoexpandir `Organizacion` al entrar en `Tokens API`.
- Asegurar que el item activo queda visible en el sidebar.
- Revisar tabla en movil:
  - si cabe, mantener columnas criticas;
  - si no cabe, usar filas compactas con detalles secundarios.

No introducir una nueva navegacion lateral solo para esta pantalla.

### 8. Documentacion

Actualizar `docs/api-tokens.md`:

- El usuario crea tokens, no usuarios de integracion.
- Cada token pertenece internamente a una integracion.
- La integracion se crea automaticamente si no existe.
- El secreto solo se muestra una vez.
- Listar scopes soportados.
- Mostrar ejemplos `curl` actualizados.

Actualizar el plan tecnico original si alguna decision queda obsoleta por este
pulido de UX.

## Validacion de calidad de codigo

### Revision estatica

Ejecutar:

```sh
gleam check
bash scripts/build-prod.sh
```

Criterios:

- Sin warnings nuevos.
- Sin ramas muertas ni imports no usados.
- Sin strings de scopes duplicados innecesariamente.
- Sin `result.unwrap(0)` en tests nuevos cuando el valor sea imprescindible.
- Los errores esperados se validan con `let assert Ok(...) = ...` o patrones
  equivalentes.

### Tests de servidor

Cubrir:

- crear token con integracion nueva;
- crear token reutilizando integracion existente;
- no permitir `projects:write`;
- deduplicar scopes;
- rechazar scopes vacios;
- rechazar expiracion invalida;
- devolver secreto solo en creacion;
- revocar token;
- token revocado o expirado no autentica;
- rutas no soportadas con Bearer devuelven denegacion;
- auditoria registra token, IP, endpoint, fecha y status cuando aplique.

Ejecutar con base de datos local:

```sh
DATABASE_URL='postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_test?sslmode=disable' gleam test
```

### Tests de cliente

Cubrir:

- la pantalla no muestra CTA principal de crear usuario de integracion;
- el dialogo de token muestra campo `Integracion`;
- la matriz de permisos no renderiza `projects:write`;
- toggles de permisos producen scopes esperados;
- estados de token se renderizan como badges;
- revocacion muestra el nombre del token;
- el aviso de secreto permite cerrar y, si se implementa en test, copiar.

Ejecutar:

```sh
cd apps/client
gleam test
```

### Pruebas de contrato

Anadir una comprobacion que compare el catalogo de scopes de aplicacion contra
la lista permitida por la migracion o contra una constante compartida. El
objetivo es que una divergencia como `projects:write` falle en tests antes de
llegar a UI o base de datos.

## Validacion visual con agent-browser

### Preparacion

Levantar entorno local con la base de datos de test:

```sh
DATABASE_URL='postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_test?sslmode=disable' \
SB_HOST=127.0.0.1 \
DEV_HOST=127.0.0.1 \
CADDY_HTTP_HOST=127.0.0.1 \
CADDY_HTTP_PORT=19197 \
bash scripts/dev-hot.sh
```

Abrir:

```sh
npx agent-browser open http://127.0.0.1:19197
```

### Desktop

Viewport recomendado:

```sh
npx agent-browser resize 1440 1000
```

Validar:

- `Tokens API` es visible o queda accesible sin confusion en la navegacion.
- La pantalla tiene un unico CTA principal: `Crear token API`.
- No aparece `Crear usuario de integracion` como accion principal.
- La tabla de tokens tiene jerarquia visual clara.
- Badges de estado son distinguibles.
- `Todos los proyectos` se entiende como alcance global.
- El dialogo de token cabe sin scroll innecesario.
- La matriz de permisos es escaneable.
- No aparece `projects:write`.
- Crear token muestra el secreto en un bloque claro, con boton copiar.
- Revocar token muestra el nombre correcto.

Capturas recomendadas:

- pantalla vacia;
- dialogo crear token;
- pantalla con token activo;
- aviso de secreto creado;
- dialogo de revocacion;
- token revocado.

### Movil

Viewport recomendado:

```sh
npx agent-browser resize 390 844
```

Validar:

- El CTA principal no se corta.
- El modal ocupa el ancho disponible sin desbordes horizontales.
- La matriz de permisos mantiene filas legibles.
- Labels y checkboxes no se solapan.
- La tabla/lista de tokens no obliga a leer columnas comprimidas.
- Acciones destructivas siguen siendo claras.
- No hay texto que salga de botones, badges o celdas.

Capturas recomendadas:

- pantalla principal;
- dialogo crear token;
- selector de permisos;
- aviso de secreto;
- token revocado.

### Criterios de aceptacion visual

- La pantalla se percibe como una vista administrativa del producto, no como una
  pagina aislada.
- No hay conceptos tecnicos innecesarios en el flujo principal.
- El usuario puede crear un token sin crear manualmente otra entidad antes.
- Los permisos son comprensibles sin conocer los strings internos.
- La UI movil es usable sin desbordes ni labels partidos de forma incoherente.

## Orden recomendado

1. Corregir catalogo de scopes y tests de consistencia.
2. Crear caso de uso `create_for_integration`.
3. Simplificar la pantalla principal y quitar CTA de usuario de integracion.
4. Redisenar dialogo de token y matriz de permisos.
5. Mejorar secreto creado, badges y revocacion.
6. Ajustar sidebar y responsive.
7. Actualizar documentacion.
8. Ejecutar validacion tecnica completa.
9. Ejecutar barrido visual con agent-browser en desktop y movil.

## Riesgos

- Cambiar el flujo puede afectar tests existentes que esperan creacion manual de
  usuarios de integracion.
- La normalizacion de integraciones debe evitar duplicados triviales por casing o
  espacios.
- Si se conserva el endpoint de usuarios de integracion, debe quedar claro que
  es soporte administrativo y no flujo principal.
- El boton copiar puede requerir FFI o API de navegador; si complica demasiado,
  puede implementarse como mejora incremental, manteniendo primero el campo de
  solo lectura.

## Resultado esperado

La funcionalidad queda mas simple para el usuario y mas consistente para el
codigo:

- un unico flujo principal;
- usuarios de integracion transparentes;
- scopes alineados entre UI, backend, rutas y base de datos;
- visualmente coherente con el resto de administracion;
- validada por tests, build de produccion y barrido agent-browser.
