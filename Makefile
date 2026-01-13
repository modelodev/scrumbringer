.PHONY: help deps migrate squirrel test verify fmt

DATABASE_URL ?= postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_test?sslmode=disable

GLEAN_BIN := $(shell if [ -x .tools/gleam-1.14.0/gleam ]; then echo .tools/gleam-1.14.0/gleam; else echo gleam; fi)

help:
	@echo "Targets:"
	@echo "  make deps       # download Gleam deps"
	@echo "  make migrate    # apply dbmate migrations (DATABASE_URL=...)"
	@echo "  make squirrel   # regenerate Squirrel sql.gleam (DATABASE_URL=...)"
	@echo "  make test       # run tests (DATABASE_URL=... for server)"
	@echo "  make verify     # migrate + squirrel + test"
	@echo "  make fmt        # format Gleam code"

# ---- Dependencies ----

deps:
	@echo "Using gleam: $(GLEAN_BIN)"
	@cd apps/server && $(GLEAN_BIN) deps download
	@cd packages/domain && $(GLEAN_BIN) deps download
	@cd packages/birl && $(GLEAN_BIN) deps download

# ---- Database ----

migrate:
	@command -v dbmate >/dev/null 2>&1 || (echo "dbmate is required (install it)" && exit 1)
	@echo "Applying migrations with DATABASE_URL=$(DATABASE_URL)"
	@DBMATE_DATABASE_URL="$(DATABASE_URL)" dbmate up

# ---- Squirrel ----

squirrel:
	@echo "Regenerating Squirrel code with DATABASE_URL=$(DATABASE_URL)"
	@cd apps/server && DATABASE_URL="$(DATABASE_URL)" $(GLEAN_BIN) run -m squirrel

# ---- Tests ----

test:
	@echo "Running server tests with DATABASE_URL=$(DATABASE_URL)"
	@cd apps/server && DATABASE_URL="$(DATABASE_URL)" $(GLEAN_BIN) test
	@cd packages/domain && $(GLEAN_BIN) test
	@cd packages/birl && $(GLEAN_BIN) test

verify: migrate squirrel test

fmt:
	@cd apps/server && $(GLEAN_BIN) format
	@cd packages/domain && $(GLEAN_BIN) format
	@cd packages/birl && $(GLEAN_BIN) format
