# shellcheck shell=bash
# Substantive artifact validation at delivery (P2).

_sb_substance_find_artifact() {
  local repo_root="$1"
  local pattern="$2"
  local f
  for f in \
    "$repo_root/.planning/$pattern" \
    "$repo_root/.planning/phases"/*/"$pattern" \
    "$repo_root/.planning/phases"/*/*-"$pattern"; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    printf '%s' "$f"
    return 0
  done
  return 1
}

_sb_substance_is_stub() {
  local file="$1"
  local body
  body="$(grep -vE '^#|^$|^\s*$|^\|[-: ]+\|' "$file" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ -z "$body" ]] && return 0
  grep -qiE '\bTODO\b|\bFIXME\b|placeholder|coming soon|not available|lorem ipsum|\bTBD\b' "$file" 2>/dev/null && return 0
  return 1
}

_sb_substance_has_command_output() {
  local file="$1"
  grep -qE '```(bash|sh|shell|console|text)' "$file" 2>/dev/null && return 0
  grep -qiE '\$ (bash|npm|pytest|cargo|go test|make test)' "$file" 2>/dev/null && return 0
  return 1
}

# Args: repo_root emit_warn_fn emit_block_fn strict(0|1) state_contents(optional)
sb_artifact_substance_gate_enforce() {
  local repo_root="$1"
  local emit_warn_fn="$2"
  local emit_block_fn="$3"
  local strict="${4:-1}"
  local state_contents="${5:-}"
  local issues="" vfile rfile

  # Only validate REVIEW when review skill was recorded this session
  local check_review=false check_verify=false
  if [[ -n "$state_contents" ]]; then
    printf '%s\n' "$state_contents" | grep -Fqx 'silver-review' 2>/dev/null && check_review=true
    printf '%s\n' "$state_contents" | grep -Fqx 'silver-verify' 2>/dev/null && check_verify=true
  else
    check_review=true
    check_verify=true
  fi

  if [[ "$check_verify" == true ]]; then
    vfile="$(_sb_substance_find_artifact "$repo_root" "VERIFICATION.md" 2>/dev/null || true)"
    if [[ -n "$vfile" ]]; then
      if _sb_substance_is_stub "$vfile"; then
        issues="${issues}  ❌ VERIFICATION.md is empty or stub-only ($vfile)\n"
      elif ! _sb_substance_has_command_output "$vfile"; then
        issues="${issues}  ❌ VERIFICATION.md missing fenced command output blocks (docs/evidence-schema.md) ($vfile)\n"
      fi
    fi
  fi

  if [[ "$check_review" == true ]]; then
    rfile="$(_sb_substance_find_artifact "$repo_root" "REVIEW.md" 2>/dev/null || true)"
    if [[ -n "$rfile" ]]; then
      if _sb_substance_is_stub "$rfile"; then
        issues="${issues}  ❌ REVIEW.md is empty or stub-only ($rfile)\n"
      elif ! grep -qiE 'finding|no issues|no findings|clean pass|must-fix|nice-to-have' "$rfile" 2>/dev/null; then
        issues="${issues}  ❌ REVIEW.md missing findings section or explicit no-issues statement ($rfile)\n"
      fi
    fi
  fi

  if printf '%s\n' "$state_contents" | grep -Fqx 'silver-plan' 2>/dev/null; then
    pfile="$(_sb_substance_find_artifact "$repo_root" "PLAN.md" 2>/dev/null || true)"
    if [[ -n "$pfile" ]]; then
      if _sb_substance_is_stub "$pfile"; then
        issues="${issues}  ❌ PLAN.md is empty or stub-only ($pfile)\n"
      elif ! grep -qiE 'acceptance|task|wave|verification|dependency' "$pfile" 2>/dev/null; then
        issues="${issues}  ❌ PLAN.md missing task/acceptance/verification sections ($pfile)\n"
      fi
    fi
  fi

  [[ -n "$issues" ]] || return 0

  local msg
  msg=$(printf '🛑 ARTIFACT SUBSTANCE GATE — Delivery blocked until verification/review artifacts contain real evidence.\n\n%s\nReference: docs/evidence-schema.md' "$issues")

  if [[ "$strict" == "1" ]]; then
    "$emit_block_fn" "$msg"
    exit 0
  fi
  "$emit_warn_fn" "$msg"
}
