//// API token admin view.

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, form, input, label, option, p, select, text}
import lustre/event

import domain/api_token.{type ApiToken, type IntegrationUser}
import domain/api_token_scope
import domain/project.{type Project}
import domain/remote
import scrumbringer_client/client_state/admin/api_tokens as api_tokens_state
import scrumbringer_client/client_state/types.{
  DialogClosed, DialogOpen, Error as OperationError, InFlight,
}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/admin_surface
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/copyable_input
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/guidance
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/utils/format_date

pub type Config(msg) {
  Config(
    locale: Locale,
    model: api_tokens_state.Model,
    projects: List(Project),
    on_token_create_opened: msg,
    on_token_create_closed: msg,
    on_token_name_changed: fn(String) -> msg,
    on_token_integration_changed: fn(String) -> msg,
    on_token_project_changed: fn(String) -> msg,
    on_token_scope_toggled: fn(api_token_scope.Scope) -> msg,
    on_token_expires_at_changed: fn(String) -> msg,
    on_token_create_submitted: msg,
    on_token_secret_dismissed: msg,
    on_token_secret_copy_clicked: fn(String) -> msg,
    on_token_rename_clicked: fn(Int, String) -> msg,
    on_token_rename_cancelled: msg,
    on_token_rename_name_changed: fn(String) -> msg,
    on_token_rename_submitted: msg,
    on_token_revoke_clicked: fn(Int) -> msg,
    on_token_revoke_cancelled: msg,
    on_token_revoke_confirmed: msg,
    on_integration_deactivate_clicked: fn(Int) -> msg,
    on_integration_deactivate_cancelled: msg,
    on_integration_deactivate_confirmed: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  admin_surface.view(
    section_header.view_with_action(
      icons.Cog,
      t(config, i18n_text.AdminApiTokens),
      ui_button.icon_text(
        t(config, i18n_text.CreateApiToken),
        config.on_token_create_opened,
        icons.Plus,
        ui_button.Primary,
        ui_button.GlobalAction,
      )
        |> ui_button.view,
    ),
    div([], [
      view_created_secret(config),
      guidance.section(t(config, i18n_text.ApiTokenGrantsImmutable)),
      div([attribute.class("api-token-list-card")], [view_tokens(config)]),
      div([attribute.class("api-token-list-card")], [
        section_header.view(icons.Team, t(config, i18n_text.Integrations)),
        view_integrations(config),
      ]),
    ]),
    [
      view_token_dialog(config),
      view_rename_dialog(config),
      view_revoke_dialog(config),
      view_deactivate_integration_dialog(config),
    ],
  )
}

fn view_created_secret(config: Config(msg)) -> Element(msg) {
  case config.model.created_token {
    opt.None -> element.none()
    opt.Some(secret) ->
      div([attribute.class("notice success api-token-secret")], [
        p([], [text(t(config, i18n_text.ApiTokenCreatedSecretNotice))]),
        copyable_input.view(
          t(config, i18n_text.ApiTokenSecret),
          secret,
          config.on_token_secret_copy_clicked(secret),
          t(config, i18n_text.Copy),
          config.model.token_secret_copy_status,
        ),
        ui_button.text(
          t(config, i18n_text.Dismiss),
          config.on_token_secret_dismissed,
          ui_button.Secondary,
          ui_button.EntityAction,
        )
          |> ui_button.view,
      ])
  }
}

fn view_tokens(config: Config(msg)) -> Element(msg) {
  data_table.view_remote(
    config.model.tokens,
    loading_msg: t(config, i18n_text.LoadingEllipsis),
    empty_msg: t(config, i18n_text.NoApiTokensYet),
    config: data_table.new()
      |> data_table.with_error_prefix(t(config, i18n_text.FailedToLoadPrefix))
      |> data_table.with_columns([
        data_table.column_with_class(
          t(config, i18n_text.Name),
          fn(token: ApiToken) { text(token.name) },
          "token-col-name",
          "token-cell-name",
        ),
        data_table.column_with_class(
          t(config, i18n_text.Integration),
          fn(token: ApiToken) { text(token.integration_user_email) },
          "token-col-integration",
          "token-cell-integration",
        ),
        data_table.column_with_class(
          t(config, i18n_text.Project),
          fn(token: ApiToken) {
            badge.new_unchecked(
              project_name(config, config.projects, token.project_id),
              badge.Neutral,
            )
            |> badge.view_with_class("api-token-project-badge")
          },
          "token-col-project",
          "token-cell-project",
        ),
        data_table.column_with_class(
          t(config, i18n_text.Scopes),
          fn(token: ApiToken) { view_scope_summary(config, token.scopes) },
          "token-col-scopes",
          "token-cell-scopes",
        ),
        data_table.column_with_class(
          t(config, i18n_text.LastUsed),
          fn(token: ApiToken) { text(optional_date(token.last_used_at)) },
          "token-col-last-used",
          "token-cell-last-used",
        ),
        data_table.column_with_class(
          t(config, i18n_text.State),
          fn(token: ApiToken) { token_state_badge(config, token) },
          "token-col-state",
          "token-cell-state",
        ),
        data_table.column_with_class(
          t(config, i18n_text.Actions),
          fn(token: ApiToken) { view_token_actions(config, token) },
          "token-col-actions col-actions",
          "token-cell-actions cell-actions",
        ),
      ])
      |> data_table.with_class("api-token-table")
      |> data_table.with_key(fn(token: ApiToken) { int.to_string(token.id) }),
  )
}

fn view_token_actions(config: Config(msg), token: ApiToken) -> Element(msg) {
  let rename =
    action_buttons.edit_button(
      t(config, i18n_text.RenameApiToken),
      config.on_token_rename_clicked(token.id, token.name),
    )

  let actions = case token.revoked_at {
    opt.None -> [
      rename,
      action_buttons.delete_button(
        t(config, i18n_text.RevokeApiToken),
        config.on_token_revoke_clicked(token.id),
      ),
    ]
    opt.Some(_) -> [rename]
  }

  div([attribute.class("action-buttons")], actions)
}

fn view_integrations(config: Config(msg)) -> Element(msg) {
  data_table.view_remote(
    config.model.integration_users,
    loading_msg: t(config, i18n_text.LoadingEllipsis),
    empty_msg: t(config, i18n_text.NoIntegrationUsersYet),
    config: data_table.new()
      |> data_table.with_error_prefix(t(config, i18n_text.FailedToLoadPrefix))
      |> data_table.with_columns([
        data_table.column(
          t(config, i18n_text.IntegrationIdentity),
          fn(user: IntegrationUser) { text(user.email) },
        ),
        data_table.column(
          t(config, i18n_text.CreatedAt),
          fn(user: IntegrationUser) {
            text(format_date.date_only(user.created_at))
          },
        ),
        data_table.column(
          t(config, i18n_text.ActiveTokenCount),
          fn(user: IntegrationUser) {
            text(int.to_string(user.active_token_count))
          },
        ),
        data_table.column_with_class(
          t(config, i18n_text.Actions),
          fn(user: IntegrationUser) { view_integration_actions(config, user) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(user: IntegrationUser) {
        int.to_string(user.id)
      }),
  )
}

fn view_integration_actions(
  config: Config(msg),
  user: IntegrationUser,
) -> Element(msg) {
  case user.active_token_count {
    0 ->
      action_buttons.delete_button(
        t(config, i18n_text.DeactivateIntegration),
        config.on_integration_deactivate_clicked(user.id),
      )
    _ -> element.none()
  }
}

fn view_token_dialog(config: Config(msg)) -> Element(msg) {
  let #(open, token_form, error, in_flight) = token_dialog_info(config.model)
  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.CreateApiToken),
      icon: opt.None,
      size: dialog.DialogLg,
      on_close: config.on_token_create_closed,
    ),
    open,
    error,
    [
      form([event.on_submit(fn(_) { config.on_token_create_submitted })], [
        form_field.view_required(
          t(config, i18n_text.Name),
          input([
            attribute.type_("text"),
            attribute.value(token_form.name),
            attribute.required(True),
            event.on_input(config.on_token_name_changed),
          ]),
        ),
        form_field.view_required(
          t(config, i18n_text.IntegrationIdentity),
          input([
            attribute.type_("text"),
            attribute.value(token_form.integration),
            attribute.required(True),
            event.on_input(config.on_token_integration_changed),
          ]),
        ),
        form_field.hint(t(config, i18n_text.IntegrationIdentityHint)),
        form_field.view(
          t(config, i18n_text.Project),
          select(
            [event.on_input(config.on_token_project_changed)],
            project_options(config, config.projects, token_form.project_id),
          ),
        ),
        form_field.view(
          t(config, i18n_text.ExpiresAtOptional),
          input([
            attribute.type_("datetime-local"),
            attribute.value(token_form.expires_at),
            event.on_input(config.on_token_expires_at_changed),
          ]),
        ),
        view_scope_checkboxes(config, token_form),
      ]),
    ],
    [
      dialog.cancel_button_with_locale(
        config.locale,
        config.on_token_create_closed,
      ),
      dialog.submit_button_with_locale_click(
        config.locale,
        config.on_token_create_submitted,
        in_flight,
        False,
        i18n_text.Create,
        i18n_text.Creating,
      ),
    ],
  )
}

fn view_rename_dialog(config: Config(msg)) -> Element(msg) {
  let #(open, name, error, in_flight) = rename_dialog_info(config.model)
  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.RenameApiToken),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_token_rename_cancelled,
    ),
    open,
    error,
    [
      form([event.on_submit(fn(_) { config.on_token_rename_submitted })], [
        form_field.view_required(
          t(config, i18n_text.Name),
          input([
            attribute.type_("text"),
            attribute.value(name),
            attribute.required(True),
            event.on_input(config.on_token_rename_name_changed),
          ]),
        ),
      ]),
    ],
    [
      dialog.cancel_button_with_locale(
        config.locale,
        config.on_token_rename_cancelled,
      ),
      ui_button.text(
        t(config, i18n_text.Save),
        config.on_token_rename_submitted,
        ui_button.Primary,
        ui_button.EntityAction,
      )
        |> ui_button.with_disabled(in_flight)
        |> ui_button.view,
    ],
  )
}

