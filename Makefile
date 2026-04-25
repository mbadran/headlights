.PHONY: test test-file lint help

# Adjust this path if plenary.nvim lives elsewhere on your system.
PLENARY ?= $(HOME)/.local/share/nvim/lazy/plenary.nvim
PLENARY_ALT ?= $(HOME)/.local/share/nvim/site/pack/packer/start/plenary.nvim

# Prefer lazy path; fall back to packer path
PLENARY_PATH := $(shell [ -d "$(PLENARY)" ] && echo "$(PLENARY)" || echo "$(PLENARY_ALT)")

NVIM ?= nvim

## Run the full test suite using plenary.nvim
test:
	@echo "==> Running headlights tests with plenary..."
	@echo "    plenary: $(PLENARY_PATH)"
	$(NVIM) \
		--headless \
		--noplugin \
		-u tests/minimal_init.lua \
		-c "lua vim.opt.runtimepath:prepend('$(PLENARY_PATH)')" \
		-c "lua vim.opt.runtimepath:prepend('.')" \
		-c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua', sequential=true}" \
		-c "qa!"

## Run a single spec file: make test-file FILE=tests/headlights/bundler_spec.lua
test-file:
	$(NVIM) \
		--headless \
		--noplugin \
		-u tests/minimal_init.lua \
		-c "lua vim.opt.runtimepath:prepend('$(PLENARY_PATH)')" \
		-c "lua vim.opt.runtimepath:prepend('.')" \
		-c "PlenaryBustedFile $(FILE)" \
		-c "qa!"

help:
	@echo "Available targets:"
	@echo "  make test              Run the full test suite"
	@echo "  make test-file FILE=…  Run a single spec file"
	@echo ""
	@echo "Dependencies: plenary.nvim must be installed."
	@echo "  Set PLENARY=/path/to/plenary.nvim to override the default location."
