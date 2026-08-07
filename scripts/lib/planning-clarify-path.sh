#!/usr/bin/env bash
# Resolve /silver:clarify output paths under .planning/
#
# Canonical pattern:
#   .planning/{plan-basename}-CLARIFY-{YYMMDD}-{timestamp}.md
#
# - plan-basename: basename of input plan file without extension
# - YYMMDD:        UTC date (e.g. 260716)
# - timestamp:     compact UTC instant (YYYYMMDDTHHMMSSZ) — matches .planning run dirs
#
# Usage:
#   source scripts/lib/planning-clarify-path.sh
#   sb_planning_clarify_output_path "$repo_root" "$plan_file_path"
#   sb_planning_clarify_output_path "$repo_root" "" "my-topic-slug"
set -euo pipefail

# Emit plan doc basename (no extension) from a plan file path.
sb_planning_clarify_plan_basename() {
  local plan_path="${1:-}"
  local base
  [[ -n "$plan_path" ]] || return 1
  base="$(basename "$plan_path")"
  base="${base%.plan.md}"
  base="${base%.md}"
  [[ -n "$base" ]] || return 1
  printf '%s\n' "$base"
}

# Slugify a free-text topic for clarify output when no plan file is provided.
sb_planning_clarify_slugify_topic() {
  local topic="${1:-}"
  local slug
  [[ -n "$topic" ]] || return 1
  slug="$(printf '%s' "$topic" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g; s/-{2,}/-/g')"
  [[ -n "$slug" ]] || return 1
  printf '%s\n' "$slug"
}

# Resolve basename segment for clarify filename.
sb_planning_clarify_basename_segment() {
  local plan_path="${1:-}" topic_slug="${2:-}"
  local base
  if [[ -n "$plan_path" ]]; then
    base="$(sb_planning_clarify_plan_basename "$plan_path" 2>/dev/null || true)"
  fi
  if [[ -z "${base:-}" && -n "$topic_slug" ]]; then
    base="$(sb_planning_clarify_slugify_topic "$topic_slug" 2>/dev/null || true)"
  fi
  if [[ -z "${base:-}" ]]; then
    base="clarify-session"
  fi
  printf '%s\n' "$base"
}

# Compact UTC timestamp (YYYYMMDDTHHMMSSZ).
sb_planning_clarify_timestamp() {
  date -u '+%Y%m%dT%H%M%SZ'
}

# YYMMDD date component.
sb_planning_clarify_yymmdd() {
  date -u '+%y%m%d'
}

# Relative path under repo root, e.g. .planning/foo-CLARIFY-260716-20260716T011730Z.md
sb_planning_clarify_output_relpath() {
  local plan_path="${1:-}" topic_slug="${2:-}" ts="${3:-}" ymd="${4:-}"
  local base segment
  base="$(sb_planning_clarify_basename_segment "$plan_path" "$topic_slug")"
  ts="${ts:-$(sb_planning_clarify_timestamp)}"
  ymd="${ymd:-$(sb_planning_clarify_yymmdd)}"
  printf '.planning/%s-CLARIFY-%s-%s.md' "$base" "$ymd" "$ts"
}

# Absolute clarify output path.
sb_planning_clarify_output_path() {
  local repo_root="$1" plan_path="${2:-}" topic_slug="${3:-}" ts="${4:-}" ymd="${5:-}"
  local rel
  rel="$(sb_planning_clarify_output_relpath "$plan_path" "$topic_slug" "$ts" "$ymd")"
  printf '%s/%s' "$repo_root" "$rel"
}

# True when filename matches *-CLARIFY-{YYMMDD}-{timestamp}.md
sb_planning_clarify_filename_matches() {
  local name="$1"
  [[ "$name" =~ -CLARIFY-[0-9]{6}-[0-9]{8}T[0-9]{6}Z\.md$ ]]
}

# Print newest clarify doc path under .planning (legacy CLARIFY.md or new pattern).
sb_planning_find_newest_clarify_doc() {
  local work_dir="$1"
  local planning="${work_dir}/.planning"
  local newest="" candidate mtime best=0 cur
  [[ -d "$planning" ]] || return 1

  if [[ -f "${planning}/CLARIFY.md" ]]; then
    newest="${planning}/CLARIFY.md"
    best="$(stat -f '%m' "$newest" 2>/dev/null || stat -c '%Y' "$newest" 2>/dev/null || echo 0)"
    [[ "$best" =~ ^[0-9]+$ ]] || best=0
  fi

  shopt -s nullglob
  for candidate in "${planning}"/*-CLARIFY-*-*.md; do
    [[ -f "$candidate" ]] || continue
    [[ "$(basename "$candidate")" == "CLARIFY.md" ]] && continue
    if sb_planning_clarify_filename_matches "$(basename "$candidate")"; then
      cur="$(stat -f '%m' "$candidate" 2>/dev/null || stat -c '%Y' "$candidate" 2>/dev/null || echo 0)"
      [[ "$cur" =~ ^[0-9]+$ ]] || cur=0
      if [[ "$cur" -ge "$best" ]]; then
        best="$cur"
        newest="$candidate"
      fi
    fi
  done
  shopt -u nullglob

  [[ -n "$newest" ]] || return 1
  printf '%s\n' "$newest"
}

# True when clarify doc contains locked decision evidence.
sb_planning_clarify_doc_has_locked_decisions() {
  local clarify_doc="$1"
  [[ -f "$clarify_doc" ]] || return 1
  grep -qiE 'locked|decision_class' "$clarify_doc" 2>/dev/null
}
