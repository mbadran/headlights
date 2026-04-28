.PHONY: help test test-file smoke lint clean test-deps session-start session-end \
        cli docker-build docker-test

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

NVIM      ?= nvim
DEPS_DIR  := tests/.deps
MINI_TEST_DIR := $(DEPS_DIR)/mini.test
MINI_TEST_REPO := https://github.com/nvim-mini/mini.test
MINI_TEST_REF  ?= main

# Allow callers to point at a local mini.test checkout instead of cloning.
ifneq ($(MINI_TEST),)
MINI_TEST_DIR := $(MINI_TEST)
endif

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

help:
	@echo "Targets:"
	@echo "  make smoke          single end-to-end smoke test (fast)"
	@echo "  make test           full mini.test suite"
	@echo "  make test-file F=…  run one mini.test file (e.g. F=tests/test_bundler.lua)"
	@echo "  make test-deps      clone nvim-mini/mini.test into $(MINI_TEST_DIR)"
	@echo "  make lint           run luacheck if available (no-op otherwise)"
	@echo "  make cli            quick demo of the bin/headlights CLI driver"
	@echo "  make docker-build   build the local Docker test image"
	@echo "  make docker-test    run the smoke test inside Docker"
	@echo "  make session-start  print the start-of-session status summary"
	@echo "  make session-end    run the end-of-session quality gates + summary"
	@echo "  make clean          remove tests/.deps"
	@echo ""
	@echo "Override defaults via env vars:"
	@echo "  NVIM=/path/to/nvim         use a specific Neovim binary"
	@echo "  MINI_TEST=/path/checkout   use an existing mini.test clone"

# -----------------------------------------------------------------------------
# Test deps (mini.test)
# -----------------------------------------------------------------------------

test-deps: $(MINI_TEST_DIR)

$(MINI_TEST_DIR):
	@echo "==> Installing mini.test from $(MINI_TEST_REPO) ($(MINI_TEST_REF))"
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(MINI_TEST_DIR)/.git" ]; then \
	  git clone --depth=1 --branch=$(MINI_TEST_REF) \
	    $(MINI_TEST_REPO) $(MINI_TEST_DIR); \
	fi

# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

# Single end-to-end smoke test.
smoke:
	@tests/smoke/smoke.sh

# Full mini.test suite — discovers all tests/test_*.lua files.
test: test-deps
	@echo "==> Running headlights tests with mini.test ($(MINI_TEST_DIR))"
	$(NVIM) --headless --clean \
	  -u tests/minimal_init.lua \
	  -c "lua MiniTest.run({ collect = { find_files = function() return vim.fn.globpath('tests', 'test_*.lua', false, true) end } })" \
	  -c "qa!"

# Run a single spec file: make test-file F=tests/test_bundler.lua
test-file: test-deps
	@if [ -z "$(F)" ]; then echo "usage: make test-file F=tests/test_<x>.lua"; exit 64; fi
	$(NVIM) --headless --clean \
	  -u tests/minimal_init.lua \
	  -c "lua MiniTest.run_file('$(F)')" \
	  -c "qa!"

# -----------------------------------------------------------------------------
# Lint
# -----------------------------------------------------------------------------

lint:
	@if command -v luacheck >/dev/null 2>&1; then \
	  luacheck lua bin tests --no-max-line-length --globals vim MiniTest describe it before_each after_each; \
	else \
	  echo "luacheck not installed — skipping"; \
	fi

# -----------------------------------------------------------------------------
# CLI demo
# -----------------------------------------------------------------------------

cli:
	@bin/headlights --format=text | head -30

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------

docker-build:
	@docker build -t headlights-test -f docker/Dockerfile .

docker-test: docker-build
	@docker run --rm -t headlights-test make smoke

# -----------------------------------------------------------------------------
# Session hygiene
# -----------------------------------------------------------------------------

session-start:
	@scripts/session-start.sh

session-end:
	@scripts/session-end.sh

# -----------------------------------------------------------------------------
# Housekeeping
# -----------------------------------------------------------------------------

clean:
	@rm -rf $(DEPS_DIR)
	@echo "removed $(DEPS_DIR)"
