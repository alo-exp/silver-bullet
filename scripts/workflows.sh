#!/usr/bin/env bash
# scripts/workflows.sh — Composed-workflow lifecycle helper (Pass 2).
#
# Tracks active composed workflows (one per `silver:*` composition) as
# per-instance markdown files under `.planning/workflows/<id>.md`. Each file
# is created on `start`, mutated on `complete-flow`, and deleted on `complete`.
#
# This replaces the v0.22.0 single-file `.planning/WORKFLOW.md` model. The
# legacy file was retired in v0.29.0 (Pass 1 hotfix) because a stale
# milestone WORKFLOW.md left on disk silently bypassed the final-delivery
# enforcement gate. Per-instance files plus strict ID-matched gating fix
# that leak.
#
# Operations:
#   start <composer> [intent] [flow1,flow2,...]   → prints WORKFLOW_ID
#   heartbeat <id>                                 → touch mtime
#   complete-flow <id> <flow-name>                 → mark a flow row complete
#   complete <id>                                  → archive + delete file
#   list                                           → print active workflow IDs
#   get <id>                                       → print workflow file path
#   active                                         → print path of single
#                                                    active workflow if exactly
#                                                    one exists, else fail
#
# ID scheme: <UTC-compact>-<6char-base32>-<composer>
#   e.g. 20260428T120000Z-7a9bcd-silver-feature
#
# Invariants:
# - Files live under `<repo>/.planning/workflows/<id>.md`.
# - Directory is gitignored (added to .gitignore by the v0.29.1 release).
# - Workflow files are purely local; no external state.
# - `complete` archives the file to `.planning/workflows/.archive/<id>.md`
#   for postmortem reference (kept lightweight; not gitignored).
# - Atomic-write pattern via tmpfile + mv.

set -euo pipefail
trap 'exit 1' ERR

# ── Resolve repo root (walk up looking for .planning/ or .git/) ──────────────
_resolve_repo_root() {
  local d="$PWD"
  while [[ "$d" != "/" && -n "$d" ]]; do
    if [[ -d "$d/.planning" || -d "$d/.git" ]]; then
      printf '%s' "$d"
      return 0
    fi
    d=$(dirname "$d")
  done
  return 1
}

REPO_ROOT=$(_resolve_repo_root || true)
if [[ -z "$REPO_ROOT" ]]; then
  printf 'workflows.sh: not inside a repo (no .planning/ or .git/ found)\n' >&2
  exit 1
fi

WORKFLOWS_DIR="$REPO_ROOT/.planning/workflows"
ARCHIVE_DIR="$WORKFLOWS_DIR/.archive"

# ── Helpers ──────────────────────────────────────────────────────────────────
_iso_utc()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
_compact()  { date -u +%Y%m%dT%H%M%SZ; }

# 6-char lowercase base32-ish suffix from /dev/urandom
_rand_suffix() {
  # Use head -c on /dev/urandom + base32 if available, fall back to hexdump.
  if command -v base32 >/dev/null 2>&1; then
    head -c 12 /dev/urandom 2>/dev/null | base32 2>/dev/null \
      | tr -d '=' | tr '[:upper:]' '[:lower:]' | head -c 6
  else
    head -c 4 /dev/urandom 2>/dev/null \
      | od -An -tx1 | tr -d ' \n' | head -c 6
  fi
}

# Sanitize composer slug (allow lowercase alnum, dash, colon → dash)
_sanitize_composer() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ':/' '--' \
    | tr -c 'a-z0-9-' '-' | sed 's/--*/-/g; s/^-//; s/-$//'
}

# Validate workflow id (letters/digits/dash, must start with date-prefix)
_valid_id() {
  [[ "$1" =~ ^[0-9]{8}T[0-9]{6}Z-[a-z0-9]+-[a-z0-9-]+$ ]]
}

# Resolve workflow file path from id; bail if invalid or missing.
_workflow_file() {
  local id="$1"
  if ! _valid_id "$id"; then
    printf 'workflows.sh: invalid workflow id: %s\n' "$id" >&2
    return 1
  fi
  local f="$WORKFLOWS_DIR/$id.md"
  if [[ ! -f "$f" || -L "$f" ]]; then
    printf 'workflows.sh: workflow not found: %s\n' "$id" >&2
    return 1
  fi
  printf '%s' "$f"
}

# Atomic write: write content to file via tmpfile + mv.
_atomic_write() {
  local target="$1"
  local content="$2"
  local tmp
  tmp=$(mktemp "${target}.XXXXXX")
  printf '%s' "$content" > "$tmp"
  mv -f "$tmp" "$target"
}

# ── Operations ───────────────────────────────────────────────────────────────

cmd_start() {
  local composer="${1:-}"
  local intent="${2:-}"
  local flows_csv="${3:-}"

  if [[ -z "$composer" ]]; then
    printf 'usage: workflows.sh start <composer> [intent] [flow1,flow2,...]\n' >&2
    return 1
  fi

  local composer_slug
  composer_slug=$(_sanitize_composer "$composer")
  [[ -z "$composer_slug" ]] && { printf 'workflows.sh: invalid composer name\n' >&2; return 1; }

  local id
  id="$(_compact)-$(_rand_suffix)-$composer_slug"
  if ! _valid_id "$id"; then
    printf 'workflows.sh: failed to generate valid id (%s)\n' "$id" >&2
    return 1
  fi

  umask 0077
  mkdir -p "$WORKFLOWS_DIR"
  local file="$WORKFLOWS_DIR/$id.md"

  # Build flow log table rows (one row per flow if provided).
  local flow_rows=""
  local n=1
  if [[ -n "$flows_csv" ]]; then
    local IFS=','
    for flow in $flows_csv; do
      flow=$(printf '%s' "$flow" | tr -d ' ')
      [[ -z "$flow" ]] && continue
      flow_rows+=$'| '"$n"$' | '"$flow"$' | pending | - | - |\n'
      n=$((n + 1))
    done
  fi
  if [[ -z "$flow_rows" ]]; then
    flow_rows='| 1 | (unspecified) | pending | - | - |'$'\n'
  fi

  local now
  now=$(_iso_utc)

  local body
  body=$(cat <<EOF
---
workflow_id: $id
composer: $composer
started_at: $now
status: active
intent: ${intent:-(none)}
---

# Workflow $id

**Composer:** $composer
**Started:** $now
**Intent:** ${intent:-(none)}

## Flow Log

| # | Path/Skill | Status | Started | Completed |
|---|------------|--------|---------|-----------|
$flow_rows
EOF
)

  _atomic_write "$file" "$body"
  printf '%s\n' "$id"
}

