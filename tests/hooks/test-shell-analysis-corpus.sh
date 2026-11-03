#!/usr/bin/env bash
# Table-driven delivery classification over tests/fixtures/shell-analysis/corpus.json.
#
# Every case with a "tier" goes through the shipped contract, ca_classify_command in
# hooks/lib/completion-audit/classify.sh, exactly as completion-audit.sh calls it. The
# corpus holds each bypass from review findings R1-01/R1-02/R1-03/R1-12/R1-13/R5-05
# (newlines, wrappers, git global options, aliases, substitutions, chained verbs, verb
# equivalents) and an equally large set of honest commands that must not be gated.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

CORPUS="$TL_REPO_ROOT/tests/fixtures/shell-analysis/corpus.json"
LIBDIR="$TL_REPO_ROOT/hooks/lib"
WORK="$TL_TMP/work"
mkdir -p "$WORK"

# One bash process sources the libraries once and classifies every case, printing
# "<id><TAB><tier>" where tier is none|intermediate|completion|both.
classify_all() {
  (cd "$WORK" && bash -c '
    source "$1/required-skills.sh"
    source "$1/workflow-utils.sh"
    source "$1/tool-input.sh"
    source "$1/completion-audit/classify.sh"
    while IFS= read -r -d "" id && IFS= read -r -d "" cmd; do
      tier=none
      if ca_classify_command "$cmd"; then
        if [[ "$is_completion" == true && "$is_intermediate" == true ]]; then
          tier=both
        elif [[ "$is_completion" == true ]]; then
          tier=completion
        elif [[ "$is_intermediate" == true ]]; then
          tier=intermediate
        fi
      fi
      printf "%s\t%s\n" "$id" "$tier"
    done
  ' _ "$LIBDIR" < <(jq -j '.[] | select(.tier) | .id, "\u0000", .cmd, "\u0000"' "$CORPUS"))
}

got_file="$TL_TMP/got.tsv"
classify_all >"$got_file"

total=0
while IFS=$'\t' read -r id want finding; do
  total=$((total + 1))
  got="$(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$got_file")"
  assert_eq "[$finding] $id -> $want" "$want" "${got:-missing}"
done < <(jq -r '.[] | select(.tier) | [.id, .tier, .finding] | @tsv' "$CORPUS")

# The corpus is large on both sides: bypasses and honest commands.
gated="$(jq '[.[] | select(.tier and .tier != "none")] | length' "$CORPUS")"
honest="$(jq '[.[] | select(.tier == "none")] | length' "$CORPUS")"
[[ "$gated" -ge 100 ]] && tl_pass "corpus has $gated gated cases" || tl_fail "corpus too small: $gated gated cases"
[[ "$honest" -ge "$gated" ]] && tl_pass "honest corpus ($honest) is at least as large as the gated one" ||
  tl_fail "honest corpus ($honest) smaller than gated ($gated)"
assert_eq "every tier case was classified" "$total" "$(wc -l <"$got_file" | tr -d ' ')"

# ── classify.sh details beyond the tier ────────────────────────────────────────────
# show <classify.sh path> <command>: rc, flags, the ca_* outputs and cmd_first_line.
show() {
  tl_run bash -c 'source "$1"; ca_classify_command "$2"; rc=$?
    printf "rc=%s inter=%s comp=%s tier=%s status=%s actions=%s possible=%s could=%s opaque=%s\nfirst=%s\n" \
      "$rc" "$is_intermediate" "$is_completion" "$ca_tier" "$ca_analysis_status" "$ca_actions" \
      "$ca_possible_actions" "$ca_could_be_delivery" "$ca_opaque" "$cmd_first_line"' _ "$1" "$2"
}
CLASSIFY="$LIBDIR/completion-audit/classify.sh"
show "$CLASSIFY" 'git push && gh release new v1'
assert_contains "outputs for a chain" "$TL_OUT" \
  "rc=0 inter=false comp=true tier=completion status=ok actions=push release_create possible= could=false opaque=false"
assert_contains "cmd_first_line restates the release for the release gates" "$TL_OUT" \
  "first=gh release create [gh release new v1]"
show "$CLASSIFY" '$G commit -m x'
assert_contains "obfuscated commit fails closed at its possible tier" "$TL_OUT" \
  "rc=0 inter=true comp=false tier=intermediate status=ok actions= possible=commit could=true opaque=true"
show "$CLASSIFY" $'echo ok\ngit commit -m \'unterminated'
assert_contains "unparseable text is held at the strictest tier (bash may accept it)" "$TL_OUT" \
  "rc=0 inter=false comp=true tier=completion status=parse_failed"
assert_contains "the unseen code is named for the regex consumers" "$TL_OUT" "first=deploy [unseen: parse error"
show "$CLASSIFY" $'git push\ngh pr create --title \'x'
assert_contains "a parsed intermediate is raised to completion" "$TL_OUT" "tier=completion status=parse_failed"
show "$CLASSIFY" 'scripts/silver-bullet invoke-skill silver-plan'
assert_contains "skill adapter is not gated" "$TL_OUT" "rc=1 inter=false comp=false"
tl_run bash -c 'source "$1"; shell_payload_is_sb_skill_adapter_invocation "$2" && echo yes || echo no
  shell_payload_is_sb_skill_adapter_invocation "$3" && echo yes || echo no
  shell_payload_is_sb_skill_adapter_invocation "" && echo yes || echo no' _ "$CLASSIFY" \
  'scripts/silver-bullet invoke-skill x $(git commit -m y)' $'scripts/silver-bullet invoke-skill x\nls'
assert_eq "adapter with a substitution, two lines, empty: not adapters (R1-01)" $'no\nno\nno' "$TL_OUT"

# Without shell-analysis.sh (a partial install) classify.sh falls back to the regex tier.
NOLIB="$TL_TMP/nolib/hooks/lib/completion-audit"
mkdir -p "$NOLIB"
cp "$CLASSIFY" "$NOLIB/classify.sh"
show "$NOLIB/classify.sh" $'true\ngh pr merge 3'
assert_contains "no analyzer: completion verb on line 2" "$TL_OUT" "rc=0 inter=false comp=true tier=completion status=helper_unavailable"
show "$NOLIB/classify.sh" 'git -C . -c a=b commit -m x'
assert_contains "no analyzer: git global options before the verb" "$TL_OUT" "rc=0 inter=true comp=false tier=intermediate"
show "$NOLIB/classify.sh" 'npm run deploy:prod'
assert_contains "no analyzer: deploy script" "$TL_OUT" "tier=completion"
show "$NOLIB/classify.sh" '$G commit -m x'
assert_contains "no analyzer: a variable program naming a verb gets the planning floor" "$TL_OUT" "rc=0 inter=true comp=false tier=intermediate"
show "$NOLIB/classify.sh" 'X=1; $X gh pr create'
assert_contains "no analyzer: a variable program naming a PR verb is final delivery" "$TL_OUT" "tier=completion"
show "$NOLIB/classify.sh" 'echo $HOME'
assert_contains "no analyzer: a variable that is not a program is not gated" "$TL_OUT" "rc=1 inter=false comp=false tier=none"
show "$NOLIB/classify.sh" 'git log --grep commit'
assert_contains "no analyzer: a verb after another subcommand is not gated" "$TL_OUT" "rc=1 inter=false comp=false tier=none"
tl_run bash -c 'source "$1"; shell_payload_is_sb_skill_adapter_invocation "scripts/silver-bullet invoke-skill x" && echo yes || echo no' \
  _ "$NOLIB/classify.sh"
assert_eq "no analyzer: nothing is exempt as an adapter" "no" "$TL_OUT"

tl_results
