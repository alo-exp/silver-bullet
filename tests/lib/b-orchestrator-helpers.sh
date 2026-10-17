# shellcheck shell=bash
# Shared helpers for the orchestrator / delegation hook tests (package B-orchestrator).
#
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
#   tl_init
#   orch_make_project "$TL_TMP/proj"          # SB project boundary + git dir
#
# Every helper writes only under $TL_TMP or $SB_RUNTIME_STATE_DIR (sandboxed by tl_init).

# orch_make_project DIR [config-json]: create an SB project (boundary files + .git dir).
orch_make_project() {
  local dir="$1" config="${2:-}"
  [[ -n "$config" ]] || config='{"sb_initiated":true,"orchestrator_mode":"parent"}'
  mkdir -p "$dir/.planning"
  git -C "$dir" init -q 2>/dev/null || mkdir -p "$dir/.git"
  printf '%s\n' "$config" >"$dir/.silver-bullet.json"
  printf '# Silver Bullet\n' >"$dir/silver-bullet.md"
}

# orch_stage_hook NAME [with-lib]: copy hooks/NAME into a temp plugin layout and print the
# staged path. Without "with-lib" the staged copy has no hooks/lib directory, which is how
# a partially installed plugin looks.
orch_stage_hook() {
  local name="$1" with_lib="${2:-}"
  local root="$TL_TMP/staged-${name%.sh}-${with_lib:-nolib}"
  mkdir -p "$root/hooks"
  cp "$TL_REPO_ROOT/hooks/$name" "$root/hooks/$name"
  if [[ "$with_lib" == "with-lib" ]]; then
    cp -R "$TL_REPO_ROOT/hooks/lib" "$root/hooks/lib"
  fi
  printf '%s' "$root/hooks/$name"
}

# orch_state_file: path of orchestrator.json in the sandboxed state dir.
orch_state_file() { printf '%s/orchestrator.json' "$SB_RUNTIME_STATE_DIR"; }

# orch_directive_file: path of orchestrator-directive.json in the sandboxed state dir.
orch_directive_file() { printf '%s/orchestrator-directive.json' "$SB_RUNTIME_STATE_DIR"; }

# orch_write_state JSON: replace orchestrator.json.
orch_write_state() {
  mkdir -p "$SB_RUNTIME_STATE_DIR"
  printf '%s\n' "$1" >"$(orch_state_file)"
}

# orch_state_get JQ-FILTER: read a field from orchestrator.json (raw output).
orch_state_get() {
  jq -r "$1" "$(orch_state_file)" 2>/dev/null
}

# orch_directive_get JQ-FILTER: read a field from orchestrator-directive.json (raw output).
orch_directive_get() {
  jq -r "$1" "$(orch_directive_file)" 2>/dev/null
}

