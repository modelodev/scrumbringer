\restrict dbmate

-- Dumped from database version 17.9 (Debian 17.9-0+deb13u1)
-- Dumped by pg_dump version 17.9 (Debian 17.9-0+deb13u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: check_capability_project(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_capability_project() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM capabilities
    WHERE id = NEW.capability_id AND project_id = NEW.project_id
  ) THEN
    RAISE EXCEPTION 'Capability % does not belong to project %', NEW.capability_id, NEW.project_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_api_token_org_scope(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_api_token_org_scope() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.project_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.projects
    WHERE id = NEW.project_id
      AND org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'api token project % does not belong to org %',
      NEW.project_id, NEW.org_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = NEW.integration_user_id
      AND org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'api token integration user % does not belong to org %',
      NEW.integration_user_id, NEW.org_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = NEW.created_by
      AND org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'api token creator % does not belong to org %',
      NEW.created_by, NEW.org_id
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: enforce_audit_event_org_project(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_audit_event_org_project() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.task_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.tasks task
    JOIN public.projects project ON project.id = task.project_id
    WHERE task.id = NEW.task_id
      AND task.project_id = NEW.project_id
      AND project.org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'audit task target does not match event org/project'
      USING ERRCODE = '23503';
  END IF;

  IF NEW.card_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.cards card
    JOIN public.projects project ON project.id = card.project_id
    WHERE card.id = NEW.card_id
      AND card.project_id = NEW.project_id
      AND project.org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'audit card target does not match event org/project'
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: enforce_card_child_kind_invariant(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_card_child_kind_invariant() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_TABLE_NAME = 'cards' THEN
    IF NEW.parent_card_id IS NOT NULL THEN
      IF EXISTS (
        SELECT 1
        FROM public.tasks
        WHERE card_id = NEW.parent_card_id
      ) THEN
        RAISE EXCEPTION 'parent card % already contains tasks', NEW.parent_card_id
          USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'tasks' THEN
    IF NEW.card_id IS NOT NULL THEN
      IF EXISTS (
        SELECT 1
        FROM public.cards
        WHERE parent_card_id = NEW.card_id
      ) THEN
        RAISE EXCEPTION 'card % already contains child cards', NEW.card_id
          USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: prevent_card_cycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_card_cycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.parent_card_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.parent_card_id = NEW.id THEN
    RAISE EXCEPTION 'card % cannot be parent of itself', NEW.id
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    WITH RECURSIVE descendants(id) AS (
      SELECT id
      FROM public.cards
      WHERE parent_card_id = NEW.id
      UNION ALL
      SELECT child.id
      FROM public.cards child
      JOIN descendants d ON child.parent_card_id = d.id
    )
    SELECT 1
    FROM descendants
    WHERE id = NEW.parent_card_id
  ) THEN
    RAISE EXCEPTION 'card % cannot be moved below its descendant %',
      NEW.id, NEW.parent_card_id
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: prevent_task_dependency_cycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_task_dependency_cycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  source_project_id BIGINT;
  dependency_project_id BIGINT;
BEGIN
  SELECT project_id
  INTO source_project_id
  FROM public.tasks
  WHERE id = NEW.task_id;

  SELECT project_id
  INTO dependency_project_id
  FROM public.tasks
  WHERE id = NEW.depends_on_task_id;

  IF source_project_id IS NULL OR dependency_project_id IS NULL THEN
    RAISE EXCEPTION 'dependency task does not exist'
      USING ERRCODE = '23503';
  END IF;

  IF source_project_id <> dependency_project_id THEN
    RAISE EXCEPTION 'task dependency must stay inside project %',
      source_project_id
      USING ERRCODE = '23503';
  END IF;

  IF EXISTS (
    WITH RECURSIVE dependency_chain(task_id) AS (
      SELECT depends_on_task_id
      FROM public.task_dependencies
      WHERE task_id = NEW.depends_on_task_id
      UNION ALL
      SELECT td.depends_on_task_id
      FROM public.task_dependencies td
      JOIN dependency_chain dc ON td.task_id = dc.task_id
    )
    SELECT 1
    FROM dependency_chain
    WHERE task_id = NEW.task_id
  ) THEN
    RAISE EXCEPTION 'task dependency cycle detected for task %', NEW.task_id
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: project_settings_increment_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.project_settings_increment_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.version = OLD.version + 1;
  RETURN NEW;
END;
$$;


--
-- Name: rules_workflow_task_type_project_fk(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rules_workflow_task_type_project_fk() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  workflow_project_id BIGINT;
BEGIN
  IF NEW.task_type_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT project_id
  INTO workflow_project_id
  FROM public.workflows
  WHERE id = NEW.workflow_id;

  IF workflow_project_id IS NULL THEN
    RAISE EXCEPTION 'workflow % does not exist', NEW.workflow_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.task_types
    WHERE id = NEW.task_type_id
      AND project_id = workflow_project_id
  ) THEN
    RAISE EXCEPTION 'task type % does not belong to workflow project %',
      NEW.task_type_id, workflow_project_id
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: api_token_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_token_audit_log (
    id bigint NOT NULL,
    token_id bigint,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    ip text,
    method text NOT NULL,
    endpoint text NOT NULL,
    status integer NOT NULL
);


--
-- Name: api_token_audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_token_audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_token_audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_token_audit_log_id_seq OWNED BY public.api_token_audit_log.id;


--
-- Name: api_token_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_token_scopes (
    token_id bigint NOT NULL,
    scope text NOT NULL,
    CONSTRAINT api_token_scopes_scope_check CHECK ((scope = ANY (ARRAY['projects:read'::text, 'tasks:read'::text, 'tasks:write'::text, 'cards:read'::text, 'cards:write'::text, 'notes:read'::text, 'notes:write'::text])))
);


--
-- Name: api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_tokens (
    id bigint NOT NULL,
    org_id bigint NOT NULL,
    integration_user_id bigint NOT NULL,
    project_id bigint,
    created_by bigint NOT NULL,
    name text NOT NULL,
    public_id text NOT NULL,
    token_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone,
    expires_at timestamp with time zone,
    revoked_at timestamp with time zone,
    CONSTRAINT api_tokens_name_check CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


--
-- Name: api_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_tokens_id_seq OWNED BY public.api_tokens.id;


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id bigint NOT NULL,
    org_id bigint NOT NULL,
    project_id bigint NOT NULL,
    task_id bigint,
    actor_user_id bigint NOT NULL,
    event_type text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    card_id bigint,
    payload_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT audit_events_event_type_check CHECK ((event_type = ANY (ARRAY['task_created'::text, 'task_claimed'::text, 'task_released'::text, 'task_closed'::text, 'card_activated'::text, 'card_closed'::text, 'card_moved'::text, 'task_dependency_added'::text, 'task_dependency_removed'::text]))),
    CONSTRAINT audit_events_target_check CHECK ((((event_type = ANY (ARRAY['task_created'::text, 'task_claimed'::text, 'task_released'::text, 'task_closed'::text, 'task_dependency_added'::text, 'task_dependency_removed'::text])) AND (task_id IS NOT NULL) AND (card_id IS NULL)) OR ((event_type = ANY (ARRAY['card_activated'::text, 'card_closed'::text, 'card_moved'::text])) AND (card_id IS NOT NULL) AND (task_id IS NULL))))
);


--
-- Name: audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_events_id_seq OWNED BY public.audit_events.id;


--
-- Name: capabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capabilities (
    id bigint NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    project_id bigint NOT NULL
);


--
-- Name: capabilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.capabilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: capabilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.capabilities_id_seq OWNED BY public.capabilities.id;


--
-- Name: card_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.card_notes (
    id bigint NOT NULL,
    card_id bigint NOT NULL,
    user_id bigint NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: card_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.card_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.card_notes_id_seq OWNED BY public.card_notes.id;


--
-- Name: cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cards (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    title text NOT NULL,
    description text,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    color text,
    parent_card_id bigint,
    execution_state text DEFAULT 'draft'::text NOT NULL,
    activated_at timestamp with time zone,
    activated_by bigint,
    activation_source text,
    activation_source_card_id bigint,
    closed_at timestamp with time zone,
    closed_by bigint,
    closed_by_kind text,
    closed_reason text,
    due_date date,
    CONSTRAINT cards_activation_source_check CHECK (((activation_source IS NULL) OR (activation_source = ANY (ARRAY['direct_activation'::text, 'activated_by_ancestor'::text])))),
    CONSTRAINT cards_closed_by_kind_check CHECK (((closed_by_kind IS NULL) OR (closed_by_kind = ANY (ARRAY['user'::text, 'system'::text])))),
    CONSTRAINT cards_closed_reason_check CHECK (((closed_reason IS NULL) OR (closed_reason = ANY (ARRAY['rollup'::text, 'manually_closed'::text])))),
    CONSTRAINT cards_color_check CHECK (((color IS NULL) OR (color = ANY (ARRAY['gray'::text, 'red'::text, 'orange'::text, 'yellow'::text, 'green'::text, 'blue'::text, 'purple'::text, 'pink'::text])))),
    CONSTRAINT cards_execution_state_check CHECK ((execution_state = ANY (ARRAY['draft'::text, 'active'::text, 'closed'::text])))
);


--
-- Name: cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cards_id_seq OWNED BY public.cards.id;


--
-- Name: org_invite_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_invite_links (
    token text NOT NULL,
    org_id bigint NOT NULL,
    email text NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    used_at timestamp with time zone,
    used_by bigint,
    invalidated_at timestamp with time zone
);


--
-- Name: org_invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_invites (
    code text NOT NULL,
    org_id bigint NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    used_at timestamp with time zone,
    used_by bigint
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id bigint NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_id_seq OWNED BY public.organizations.id;


--
-- Name: password_resets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_resets (
    token text NOT NULL,
    email text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    used_at timestamp with time zone,
    invalidated_at timestamp with time zone
);


--
-- Name: project_card_depth_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_card_depth_names (
    project_id bigint NOT NULL,
    depth integer NOT NULL,
    singular_name text NOT NULL,
    plural_name text NOT NULL,
    CONSTRAINT project_card_depth_names_depth_check CHECK ((depth > 0))
);


--
-- Name: project_member_capabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_member_capabilities (
    project_id bigint NOT NULL,
    user_id bigint NOT NULL,
    capability_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: project_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_members (
    project_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role text DEFAULT 'member'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT project_members_role_check CHECK ((role = ANY (ARRAY['manager'::text, 'member'::text])))
);


--
-- Name: project_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_settings (
    project_id bigint NOT NULL,
    healthy_pool_limit integer DEFAULT 20 NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT project_settings_healthy_pool_limit_check CHECK ((healthy_pool_limit > 0))
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    name text NOT NULL,
    org_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: rule_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule_executions (
    id bigint NOT NULL,
    rule_id bigint NOT NULL,
    outcome text NOT NULL,
    suppression_reason text,
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    task_id bigint,
    card_id bigint,
    CONSTRAINT rule_executions_outcome_check CHECK ((outcome = ANY (ARRAY['applied'::text, 'suppressed'::text]))),
    CONSTRAINT rule_executions_target_check CHECK ((((task_id IS NOT NULL) AND (card_id IS NULL)) OR ((task_id IS NULL) AND (card_id IS NOT NULL))))
);


--
-- Name: rule_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rule_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rule_executions_id_seq OWNED BY public.rule_executions.id;


--
-- Name: rule_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule_templates (
    rule_id bigint NOT NULL,
    template_id bigint NOT NULL,
    execution_order integer DEFAULT 0 NOT NULL
);


--
-- Name: rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rules (
    id bigint NOT NULL,
    workflow_id bigint NOT NULL,
    name text NOT NULL,
    goal text,
    resource_type text NOT NULL,
    task_type_id bigint,
    to_state text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rules_resource_type_check CHECK ((resource_type = ANY (ARRAY['task'::text, 'card'::text])))
);


--
-- Name: rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rules_id_seq OWNED BY public.rules.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: task_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_dependencies (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    depends_on_task_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT task_dependencies_check CHECK ((task_id <> depends_on_task_id))
);


--
-- Name: task_dependencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_dependencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_dependencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_dependencies_id_seq OWNED BY public.task_dependencies.id;


--
-- Name: task_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_notes (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    user_id bigint NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: task_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_notes_id_seq OWNED BY public.task_notes.id;


--
-- Name: task_positions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_positions (
    task_id bigint NOT NULL,
    user_id bigint NOT NULL,
    x integer DEFAULT 0 NOT NULL,
    y integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: task_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_templates (
    id bigint NOT NULL,
    org_id bigint NOT NULL,
    project_id bigint NOT NULL,
    name text NOT NULL,
    description text,
    type_id bigint NOT NULL,
    priority integer DEFAULT 3 NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT task_templates_priority_check CHECK (((priority >= 1) AND (priority <= 5)))
);


--
-- Name: task_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_templates_id_seq OWNED BY public.task_templates.id;


--
-- Name: task_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_types (
    id bigint NOT NULL,
    name text NOT NULL,
    icon text NOT NULL,
    capability_id bigint,
    project_id bigint NOT NULL,
    CONSTRAINT task_types_icon_non_empty CHECK ((TRIM(BOTH FROM icon) <> ''::text))
);


--
-- Name: task_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_types_id_seq OWNED BY public.task_types.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id bigint NOT NULL,
    title text NOT NULL,
    description text,
    priority integer DEFAULT 3 NOT NULL,
    type_id bigint NOT NULL,
    project_id bigint NOT NULL,
    created_by bigint NOT NULL,
    claimed_by bigint,
    claimed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    card_id bigint,
    pool_lifetime_s bigint DEFAULT 0 NOT NULL,
    last_entered_pool_at timestamp with time zone,
    created_from_rule_id bigint,
    execution_state text NOT NULL,
    claimed_mode text,
    closed_at timestamp with time zone,
    closed_by bigint,
    closed_reason text,
    due_date date,
    capability_id bigint,
    CONSTRAINT tasks_claimed_mode_check CHECK (((claimed_mode IS NULL) OR (claimed_mode = ANY (ARRAY['taken'::text, 'ongoing'::text])))),
    CONSTRAINT tasks_closed_reason_check CHECK (((closed_reason IS NULL) OR (closed_reason = ANY (ARRAY['done'::text, 'manually_closed'::text, 'closed_by_ancestor'::text])))),
    CONSTRAINT tasks_execution_state_check CHECK ((execution_state = ANY (ARRAY['available'::text, 'claimed'::text, 'closed'::text]))),
    CONSTRAINT tasks_pool_lifetime_non_negative CHECK ((pool_lifetime_s >= 0)),
    CONSTRAINT tasks_priority_check CHECK (((priority >= 1) AND (priority <= 5))),
    CONSTRAINT tasks_title_max_56 CHECK ((char_length(title) <= 56))
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: user_card_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_card_views (
    user_id bigint NOT NULL,
    card_id bigint NOT NULL,
    last_viewed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_task_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_task_views (
    user_id bigint NOT NULL,
    task_id bigint NOT NULL,
    last_viewed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_task_work_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_task_work_session (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    task_id bigint NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    last_heartbeat_at timestamp with time zone DEFAULT now() NOT NULL,
    ended_at timestamp with time zone,
    ended_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_task_work_session_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_task_work_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_task_work_session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_task_work_session_id_seq OWNED BY public.user_task_work_session.id;


--
-- Name: user_task_work_total; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_task_work_total (
    user_id bigint NOT NULL,
    task_id bigint NOT NULL,
    accumulated_s integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_task_work_total_accumulated_s_check CHECK ((accumulated_s >= 0))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email text NOT NULL,
    password_hash text,
    org_id bigint NOT NULL,
    org_role text DEFAULT 'member'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    first_login_at timestamp with time zone,
    deleted_at timestamp with time zone,
    user_kind text DEFAULT 'human'::text NOT NULL,
    CONSTRAINT users_org_role_check CHECK ((org_role = ANY (ARRAY['member'::text, 'admin'::text]))),
    CONSTRAINT users_password_for_humans_check CHECK ((((user_kind = 'human'::text) AND (password_hash IS NOT NULL)) OR ((user_kind = 'integration'::text) AND (password_hash IS NULL)))),
    CONSTRAINT users_user_kind_check CHECK ((user_kind = ANY (ARRAY['human'::text, 'integration'::text])))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: workflows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflows (
    id bigint NOT NULL,
    org_id bigint NOT NULL,
    project_id bigint NOT NULL,
    name text NOT NULL,
    description text,
    active boolean DEFAULT false NOT NULL,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: workflows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.workflows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workflows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.workflows_id_seq OWNED BY public.workflows.id;


--
-- Name: api_token_audit_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_token_audit_log ALTER COLUMN id SET DEFAULT nextval('public.api_token_audit_log_id_seq'::regclass);


--
-- Name: api_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens ALTER COLUMN id SET DEFAULT nextval('public.api_tokens_id_seq'::regclass);


--
-- Name: audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events ALTER COLUMN id SET DEFAULT nextval('public.audit_events_id_seq'::regclass);


--
-- Name: capabilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capabilities ALTER COLUMN id SET DEFAULT nextval('public.capabilities_id_seq'::regclass);


--
-- Name: card_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_notes ALTER COLUMN id SET DEFAULT nextval('public.card_notes_id_seq'::regclass);


--
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations ALTER COLUMN id SET DEFAULT nextval('public.organizations_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: rule_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions ALTER COLUMN id SET DEFAULT nextval('public.rule_executions_id_seq'::regclass);


--
-- Name: rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules ALTER COLUMN id SET DEFAULT nextval('public.rules_id_seq'::regclass);


--
-- Name: task_dependencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies ALTER COLUMN id SET DEFAULT nextval('public.task_dependencies_id_seq'::regclass);


--
-- Name: task_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_notes ALTER COLUMN id SET DEFAULT nextval('public.task_notes_id_seq'::regclass);


--
-- Name: task_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_templates ALTER COLUMN id SET DEFAULT nextval('public.task_templates_id_seq'::regclass);


--
-- Name: task_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_types ALTER COLUMN id SET DEFAULT nextval('public.task_types_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: user_task_work_session id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_work_session ALTER COLUMN id SET DEFAULT nextval('public.user_task_work_session_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: workflows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows ALTER COLUMN id SET DEFAULT nextval('public.workflows_id_seq'::regclass);


--
-- Name: api_token_audit_log api_token_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_token_audit_log
    ADD CONSTRAINT api_token_audit_log_pkey PRIMARY KEY (id);


--
-- Name: api_token_scopes api_token_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_token_scopes
    ADD CONSTRAINT api_token_scopes_pkey PRIMARY KEY (token_id, scope);


--
-- Name: api_tokens api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_pkey PRIMARY KEY (id);


--
-- Name: api_tokens api_tokens_public_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_public_id_key UNIQUE (public_id);


--
-- Name: api_tokens api_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: capabilities capabilities_name_project_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capabilities
    ADD CONSTRAINT capabilities_name_project_id_key UNIQUE (name, project_id);


--
-- Name: capabilities capabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capabilities
    ADD CONSTRAINT capabilities_pkey PRIMARY KEY (id);


--
-- Name: capabilities capabilities_project_id_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capabilities
    ADD CONSTRAINT capabilities_project_id_id_unique UNIQUE (project_id, id);


--
-- Name: card_notes card_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_notes
    ADD CONSTRAINT card_notes_pkey PRIMARY KEY (id);


--
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- Name: cards cards_project_id_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_project_id_id_unique UNIQUE (project_id, id);


--
-- Name: org_invite_links org_invite_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_invite_links
    ADD CONSTRAINT org_invite_links_pkey PRIMARY KEY (token);


--
-- Name: org_invites org_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_invites
    ADD CONSTRAINT org_invites_pkey PRIMARY KEY (code);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: password_resets password_resets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_resets
    ADD CONSTRAINT password_resets_pkey PRIMARY KEY (token);


--
-- Name: project_card_depth_names project_card_depth_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_card_depth_names
    ADD CONSTRAINT project_card_depth_names_pkey PRIMARY KEY (project_id, depth);


--
-- Name: project_member_capabilities project_member_capabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_member_capabilities
    ADD CONSTRAINT project_member_capabilities_pkey PRIMARY KEY (project_id, user_id, capability_id);


--
-- Name: project_members project_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_pkey PRIMARY KEY (project_id, user_id);


--
-- Name: project_settings project_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_settings
    ADD CONSTRAINT project_settings_pkey PRIMARY KEY (project_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: rule_executions rule_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT rule_executions_pkey PRIMARY KEY (id);


--
-- Name: rule_templates rule_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_templates
    ADD CONSTRAINT rule_templates_pkey PRIMARY KEY (rule_id, template_id);


--
-- Name: rules rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT rules_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: task_dependencies task_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_pkey PRIMARY KEY (id);


--
-- Name: task_dependencies task_dependencies_task_id_depends_on_task_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_task_id_depends_on_task_id_key UNIQUE (task_id, depends_on_task_id);


--
-- Name: task_notes task_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_notes
    ADD CONSTRAINT task_notes_pkey PRIMARY KEY (id);


--
-- Name: task_positions task_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_positions
    ADD CONSTRAINT task_positions_pkey PRIMARY KEY (task_id, user_id);


--
-- Name: task_templates task_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_templates
    ADD CONSTRAINT task_templates_pkey PRIMARY KEY (id);


--
-- Name: task_types task_types_name_project_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT task_types_name_project_id_key UNIQUE (name, project_id);


--
-- Name: task_types task_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT task_types_pkey PRIMARY KEY (id);


--
-- Name: task_types task_types_project_id_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT task_types_project_id_id_unique UNIQUE (project_id, id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_project_id_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_id_id_unique UNIQUE (project_id, id);


--
-- Name: user_card_views user_card_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_card_views
    ADD CONSTRAINT user_card_views_pkey PRIMARY KEY (user_id, card_id);


--
-- Name: user_task_views user_task_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_views
    ADD CONSTRAINT user_task_views_pkey PRIMARY KEY (user_id, task_id);


--
-- Name: user_task_work_session user_task_work_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_work_session
    ADD CONSTRAINT user_task_work_session_pkey PRIMARY KEY (id);


--
-- Name: user_task_work_total user_task_work_total_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_work_total
    ADD CONSTRAINT user_task_work_total_pkey PRIMARY KEY (user_id, task_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: workflows workflows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_pkey PRIMARY KEY (id);


--
-- Name: workflows workflows_project_id_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_project_id_id_unique UNIQUE (project_id, id);


--
-- Name: workflows workflows_project_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_project_id_name_key UNIQUE (project_id, name);


--
-- Name: idx_audit_events_actor_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_events_actor_created_at ON public.audit_events USING btree (actor_user_id, created_at);


--
-- Name: idx_audit_events_card_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_events_card_created_at ON public.audit_events USING btree (card_id, created_at);


--
-- Name: idx_audit_events_org_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_events_org_created_at ON public.audit_events USING btree (org_id, created_at);


--
-- Name: idx_audit_events_project_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_events_project_created_at ON public.audit_events USING btree (project_id, created_at);


--
-- Name: idx_audit_events_task_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_events_task_created_at ON public.audit_events USING btree (task_id, created_at);


--
-- Name: idx_capabilities_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_capabilities_project ON public.capabilities USING btree (project_id);


--
-- Name: idx_card_notes_card; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_card_notes_card ON public.card_notes USING btree (card_id);


--
-- Name: idx_cards_parent_card; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cards_parent_card ON public.cards USING btree (parent_card_id);


--
-- Name: idx_cards_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cards_project ON public.cards USING btree (project_id);


--
-- Name: idx_cards_project_execution_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cards_project_execution_state ON public.cards USING btree (project_id, execution_state);


--
-- Name: idx_cards_project_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cards_project_parent ON public.cards USING btree (project_id, parent_card_id);


--
-- Name: idx_org_invite_links_active_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_org_invite_links_active_email ON public.org_invite_links USING btree (org_id, email) WHERE ((used_at IS NULL) AND (invalidated_at IS NULL));


--
-- Name: idx_org_invite_links_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_invite_links_email ON public.org_invite_links USING btree (email);


--
-- Name: idx_org_invite_links_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_invite_links_org ON public.org_invite_links USING btree (org_id);


--
-- Name: idx_org_invites_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_invites_org ON public.org_invites USING btree (org_id);


--
-- Name: idx_org_invites_used_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_invites_used_at ON public.org_invites USING btree (used_at);


--
-- Name: idx_password_resets_active_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_password_resets_active_email ON public.password_resets USING btree (email) WHERE ((used_at IS NULL) AND (invalidated_at IS NULL));


--
-- Name: idx_password_resets_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_password_resets_created_at ON public.password_resets USING btree (created_at);


--
-- Name: idx_password_resets_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_password_resets_email ON public.password_resets USING btree (email);


--
-- Name: idx_project_member_capabilities_capability; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_member_capabilities_capability ON public.project_member_capabilities USING btree (capability_id);


--
-- Name: idx_project_member_capabilities_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_member_capabilities_user ON public.project_member_capabilities USING btree (user_id);


--
-- Name: idx_project_members_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_members_user ON public.project_members USING btree (user_id);


--
-- Name: idx_rule_executions_card; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rule_executions_card ON public.rule_executions USING btree (card_id) WHERE (card_id IS NOT NULL);


--
-- Name: idx_rule_executions_rule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rule_executions_rule ON public.rule_executions USING btree (rule_id);


--
-- Name: idx_rule_executions_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rule_executions_task ON public.rule_executions USING btree (task_id) WHERE (task_id IS NOT NULL);


--
-- Name: idx_rules_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rules_active ON public.rules USING btree (active) WHERE (active = true);


--
-- Name: idx_rules_workflow; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rules_workflow ON public.rules USING btree (workflow_id);


--
-- Name: idx_task_dependencies_depends_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_dependencies_depends_on_task_id ON public.task_dependencies USING btree (depends_on_task_id);


--
-- Name: idx_task_dependencies_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_dependencies_task_id ON public.task_dependencies USING btree (task_id);


--
-- Name: idx_task_notes_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_notes_task ON public.task_notes USING btree (task_id);


--
-- Name: idx_task_templates_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_templates_org ON public.task_templates USING btree (org_id);


--
-- Name: idx_task_templates_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_templates_project ON public.task_templates USING btree (project_id);


--
-- Name: idx_task_types_capability; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_types_capability ON public.task_types USING btree (capability_id);


--
-- Name: idx_task_types_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_types_project ON public.task_types USING btree (project_id);


--
-- Name: idx_tasks_card; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_card ON public.tasks USING btree (card_id);


--
-- Name: idx_tasks_card_execution_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_card_execution_state ON public.tasks USING btree (card_id, execution_state);


--
-- Name: idx_tasks_claimed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_claimed_by ON public.tasks USING btree (claimed_by);


--
-- Name: idx_tasks_created_from_rule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_created_from_rule ON public.tasks USING btree (created_from_rule_id);


--
-- Name: idx_tasks_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_project ON public.tasks USING btree (project_id);


--
-- Name: idx_tasks_project_execution_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_project_execution_state ON public.tasks USING btree (project_id, execution_state);


--
-- Name: idx_user_card_views_card; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_card_views_card ON public.user_card_views USING btree (card_id);


--
-- Name: idx_user_task_views_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_task_views_task ON public.user_task_views USING btree (task_id);


--
-- Name: idx_work_session_active_task; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_work_session_active_task ON public.user_task_work_session USING btree (task_id) WHERE (ended_at IS NULL);


--
-- Name: idx_work_session_stale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_session_stale ON public.user_task_work_session USING btree (last_heartbeat_at) WHERE (ended_at IS NULL);


--
-- Name: idx_work_session_user_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_session_user_active ON public.user_task_work_session USING btree (user_id) WHERE (ended_at IS NULL);


--
-- Name: idx_work_total_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_total_task_id ON public.user_task_work_total USING btree (task_id);


--
-- Name: idx_workflows_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_workflows_org ON public.workflows USING btree (org_id);


--
-- Name: idx_workflows_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_workflows_project ON public.workflows USING btree (project_id);


--
-- Name: rule_executions_rule_id_card_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rule_executions_rule_id_card_id_key ON public.rule_executions USING btree (rule_id, card_id) WHERE (card_id IS NOT NULL);


--
-- Name: rule_executions_rule_id_task_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rule_executions_rule_id_task_id_key ON public.rule_executions USING btree (rule_id, task_id) WHERE (task_id IS NOT NULL);


--
-- Name: api_tokens trg_api_tokens_org_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_api_tokens_org_scope BEFORE INSERT OR UPDATE OF org_id, project_id, integration_user_id, created_by ON public.api_tokens FOR EACH ROW EXECUTE FUNCTION public.enforce_api_token_org_scope();


--
-- Name: audit_events trg_audit_events_org_project; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_events_org_project BEFORE INSERT OR UPDATE OF org_id, project_id, task_id, card_id ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.enforce_audit_event_org_project();


--
-- Name: cards trg_cards_child_kind_invariant; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cards_child_kind_invariant BEFORE INSERT OR UPDATE OF parent_card_id ON public.cards FOR EACH ROW EXECUTE FUNCTION public.enforce_card_child_kind_invariant();


--
-- Name: cards trg_cards_prevent_cycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cards_prevent_cycle BEFORE INSERT OR UPDATE OF parent_card_id ON public.cards FOR EACH ROW EXECUTE FUNCTION public.prevent_card_cycle();


--
-- Name: project_member_capabilities trg_check_capability_project; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_capability_project BEFORE INSERT OR UPDATE ON public.project_member_capabilities FOR EACH ROW EXECUTE FUNCTION public.check_capability_project();


--
-- Name: project_settings trg_project_settings_increment_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_project_settings_increment_version BEFORE UPDATE ON public.project_settings FOR EACH ROW EXECUTE FUNCTION public.project_settings_increment_version();


--
-- Name: rules trg_rules_workflow_task_type_project_fk; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rules_workflow_task_type_project_fk BEFORE INSERT OR UPDATE OF workflow_id, task_type_id ON public.rules FOR EACH ROW EXECUTE FUNCTION public.rules_workflow_task_type_project_fk();


--
-- Name: task_dependencies trg_task_dependencies_prevent_cycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_task_dependencies_prevent_cycle BEFORE INSERT OR UPDATE OF task_id, depends_on_task_id ON public.task_dependencies FOR EACH ROW EXECUTE FUNCTION public.prevent_task_dependency_cycle();


--
-- Name: tasks trg_tasks_child_kind_invariant; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tasks_child_kind_invariant BEFORE INSERT OR UPDATE OF card_id ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.enforce_card_child_kind_invariant();


--
-- Name: api_token_audit_log api_token_audit_log_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_token_audit_log
    ADD CONSTRAINT api_token_audit_log_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.api_tokens(id);


--
-- Name: api_token_scopes api_token_scopes_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_token_scopes
    ADD CONSTRAINT api_token_scopes_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.api_tokens(id) ON DELETE CASCADE;


--
-- Name: api_tokens api_tokens_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: api_tokens api_tokens_integration_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_integration_user_id_fkey FOREIGN KEY (integration_user_id) REFERENCES public.users(id);


--
-- Name: api_tokens api_tokens_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- Name: api_tokens api_tokens_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: audit_events audit_events_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id);


--
-- Name: audit_events audit_events_card_project_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_card_project_fk FOREIGN KEY (project_id, card_id) REFERENCES public.cards(project_id, id);


--
-- Name: audit_events audit_events_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- Name: audit_events audit_events_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: audit_events audit_events_task_project_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_task_project_fk FOREIGN KEY (project_id, task_id) REFERENCES public.tasks(project_id, id);


--
-- Name: capabilities capabilities_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capabilities
    ADD CONSTRAINT capabilities_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: card_notes card_notes_card_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_notes
    ADD CONSTRAINT card_notes_card_id_fkey FOREIGN KEY (card_id) REFERENCES public.cards(id) ON DELETE CASCADE;


--
-- Name: card_notes card_notes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_notes
    ADD CONSTRAINT card_notes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: cards cards_activated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_activated_by_fkey FOREIGN KEY (activated_by) REFERENCES public.users(id);


--
-- Name: cards cards_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES public.users(id);


--
-- Name: cards cards_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: cards cards_parent_card_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_parent_card_fk FOREIGN KEY (project_id, parent_card_id) REFERENCES public.cards(project_id, id);


--
-- Name: cards cards_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: org_invite_links org_invite_links_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_invite_links
    ADD CONSTRAINT org_invite_links_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: org_invite_links org_invite_links_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_invite_links
    ADD CONSTRAINT org_invite_links_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- Name: org_invite_links org_invite_links_used_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_invite_links
    ADD CONSTRAINT org_invite_links_used_by_fkey FOREIGN KEY (used_by) REFERENCES public.users(id);


--
-- Name: org_invites org_invites_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_invites
    ADD CONSTRAINT org_invites_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: org_invites org_invites_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_invites
    ADD CONSTRAINT org_invites_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- Name: org_invites org_invites_used_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_invites
    ADD CONSTRAINT org_invites_used_by_fkey FOREIGN KEY (used_by) REFERENCES public.users(id);


--
-- Name: project_card_depth_names project_card_depth_names_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_card_depth_names
    ADD CONSTRAINT project_card_depth_names_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_member_capabilities project_member_capabilities_capability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_member_capabilities
    ADD CONSTRAINT project_member_capabilities_capability_id_fkey FOREIGN KEY (capability_id) REFERENCES public.capabilities(id) ON DELETE CASCADE;


--
-- Name: project_member_capabilities project_member_capabilities_project_id_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_member_capabilities
    ADD CONSTRAINT project_member_capabilities_project_id_user_id_fkey FOREIGN KEY (project_id, user_id) REFERENCES public.project_members(project_id, user_id) ON DELETE CASCADE;


--
-- Name: project_members project_members_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: project_members project_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: project_settings project_settings_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_settings
    ADD CONSTRAINT project_settings_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: projects projects_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- Name: rule_executions rule_executions_card_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT rule_executions_card_id_fkey FOREIGN KEY (card_id) REFERENCES public.cards(id) ON DELETE CASCADE;


--
-- Name: rule_executions rule_executions_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT rule_executions_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES public.rules(id) ON DELETE CASCADE;


--
-- Name: rule_executions rule_executions_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT rule_executions_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: rule_executions rule_executions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT rule_executions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: rule_templates rule_templates_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_templates
    ADD CONSTRAINT rule_templates_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES public.rules(id) ON DELETE CASCADE;


--
-- Name: rule_templates rule_templates_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_templates
    ADD CONSTRAINT rule_templates_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.task_templates(id) ON DELETE CASCADE;


--
-- Name: rules rules_task_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT rules_task_type_id_fkey FOREIGN KEY (task_type_id) REFERENCES public.task_types(id);


--
-- Name: rules rules_workflow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT rules_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES public.workflows(id) ON DELETE CASCADE;


--
-- Name: task_dependencies task_dependencies_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: task_dependencies task_dependencies_depends_on_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_depends_on_task_id_fkey FOREIGN KEY (depends_on_task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_dependencies task_dependencies_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_notes task_notes_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_notes
    ADD CONSTRAINT task_notes_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: task_notes task_notes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_notes
    ADD CONSTRAINT task_notes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: task_positions task_positions_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_positions
    ADD CONSTRAINT task_positions_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: task_positions task_positions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_positions
    ADD CONSTRAINT task_positions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: task_templates task_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_templates
    ADD CONSTRAINT task_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: task_templates task_templates_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_templates
    ADD CONSTRAINT task_templates_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- Name: task_templates task_templates_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_templates
    ADD CONSTRAINT task_templates_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: task_templates task_templates_project_type_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_templates
    ADD CONSTRAINT task_templates_project_type_fk FOREIGN KEY (project_id, type_id) REFERENCES public.task_types(project_id, id);


--
-- Name: task_types task_types_project_capability_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT task_types_project_capability_fk FOREIGN KEY (project_id, capability_id) REFERENCES public.capabilities(project_id, id);


--
-- Name: task_types task_types_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT task_types_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: tasks tasks_card_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_card_id_fkey FOREIGN KEY (card_id) REFERENCES public.cards(id);


--
-- Name: tasks tasks_claimed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_claimed_by_fkey FOREIGN KEY (claimed_by) REFERENCES public.users(id);


--
-- Name: tasks tasks_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES public.users(id);


--
-- Name: tasks tasks_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: tasks tasks_created_from_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_created_from_rule_id_fkey FOREIGN KEY (created_from_rule_id) REFERENCES public.rules(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_project_capability_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_capability_fk FOREIGN KEY (project_id, capability_id) REFERENCES public.capabilities(project_id, id);


--
-- Name: tasks tasks_project_card_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_card_fk FOREIGN KEY (project_id, card_id) REFERENCES public.cards(project_id, id);


--
-- Name: tasks tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: tasks tasks_project_type_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_type_fk FOREIGN KEY (project_id, type_id) REFERENCES public.task_types(project_id, id);


--
-- Name: user_card_views user_card_views_card_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_card_views
    ADD CONSTRAINT user_card_views_card_id_fkey FOREIGN KEY (card_id) REFERENCES public.cards(id) ON DELETE CASCADE;


--
-- Name: user_card_views user_card_views_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_card_views
    ADD CONSTRAINT user_card_views_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_task_views user_task_views_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_views
    ADD CONSTRAINT user_task_views_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: user_task_views user_task_views_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_views
    ADD CONSTRAINT user_task_views_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_task_work_session user_task_work_session_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_work_session
    ADD CONSTRAINT user_task_work_session_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: user_task_work_session user_task_work_session_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_work_session
    ADD CONSTRAINT user_task_work_session_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_task_work_total user_task_work_total_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_work_total
    ADD CONSTRAINT user_task_work_total_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: user_task_work_total user_task_work_total_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_task_work_total
    ADD CONSTRAINT user_task_work_total_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users users_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- Name: workflows workflows_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: workflows workflows_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- Name: workflows workflows_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20260112100000'),
    ('20260112100001'),
    ('20260112100002'),
    ('20260112100003'),
    ('20260112100004'),
    ('20260113120000'),
    ('20260113130000'),
    ('20260113130001'),
    ('20260113140000'),
    ('20260113140001'),
    ('20260114100000'),
    ('20260114120000'),
    ('20260114231500'),
    ('20260115130000'),
    ('20260115193000'),
    ('20260115194000'),
    ('20260115223000'),
    ('20260116120000'),
    ('20260118100000'),
    ('20260119100000'),
    ('20260119120000'),
    ('20260119123000'),
    ('20260120100000'),
    ('20260121100001'),
    ('20260121100002'),
    ('20260121100003'),
    ('20260121100004'),
    ('20260128100000'),
    ('20260128120000'),
    ('20260128130000'),
    ('20260129100000'),
    ('20260201090000'),
    ('20260206183000'),
    ('20260610120000'),
    ('20260612170000'),
    ('20260619120000'),
    ('20260619130000'),
    ('20260619140000'),
    ('20260620100000'),
    ('20260620101000'),
    ('20260620102000'),
    ('20260620103000'),
    ('20260620104000'),
    ('20260620105000'),
    ('20260620106000'),
    ('20260620107000'),
    ('20260620108000'),
    ('20260621120000'),
    ('20260621121000'),
    ('20260622120000');
