//// Spanish translations for Scrumbringer UI.
////
//// Provides Spanish (es) translations for all UI text keys defined in text.gleam.

import gleam/int

import scrumbringer_client/i18n/text.{type Text}

pub fn translate(text: Text) -> String {
  case text {
    // App
    text.AppName -> "ScrumBringer"
    text.AppSectionTitle -> "App"

    // Auth
    text.LoginTitle -> "Acceso"
    text.LoginSubtitle ->
      "Inicia sesión para acceder al panel de administración."
    text.NoEmailIntegrationNote ->
      "No hay integración de email en el MVP. Esto genera un link de reset que puedes copiar/pegar."
    text.EmailLabel -> "Email"
    text.EmailPlaceholderExample -> "user@company.com"
    text.PasswordLabel -> "Contraseña"
    text.NewPasswordLabel -> "Nueva contraseña"
    text.MinimumPasswordLength -> "Mínimo 12 caracteres"
    text.Logout -> "Salir"

    text.AcceptInviteTitle -> "Aceptar invitación"
    text.ResetPasswordTitle -> "Restablecer contraseña"
    text.MissingInviteToken -> "Falta el token de invitación"
    text.ValidatingInvite -> "Validando invitación…"
    text.SignedIn -> "Sesión iniciada"
    text.MissingResetToken -> "Falta el token de reset"
    text.ValidatingResetToken -> "Validando token de reset…"
    text.PasswordUpdated -> "Contraseña actualizada"
    text.Welcome -> "Bienvenido"
    text.LoggedIn -> "Sesión iniciada"
    text.InvalidCredentials -> "Credenciales inválidas"
    text.EmailAndPasswordRequired -> "Email y contraseña requeridos"
    text.EmailRequired -> "El email es obligatorio"
    text.LogoutFailed -> "Error al salir"

    // Toasts / messages
    text.LoggedOut -> "Sesión cerrada"
    text.ProjectCreated -> "Proyecto creado"
    text.CapabilityCreated -> "Capacidad creada"
    text.InviteLinkCreated -> "Link de invitación creado"
    text.InviteLinkRegenerated -> "Link de invitación regenerado"
    text.RoleUpdated -> "Rol actualizado"
    text.CannotDemoteLastManager -> "No se puede degradar al último manager del proyecto"
    text.MemberAdded -> "Miembro añadido"
    text.MemberRemoved -> "Miembro quitado"
    text.TaskTypeCreated -> "Tipo de tarea creado"
    text.TaskCreated -> "Tarea creada"
    text.TaskClaimed -> "Tarea reclamada"
    text.TaskReleased -> "Tarea liberada"
    text.TaskCompleted -> "Tarea completada"
    text.SkillsSaved -> "Skills guardadas"
    text.NoteAdded -> "Nota añadida"

    // Validation
    text.NameRequired -> "El nombre es obligatorio"
    text.TitleRequired -> "El título es obligatorio"
    text.TypeRequired -> "El tipo es obligatorio"
    text.SelectProjectFirst -> "Selecciona un proyecto primero"
    text.SelectUserFirst -> "Selecciona un usuario primero"
    text.InvalidXY -> "x/y inválidos"
    text.ContentRequired -> "Contenido obligatorio"

    text.Copied -> "Copiado"
    text.Copying -> "Copiando…"
    text.CopyFailed -> "Error al copiar"

    // Accessibility
    text.SkipToContent -> "Saltar al contenido"

    // Common
    text.Dismiss -> "Cerrar"
    text.Cancel -> "Cancelar"
    text.Close -> "Cerrar"
    text.Create -> "Crear"
    text.Creating -> "Creando…"
    text.Copy -> "Copiar"
    text.Save -> "Guardar"
    text.SaveNewPassword -> "Guardar nueva contraseña"
    text.Saving -> "Guardando…"
    text.Register -> "Registrarse"
    text.Registering -> "Registrando…"
    text.Working -> "Trabajando…"
    text.GenerateResetLink -> "Generar link de reset"
    text.ForgotPassword -> "¿Olvidaste la contraseña?"
    text.ResetLink -> "Link de reset"
    text.CreateInviteLink -> "Crear link de invitación"
    text.Add -> "Añadir"
    text.Adding -> "Añadiendo…"
    text.Removing -> "Quitando…"
    text.NoneOption -> "Ninguna"
    text.Start -> "Empezar"
    text.LoggingIn -> "Iniciando sesión…"
    text.Loading -> "Cargando"
    text.LoadingEllipsis -> "Cargando…"

    // Settings controls
    text.ThemeLabel -> "Tema"
    text.ThemeDefault -> "Por defecto"
    text.ThemeDark -> "Oscuro"
    text.LanguageLabel -> "Idioma"
    text.LanguageEs -> "Español"
    text.LanguageEn -> "Inglés"

    // Member sections
    text.Pool -> "Pool"
    text.MyBar -> "Mi barra"
    text.MySkills -> "Mis skills"
    text.MySkillsHelp ->
      "Selecciona las capacidades que tienes. El Pool destacará las tareas que coincidan."
    text.MyTasks -> "Mis tareas"
    text.NoClaimedTasks -> "No hay tareas reclamadas"
    text.GoToPoolToClaimTasks -> "Ve al Pool para reclamar tareas"
    text.NoProjectsBody -> "Pide a un admin que te añada a un proyecto."
    text.You -> "Tú"
    text.Notes -> "Notas"
    text.AddNote -> "Añadir nota"
    text.EditPosition -> "Editar posición"
    text.XLabel -> "x"
    text.YLabel -> "y"

    // Member pool controls
    text.ViewCanvas -> "Vista: canvas"
    text.ViewList -> "Vista: lista"
    text.Canvas -> "Lienzo"
    text.List -> "Lista"
    text.ShowFilters -> "Mostrar filtros"
    text.HideFilters -> "Ocultar filtros"
    text.NewTask -> "Nueva tarea"
    text.Description -> "Descripción"
    text.Priority -> "Prioridad"
    text.NewTaskShortcut -> "Nueva tarea (n)"
    text.AllOption -> "Todas"
    text.SelectType -> "Selecciona tipo"
    text.MyCapabilitiesOn -> "Activado"
    text.MyCapabilitiesOff -> "Desactivado"
    text.TypeLabel -> "Tipo"
    text.CapabilityLabel -> "Capacidad"
    text.MyCapabilitiesLabel -> "Mis capacidades"
    text.MyCapabilitiesHint -> "Filtrar tareas que coinciden con mis capacidades"
    text.SearchLabel -> "Buscar"
    text.SearchPlaceholder -> "q"
    text.NoAvailableTasksRightNow -> "No hay tareas disponibles ahora"
    text.CreateFirstTaskToStartUsingPool ->
      "Crea tu primera tarea para empezar a usar el Pool."
    text.NoTasksMatchYourFilters -> "Ninguna tarea coincide con tus filtros"
    text.TypeNumber(type_id) -> "Tipo #" <> int.to_string(type_id)
    text.MetaType -> "tipo: "
    text.MetaPriority -> "prioridad: "
    text.MetaCreated -> "creada: "
    text.PriorityShort(priority) -> "P" <> int.to_string(priority)
    text.Claim -> "Reclamar"
    text.Drag -> "Arrastrar"
    text.StartNowWorking -> "Empezar en curso"
    text.PauseNowWorking -> "Pausar en curso"

    // Now working
    text.NowWorking -> "En curso"
    text.NowWorkingLoading -> "En curso: cargando…"
    text.NowWorkingNone -> "En curso: ninguna"
    text.NowWorkingErrorPrefix -> "Error En curso: "
    text.Pause -> "Pausar"
    text.Complete -> "Completar"
    text.Release -> "Liberar"
    text.TaskNumber(task_id) -> "Tarea #" <> int.to_string(task_id)

    // Admin
    text.Admin -> "Admin"
    text.AdminInvites -> "Invitaciones"
    text.AdminOrgSettings -> "Org"
    text.OrgSettingsHelp ->
      "Gestiona roles de la org (admin/member). Los cambios requieren Guardar y están protegidos por una regla de último admin."
    text.RoleAdmin -> "admin"
    text.RoleMember -> "miembro"
    text.RoleManager -> "manager"
    text.AdminProjects -> "Proyectos"
    text.AdminMetrics -> "Métricas"
    text.AdminMembers -> "Miembros"
    text.AdminCapabilities -> "Capacidades"
    text.AdminTaskTypes -> "Tipos de tarea"
    text.NoAdminPermissions -> "Sin permisos de admin"
    text.NotPermitted -> "No permitido"
    text.NotPermittedBody -> "No tienes permiso para acceder a esta sección."

    // Admin sidebar groups (SA01-SA05)
    text.NavGroupOrganization -> "Organización"
    text.NavGroupProjects -> "Proyectos"
    text.NavGroupConfiguration -> "Configuración"
    text.NavGroupContent -> "Contenido"

    // Project selector
    text.ProjectLabel -> "Proyecto"
    text.AllProjects -> "Todos los proyectos"
    text.SelectProjectToManageSettings ->
      "Selecciona un proyecto para gestionar ajustes…"
    text.ShowingTasksFromAllProjects ->
      "Mostrando tareas de todos los proyectos"
    text.SelectProjectToManageMembersOrTaskTypes ->
      "Selecciona un proyecto para gestionar miembros o tipos de tarea"

    // Metrics
    text.MyMetrics -> "Mis métricas"
    text.LoadingMetrics -> "Cargando métricas…"
    text.WindowDays(days) -> "Ventana: " <> int.to_string(days) <> " días"
    text.Claimed -> "Reclamadas"
    text.Released -> "Liberadas"
    text.Completed -> "Completadas"
    text.MetricsOverview -> "Resumen de métricas"
    text.LoadingOverview -> "Cargando resumen…"
    text.ReleasePercent -> "Liberación %"
    text.FlowPercent -> "Flujo %"
    text.TimeToFirstClaim -> "Tiempo hasta el primer claim"
    text.TimeToFirstClaimP50(p50, sample_size) ->
      "P50: " <> p50 <> " (n=" <> int.to_string(sample_size) <> ")"
    text.ReleaseRateDistribution -> "Distribución de tasa de liberación"
    text.Bucket -> "Rango"
    text.Count -> "Cantidad"
    text.ByProject -> "Por proyecto"
    text.Drill -> "Detalle"
    text.View -> "Ver"
    text.ProjectDrillDown -> "Detalle por proyecto"
    text.SelectProjectToInspectTasks ->
      "Selecciona un proyecto para inspeccionar tareas."
    text.LoadingTasks -> "Cargando tareas…"
    text.Title -> "Título"
    text.Status -> "Estado"
    text.Claims -> "Claims"
    text.Releases -> "Liberaciones"
    text.Completes -> "Completadas"
    text.FirstClaim -> "Primer claim"
    text.ProjectTasks(project_name) -> "Tareas del proyecto: " <> project_name

    // Org users
    text.OpenThisSectionToLoadUsers -> "Abre esta sección para cargar usuarios."
    text.LoadingUsers -> "Cargando usuarios…"
    text.Role -> "Rol"
    text.Actions -> "Acciones"
    text.User -> "Usuario"
    text.UserId -> "ID usuario"
    text.UserNumber(user_id) -> "Usuario #" <> int.to_string(user_id)
    text.Created -> "Creado"
    text.SearchByEmail -> "Buscar por email"
    text.Searching -> "Buscando…"
    text.TypeAnEmailToSearch -> "Escribe un email para buscar"
    text.NoResults -> "Sin resultados"
    text.Select -> "Seleccionar"
    text.OrgRole -> "Rol org"

    // Invite links
    text.InvitesTitle -> "INVITACIONES"
    text.LatestInviteLink -> "Último link de invitación"
    text.InviteLinks -> "Links de invitación"
    text.InviteLinksHelp ->
      "Crea links de invitación asociados a un email. Copia el link generado para dar de alta a un usuario."
    text.FailedToLoadInviteLinksPrefix -> "Error cargando links: "
    text.NoInviteLinksYet -> "Aún no hay links de invitación"
    text.Link -> "Link"
    text.State -> "Estado"
    text.CreatedAt -> "Creado"
    text.Regenerate -> "Regenerar"

    // Projects
    text.Projects -> "Proyectos"
    text.CreateProject -> "Crear proyecto"
    text.Name -> "Nombre"
    text.MyRole -> "Mi rol"
    text.NoProjectsYet -> "Aún no hay proyectos"

    // Capabilities
    text.Capabilities -> "Capacidades"
    text.CreateCapability -> "Crear capacidad"
    text.CapabilityNamePlaceholder -> "ej., Frontend, Backend, UX..."
    text.NoCapabilitiesYet -> "Aún no hay capacidades"

    // Members
    text.SelectProjectToManageMembers ->
      "Selecciona un proyecto para gestionar miembros."
    text.MembersTitle(project_name) -> "Miembros - " <> project_name
    text.MembersHelp ->
      "Los miembros pueden ver y reclamar tareas de este proyecto. Gestiona quién tiene acceso y con qué rol."
    text.AddMember -> "Añadir miembro"
    text.NoMembersYet -> "Aún no hay miembros"
    text.RemoveMemberTitle -> "Quitar miembro"
    text.RemoveMemberConfirm(user_email, project_name) ->
      "¿Quitar " <> user_email <> " de " <> project_name <> "?"
    text.Remove -> "Quitar"

    // User Projects dialog
    text.UserProjectsTitle(user_email) -> "Proyectos de " <> user_email
    text.UserProjectsEmpty -> "Este usuario no pertenece a ningún proyecto."
    text.UserProjectsAdd -> "Añadir a proyecto"
    text.SelectProject -> "Seleccionar proyecto"
    text.UserProjectRemove -> "Quitar"
    text.RoleInProject -> "Rol en proyecto"
    text.ProjectRoleUpdated -> "Rol de proyecto actualizado"

    // Org Users main table
    text.Manage -> "Gestionar"
    text.SaveOrgRoleChanges -> "Guardar cambios de rol"
    text.PendingChanges -> "cambios pendientes"
    text.ProjectsSummary(count, summary) ->
      case count {
        0 -> "Sin proyectos"
        _ -> int.to_string(count) <> ": " <> summary
      }

    // Task types
    text.SelectProjectToManageTaskTypes ->
      "Selecciona un proyecto para gestionar tipos de tarea."
    text.TaskTypesTitle(project_name) -> "Tipos de tarea - " <> project_name
    text.CreateTaskType -> "Crear tipo de tarea"
    text.IdentitySection -> "Identidad"
    text.AppearanceSection -> "Apariencia"
    text.ConfigurationSection -> "Configuración"
    text.Icon -> "Icono"
    text.UnknownIcon -> "Icono desconocido"
    text.CapabilityOptional -> "Capacidad (opcional)"
    text.LoadingCapabilities -> "Cargando capacidades…"
    text.NoTaskTypesYet -> "Aún no hay tipos de tarea"
    text.CreateFirstTaskTypeHint ->
      "Crea el primer tipo de tarea abajo para empezar a usar el Pool."
    text.TaskTypesExplain ->
      "Los tipos de tarea definen qué tarjetas se pueden crear (p.ej. Bug, Feature)."
    text.HeroiconSearchPlaceholder -> "Busca nombre de heroicon (p.ej. bug-ant)"
    text.WaitForIconPreview -> "Espera la previsualización del icono"
    text.TitleTooLongMax56 -> "Título demasiado largo (máx 56 caracteres)"
    text.NameAndIconRequired -> "Nombre e icono obligatorios"
    text.PriorityMustBe1To5 -> "La prioridad debe ser 1-5"

    // Popover
    text.PopoverType -> "Tipo"
    text.PopoverCreated -> "Creada"
    text.PopoverStatus -> "Estado"
    text.CreatedAgoDays(days) -> {
      case days {
        0 -> "hoy"
        1 -> "hace 1 día"
        _ -> "hace " <> int.to_string(days) <> " días"
      }
    }

    // Cards
    text.AdminCards -> "Fichas"
    text.CardsTitle(project_name) -> "Fichas - " <> project_name
    text.SelectProjectToManageCards ->
      "Selecciona un proyecto para gestionar fichas."
    text.CreateCard -> "Crear ficha"
    text.EditCard -> "Editar ficha"
    text.DeleteCard -> "Eliminar ficha"
    text.CardTitle -> "Título"
    text.CardDescription -> "Descripción"
    text.CardState -> "Estado"
    text.CardStatePendiente -> "Pendiente"
    text.CardStateEnCurso -> "En curso"
    text.CardStateCerrada -> "Cerrada"
    text.CardTasks -> "Tareas"
    text.CardProgress -> "Progreso"
    text.CardCreated -> "Ficha creada"
    text.CardUpdated -> "Ficha actualizada"
    text.CardDeleted -> "Ficha eliminada"
    text.CardDeleteBlocked -> "No se puede eliminar: tiene tareas"
    text.CardDeleteConfirm(card_title) ->
      "¿Eliminar la ficha \"" <> card_title <> "\"?"
    text.NoCardsYet -> "Aún no hay fichas"
    text.CardTaskCount(completed, total) ->
      int.to_string(completed) <> "/" <> int.to_string(total)

    // Workflows
    text.AdminWorkflows -> "Automatizaciones"
    text.WorkflowsTitle -> "Automatizaciones"
    text.WorkflowsOrgTitle -> "Automatizaciones de la organización"
    text.WorkflowsProjectTitle(project_name) ->
      "Automatizaciones - " <> project_name
    text.WorkflowName -> "Nombre"
    text.WorkflowDescription -> "Descripción"
    text.WorkflowScope -> "Alcance"
    text.WorkflowScopeOrg -> "Organización"
    text.WorkflowScopeProject -> "Proyecto"
    text.WorkflowRules -> "Reglas"
    text.WorkflowActive -> "Activo"
    text.WorkflowCreated -> "Automatización creada"
    text.WorkflowUpdated -> "Automatización actualizada"
    text.CreateWorkflow -> "Crear automatización"
    text.EditWorkflow -> "Editar automatización"
    text.DeleteWorkflow -> "Eliminar automatización"
    text.WorkflowDeleteConfirm(name) ->
      "¿Eliminar la automatización \"" <> name <> "\"?"
    text.NoWorkflowsYet -> "Aún no hay automatizaciones"
    text.WorkflowDeleted -> "Automatización eliminada"

    // Rules
    text.RulesTitle(workflow_name) -> "Reglas - " <> workflow_name
    text.RuleName -> "Nombre"
    text.RuleGoal -> "Objetivo"
    text.RuleResourceType -> "Tipo recurso"
    text.RuleResourceTypeTask -> "Tarea"
    text.RuleResourceTypeCard -> "Ficha"
    text.RuleToState -> "Estado destino"
    text.RuleTaskType -> "Tipo de tarea"
    text.RuleActive -> "Activo"
    text.RuleTemplates -> "Plantillas"
    text.CreateRule -> "Crear regla"
    text.EditRule -> "Editar regla"
    text.DeleteRule -> "Eliminar regla"
    text.NoRulesYet -> "Aún no hay reglas"
    text.RuleCreated -> "Regla creada"
    text.RuleUpdated -> "Regla actualizada"
    text.RuleDeleted -> "Regla eliminada"
    text.RuleDeleteConfirm(name) -> "¿Eliminar la regla \"" <> name <> "\"?"
    text.AttachTemplate -> "Asociar plantilla"
    text.DetachTemplate -> "Quitar plantilla"
    text.RuleMetricsApplied -> "Aplicadas"
    text.RuleMetricsSuppressed -> "Suprimidas"

    // Task States (for Rules)
    text.TaskStateAvailable -> "Disponible"
    text.TaskStateClaimed -> "Reclamada"
    text.TaskStateCompleted -> "Completada"

    // Task Templates
    text.AdminTaskTemplates -> "Plantillas de tarea"
    text.TaskTemplatesTitle -> "Plantillas de tarea"
    text.TaskTemplatesOrgTitle -> "Plantillas de la organización"
    text.TaskTemplatesProjectTitle(project_name) ->
      "Plantillas - " <> project_name
    text.TaskTemplateName -> "Nombre"
    text.TaskTemplateDescription -> "Descripción"
    text.TaskTemplateType -> "Tipo"
    text.TaskTemplatePriority -> "Prioridad"
    text.TaskTemplateScope -> "Alcance"
    text.TaskTemplateCreated -> "Plantilla creada"
    text.TaskTemplateUpdated -> "Plantilla actualizada"
    text.CreateTaskTemplate -> "Crear plantilla"
    text.EditTaskTemplate -> "Editar plantilla"
    text.DeleteTaskTemplate -> "Eliminar plantilla"
    text.NoTaskTemplatesYet -> "Aún no hay plantillas de tarea"
    text.TaskTemplateDeleted -> "Plantilla eliminada"
    text.TaskTemplateDeleteConfirm(name) -> "¿Eliminar la plantilla \"" <> name <> "\"?"
    text.TaskTemplateVariablesHelp ->
      "Variables: {{father}}, {{from_state}}, {{to_state}}, {{project}}, {{user}}"

    // Rule Metrics Tab
    text.AdminRuleMetrics -> "Métricas de reglas"
    text.RuleMetricsTitle -> "Métricas de reglas"
    text.RuleMetricsHelp ->
      "Ver métricas de ejecución de reglas por workflow. Selecciona un rango de fechas (máx 90 días) para ver conteos de aplicadas y suprimidas."
    text.RuleMetricsFrom -> "Desde"
    text.RuleMetricsTo -> "Hasta"
    text.RuleMetricsRefresh -> "Actualizar"
    text.RuleMetricsSelectRange -> "Selecciona un rango de fechas y haz clic en Actualizar"
    text.RuleMetricsNoData -> "Sin datos de métricas para el rango seleccionado"
    text.RuleMetricsRuleCount -> "Reglas"
    text.RuleMetricsEvaluated -> "Evaluadas"
    text.RuleMetricsNoRules -> "No hay reglas en este workflow"
    text.ViewDetails -> "Ver detalles"
    text.RuleMetricsDrilldown -> "Detalles de métricas de regla"
    text.SuppressionBreakdown -> "Desglose de supresiones"
    text.SuppressionIdempotent -> "Idempotente (ya aplicada)"
    text.SuppressionNotUserTriggered -> "No disparada por usuario"
    text.SuppressionNotMatching -> "Condiciones no coinciden"
    text.SuppressionInactive -> "Regla inactiva"
    text.RecentExecutions -> "Ejecuciones recientes"
    text.NoExecutions -> "No se encontraron ejecuciones"
    text.Origin -> "Origen"
    text.Outcome -> "Resultado"
    text.Timestamp -> "Fecha/Hora"
    text.OutcomeApplied -> "Aplicada"
    text.OutcomeSuppressed -> "Suprimida"

    // Story 3.4 - Member Card Views
    text.MemberFichas -> "Fichas"
    text.MemberFichasEmpty -> "No hay fichas"
    text.MemberFichasEmptyHint -> "Las fichas agrupan tareas relacionadas"

    // Color picker
    text.ColorLabel -> "Color"
    text.ColorNone -> "Ninguno"
    text.ColorGray -> "Gris"
    text.ColorRed -> "Rojo"
    text.ColorOrange -> "Naranja"
    text.ColorYellow -> "Amarillo"
    text.ColorGreen -> "Verde"
    text.ColorBlue -> "Azul"
    text.ColorPurple -> "Morado"
    text.ColorPink -> "Rosa"

    // Card grouping
    text.UngroupedTasks -> "Sin ficha"
    text.CardProgressCount(completed, total) ->
      int.to_string(completed) <> "/" <> int.to_string(total)

    // Card detail (member)
    text.CardAddTask -> "Añadir tarea"
    text.CardTasksEmpty -> "No hay tareas"
    text.CardTasksCompleted -> "completadas"
    text.TaskType -> "Tipo de tarea"
    text.TaskTitlePlaceholder -> "Título de la tarea..."
  }
}