# orch_fixture_catalog PATH: write a small APO catalog used by scheduler tests.
#   AF-PLAN     serial, two owned flow steps, worker template PLAN.md
#   AF-READ-A   parallel, scope "a", template FIXTURE-READ-A.md, one owned step
#   AF-READ-B   parallel, scope "b", no worker template (slug fallback)
#   AF-READ-C   parallel, scope "a" (conflicts with AF-READ-A)
#   AF-DEP      parallel, depends on AF-LATER
#   AF-LATER    parallel, scope "later"
#   AF-SECURE   serial
orch_fixture_catalog() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'JSON'
{
  "atomic_flows": [
    {"id": "AF-PLAN", "slug": "PLAN",
     "execution": {"parallelizable": false, "worker_template": "templates/orchestrator-workers/PLAN.md",
                   "mutation_scopes": ["planning"], "dispatch_record_shape": "plan-shape"},
     "flow_steps": ["FS-PLAN-1", "FS-PLAN-2"]},
    {"id": "AF-READ-A", "slug": "FIXTURE-READ-A",
     "execution": {"parallelizable": true, "worker_template": "templates/orchestrator-workers/FIXTURE-READ-A.md",
                   "mutation_scopes": ["a"]},
     "flow_steps": ["FS-A-1"]},
    {"id": "AF-READ-B", "slug": "FIXTURE-READ-B",
     "execution": {"parallelizable": true, "mutation_scopes": ["b"]},
     "flow_steps": []},
    {"id": "AF-READ-C", "slug": "read-c",
     "execution": {"parallelizable": true, "mutation_scopes": ["a"]}},
    {"id": "AF-DEP", "slug": "DEP",
     "execution": {"parallelizable": true, "depends_on_atoms": ["AF-LATER", "not-an-atom"], "mutation_scopes": ["dep"]}},
    {"id": "AF-LATER", "slug": "LATER",
     "execution": {"parallelizable": true, "mutation_scopes": ["later"]}},
    {"id": "AF-SECURE", "slug": "SECURE",
     "execution": {"parallelizable": false}}
  ],
  "migration_map": {
    "runtime_queue_tokens": {
      "FLOW-PLAN-TOKEN": "AF-PLAN",
      "silver-plan": "AF-PLAN",
      "silver-fixture-read-a": "AF-READ-A",
      "silver-fixture-read-b": "AF-READ-B",
      "security": "AF-SECURE",
      "ghost-token": "AF-GHOST"
    },
    "skill_to_entity": {
      "plan-skill": "AF-PLAN",
      "orphan-skill": "AF-ORPHAN"
    },
    "gsd_alias_to_entity": {
      "gsd-plan-phase": "AF-PLAN"
    },
    "legacy_flows": {
      "FLOW 7": "AF-PLAN",
      "FLOW 99": "not-an-af"
    }
  }
}
JSON
}

# orch_bash_env_wrapper FILE...: print the path of a BASH_ENV script that first sources the
# coverage tracer (when one is active) and then FILE..., so child bash processes start with
# extra functions already defined. Use as: BASH_ENV="$(orch_bash_env_wrapper lib.sh)" cmd
orch_bash_env_wrapper() {
  local wrapper="$TL_TMP/bash-env-wrapper.$$.sh" f
  {
    if [[ -n "${BASH_ENV:-}" && "$BASH_ENV" != "$wrapper" ]]; then
      printf 'source %q\n' "$BASH_ENV"
    fi
    for f in "$@"; do printf 'source %q\n' "$f"; done
  } >"$wrapper"
  printf '%s' "$wrapper"
}

# orch_stub_failing CMD PATTERN: put a stub CMD first on PATH that exits 1 when any argument
# contains PATTERN and otherwise runs the real command. Clears bash's command hash so the
# current shell picks the stub up. Undo with orch_unstub CMD.
orch_stub_failing() {
  local cmd="$1" pattern="$2" real
  rm -f "$TL_BIN/$cmd"
  hash -r
  real="$(command -v "$cmd")"
  tl_stub "$cmd" "for a in \"\$@\"; do [[ \"\$a\" == *'$pattern'* ]] && exit 1; done; exec $real \"\$@\""
  hash -r
}

# orch_unstub CMD: remove a stub installed with orch_stub_failing/tl_stub and clear the hash.
orch_unstub() {
  rm -f "$TL_BIN/$1"
  hash -r
}

# orch_stage_libs NAME...: copy the named hooks/lib files (and nothing else) into a fresh
# <tmp>/hooks/lib directory and print that directory. The two-component path keeps the
# coverage mapper able to credit the copies to the real files.
orch_stage_libs() {
  local dir name
  dir="$(mktemp -d "$TL_TMP/stage.XXXXXX")/hooks/lib"
  mkdir -p "$dir"
  for name in "$@"; do cp "$TL_REPO_ROOT/hooks/lib/$name" "$dir/$name"; done
  printf '%s' "$dir"
}

# orch_stage_tree: copy the whole hooks/ tree to <tmp>/hooks and print the hooks directory,
# so a test can remove or replace single libs before running a hook from the copy.
orch_stage_tree() {
  local root
  root="$(mktemp -d "$TL_TMP/tree.XXXXXX")"
  cp -R "$TL_REPO_ROOT/hooks" "$root/hooks"
  printf '%s' "$root/hooks"
}
