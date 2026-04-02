#!/usr/bin/env bash
# Semantic context assembler. Bash 3.2+ compatible (no mapfile, no declare -A, no local -n).
# Reads .silver-bullet.json, extracts phase goal, globs source + doc files,
# runs TF-IDF ranking (source prioritised over docs), and outputs
# hookSpecificOutput.additionalContext JSON.
set -euo pipefail

# Locate repo root by walking up to .silver-bullet.json
find_config_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/.silver-bullet.json" ]] && { printf '%s' "$dir"; return; }
    dir=$(dirname "$dir")
  done
  printf ''
}

REPO_ROOT="${REPO_ROOT:-$(find_config_root)}"
[[ -z "$REPO_ROOT" ]] && exit 0
CONFIG="$REPO_ROOT/.silver-bullet.json"
[[ -f "$CONFIG" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Read config
enabled=$(jq -r 'if .semantic_compression.enabled == false then "false" else "true" end' "$CONFIG")
if [[ "$enabled" == "false" ]]; then exit 0; fi

budget_kb=$(jq -r '.semantic_compression.context_budget_kb // 50' "$CONFIG")
min_bytes=$(jq -r '.semantic_compression.min_file_size_bytes // 3072' "$CONFIG")
top_n=$(jq -r '.semantic_compression.top_chunks_per_file // 3' "$CONFIG")
debug=$(jq -r '.semantic_compression.debug // false' "$CONFIG")
src_pattern=$(jq -r '.project.src_pattern // "/src/"' "$CONFIG")
exclude_pattern=$(jq -r '.project.src_exclude_pattern // "__tests__|\\.test\\."' "$CONFIG")
export SB_CHUNK_BYTES; SB_CHUNK_BYTES=$(jq -r '.semantic_compression.chunk_size_bytes // 1024' "$CONFIG")

budget_bytes=$(( budget_kb * 1024 ))
cache_dir="$REPO_ROOT/.planning/.context-cache"
debug_log="$cache_dir/debug.log"

SCRIPTS_DIR="${SCRIPTS_DIR_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Portable md5
md5_str() {
  local input="$1"
  local tmp; tmp=$(mktemp)
  printf '%s' "$input" > "$tmp"
  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$tmp" 2>/dev/null || md5 "$tmp" 2>/dev/null | awk '{print $NF}'
  else
    md5sum "$tmp" 2>/dev/null | awk '{print $1}'
  fi
  rm -f "$tmp"
}

# Portable stat: file size
file_size() {
  stat -f '%z' "$1" 2>/dev/null || stat -c '%s' "$1" 2>/dev/null || echo "0"
}

# Portable stat: mtime
file_mtime() {
  stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1" 2>/dev/null || echo "0"
}

# Get phase goal — extract-phase-goal.sh uses .planning/ relative to CWD
phase_goal=""
if [[ -d "$REPO_ROOT/.planning" ]]; then
  phase_goal=$(cd "$REPO_ROOT" && "$SCRIPTS_DIR/extract-phase-goal.sh" 2>/dev/null || true)
fi

# If goal is empty AND no planning files exist (dir exists but empty), exit cleanly
if [[ -z "${phase_goal:-}" ]]; then
  planning_files=$(ls "$REPO_ROOT/.planning/"*-CONTEXT.md "$REPO_ROOT/.planning/"*-RESEARCH.md "$REPO_ROOT/.planning/"*-PLAN.md 2>/dev/null | head -1 || true)
  [[ -z "$planning_files" ]] && exit 0
fi

# Build file lists (no mapfile — bash 3.2 compatible)
src_root="$REPO_ROOT${src_pattern%/}"
TEXT_SRC=()
if [[ -d "$src_root" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    mime=$(file --mime-type -b "$f" 2>/dev/null || echo "application/octet-stream")
    [[ "$mime" == text/* ]] && TEXT_SRC+=("$f")
  done < <(find "$src_root" -type f 2>/dev/null | grep -Ev "$exclude_pattern" || true)
fi

TEXT_DOC=()
if [[ -d "$REPO_ROOT/docs" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    mime=$(file --mime-type -b "$f" 2>/dev/null || echo "application/octet-stream")
    [[ "$mime" == text/* ]] && TEXT_DOC+=("$f")
  done < <(find "$REPO_ROOT/docs" -name '*.md' -type f 2>/dev/null || true)
fi

[[ ${#TEXT_SRC[@]} -eq 0 && ${#TEXT_DOC[@]} -eq 0 ]] && exit 0

mkdir -p "$cache_dir"

# Cache key from file mtimes + phase goal
mtime_str=""
for f in "${TEXT_SRC[@]+"${TEXT_SRC[@]}"}" "${TEXT_DOC[@]+"${TEXT_DOC[@]}"}"; do
  mtime_str+=$(file_mtime "$f")
done
cache_key=$(md5_str "${mtime_str}${phase_goal}")
phase_slug=$(printf '%s' "${phase_goal:-nogoal}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | cut -c1-40)
cache_file="$cache_dir/${phase_slug}-${cache_key}.json"

if [[ -f "$cache_file" ]]; then
  cat "$cache_file"
  exit 0
fi

if [[ "$debug" == "true" ]]; then printf '[semantic-compress] phase: %s\n  src: %d, doc: %d\n' \
  "${phase_goal:-empty}" "${#TEXT_SRC[@]}" "${#TEXT_DOC[@]}" >> "$debug_log"; fi

# Partition files by size — inline loops (no partition_files function, no local -n)
SMALL_SRC=(); LARGE_SRC=()
for f in "${TEXT_SRC[@]+"${TEXT_SRC[@]}"}"; do
  sz=$(file_size "$f")
  if [[ $sz -le $min_bytes ]]; then SMALL_SRC+=("$f"); else LARGE_SRC+=("$f"); fi
done

SMALL_DOC=(); LARGE_DOC=()
for f in "${TEXT_DOC[@]+"${TEXT_DOC[@]}"}"; do
  sz=$(file_size "$f")
  if [[ $sz -le $min_bytes ]]; then SMALL_DOC+=("$f"); else LARGE_DOC+=("$f"); fi
done

# Budget tracking
output=""
used_bytes=0

add_block() {
  local rel="$1" content="$2" label="${3:-}"
  local block
  block=$(printf '### %s%s\n```\n%s\n```\n' "$rel" "${label:+ ($label)}" "$content")
  local block_bytes=${#block}
  if (( used_bytes + block_bytes <= budget_bytes )); then
    output+="$block"
    (( used_bytes += block_bytes )) || true
    return 0
  fi
  return 1
}

# Small source files in full (source first — priority over docs)
for f in "${SMALL_SRC[@]+"${SMALL_SRC[@]}"}"; do
  rel="${f#$REPO_ROOT/}"
  content=$(cat "$f")
  add_block "$rel" "$content" || break
done

# Small doc files in full
for f in "${SMALL_DOC[@]+"${SMALL_DOC[@]}"}"; do
  rel="${f#$REPO_ROOT/}"
  content=$(cat "$f")
  add_block "$rel" "$content" || break
done

# Score and add large files using temp-file counter (no declare -A)
score_and_add() {
  local query="$1"; shift
  local files=("$@")
  [[ ${#files[@]} -eq 0 ]] && return

  local TMP_COUNTS; TMP_COUNTS=$(mktemp)
  trap 'rm -f "$TMP_COUNTS"' RETURN

  local scored_line
  while IFS= read -r scored_line; do
    local score file start end chunk_text
    score=$(printf '%s' "$scored_line" | cut -f1)
    file=$(printf '%s' "$scored_line" | cut -f2)
    start=$(printf '%s' "$scored_line" | cut -f3)
    end=$(printf '%s' "$scored_line" | cut -f4)
    chunk_text=$(printf '%s' "$scored_line" | cut -f5-)
    chunk_text="${chunk_text//\\n/$'\n'}"  # unescape \n sequences → real newlines
    local rel="${file#$REPO_ROOT/}"
    local key; key=$(printf '%s' "$file" | tr '/: ' '___')
    local cnt=0
    cnt=$(grep -Fm1 "^${key}=" "$TMP_COUNTS" 2>/dev/null | cut -d= -f2 || echo 0)
    if [[ $cnt -ge $top_n ]]; then continue; fi
    if add_block "$rel" "$chunk_text" "lines ${start}-${end}"; then
      grep -Fv "^${key}=" "$TMP_COUNTS" > "${TMP_COUNTS}.tmp" 2>/dev/null && mv "${TMP_COUNTS}.tmp" "$TMP_COUNTS" || true
      printf '%s=%s\n' "$key" "$(( cnt + 1 ))" >> "$TMP_COUNTS"
      if [[ "$debug" == "true" ]]; then printf '  chunk: %s lines %s-%s score=%s\n' "$rel" "$start" "$end" "$score" >> "$debug_log"; fi
    fi
    true
  done < <(printf '%s\n' "${files[@]}" | "$SCRIPTS_DIR/tfidf-rank.sh" "${query}")
}

if [[ -n "$phase_goal" ]]; then
  if [[ ${#LARGE_SRC[@]} -gt 0 ]]; then score_and_add "$phase_goal" "${LARGE_SRC[@]}"; fi
  if [[ ${#LARGE_DOC[@]} -gt 0 ]]; then score_and_add "$phase_goal" "${LARGE_DOC[@]}"; fi
else
  # Empty goal fallback: include first 30 lines of each large file (source first)
  for f in "${LARGE_SRC[@]+"${LARGE_SRC[@]}"}" "${LARGE_DOC[@]+"${LARGE_DOC[@]}"}"; do
    rel="${f#$REPO_ROOT/}"
    content=$(head -30 "$f" 2>/dev/null || true)
    add_block "$rel" "$content" "first 30 lines" || break
  done
fi

if [[ -z "$output" ]]; then exit 0; fi

header="## Semantic Context (auto-compressed — phase: ${phase_goal:-no active phase})\n\n"
full_output=$(printf '%b' "${header}${output}")
json_output=$(printf '%s' "$full_output" | jq -Rs '{"hookSpecificOutput":{"additionalContext":.}}')

printf '%s' "$json_output" > "$cache_file"
printf '%s' "$json_output"