cmd_heartbeat() {
  local id="${1:-}"
  local f
  f=$(_workflow_file "$id") || return 1
  touch "$f"
}

cmd_complete_flow() {
  local id="${1:-}"
  local flow="${2:-}"
  if [[ -z "$id" || -z "$flow" ]]; then
    printf 'usage: workflows.sh complete-flow <id> <flow-name>\n' >&2
    return 1
  fi
  local f
  f=$(_workflow_file "$id") || return 1

  # Reject symlinks — never write through a symlink (SEC-02 pattern).
  if [[ -L "$f" ]]; then
    printf 'workflows.sh: refusing to write through symlink: %s\n' "$f" >&2
    return 1
  fi

  local now
  now=$(_iso_utc)

  # Update the matching flow row: change `pending` → `complete`, fill completed-at.
  # awk-based mutation for portability. Match on the second column equal to flow.
  local tmp
  tmp=$(mktemp "${f}.XXXXXX")
  awk -v flow="$flow" -v now="$now" '
    BEGIN { FS = "|"; OFS = "|" }
    /^\| [0-9]+ \|/ {
      # Column 3 is the path/skill (after the leading empty + numeric col).
      name = $3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == flow) {
        # Replace status column 4 → " complete " and completed col 6 → " <now> "
        sub(/\| pending \| - \| - \|$/, "| complete | - | " now " |", $0)
        # Also handle cases where started has been set but completed is still "-"
        sub(/\| (pending|in-progress) \| ([^|]+) \| - \|$/, "| complete | \\2 | " now " |", $0)
      }
      print
      next
    }
    { print }
  ' "$f" > "$tmp"
  mv -f "$tmp" "$f"
}

cmd_complete() {
  local id="${1:-}"
  local f
  f=$(_workflow_file "$id") || return 1

  local now
  now=$(_iso_utc)

  # Update frontmatter `status: active` → `status: complete` and add completed_at.
  local tmp
  tmp=$(mktemp "${f}.XXXXXX")
  awk -v now="$now" '
    BEGIN { in_fm = 0; fm_count = 0; status_done = 0 }
    /^---$/ {
      fm_count++
      if (fm_count == 1) { in_fm = 1; print; next }
      if (fm_count == 2) {
        in_fm = 0
        if (!status_done) print "completed_at: " now
        print
        next
      }
    }
    in_fm && /^status:/ {
      print "status: complete"
      print "completed_at: " now
      status_done = 1
      next
    }
    { print }
  ' "$f" > "$tmp"
  mv -f "$tmp" "$f"

  # Archive then delete from active dir.
  mkdir -p "$ARCHIVE_DIR"
  mv -f "$f" "$ARCHIVE_DIR/$id.md"
}

cmd_list() {
  if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    return 0
  fi
  shopt -s nullglob
  for wf in "$WORKFLOWS_DIR"/*.md; do
    [[ -f "$wf" ]] || continue
    basename "$wf" .md
  done
  shopt -u nullglob
}

cmd_get() {
  local id="${1:-}"
  _workflow_file "$id"
}

cmd_active() {
  if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    printf 'workflows.sh: no active workflows\n' >&2
    return 1
  fi
  local count=0
  local single=""
  shopt -s nullglob
  for wf in "$WORKFLOWS_DIR"/*.md; do
    [[ -f "$wf" ]] || continue
    count=$((count + 1))
    single="$wf"
  done
  shopt -u nullglob
  if [[ "$count" -eq 0 ]]; then
    printf 'workflows.sh: no active workflows\n' >&2
    return 1
  elif [[ "$count" -gt 1 ]]; then
    printf 'workflows.sh: multiple active workflows; pass id explicitly\n' >&2
    return 1
  fi
  printf '%s\n' "$single"
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "${1:-}" in
  start)         shift; cmd_start "$@" ;;
  heartbeat)     shift; cmd_heartbeat "$@" ;;
  complete-flow) shift; cmd_complete_flow "$@" ;;
  complete)      shift; cmd_complete "$@" ;;
  list)          shift; cmd_list "$@" ;;
  get)           shift; cmd_get "$@" ;;
  active)        shift; cmd_active "$@" ;;
  ""|-h|--help)
    cat <<EOF
workflows.sh — composed-workflow lifecycle helper

  start <composer> [intent] [flow1,flow2,...]   → prints WORKFLOW_ID
  heartbeat <id>
  complete-flow <id> <flow-name>
  complete <id>                                 → archives + removes from active
  list                                           → active workflow ids
  get <id>                                       → workflow file path
  active                                         → path of single active workflow

ID scheme: <UTC-compact>-<6char>-<composer>
EOF
    ;;
  *)
    printf 'workflows.sh: unknown command: %s\n' "$1" >&2
    exit 1
    ;;
esac
