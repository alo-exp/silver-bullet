# Developer entry points. Every target wraps a script you can also run directly;
# CI (.github/workflows/ci.yml) runs the same commands.
#
#   make setup      install Python test/coverage packages and check prerequisites
#   make lint       syntax-check and shellcheck shell sources, validate JSON
#   make test       full suite (JOBS=4 make test, SUITE=hooks make test)
#   make coverage   full suite with coverage; FAIL_UNDER=100 make coverage
#   make check      lint + test (what a pull request must pass)

SHELL := /usr/bin/env bash
JOBS ?= 4
SUITE ?=
FAIL_UNDER ?=
PYTHON ?= python3

SHELLCHECK_EXCLUDES := SC2317,SC1091,SC2329

.PHONY: help setup prereqs lint test coverage check sync-check

help:
	@sed -n '1,9p' Makefile | sed 's/^# \{0,1\}//'

prereqs:
	@missing=0; for cmd in bash git jq $(PYTHON) rsync; do \
	  command -v $$cmd >/dev/null 2>&1 || { echo "missing required tool: $$cmd"; missing=1; }; \
	done; \
	for cmd in shellcheck expect tmux node; do \
	  command -v $$cmd >/dev/null 2>&1 || echo "optional tool not found: $$cmd (some checks/tests will be skipped or fail)"; \
	done; \
	exit $$missing

setup: prereqs
	$(PYTHON) -m pip install -r requirements-dev.txt

lint:
	@for f in hooks/*.sh hooks/session-start hooks/lib/*.sh hooks/lib/*/*.sh scripts/*.sh $$(find scripts/lib scripts/enterprise-e2e scripts/agent-* -name '*.sh'); do \
	  bash -n "$$f" || exit 1; \
	done; echo "bash -n: ok"
	@for f in hooks/hooks.json templates/silver-bullet.config.json.default .silver-bullet.json package.json \
	  .claude-plugin/plugin.json .claude-plugin/marketplace.json .cursor-plugin/plugin.json .cursor-plugin/marketplace.json \
	  .agents/plugins/marketplace.json; do jq empty "$$f" || exit 1; done; echo "json: ok"
	shellcheck --exclude=$(SHELLCHECK_EXCLUDES) hooks/*.sh hooks/lib/*.sh scripts/*.sh

test:
	bash tests/run-all-tests.sh --jobs $(JOBS) $(if $(SUITE),--suite $(SUITE),)

coverage:
	bash tests/coverage/run-coverage.sh --jobs $(JOBS) $(if $(SUITE),--suite $(SUITE),) $(if $(FAIL_UNDER),--fail-under $(FAIL_UNDER),)

sync-check:
	bash scripts/sync-runtime-mirrors.sh --check
	bash scripts/validate-plugin-mirror.sh

check: lint test
