# Developer entry points. Every target wraps a script you can also run directly;
# CI (.github/workflows/ci.yml) runs the same commands.
#
#   make setup      check prerequisites and install the Python test/coverage packages
#                   into a virtualenv (.venv); never into the system interpreter
#   make lint       syntax-check and shellcheck shell sources, validate JSON
#   make test       full suite (JOBS=4 make test, SUITE=hooks make test)
#   make coverage   full suite with coverage; FAIL_UNDER=100 make coverage
#   make check      lint + test (what a pull request must pass)

SHELL := /usr/bin/env bash
JOBS ?= 4
SUITE ?=
FAIL_UNDER ?=
PYTHON ?= python3
# Contributor Python packages live in a virtualenv: Debian/Ubuntu and Homebrew Pythons are
# externally managed (PEP 668), so pip refuses to install into them. Once it exists, the
# venv's bin/ goes first on PATH for every target, so tests and coverage use its packages.
VENV ?= .venv
ifneq ($(wildcard $(VENV)/bin/python),)
export PATH := $(abspath $(VENV))/bin:$(PATH)
endif

.PHONY: help setup prereqs lint test coverage check sync-check

help:
	@sed -n '1,10p' Makefile | sed 's/^# \{0,1\}//'

prereqs:
	@missing=0; for cmd in bash git jq $(PYTHON) rsync; do \
	  command -v $$cmd >/dev/null 2>&1 || { echo "missing required tool: $$cmd"; missing=1; }; \
	done; \
	for cmd in shellcheck expect tmux node xxd zip unzip; do \
	  command -v $$cmd >/dev/null 2>&1 || echo "optional tool not found: $$cmd (some checks/tests will be skipped or fail)"; \
	done; \
	if [ "$${BASH_VERSINFO:-0}" -lt 4 ] 2>/dev/null; then echo "note: bash $${BASH_VERSION:-?} is older than 4 (the full suite expects bash >= 4; Homebrew: brew install bash)"; fi; \
	command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1 || echo "optional tool not found: timeout (GNU coreutils)"; \
	exit $$missing

setup: prereqs
	@test -x "$(VENV)/bin/python" || $(PYTHON) -m venv "$(VENV)" || { \
	  echo "could not create $(VENV): install the venv module (Debian/Ubuntu: apt install python3-venv)"; exit 1; }
	"$(VENV)/bin/python" -m pip install -r requirements-dev.txt
	@echo "setup done: Python packages are in $(VENV); make test and make coverage use them automatically"

lint:
	@files="$$(bash scripts/lint-shell.sh --list)" || exit 1; \
	for f in $$files; do \
	  bash -n "$$f" || exit 1; \
	done; echo "bash -n: ok"
	@for f in hooks/hooks.json templates/silver-bullet.config.json.default .silver-bullet.json package.json \
	  .claude-plugin/plugin.json .claude-plugin/marketplace.json \
	  .agents/plugins/marketplace.json; do jq empty "$$f" || exit 1; done; echo "json: ok"
	bash scripts/lint-shell.sh --all

test:
	bash tests/run-all-tests.sh --jobs $(JOBS) $(if $(SUITE),--suite $(SUITE),)

coverage:
	bash tests/coverage/run-coverage.sh --jobs $(JOBS) $(if $(SUITE),--suite $(SUITE),) $(if $(FAIL_UNDER),--fail-under $(FAIL_UNDER),)

sync-check:
	bash scripts/sync-runtime-mirrors.sh --check
	bash scripts/validate-plugin-mirror.sh

check: lint test