fn view_revoke_dialog(config: Config(msg)) -> Element(msg) {
  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.RevokeApiToken),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_token_revoke_cancelled,
    ),
    config.model.revoke_confirm != opt.None,
    opt.None,
    [
      p([], [
        text(t(config, i18n_text.RevokeApiTokenConfirm)),
        text(" "),
        text(revoke_token_name(config)),
      ]),
    ],
    [
      dialog.cancel_button_with_locale(
        config.locale,
        config.on_token_revoke_cancelled,
      ),
      ui_button.text(
        t(config, i18n_text.Revoke),
        config.on_token_revoke_confirmed,
        ui_button.Danger,
        ui_button.EntityAction,
      )
        |> ui_button.view,
    ],
  )
}

fn view_deactivate_integration_dialog(config: Config(msg)) -> Element(msg) {
  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.DeactivateIntegration),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_integration_deactivate_cancelled,
    ),
    config.model.integration_deactivate_confirm != opt.None,
    opt.None,
    [
      p([], [
        text(t(config, i18n_text.DeactivateIntegrationConfirm)),
        text(" "),
        text(deactivate_integration_name(config)),
      ]),
    ],
    [
      dialog.cancel_button_with_locale(
        config.locale,
        config.on_integration_deactivate_cancelled,
      ),
      ui_button.text(
        t(config, i18n_text.DeactivateIntegration),
        config.on_integration_deactivate_confirmed,
        ui_button.Danger,
        ui_button.EntityAction,
      )
        |> ui_button.view,
    ],
  )
}

