# Helpers Catalog

Objetivo: mantener un inventario claro de helpers para evitar duplicados y
facilitar el reuso.

## Como usar este catalogo

- Antes de crear un helper nuevo, buscar aqui por dominio o palabra clave.
- Si existe un helper similar, reutilizarlo o extenderlo.
- Si no existe, crear el helper en el modulo correcto y registrar la entrada.

## Criterios de modularizacion

Reusar un modulo existente si:
- El helper es generico y ya hay un modulo del dominio (ej: time, validation).
- Evita crear dependencias entre features.

Crear modulo nuevo si:
- Hay 3 o mas funciones relacionadas y reutilizables.
- El helper no depende del Model ni de un feature especifico.

Mantener helper dentro del feature si:
- Usa tipos internos del feature.
- No es reutilizable fuera del feature.

## Inventario

### scrumbringer_client/helpers/dicts.gleam

Proposito: helpers de conversion y manipulacion de diccionarios/listas.

- ids_to_bool_dict(ids: List(Int)) -> Dict(Int, Bool)
- bool_dict_to_ids(values: Dict(Int, Bool)) -> List(Int)
- positions_to_dict(positions: List(TaskPosition)) -> Dict(Int, #(Int, Int))
- flatten_tasks(tasks_by_project: Dict(Int, List(Task))) -> List(Task)
- flatten_task_types(task_types_by_project: Dict(Int, List(TaskType))) -> List(TaskType)

### scrumbringer_client/helpers/options.gleam

Proposito: conversiones simples a Option.

- empty_to_opt(value: String) -> Option(String)
- empty_to_int_opt(value: String) -> Option(Int)

### scrumbringer_client/helpers/lookup.gleam

Proposito: busquedas en colecciones remotas/cache.

- find_task_by_id(tasks: Remote(List(Task)), task_id: Int) -> Option(Task)
- resolve_org_user(cache: Remote(List(OrgUser)), user_id: Int) -> Option(OrgUser)

### scrumbringer_client/helpers/time.gleam

Proposito: helpers de tiempo y formato.

- format_seconds(value: Int) -> String
- now_working_elapsed_from_ms(accumulated_s: Int, started_ms: Int, server_now_ms: Int) -> String

### scrumbringer_client/helpers/validation.gleam

Proposito: validaciones comunes y wrappers.

- NonEmptyString (opaque)
- non_empty_string_value(value: NonEmptyString) -> String
- validate_required_string(model: Model, value: String, error_text: Text) -> Result(NonEmptyString, String)
- validate_required_string_raw(model: Model, value: String, error_text: Text) -> Result(NonEmptyString, String)
- validate_required_fields(model: Model, fields: List(#(String, Text))) -> Result(List(NonEmptyString), String)

### scrumbringer_client/helpers/selection.gleam

Proposito: selection helpers del Model.

- active_projects(model: Model) -> List(Project)
- selected_project(model: Model) -> Option(Project)
- now_working_active_task(model: Model) -> Option(ActiveTask)
- now_working_active_task_id(model: Model) -> Option(Int)
- now_working_all_sessions(model: Model) -> List(WorkSession)
- ensure_selected_project(selected: Option(Int), projects: List(Project)) -> Option(Int)
- ensure_default_section(model: Model) -> Model

### scrumbringer_client/helpers/toast.gleam

Proposito: helpers de effects para toasts.

- toast_effect(message: String, variant: ToastVariant) -> Effect(Msg)
- toast_success(message: String) -> Effect(Msg)
- toast_error(message: String) -> Effect(Msg)
- toast_warning(message: String) -> Effect(Msg)

### scrumbringer_client/helpers/i18n.gleam

Proposito: traduccion.

- i18n_t(model: Model, text: Text) -> String

### scrumbringer_client/helpers/auth.gleam

Proposito: wrappers de auth y errores.

- reset_to_login(model: Model) -> #(Model, Effect(Msg))
- handle_auth_error(model: Model, err: ApiError) -> Option(#(Model, Effect(Msg)))
- handle_401_or(model: Model, err: ApiError, fallback: fn() -> #(Model, Effect(Msg))) -> #(Model, Effect(Msg))

## Politica de actualizacion

- Cada nuevo helper debe agregarse aqui.
- Si un helper cambia de modulo, actualizar esta entrada.
- En Fase 2, este documento debe revisarse y completarse al mover helpers.
