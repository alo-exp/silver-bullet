# shellcheck shell=bash
# Registered-events helper (R4-30 rule): a review-fix-ladder test may only drive an
# (event, tool) pair that hooks/hooks.json really routes to a hook command.
#
#   rfl_registered_commands <event> <tool-or-source>   # prints one hook script basename per line
#   rfl_assert_registered   <event> <tool> <script>    # tl_pass / tl_fail

rfl_registered_commands() {
  local event="$1" tool="$2" hooks_json="${RFL_HOOKS_JSON:-$TL_REPO_ROOT/hooks/hooks.json}"
  jq -r --arg e "$event" --arg t "$tool" '
    (.hooks[$e] // [])[]
    | select((.matcher // ".*") as $m | ($t | test("^(" + $m + ")$")))
    | .hooks[].command | capture("hooks/(?<n>[^\"]+)").n' "$hooks_json" 2>/dev/null
}

rfl_assert_registered() {
  local event="$1" tool="$2" script="$3"
  if rfl_registered_commands "$event" "$tool" | grep -qx "$script"; then
    tl_pass "registered: $event/$tool -> $script"
  else
    tl_fail "registered: $event/$tool -> $script (hooks.json does not route it)"
  fi
}
