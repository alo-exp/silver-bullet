#!/usr/bin/env bash
# completion-audit: command classification helpers

shell_payload_is_sb_skill_adapter_invocation() {
  local payload="$1"
  [[ -n "$payload" ]] || return 1
  [[ "$payload" != *$'\n'* ]] || return 1
  python3 - "$payload" <<'PY' >/dev/null 2>&1
import pathlib
import re
import shlex
import sys

payload = sys.argv[1]
assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
try:
    lexer = shlex.shlex(payload, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except Exception:
    raise SystemExit(1)

if not tokens:
    raise SystemExit(1)
if any(token in {";", "|", "||", "&", "&&", ">", ">>", "<", "<<"} for token in tokens):
    raise SystemExit(1)

idx = 0
if tokens[idx] == "env":
    idx += 1
while idx < len(tokens) and assignment_re.match(tokens[idx]):
    idx += 1
if idx + 1 >= len(tokens):
    raise SystemExit(1)

command = tokens[idx]
if not (command == "scripts/silver-bullet" or command.endswith("/scripts/silver-bullet")):
    raise SystemExit(1)
if tokens[idx + 1] != "invoke-skill":
    raise SystemExit(1)

print("adapter")
PY
}

workflow_id_from_shell_assignment() {
  local payload="$1"
  local first_line
  first_line=$(printf '%s' "$payload" | sed -n '1p')
  first_line="${first_line#"${first_line%%[![:space:]]*}"}"

  if [[ "$first_line" =~ ^export[[:space:]]+SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]]*[\;] ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$first_line" =~ ^env[[:space:]]+ ]]; then
    first_line="${first_line#env }"
    first_line="${first_line#"${first_line%%[![:space:]]*}"}"
  fi

  if [[ "$first_line" =~ (^|[[:space:]])SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]] ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

# ca_classify_command <full-cmd>
# Sets globals: is_intermediate, is_completion, cmd_first_line
# Returns 0 when the command matches a delivery gate; 1 to skip (no gate).
ca_classify_command() {
  local cmd="$1"

  is_intermediate=false
  is_completion=false
  cmd_first_line=$(printf '%s' "$cmd" | head -1)
  if declare -f sb_shell_command_unwrap_rtk >/dev/null 2>&1; then
    cmd_first_line="$(sb_shell_command_unwrap_rtk "$cmd_first_line")"
  fi

  if shell_payload_is_sb_skill_adapter_invocation "$cmd"; then
    return 1
  fi

  if printf '%s' "$cmd_first_line" | grep -qE '\bgit commit\b'; then
    is_intermediate=true
  elif printf '%s' "$cmd_first_line" | grep -qE '\bgit push\b'; then
    is_intermediate=true
  elif printf '%s' "$cmd_first_line" | grep -qE '\bgit (write-tree|commit-tree)\b'; then
    is_intermediate=true
  elif printf '%s' "$cmd_first_line" | grep -qE '\bgit hash-object\b.*\s-w\b'; then
    is_intermediate=true
  elif printf '%s' "$cmd_first_line" | grep -qE '\bgit update-ref\b.*\brefs/heads/'; then
    is_intermediate=true
  elif printf '%s' "$cmd_first_line" | grep -qE '\bgh pr create\b'; then
    is_completion=true
  elif printf '%s' "$cmd_first_line" | grep -qE '\bgh pr merge\b'; then
    is_completion=true
  elif printf '%s' "$cmd_first_line" | grep -iqE '\bdeploy\b'; then
    is_completion=true
  elif printf '%s' "$cmd_first_line" | grep -qE '\bgh release create\b'; then
    is_completion=true
  fi

  if [[ "$is_intermediate" == false && "$is_completion" == false ]]; then
    return 1
  fi
  return 0
}
