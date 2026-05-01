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

# jq is required — warn visibly if missing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️  ENFORCEMENT INACTIVE — jq not installed. Install it: brew install jq (macOS) / apt install jq (Linux). All Silver Bullet enforcement hooks are disabled until jq is available."}}'
  # Fail-open by design: without jq we cannot parse config; print a visible
  # warning so the user knows enforcement is off.
  exit 0
fi

# Read JSON from stdin (consumed per hook protocol; content not used by stop-check)
cat >/dev/null

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
# Intentionally overrides the silent ERR trap set at line 3 — this hook
# emits a visible warning rather than failing open silently, so the user
# knows something unexpected occurred rather than seeing a clean block/allow.
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️  stop-check.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

# ── Resolve config file by walking up from $PWD ──────────────────────────────
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]]; then
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

# ── Read config values ────────────────────────────────────────────────────────
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_STATE_DIR"

sb_default_state="${SB_STATE_DIR}/state"
sb_default_trivial="${SB_STATE_DIR}/trivial"
config_vals=$(jq -r --arg ds "$sb_default_state" --arg dt "$sb_default_trivial" '[
  (.state.state_file // $ds),
  (.state.trivial_file // $dt),
  ((.skills.required_deploy // []) | join(" ")),
  (.project.active_workflow // "full-dev-cycle"),
  ((.skills.required_planning // []) | join(" "))
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
state_file="${state_file/#\~/$HOME}"
trivial_file=$(printf '%s' "$config_vals" | sed -n '2p')
trivial_file="${trivial_file/#\~/$HOME}"
active_workflow=$(printf '%s' "$config_vals" | sed -n '4p')
required_planning_cfg=$(printf '%s' "$config_vals" | sed -n '5p')

# Env var override for state file
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"

# Security: validate paths stay within ~/.claude/ (SB-002/SB-003)
case "$state_file" in
  "$HOME"/.claude/*) ;;
  *) state_file="${SB_STATE_DIR}/state" ;;
esac
case "$trivial_file" in
  "$HOME"/.claude/*) ;;
  *) trivial_file="${SB_STATE_DIR}/trivial" ;;
esac

# ── Resolve lib dir (needed for trivial-bypass and required-skills helpers) ───
lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"

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
  # --untracked-files=all + --ignored=traditional: ignore user-local
  # status.showUntrackedFiles, honor all untracked paths (including
  # .gitignored locations — a session may only touch .claude/ which is
  # commonly gitignored and would otherwise be invisible to porcelain).
  #
  # v0.30.0 fix (#88): the --ignored=traditional widening over-catches
  # routine session/runtime artifacts (`.claude/scheduled_tasks.lock`,
  # `.claude/settings.local.json`, `.superpowers/**`, `.planning/workflows/**`,
  # gitignored REVIEW.md), causing the Stop hook to loop indefinitely after
  # legitimate releases. Filter porcelain output through a transient-path
  # allowlist before deciding `tree_clean`. Defaults are baked-in; projects
  # may override via `.silver-bullet.json`:
  #   { "hooks": { "stop_check": { "transient_path_ignore_patterns": ["..."] } } }
  porcelain=$(git -C "$PWD" status --porcelain --untracked-files=all --ignored=traditional 2>/dev/null)
  if [[ -n "$porcelain" ]]; then
    # Built-in transient-artifact patterns (extended-grep, anchored to
    # status-line shape `XX path`).
    sb_transient_re='(\.claude/scheduled_tasks\.lock|\.claude/settings\.local\.json|\.superpowers/|\.planning/workflows/|REVIEW\.md)'
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

# ── Branch-scope validation: skip if state is from a different branch ─────────
# State is branch-scoped by session-start. If the branch file and current branch
# diverge (session-start didn't run, ran on a different context, or a concurrent
# session overwrote the file), the state is stale — enforcing against it would
# block legitimate work on a different branch with another branch's skill history.
# Fail-open by design: stale cross-branch state should never block the current branch.
sb_branch_file="${SILVER_BULLET_BRANCH_FILE:-${SB_STATE_DIR}/branch}"
# Security: validate path stays within ~/.claude/ (mirrors session-start pattern)
case "$sb_branch_file" in
  "$HOME"/.claude/*) ;;
  *) sb_branch_file="${SB_STATE_DIR}/branch" ;;
esac
stored_state_branch=""
if [[ -f "$sb_branch_file" && ! -L "$sb_branch_file" ]]; then
  stored_state_branch=$(head -1 "$sb_branch_file" 2>/dev/null | tr -d '\n' || true)
fi
if [[ -n "$stored_state_branch" && -n "$current_branch" && \
      "$stored_state_branch" != "$current_branch" ]]; then
  exit 0
fi

# v0.30.0 fix (#85): the Stop hook is the conversation-end gate, NOT the
# delivery gate. Per CLAUDE.md's two-tier model, the full required_deploy
# list is enforced by completion-audit.sh on actual delivery commands
# (gh pr create / gh release create / deploy). Applying it on every Stop
# event blocks ad-hoc additions that don't warrant a milestone-ship
# checklist (deploy-checklist for a skill file, create-release per commit,
# etc.). Stop-tier enforcement now applies the planning floor only —
# typically just `silver-quality-gates` (and its devops substitute).
#
# Order of precedence:
#   1. .silver-bullet.json `skills.required_planning` (project override)
#   2. Library-derived planning floor (silver-quality-gates / devops pair)
#   3. Hardcoded fallback for installs missing the lib
if [[ "$active_workflow" == "devops-cycle" ]]; then
  default_planning="silver-blast-radius devops-quality-gates"
else
  default_planning="silver-quality-gates"
fi
if [[ -n "$required_planning_cfg" ]]; then
  all_skills="$required_planning_cfg"
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
for skill in $required_skills; do
  if ! printf '%s\n' "$state_contents" | grep -qx "$skill" 2>/dev/null; then
    missing="${missing:+$missing }$skill"
  fi
done

# ── Output result ─────────────────────────────────────────────────────────────
if [[ -n "$missing" ]]; then
  missing_lines=""
  for skill in $missing; do
    missing_lines="${missing_lines}  - ${skill}\n"
  done
  reason=$(printf 'Cannot complete -- missing required skills:\n%s\nRun these skills before declaring task complete.' "$missing_lines")
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"decision":"block","reason":%s}' "$json_reason"
fi

exit 0