fn view_scope_checkboxes(
  config: Config(msg),
  form: api_tokens_state.Form,
) -> Element(msg) {
  div([attribute.class("scope-matrix")], [
    label([], [text(t(config, i18n_text.Scopes))]),
    div([attribute.class("scope-matrix-table")], [
      div([attribute.class("scope-matrix-head")], [
        div([], [text("")]),
        div([], [text(t(config, i18n_text.PermissionRead))]),
        div([], [text(t(config, i18n_text.PermissionWrite))]),
      ]),
      ..list.map(scope_rows(config), fn(row) { scope_row(config, form, row) })
    ]),
  ])
}

type ScopeRow {
  ScopeRow(
    label: String,
    read: opt.Option(api_token_scope.Scope),
    write: opt.Option(api_token_scope.Scope),
  )
}

fn scope_row(
  config: Config(msg),
  form: api_tokens_state.Form,
  row: ScopeRow,
) -> Element(msg) {
  let ScopeRow(label: row_label, read: read_scope, write: write_scope) = row
  div([attribute.class("scope-matrix-row")], [
    div([attribute.class("scope-matrix-resource")], [text(row_label)]),
    scope_cell(config, form, read_scope),
    scope_cell(config, form, write_scope),
  ])
}

fn scope_cell(
  config: Config(msg),
  form: api_tokens_state.Form,
  scope: opt.Option(api_token_scope.Scope),
) -> Element(msg) {
  case scope {
    opt.None -> div([attribute.class("scope-matrix-empty")], [text("-")])
    opt.Some(scope) -> scope_checkbox(config, form, scope)
  }
}

