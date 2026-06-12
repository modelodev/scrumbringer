//// API token admin view.

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, input, label, option, p, select, text,
}
import lustre/event

import domain/project.{type Project}
import domain/remote
import scrumbringer_client/client_state/admin/api_tokens as api_tokens_state
import scrumbringer_client/client_state/types.{
  type ApiToken, type ApiTokenForm, type ApiTokensModel, DialogClosed,
  DialogOpen, Error as OperationError, InFlight,
}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/admin_surface
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/copyable_input
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/utils/format_date

pub type Config(msg) {
  Config(
    locale: Locale,
    model: ApiTokensModel,
    projects: List(Project),
    on_token_create_opened: msg,
    on_token_create_closed: msg,
    on_token_name_changed: fn(String) -> msg,
    on_token_integration_changed: fn(String) -> msg,
    on_token_project_changed: fn(String) -> msg,
    on_token_scope_toggled: fn(String) -> msg,
    on_token_expires_at_changed: fn(String) -> msg,
    on_token_create_submitted: msg,
    on_token_secret_dismissed: msg,
    on_token_secret_copy_clicked: fn(String) -> msg,
    on_token_revoke_clicked: fn(Int) -> msg,
    on_token_revoke_cancelled: msg,
    on_token_revoke_confirmed: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  admin_surface.view(
    section_header.view_with_action(
      icons.Cog,
      t(config, i18n_text.AdminApiTokens),
      button(
        [
          attribute.class("btn btn-primary"),
          event.on_click(config.on_token_create_opened),
        ],
        [
          icons.nav_icon(icons.Plus, icons.Small),
          text(t(config, i18n_text.CreateApiToken)),
        ],
      ),
    ),
    div([], [
      view_created_secret(config),
      div([attribute.class("api-token-list-card")], [view_tokens(config)]),
    ]),
    [
      view_token_dialog(config),
      view_revoke_dialog(config),
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
        button(
          [
            attribute.class("btn-secondary"),
            event.on_click(config.on_token_secret_dismissed),
          ],
          [text(t(config, i18n_text.Dismiss))],
        ),
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
        data_table.column(t(config, i18n_text.Name), fn(token: ApiToken) {
          text(token.name)
        }),
        data_table.column(t(config, i18n_text.Integration), fn(token: ApiToken) {
          text(integration_user_email(config.model, token.integration_user_id))
        }),
        data_table.column(t(config, i18n_text.Project), fn(token: ApiToken) {
          badge.new_unchecked(
            project_name(config, config.projects, token.project_id),
            badge.Neutral,
          )
          |> badge.view_with_class("api-token-project-badge")
        }),
        data_table.column(t(config, i18n_text.Scopes), fn(token: ApiToken) {
          view_scope_summary(config, token.scopes)
        }),
        data_table.column(t(config, i18n_text.LastUsed), fn(token: ApiToken) {
          text(optional_date(token.last_used_at))
        }),
        data_table.column(t(config, i18n_text.State), fn(token: ApiToken) {
          token_state_badge(config, token)
        }),
        data_table.column_with_class(
          t(config, i18n_text.Actions),
          fn(token: ApiToken) {
            action_buttons.delete_button(
              t(config, i18n_text.RevokeApiToken),
              config.on_token_revoke_clicked(token.id),
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(token: ApiToken) { int.to_string(token.id) }),
  )
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
          t(config, i18n_text.Integration),
          input([
            attribute.type_("text"),
            attribute.value(token_form.integration),
            attribute.required(True),
            event.on_input(config.on_token_integration_changed),
          ]),
        ),
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
      submit_button(config, in_flight, config.on_token_create_submitted),
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
      button(
        [
          attribute.class("btn-danger"),
          event.on_click(config.on_token_revoke_confirmed),
        ],
        [text(t(config, i18n_text.Revoke))],
      ),
    ],
  )
}

fn view_scope_checkboxes(
  config: Config(msg),
  form: ApiTokenForm,
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
  ScopeRow(label: String, read: opt.Option(String), write: opt.Option(String))
}

fn scope_row(
  config: Config(msg),
  form: ApiTokenForm,
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
  form: ApiTokenForm,
  scope: opt.Option(String),
) -> Element(msg) {
  case scope {
    opt.None -> div([attribute.class("scope-matrix-empty")], [text("-")])
    opt.Some(scope) -> scope_checkbox(config, form, scope)
  }
}

fn scope_checkbox(
  config: Config(msg),
  form: ApiTokenForm,
  scope: String,
) -> Element(msg) {
  label([attribute.class("checkbox-label scope-checkbox")], [
    input([
      attribute.type_("checkbox"),
      attribute.value(scope),
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
  model: ApiTokensModel,
) -> #(Bool, ApiTokenForm, opt.Option(String), Bool) {
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

fn operation_error(operation) -> opt.Option(String) {
  case operation {
    OperationError(message) -> opt.Some(message)
    _ -> opt.None
  }
}

fn integration_user_email(model: ApiTokensModel, id: Int) -> String {
  case model.integration_users {
    remote.Loaded(users) ->
      case list.find(users, fn(user) { user.id == id }) {
        Ok(user) -> user.email
        Error(_) -> "#" <> int.to_string(id)
      }
    _ -> "#" <> int.to_string(id)
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

fn view_scope_summary(config: Config(msg), scopes: List(String)) -> Element(msg) {
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
      read: opt.Some("projects:read"),
      write: opt.None,
    ),
    ScopeRow(
      label: t(config, i18n_text.ResourceTasks),
      read: opt.Some("tasks:read"),
      write: opt.Some("tasks:write"),
    ),
    ScopeRow(
      label: t(config, i18n_text.ResourceCards),
      read: opt.Some("cards:read"),
      write: opt.Some("cards:write"),
    ),
    ScopeRow(
      label: t(config, i18n_text.ResourceNotes),
      read: opt.Some("notes:read"),
      write: opt.Some("notes:write"),
    ),
    ScopeRow(
      label: t(config, i18n_text.ResourceMilestones),
      read: opt.Some("milestones:read"),
      write: opt.Some("milestones:write"),
    ),
  ]
}

fn access_label(config: Config(msg), scope: String) -> String {
  case string.ends_with(scope, ":write") {
    True -> t(config, i18n_text.PermissionWrite)
    False -> t(config, i18n_text.PermissionRead)
  }
}

fn scope_label(config: Config(msg), scope: String) -> String {
  case string.split(scope, ":") {
    [resource, access] ->
      resource_label(config, resource) <> " / " <> access_text(config, access)
    _ -> scope
  }
}

fn resource_label(config: Config(msg), resource: String) -> String {
  case resource {
    "projects" -> t(config, i18n_text.ResourceProjects)
    "tasks" -> t(config, i18n_text.ResourceTasks)
    "cards" -> t(config, i18n_text.ResourceCards)
    "notes" -> t(config, i18n_text.ResourceNotes)
    "milestones" -> t(config, i18n_text.ResourceMilestones)
    _ -> resource
  }
}

fn access_text(config: Config(msg), access: String) -> String {
  case access {
    "read" -> t(config, i18n_text.PermissionRead)
    "write" -> t(config, i18n_text.PermissionWrite)
    _ -> access
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

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

fn submit_button(
  config: Config(msg),
  in_flight: Bool,
  on_click: msg,
) -> Element(msg) {
  button(
    [
      attribute.type_("button"),
      attribute.disabled(in_flight),
      attribute.class(case in_flight {
        True -> "btn-loading"
        False -> ""
      }),
      event.on_click(on_click),
    ],
    [
      text(case in_flight {
        True -> t(config, i18n_text.Creating)
        False -> t(config, i18n_text.Create)
      }),
    ],
  )
}
