.PHONY: help deps build build-prod ci smoke-staging pre-go-live release-check migrate squirrel test verify fmt format

# Default local DB URL. CI should override `DATABASE_URL`.
# Note: `dbmate migrate` does NOT create the database.
DATABASE_URL ?= postgres://scrumbringer:scrumbringer@localhost:5432/scrumbringer_test?sslmode=disable
SB_DB_POOL_SIZE ?= 2
SB_DB_WAIT_ATTEMPTS ?= 120
SB_DB_WAIT_MS ?= 100
SB_DB_WAIT_QUERY_TIMEOUT_MS ?= 15000

ROOT := $(abspath $(CURDIR))
GLEAN_BIN := $(shell if [ -x "$(ROOT)/.tools/gleam-1.14.0/gleam" ]; then echo "$(ROOT)/.tools/gleam-1.14.0/gleam"; else echo gleam; fi)

help:
	@echo "Targets:"
	@echo "  make deps       # download Gleam deps"
	@echo "  make build      # build all Gleam packages/apps"
	@echo "  make build-prod # build all + client dist bundle"
	@echo "  make ci         # deps + build + test"
	@echo "  make smoke-staging # run smoke checks against STAGING_BASE_URL"
	@echo "  make pre-go-live   # release-check + optional staging smoke"
	@echo "  make release-check # ci (+ optional smoke when RUN_SMOKE=1)"
	@echo "  make migrate    # apply dbmate migrations (DATABASE_URL=...)"
	@echo "  make squirrel   # regenerate Squirrel sql.gleam (DATABASE_URL=...)"
	@echo "  make test       # run tests (DATABASE_URL=... for server)"
	@echo "  make verify     # migrate + squirrel + test"
	@echo "  make fmt        # format Gleam code"
	@echo "  make format     # format Gleam code"

# ---- Dependencies ----

deps:
	@echo "Using gleam: $(GLEAN_BIN)"
	@cd apps/server && $(GLEAN_BIN) deps download
	@cd apps/client && $(GLEAN_BIN) deps download
	@cd shared && $(GLEAN_BIN) deps download
	@cd packages/birl && $(GLEAN_BIN) deps download

# ---- Database ----

build:
	@echo "Using gleam: $(GLEAN_BIN)"
	@cd apps/server && $(GLEAN_BIN) build
	@cd apps/client && $(GLEAN_BIN) build
	@cd shared && $(GLEAN_BIN) build
	@cd packages/birl && $(GLEAN_BIN) build

build-prod:
	@ROOT_DIR="$(ROOT)" GLEAM_BIN="$(GLEAN_BIN)" bash scripts/build-prod.sh

ci: deps build test

release-check: ci
	@if [ "$(RUN_SMOKE)" = "1" ]; then \
		echo "Running smoke checks..."; \
		bash scripts/smoke-active-task.sh; \
	else \
		echo "Skipping smoke checks (set RUN_SMOKE=1 to enable)"; \
	fi

smoke-staging:
	@STAGING_BASE_URL="$(STAGING_BASE_URL)" \
	STAGING_API_URL="$(STAGING_API_URL)" \
	SMOKE_EMAIL="$(SMOKE_EMAIL)" \
	SMOKE_PASSWORD="$(SMOKE_PASSWORD)" \
	SMOKE_TASK_ID="$(SMOKE_TASK_ID)" \
	bash scripts/smoke-staging.sh

pre-go-live: release-check
	@if [ -n "$(STAGING_BASE_URL)" ]; then \
		echo "Running staging smoke against $(STAGING_BASE_URL)..."; \
		$(MAKE) smoke-staging \
			STAGING_BASE_URL="$(STAGING_BASE_URL)" \
			STAGING_API_URL="$(STAGING_API_URL)" \
			SMOKE_EMAIL="$(SMOKE_EMAIL)" \
			SMOKE_PASSWORD="$(SMOKE_PASSWORD)" \
			SMOKE_TASK_ID="$(SMOKE_TASK_ID)"; \
	else \
		echo "Skipping staging smoke (set STAGING_BASE_URL to enable)"; \
	fi

migrate:
	@command -v dbmate >/dev/null 2>&1 || (echo "dbmate is required (install it)" && exit 1)
	@echo "Applying migrations with DATABASE_URL=$(DATABASE_URL)"
	@dbmate --url "$(DATABASE_URL)" migrate

# ---- Squirrel ----

squirrel:
	@echo "Regenerating Squirrel code with DATABASE_URL=$(DATABASE_URL)"
	@cd apps/server && DATABASE_URL="$(DATABASE_URL)" $(GLEAN_BIN) run -m squirrel

# ---- Tests ----

test:
	@$(MAKE) migrate
	@echo "Running server tests with DATABASE_URL=$(DATABASE_URL)"
	@cd apps/server && DATABASE_URL="$(DATABASE_URL)" \
		SB_DB_POOL_SIZE="$(SB_DB_POOL_SIZE)" \
		SB_DB_WAIT_ATTEMPTS="$(SB_DB_WAIT_ATTEMPTS)" \
		SB_DB_WAIT_MS="$(SB_DB_WAIT_MS)" \
		SB_DB_WAIT_QUERY_TIMEOUT_MS="$(SB_DB_WAIT_QUERY_TIMEOUT_MS)" \
		$(GLEAN_BIN) test
	@echo "Running client tests"
	@cd apps/client && $(GLEAN_BIN) test
	@cd shared && $(GLEAN_BIN) test
	@cd packages/birl && $(GLEAN_BIN) test

verify: migrate squirrel test

fmt:
	@cd apps/server && $(GLEAN_BIN) format
	@cd apps/client && $(GLEAN_BIN) format
	@cd shared && $(GLEAN_BIN) format
	@cd packages/birl && $(GLEAN_BIN) format

format: fmt