fn scope_checkbox(
  config: Config(msg),
  form: api_tokens_state.Form,
  scope: api_token_scope.Scope,
) -> Element(msg) {
  let scope_value = api_token_scope.to_string(scope)
  label([attribute.class("checkbox-label scope-checkbox")], [
    input([
      attribute.type_("checkbox"),
      attribute.value(scope_value),
      attribute.checked(list.contains(form.scopes, scope)),
      event.on_check(fn(_) { config.on_token_scope_toggled(scope) }),
    ]),
    text(access_label(config, scope)),
  ])
}

fn project_options(
  config: Config(msg),
  projects: List(Project),
  selected: opt.Option(Int),
) -> List(Element(msg)) {
  [
    option(
      [attribute.value(""), attribute.selected(selected == opt.None)],
      t(config, i18n_text.AllProjects),
    ),
    ..list.map(projects, fn(project) {
      option(
        [
          attribute.value(int.to_string(project.id)),
          attribute.selected(selected == opt.Some(project.id)),
        ],
        project.name,
      )
    })
  ]
}

fn token_dialog_info(
  model: api_tokens_state.Model,
) -> #(Bool, api_tokens_state.Form, opt.Option(String), Bool) {
  case model.token_dialog {
    DialogOpen(form: form, operation: operation) -> #(
      True,
      form,
      operation_error(operation),
      operation == InFlight,
    )
    DialogClosed(operation: operation) -> #(
      False,
      api_tokens_state.default_token_form(),
      operation_error(operation),
      False,
    )
  }
}

fn rename_dialog_info(
  model: api_tokens_state.Model,
) -> #(Bool, String, opt.Option(String), Bool) {
  case model.token_rename_dialog {
    DialogOpen(form: form, operation: operation) -> {
      let #(_, name) = form
      #(True, name, operation_error(operation), operation == InFlight)
    }
    DialogClosed(operation: operation) -> #(
      False,
      "",
      operation_error(operation),
      False,
    )
  }
}

fn operation_error(operation) -> opt.Option(String) {
  case operation {
    OperationError(message) -> opt.Some(message)
    _ -> opt.None
  }
}

fn project_name(
  config: Config(msg),
  projects: List(Project),
  id: opt.Option(Int),
) -> String {
  case id {
    opt.None -> t(config, i18n_text.AllProjects)
    opt.Some(project_id) ->
      case list.find(projects, fn(project) { project.id == project_id }) {
        Ok(project) -> project.name
        Error(_) -> "#" <> int.to_string(project_id)
      }
  }
}

