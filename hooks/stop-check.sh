#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Stop hook (event: Stop)
# Fires when Claude outputs a final response (declaring task complete).
# Blocks if required_planning skills (planning floor) are missing from the state file.
# The full required_deploy list is enforced by completion-audit.sh at delivery
# commands (gh pr create / gh release create / deploy).
#
# Exit format: {"decision":"block","reason":"..."} to block completion.
# Silent exit 0 to allow completion.
#
# HOOK-NN markers in this file map to GitHub issue numbers on alo-exp/silver-bullet.
# Firing order (first matching gate wins and exits 0):
#   1. jq-missing warning          (fail-open, visible)
#   2. ERR trap                    (fail-open, visible)
#   3. No .silver-bullet.json      (fail-open — project not using SB)
#   4. Trivial bypass              (lib/trivial-bypass.sh)
#   5. HOOK-14 read-only gate      (fail-open — fixes #14, hardened #17)
#   6. HOOK-04 empty state         (fail-open — non-dev session)
#   7. Required-skills check       (block or exit 0)

# Security: restrict file creation permissions (user-only)
umask 0077

# Source runtime path selector so standalone Codex/Kay hook processes do not
# depend on host-provided SB_RUNTIME_* environment variables.
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi

# jq is required — block Stop enforcement when missing inside SB projects
_lib_dir_early="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir_early=""
if [[ -f "$_lib_dir_early/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir_early/jq-gate.sh"
fi

# Read JSON from stdin (hook event + optional context)
stop_input="$(cat 2>/dev/null || true)"
stop_hook_event="$(printf '%s' "$stop_input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
# Intentionally overrides the silent ERR trap set at line 3 — this hook
# emits a visible warning rather than failing open silently, so the user
# knows something unexpected occurred rather than seeing a clean block/allow.
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️  stop-check.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

# ── Resolve config file by walking up from $PWD ──────────────────────────────
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done

# No config → project not set up with Silver Bullet.
# Fail-open by design: stop-check is a no-op for non-SB projects.
[[ -z "$config_file" ]] && exit 0

if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_is_initiated "$config_file" || exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  msg="$(sb_jq_missing_message 2>/dev/null || printf '%s' 'jq required for Silver Bullet enforcement')"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$msg" <<'PY'
import json, sys
print(json.dumps({"decision": "block", "reason": sys.argv[1]}))
PY
  else
    printf '{"decision":"block","reason":"jq required for Silver Bullet enforcement"}'
  fi
  exit 0
fi

# ── Read config values ────────────────────────────────────────────────────────
SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR"

sb_default_state="${SB_STATE_DIR}/state"
sb_default_trivial="${SB_STATE_DIR}/trivial"
config_vals=$(jq -r --arg ds "$sb_default_state" --arg dt "$sb_default_trivial" '[
  (.state.state_file // $ds),
  (.state.trivial_file // $dt),
  ((.skills.required_deploy // []) | join(" ")),
  (.project.active_workflow // "full-dev-cycle"),
  ((.skills.required_planning // []) | join(" ")),
  ((.skills.required_planning_devops // []) | join(" "))
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
state_file="${state_file/#\~/$HOME}"
trivial_file=$(printf '%s' "$config_vals" | sed -n '2p')
trivial_file="${trivial_file/#\~/$HOME}"
active_workflow=$(printf '%s' "$config_vals" | sed -n '4p')
required_planning_cfg=$(printf '%s' "$config_vals" | sed -n '5p')
required_planning_devops_cfg=$(printf '%s' "$config_vals" | sed -n '6p')

# Env var override for state file
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"

# Security: validate paths stay within the host runtime state root (SB-002/SB-003)
if ! sb_runtime_path_is_state_scoped "$state_file"; then
  state_file="${SB_STATE_DIR}/state"
fi
if ! sb_runtime_path_is_state_scoped "$trivial_file"; then
  trivial_file="${SB_STATE_DIR}/trivial"
fi

# ── Resolve lib dir (needed for trivial-bypass and required-skills helpers) ───
lib_dir="${_lib_dir:-$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)}"

if [[ -f "$lib_dir/required-skills.sh" ]]; then
  # shellcheck source=lib/required-skills.sh
  # shellcheck disable=SC1090
  source "$lib_dir/required-skills.sh"
fi
DEFAULT_PLANNING="${DEFAULT_PLANNING:-silver-quality-gates silver-context silver-plan}"
DEVOPS_DEFAULT_PLANNING="${DEVOPS_DEFAULT_PLANNING:-silver-blast-radius devops-quality-gates silver-context silver-plan}"

# shellcheck source=lib/skill-discovery.sh
if [[ -f "$lib_dir/skill-discovery.sh" ]]; then
  # shellcheck disable=SC1090
  source "$lib_dir/skill-discovery.sh"
fi
if ! declare -f sb_skill_is_installed >/dev/null 2>&1; then
  sb_skill_is_installed() { return 0; }
fi

# shellcheck source=lib/doc-scheme-gate.sh
if [[ -f "$lib_dir/doc-scheme-gate.sh" ]]; then
  # shellcheck disable=SC1090
  source "$lib_dir/doc-scheme-gate.sh"
fi

# HOOK-04 (informational half): source phase-path.sh for the
# `_phase_lock_peek_on_exit` EXIT-trap helper. EXIT and ERR traps coexist
# in bash — the existing ERR trap (line 40) still fires on errors and
# itself calls exit 0, which then triggers our EXIT trap (preserving
# the rc=0 the ERR trap sets). The peek is non-blocking informational.
# shellcheck source=lib/phase-path.sh
if [[ -f "$lib_dir/phase-path.sh" ]]; then
  # shellcheck disable=SC1091
  source "$lib_dir/phase-path.sh"
  if declare -f _phase_lock_peek_on_exit >/dev/null 2>&1; then
    trap _phase_lock_peek_on_exit EXIT
  fi
fi

# ── Trivial bypass (sourced from shared helper — REF-01) ────────────────────
# Admin session detection (BUG-05): purely administrative sessions (no Write/Edit
# tool calls) are detected via the trivial file, which is created at SessionStart
# and removed on the first Write/Edit PostToolUse. After the BUG-01 SessionStart
# ordering fix, the trivial file reliably survives all hook firings for admin
# sessions, so this bypass correctly exits 0 without any manual user action.
# shellcheck source=lib/trivial-bypass.sh
if [[ -f "$lib_dir/trivial-bypass.sh" ]]; then
  # shellcheck disable=SC1090
  source "$lib_dir/trivial-bypass.sh"
  sb_trivial_bypass "$trivial_file"
fi

# Orchestrator parent mode — parent Stop blocked while flow queue pending; worker SubagentStop clears marker.
  if [[ -f "$lib_dir/orchestrator-parent.sh" ]]; then
  # shellcheck source=lib/orchestrator-parent.sh
  source "$lib_dir/orchestrator-parent.sh"
  if [[ -f "$lib_dir/orchestrator-state.sh" ]]; then
    # shellcheck source=lib/orchestrator-state.sh
    source "$lib_dir/orchestrator-state.sh"
  fi
  if [[ -f "$lib_dir/orchestrator-directive.sh" ]]; then
    # shellcheck source=lib/orchestrator-directive.sh
    source "$lib_dir/orchestrator-directive.sh"
  fi
  if [[ "$stop_hook_event" == "SubagentStop" ]] && sb_orchestrator_is_worker_session 2>/dev/null; then
    sb_orchestrator_clear_worker_marker 2>/dev/null || true
    exit 0
  fi
  _stop_project_root="$(dirname "$config_file")"
  [[ -z "$_stop_project_root" || "$_stop_project_root" == "." ]] && _stop_project_root="$search_dir"
  if sb_orchestrator_is_parent_session 2>/dev/null \
    && sb_orchestrator_state_applies_to_project "$_stop_project_root" 2>/dev/null; then
    cur_flow=""
    orch_file="$(sb_orchestrator_state_file 2>/dev/null || true)"
    [[ -f "$orch_file" ]] && cur_flow="$(jq -r '.current_flow // ""' "$orch_file" 2>/dev/null || true)"
    tmpl=""
    next_skill=""
    directive_file="$(sb_orchestrator_directive_file 2>/dev/null || true)"
    if [[ -n "$directive_file" && -f "$directive_file" ]]; then
      tmpl="$(jq -r '.next_worker_template // ""' "$directive_file" 2>/dev/null || true)"
      next_skill="$(jq -r '.next_skill // ""' "$directive_file" 2>/dev/null || true)"
    fi
    if [[ -z "$next_skill" && -n "$cur_flow" ]]; then
      next_skill="$(sb_orchestrator_flow_to_skill "$cur_flow" 2>/dev/null || true)"
    fi
    parent_reason="Orchestrator parent: flow queue pending (${cur_flow:-unknown}). Spawn Task worker (${tmpl:-WORKER}.md) for /${next_skill:-next-skill} before ending session."
    json_reason=$(printf '%s' "$parent_reason" | jq -Rs '.')
    printf '{"decision":"block","reason":%s}' "$json_reason"
    exit 0
  fi
fi

# L-04: block Stop when autonomous stall flag is set (100+ tool calls, no skill progress).
stall_block_file="${SB_STATE_DIR}/stall-block"
if [[ -f "$stall_block_file" && ! -L "$stall_block_file" ]]; then
  session_start_epoch=""
  if [[ -n "${SILVER_BULLET_SESSION_START_FILE:-}" && -f "${SILVER_BULLET_SESSION_START_FILE}" ]]; then
    session_start_epoch=$(cat "${SILVER_BULLET_SESSION_START_FILE}" 2>/dev/null || true)
  elif [[ -f "${SB_STATE_DIR}/session-start-time" ]]; then
    session_start_epoch=$(cat "${SB_STATE_DIR}/session-start-time" 2>/dev/null || true)
  fi
  stall_mtime=0
  if [[ "$(uname)" == "Darwin" ]]; then
    stall_mtime=$(stat -f %m "$stall_block_file" 2>/dev/null || echo 0)
  else
    stall_mtime=$(stat -c %Y "$stall_block_file" 2>/dev/null || echo 0)
  fi
  if [[ -z "$session_start_epoch" || ! "$session_start_epoch" =~ ^[0-9]+$ || "$stall_mtime" -ge "$session_start_epoch" ]]; then
    stall_count=$(cat "$stall_block_file" 2>/dev/null || echo "100")
    stall_reason="Autonomous stall detected: ${stall_count} tool calls without workflow progress. Invoke the next SB skill before declaring done."
    json_reason=$(printf '%s' "$stall_reason" | jq -Rs '.')
    printf '{"decision":"block","reason":%s}' "$json_reason"
    exit 0
  fi
fi

# ── Detect current git branch ─────────────────────────────────────────────────
current_branch=""
current_branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
# Validate branch name: only allow safe characters
if [[ -n "$current_branch" ]] && ! printf '%s' "$current_branch" | grep -qE '^[a-zA-Z0-9/_.-]+$'; then
  current_branch=""
fi
# ── HOOK-14: Skip enforcement for read-only/conversational sessions ───────────
# Clean tree + no local-only commits ahead of origin → nothing to deploy → skip.
# Untracked files (including .gitignored ones) count as dirty — active work.
# Fail-closed on rev-list/ref-resolution failure (HOOK-06 / #17).
if git -C "$PWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  tree_clean=false
  # `--untracked-files=all` makes porcelain deterministic across user-local
  # git config. Ignored files stay hidden so read-only sessions with only
  # gitignored runtime artifacts can short-circuit cleanly.
  #
  # Filter porcelain output through a transient-path allowlist before deciding
  # `tree_clean`. Defaults are baked-in; projects may override via
  # `.silver-bullet.json`:
  #   { "hooks": { "stop_check": { "transient_path_ignore_patterns": ["..."] } } }
  porcelain=$(git -C "$PWD" status --porcelain --untracked-files=all 2>/dev/null)
  if [[ -n "$porcelain" ]]; then
    # Built-in transient-artifact patterns (extended-grep, anchored to
    # status-line shape `XX path`).
    sb_transient_re="(\.${SB_RUNTIME_NAME}/scheduled_tasks\.lock|\.${SB_RUNTIME_NAME}/settings\.local\.json|\.superpowers/|\.planning/workflows/|REVIEW\.md)"
    # Project-configured additional patterns (newline-separated, ERE-escaped
    # by the user). Resolved via .silver-bullet.json walk-up.
    sb_cfg_search="$PWD"
    sb_cfg=""
    while true; do
      if [[ -f "$sb_cfg_search/.silver-bullet.json" ]]; then
        sb_cfg="$sb_cfg_search/.silver-bullet.json"
        break
      fi
      if [[ -d "$sb_cfg_search/.git" ]] || [[ "$sb_cfg_search" == "/" ]]; then break; fi
      sb_cfg_search=$(dirname "$sb_cfg_search")
    done
    if [[ -n "$sb_cfg" ]] && command -v jq >/dev/null 2>&1; then
      sb_extra=$(jq -r '.hooks.stop_check.transient_path_ignore_patterns // [] | join("|")' "$sb_cfg" 2>/dev/null)
      if [[ -n "$sb_extra" ]]; then
        # Validate: reject overly-broad patterns that match a single printable char.
        # Sentinel is ASCII SOH (\001) — never present in a real file path, so
        # legitimate path-fragment patterns (e.g. REVIEW\.md, \.superpowers/) won't
        # match it, but catch-all patterns (.*, ., [^x]+, etc.) will — #90
        if printf '\001' | grep -qE "$sb_extra" 2>/dev/null; then
          printf '{"hookSpecificOutput":{"message":"⚠️ stop-check: transient_path_ignore_patterns is too broad (matches non-path control char) — ignoring. Fix your .silver-bullet.json."}}'
        else
          sb_transient_re="${sb_transient_re%)}|${sb_extra})"
        fi
      fi
    fi
    # Drop any porcelain line whose path component matches the transient regex.
    # Porcelain format: "XY path" — path starts at column 4. Use awk to extract
    # the path so renames (R/C with " -> ") don't confuse the filter.
    filtered=$(printf '%s\n' "$porcelain" | awk -v re="$sb_transient_re" '
      {
        path = substr($0, 4)
        sub(/^.* -> /, "", path)
        if (path !~ re) print
      }
    ')
    [[ -z "$filtered" ]] && tree_clean=true
  else
    tree_clean=true
  fi

  if [[ "$tree_clean" == true ]]; then
    # Pick a comparison anchor. Only origin/* refs are trusted; local `main`
    # may have been reset by the user and is not a reliable baseline.
    # upstream_broken=true means an upstream is configured for this branch
    # but the ref does not resolve (pruned/renamed remote) — must fail-closed.
    cmp_ref=""
    upstream_broken=false
    if [[ -n "$current_branch" ]] && \
       git -C "$PWD" config --get "branch.${current_branch}.remote" >/dev/null 2>&1; then
      # Branch has an upstream configured in .git/config. Try to resolve it.
      if upstream=$(git -C "$PWD" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) \
         && git -C "$PWD" rev-parse --verify "$upstream" >/dev/null 2>&1; then
        cmp_ref="$upstream"
      else
        upstream_broken=true
      fi
    fi
    if [[ -z "$cmp_ref" ]] && [[ "$upstream_broken" != true ]] && git -C "$PWD" rev-parse --verify origin/main >/dev/null 2>&1; then
      cmp_ref="origin/main"
    fi
    if [[ -z "$cmp_ref" ]] && [[ "$upstream_broken" != true ]] && git -C "$PWD" rev-parse --verify origin/master >/dev/null 2>&1; then
      cmp_ref="origin/master"
    fi

    if [[ "$upstream_broken" == true ]]; then
      # Configured upstream does not resolve (pruned/renamed remote branch).
      # Fail-closed: don't fall back to origin/main or local refs when the
      # user has explicitly scoped the branch to a now-broken upstream.
      :  # fall through to enforcement
    elif [[ -n "$cmp_ref" ]]; then
      # Separate rev-list failure from a legitimate 0-count result: on
      # failure the conditional is false and we fall through to enforcement
      # (fail-closed on unresolvable cmp_ref, HOOK-06 / #17).
      if ahead_count=$(git -C "$PWD" rev-list --count "${cmp_ref}..HEAD" 2>/dev/null); then
        if [[ "$ahead_count" =~ ^[0-9]+$ ]] && (( ahead_count == 0 )); then
          # Clean tree and no local-only commits → nothing to deploy → skip.
          # Fail-open by design: this is the whole point of HOOK-14.
          exit 0
        fi
      fi
      # rev-list failed OR non-numeric output OR ahead_count > 0 →
      # fall through to enforcement (fail-closed).
    elif [[ -n "$current_branch" ]]; then
      # No origin anchor and no configured upstream, but on a named branch
      # with a clean tree. Local `main`/`master` is intentionally NOT used
      # as a fallback anchor — it may have been reset by the user and is
      # not a reliable baseline (HOOK-06 / #17 finding #4). Without a
      # trusted anchor there is nowhere to deploy to, so skip.
      # Fail-open by design: clean tree + no remote target = read-only.
      exit 0
    fi
    # cmp_ref is empty, upstream is not broken, AND current_branch is empty.
    # NOTE: standard detached HEAD returns "HEAD" from git rev-parse --abbrev-ref
    # which is non-empty, so the elif branch above exits 0 for that case.
    # current_branch is empty only when the git command fails outright or the
    # returned ref name fails the safety validation regex (unusual). Without
    # any trusted anchor or valid branch name we cannot prove "nothing to deploy"
    # → fall through to enforcement.
  fi
fi

# ── Read state file ───────────────────────────────────────────────────────────
state_contents=""
[[ -f "$state_file" ]] && state_contents=$(cat "$state_file")

# HOOK-04: empty state file means no skills were tracked — non-dev session.
# Fail-open by design: nothing to gate against.
[[ -z "$state_contents" ]] && exit 0

# Emit block JSON for Stop
emit_stop_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"decision":"block","reason":%s}' "$json_reason"
}

# Platform-aware stat helper: returns file mtime as epoch seconds
_mtime_epoch() {
  local _v
  if [[ "$(uname)" == "Darwin" ]]; then
    _v=$(stat -f %m "$1" 2>/dev/null || true)
  else
    _v=$(stat --format=%Y "$1" 2>/dev/null || true)
  fi
  [[ "$_v" =~ ^[0-9]+$ ]] && printf '%s' "$_v" || printf '0'
}

# shellcheck disable=SC2034
# Resolve a checklist doc key to file state for the current repo/month.
# Inputs:
#   $1 repo root
#   $2 month (YYYY-MM)
#   $3 checklist key
# Outputs (globals):
#   DOC_KEY_LABEL, DOC_KEY_EXISTS (0|1), DOC_KEY_MTIME
resolve_doc_key_state() {
  local repo_root="$1"
  local month="$2"
  local doc_key="$3"
  local full=""
  local f=""
  local m=0

  DOC_KEY_LABEL="$doc_key"
  DOC_KEY_EXISTS=0
  DOC_KEY_MTIME=0

  case "$doc_key" in
    "docs/knowledge/YYYY-MM.md")
      DOC_KEY_LABEL="docs/knowledge/${month}*.md"
      shopt -s nullglob
      for f in "$repo_root/docs/knowledge/${month}"*.md; do
        [[ -f "$f" && ! -L "$f" ]] || continue
        m=$(_mtime_epoch "$f")
        if (( m > DOC_KEY_MTIME )); then
          DOC_KEY_EXISTS=1
          DOC_KEY_MTIME=$m
        fi
      done
      shopt -u nullglob
      ;;
    "docs/learnings/YYYY-MM.md")
      DOC_KEY_LABEL="docs/learnings/${month}*.md"
      shopt -s nullglob
      for f in "$repo_root/docs/learnings/${month}"*.md; do
        [[ -f "$f" && ! -L "$f" ]] || continue
        m=$(_mtime_epoch "$f")
        if (( m > DOC_KEY_MTIME )); then
          DOC_KEY_EXISTS=1
          DOC_KEY_MTIME=$m
        fi
      done
      shopt -u nullglob
      ;;
    *)
      full="$repo_root/$doc_key"
      if [[ -f "$full" && ! -L "$full" ]]; then
        DOC_KEY_EXISTS=1
        DOC_KEY_MTIME=$(_mtime_epoch "$full")
      fi
      ;;
  esac
}

# Build the governed checklist key set:
#   - mandatory every-task keys (with monthly wildcards)
#   - every concrete doc file under docs/ (excluding monthly files represented
#     by wildcard keys and placeholder .gitkeep files)
#   - root README.md / CHANGELOG.md when present
#
# Output (global array):
#   DOC_SCHEME_CHECKLIST_KEYS
build_doc_scheme_checklist_keys() {
  local repo_root="$1"
  local rel=""
  local key=""
  local deduped=()
  local seen=$'\n'

  DOC_SCHEME_CHECKLIST_KEYS=(
    "docs/CHANGELOG.md"
    "docs/knowledge/YYYY-MM.md"
    "docs/learnings/YYYY-MM.md"
  )

  if [[ -d "$repo_root/docs" && ! -L "$repo_root/docs" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      # Monthly docs are represented by wildcard keys above.
      if [[ "$rel" =~ ^docs/knowledge/[0-9]{4}-[0-9]{2}([-.].*)?\.md$ ]]; then
        continue
      fi
      if [[ "$rel" =~ ^docs/learnings/[0-9]{4}-[0-9]{2}([-.].*)?\.md$ ]]; then
        continue
      fi
      # Ignore placeholder files that are not real documentation content.
      if [[ "$rel" == ".gitkeep" || "$rel" == */.gitkeep ]]; then
        continue
      fi
      DOC_SCHEME_CHECKLIST_KEYS+=("$rel")
    done < <(cd "$repo_root" && find docs -type f -print | LC_ALL=C sort)
  fi

  if [[ -f "$repo_root/README.md" && ! -L "$repo_root/README.md" ]]; then
    DOC_SCHEME_CHECKLIST_KEYS+=("README.md")
  fi
  if [[ -f "$repo_root/CHANGELOG.md" && ! -L "$repo_root/CHANGELOG.md" ]]; then
    DOC_SCHEME_CHECKLIST_KEYS+=("CHANGELOG.md")
  fi

  for key in "${DOC_SCHEME_CHECKLIST_KEYS[@]}"; do
    [[ -n "$key" ]] || continue
    if [[ "$seen" == *$'\n'"$key"$'\n'* ]]; then
      continue
    fi
    deduped+=("$key")
    seen+="$key"$'\n'
  done
  DOC_SCHEME_CHECKLIST_KEYS=("${deduped[@]}")
}

# If docs/doc-scheme.md exists, task finalization is hard-blocked until this
# session updates required docs and completes a per-task checklist:
#   - checklist file: docs/task-doc-checklist.json (updated this session)
#   - required-updated entries:
#       docs/CHANGELOG.md
#       docs/knowledge/YYYY-MM.md
#       docs/learnings/YYYY-MM.md
#   - complete checklist coverage for governed docs.
run_doc_scheme_task_gate() {
  local repo_root="$1"
  if declare -f sb_doc_scheme_gate_enforce >/dev/null 2>&1; then
    sb_doc_scheme_gate_enforce "task" "$repo_root" "$SB_STATE_DIR" "emit_stop_block"
  fi
  return 0
}

# ── Branch-scope validation: skip if state is from a different branch ─────────
# State is branch-scoped by session-start. If the branch file and current branch
# diverge (session-start didn't run, ran on a different context, or a concurrent
# session overwrote the file), the state is stale — enforcing against it would
# block legitimate work on a different branch with another branch's skill history.
# Fail-open by design: stale cross-branch state should never block the current branch.
sb_branch_file="${SILVER_BULLET_BRANCH_FILE:-${SB_STATE_DIR}/branch}"
# Security: validate path stays within the host runtime state root (mirrors session-start pattern)
if ! sb_runtime_path_is_state_scoped "$sb_branch_file"; then
  sb_branch_file="${SB_STATE_DIR}/branch"
fi
stored_state_branch=""
stored_state_toplevel=""
current_git_toplevel=""
current_git_toplevel=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)
if [[ -f "$_lib_dir/branch-scope.sh" ]]; then
  # shellcheck source=lib/branch-scope.sh
  source "$_lib_dir/branch-scope.sh"
fi
if declare -f sb_branch_scope_read >/dev/null 2>&1 && sb_branch_scope_read "$sb_branch_file"; then
  stored_state_branch="$SB_BRANCH_SCOPE_STORED_BRANCH"
  stored_state_toplevel="$SB_BRANCH_SCOPE_STORED_TOPLEVEL"
elif [[ -f "$sb_branch_file" && ! -L "$sb_branch_file" ]]; then
  stored_state_branch=$(head -1 "$sb_branch_file" 2>/dev/null | tr -d '\n' || true)
fi
# M-04: branch / worktree mismatch — warn visibly instead of silent fail-open.
if declare -f sb_branch_scope_mismatch >/dev/null 2>&1; then
  if sb_branch_scope_mismatch "$current_branch" "$current_git_toplevel"; then
    warn_msg="⚠️ Silver Bullet: skill state is from branch '${stored_state_branch}' (worktree ${stored_state_toplevel:-unknown}) but current scope is '${current_branch}' (${current_git_toplevel:-unknown}). Run a fresh session-start on this worktree before declaring done."
    json_warn=$(printf '%s' "$warn_msg" | jq -Rs '.')
    printf '{"decision":"block","reason":%s}' "$json_warn"
    exit 0
  fi
elif [[ -n "$stored_state_branch" && -n "$current_branch" && \
      "$stored_state_branch" != "$current_branch" ]]; then
  warn_msg="⚠️ Silver Bullet: skill state is from branch '${stored_state_branch}' but current branch is '${current_branch}'. Run a fresh session-start on this branch before declaring done."
  json_warn=$(printf '%s' "$warn_msg" | jq -Rs '.')
  printf '{"decision":"block","reason":%s}' "$json_warn"
  exit 0
fi

# v0.30.0 fix (#85): the Stop hook is the conversation-end gate, NOT the
# delivery gate. Per CLAUDE.md's two-tier model, the full required_deploy
# list is enforced by completion-audit.sh on actual delivery commands
# (gh pr create / gh release create / deploy). Applying it on every Stop
# event blocks ad-hoc additions that don't warrant a milestone-ship
# checklist (deploy-checklist for a skill file, silver-create-release per commit,
# etc.). Stop-tier enforcement now applies the planning floor only —
# typically just `silver-quality-gates` (and its devops substitute).
#
# Order of precedence:
#   1. .silver-bullet.json `skills.required_planning` (project override)
#   2. Library-derived planning floor (silver-quality-gates / devops pair)
#   3. Hardcoded fallback for installs missing the lib
if [[ "$active_workflow" == "devops-cycle" ]]; then
  default_planning="$DEVOPS_DEFAULT_PLANNING"
else
  default_planning="$DEFAULT_PLANNING"
fi
if [[ "$active_workflow" == "devops-cycle" && -n "$required_planning_devops_cfg" ]]; then
  configured_planning="$required_planning_devops_cfg"
else
  configured_planning="$required_planning_cfg"
fi
if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
  all_skills="$(sb_required_skills_normalize_configured_list "$config_file" "$configured_planning" "$default_planning")"
elif [[ -n "$configured_planning" ]]; then
  all_skills="$configured_planning"
else
  all_skills="$default_planning"
fi

# Deduplicate
required_skills=""
for skill in $all_skills; do
  already=false
  for existing in $required_skills; do
    if [[ "$existing" == "$skill" ]]; then
      already=true
      break
    fi
  done
  if [[ "$already" == false ]]; then
    required_skills="${required_skills:+$required_skills }$skill"
  fi
done

# ── Check required skills ─────────────────────────────────────────────────────
missing=""
uninstalled=""
for skill in $required_skills; do
  if declare -F sb_required_skill_is_recorded >/dev/null 2>&1; then
    skill_recorded=false
    if sb_required_skill_is_recorded "$state_contents" "$skill"; then
      skill_recorded=true
    fi
  elif printf '%s\n' "$state_contents" | grep -Fqx -- "$skill" 2>/dev/null; then
    skill_recorded=true
  else
    skill_recorded=false
  fi

  if [[ "$skill_recorded" != true ]]; then
    if sb_skill_is_installed "$skill"; then
      missing="${missing:+$missing }$skill"
    else
      uninstalled="${uninstalled:+$uninstalled }$skill"
    fi
  fi
done

# ── Output result ─────────────────────────────────────────────────────────────
if [[ -n "$missing" ]]; then
  missing_lines=""
  for skill in $missing; do
    missing_lines="${missing_lines}  - ${skill}\n"
  done
  reason=$(printf 'Cannot complete -- missing required skills:\n%s\nRun these skills before declaring task complete.' "$missing_lines")
  if [[ -n "$uninstalled" ]]; then
    unavailable_lines=""
    for skill in $uninstalled; do
      unavailable_lines="${unavailable_lines}  - ${skill}\n"
    done
    reason=$(printf '%s\n\nThese required skills are not installed anywhere invocable and were ignored:\n%s\nInstall them if you want them enforced.' "$reason" "$unavailable_lines")
  fi
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"decision":"block","reason":%s}' "$json_reason"
elif [[ -n "$uninstalled" ]]; then
  run_doc_scheme_task_gate "$search_dir"
  unavailable_lines=""
  for skill in $uninstalled; do
    unavailable_lines="${unavailable_lines}  - ${skill}\n"
  done
  reason=$(printf '⚠️  Some required skills are not installed anywhere invocable and were ignored:\n%s\nInstall them if you want them enforced.' "$unavailable_lines")
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"message":%s}}' "$json_reason"
else
  run_doc_scheme_task_gate "$search_dir"
fi

exit 0