fn optional_date(value: opt.Option(String)) -> String {
  case value {
    opt.Some(date) -> format_date.date_only(date)
    opt.None -> "-"
  }
}

fn token_state(config: Config(msg), token: ApiToken) -> String {
  case token.revoked_at, token.expired {
    opt.Some(_), _ -> t(config, i18n_text.Revoked)
    _, True -> t(config, i18n_text.Expired)
    opt.None, False -> t(config, i18n_text.Active)
  }
}

fn token_state_badge(config: Config(msg), token: ApiToken) -> Element(msg) {
  let variant = case token.revoked_at, token.expired {
    opt.Some(_), _ -> badge.Danger
    _, True -> badge.Warning
    opt.None, False -> badge.Success
  }

  badge.new_unchecked(token_state(config, token), variant)
  |> badge.view_with_class("api-token-state-badge")
}

fn view_scope_summary(
  config: Config(msg),
  scopes: List(api_token_scope.Scope),
) -> Element(msg) {
  div(
    [attribute.class("api-token-scope-badges")],
    scopes
      |> list.map(fn(scope) {
        badge.new_unchecked(scope_label(config, scope), badge.Neutral)
        |> badge.view_with_class("api-token-scope-badge")
      }),
  )
}

fn scope_rows(config: Config(msg)) -> List(ScopeRow) {
  [
    ScopeRow(
      label: t(config, i18n_text.ResourceProjects),
      read: opt.Some(api_token_scope.ProjectsRead),
      write: opt.None,
    ),
    ScopeRow(
      label: t(config, i18n_text.ResourceTasks),
      read: opt.Some(api_token_scope.TasksRead),
      write: opt.Some(api_token_scope.TasksWrite),
    ),
    ScopeRow(
      label: t(config, i18n_text.ResourceCards),
      read: opt.Some(api_token_scope.CardsRead),
      write: opt.Some(api_token_scope.CardsWrite),
    ),
    ScopeRow(
      label: t(config, i18n_text.ResourceNotes),
      read: opt.Some(api_token_scope.NotesRead),
      write: opt.Some(api_token_scope.NotesWrite),
    ),
  ]
}

fn access_label(config: Config(msg), scope: api_token_scope.Scope) -> String {
  case api_token_scope.access(scope) {
    api_token_scope.Read -> t(config, i18n_text.PermissionRead)
    api_token_scope.Write -> t(config, i18n_text.PermissionWrite)
  }
}

fn scope_label(config: Config(msg), scope: api_token_scope.Scope) -> String {
  resource_label(config, api_token_scope.resource(scope))
  <> " / "
  <> access_text(config, api_token_scope.access(scope))
}

fn resource_label(
  config: Config(msg),
  resource: api_token_scope.Resource,
) -> String {
  case resource {
    api_token_scope.Projects -> t(config, i18n_text.ResourceProjects)
    api_token_scope.Tasks -> t(config, i18n_text.ResourceTasks)
    api_token_scope.Cards -> t(config, i18n_text.ResourceCards)
    api_token_scope.Notes -> t(config, i18n_text.ResourceNotes)
  }
}

fn access_text(config: Config(msg), access: api_token_scope.Access) -> String {
  case access {
    api_token_scope.Read -> t(config, i18n_text.PermissionRead)
    api_token_scope.Write -> t(config, i18n_text.PermissionWrite)
  }
}

fn revoke_token_name(config: Config(msg)) -> String {
  case config.model.revoke_confirm, config.model.tokens {
    opt.Some(id), remote.Loaded(tokens) ->
      case list.find(tokens, fn(token) { token.id == id }) {
        Ok(token) -> token.name
        Error(_) -> ""
      }
    _, _ -> ""
  }
}

fn deactivate_integration_name(config: Config(msg)) -> String {
  case
    config.model.integration_deactivate_confirm,
    config.model.integration_users
  {
    opt.Some(id), remote.Loaded(users) ->
      case list.find(users, fn(user) { user.id == id }) {
        Ok(user) -> user.email
        Error(_) -> ""
      }
    _, _ -> ""
  }
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}
