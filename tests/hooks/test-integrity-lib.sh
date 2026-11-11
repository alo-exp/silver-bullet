#!/usr/bin/env bash
# hooks/lib/integrity.sh: the keyed integrity record, verified at every gate decision point.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/integrity.sh
source "$TL_REPO_ROOT/hooks/lib/integrity.sh"

SD="$SB_RUNTIME_STATE_DIR"
BR="$TL_TMP/branch"
export SILVER_BULLET_BRANCH_FILE="$BR"
LOG="$SD/seal-events.log"
NOPY="$(tl_path_without python3)"
mkdir -p "$SD"

R="$TL_TMP/proj"
fresh() {
  rm -rf "$R" "$SD"/integrity-* "$SD/trivial" "$SD/seal.key" "$SD/contract-unlock" "$LOG" "$SD/state" "$SD/state.seal" "$SD/state.hwm" "$BR"
  mkdir -p "$R/.planning"
  git -C "$R" init -q
  printf '# SB\n' >"$R/silver-bullet.md"
  printf '{"sb_initiated":true,"skills":{"required_planning":["a","b"],"required_deploy":["a","b","c"],"required_deploy_devops":["d"]},"state":{"state_file":"custom/s"}}\n' >"$R/.silver-bullet.json"
  printf '{}\n' >"$R/.silver-bullet.prompt.json"
  printf 'rules\n' >"$R/CLAUDE.md"
  printf 'road\n' >"$R/.planning/ROADMAP.md"
  R="$(cd "$R" && pwd -P)"
}
rec_of() { printf '%s/integrity-%s.rec' "$SD" "$(printf '%s' "$R" | cksum | cut -d' ' -f1)"; }
logged() { [[ -f "$LOG" ]] && cat "$LOG" || true; }
verify() { sb_integrity_verify "$R" "${1-}"; }

# ── project root ─────────────────────────────────────────────────────────────────────────────────
fresh
assert_eq "the project root of a subdirectory" "$R" "$(cd "$R/.planning" && sb_integrity_root)"
assert_eq "an explicit directory" "$R" "$(sb_integrity_root "$R/.planning")"
mkdir -p "$TL_TMP/bare"
assert_eq "outside a project there is none" "" "$(sb_integrity_root "$TL_TMP/bare")"
assert_eq "a directory that does not exist has none" "" "$(sb_integrity_record_root "$TL_TMP/does-not-exist")"

# ── never baselined: the live files are all there is ───────────────────────────────────────────────
verify
assert_eq "status none before the first baseline" "none" "$SB_IV_STATUS"
assert_eq "the live planning list is read" "a b" "$SB_IV_REQUIRED_PLANNING"
assert_eq "and the deploy list" "a b c" "$SB_IV_REQUIRED_DEPLOY"
assert_eq "and the devops deploy list" "d" "$SB_IV_REQUIRED_DEPLOY_DEVOPS"
assert_eq "and the state file" "custom/s" "$SB_IV_STATE_FILE"
assert_eq "no marker, no bypass" "false" "$SB_IV_TRIVIAL_OK"
touch "$SD/trivial"
verify
assert_eq "an install that was never baselined keeps the legacy marker" "true" "$SB_IV_TRIVIAL_OK"
rm -f "$SD/trivial"
printf 'x\n' >"$SD/state"
verify "$SD/state"
assert_eq "with a state file given its trusted lines are returned" "x" "$SB_IV_TRUSTED_SKILLS"
rm -f "$SD/state"

# ── baseline, then verify ───────────────────────────────────────────────────────────────────────
sb_integrity_baseline "$R" session
assert_file_exists "the record is written" "$(rec_of)"
assert_file_exists "with its counter" "$(rec_of).hwm"
assert_eq "the record is keyed" "hmac" "$(sed -n 2p "$(rec_of)")"
assert_eq "its counter starts at 1" "1" "$(sed -n 3p "$(rec_of)")"
verify
assert_eq "status ok" "ok" "$SB_IV_STATUS"
assert_eq "nothing diverged" "" "$SB_IV_DIVERGED"
assert_eq "the recorded planning list" "a b" "$SB_IV_REQUIRED_PLANNING"
assert_eq "the recorded devops deploy list" "d" "$SB_IV_REQUIRED_DEPLOY_DEVOPS"
assert_eq "the recorded state file" "custom/s" "$SB_IV_STATE_FILE"
sb_integrity_baseline "" session
sb_integrity_baseline "$R" session
assert_eq "every baseline raises the counter" "2" "$(sed -n 3p "$(rec_of)")"

# ── what the hooks keep in the config does not count ──────────────────────────────────────────────
jq '.sb_enforcement_tier = 2 | .recommended_tools.graphify.optimization.score = 7' "$R/.silver-bullet.json" >"$R/t.json"
jq -S . "$R/t.json" >"$R/.silver-bullet.json"
rm -f "$R/t.json"
verify
assert_eq "a tier, tool timestamps and re-formatting are not a change of the contract" "" "$SB_IV_DIVERGED"

# ── each artifact diverges on its own ───────────────────────────────────────────────────────────
printf '{"skills":{"required_planning":[]}}\n' >"$R/.silver-bullet.json"
verify
assert_eq "a rewritten config diverges" "config" "$SB_IV_DIVERGED"
assert_eq "yet the recorded list is the one used" "a b" "$SB_IV_REQUIRED_PLANNING"
assert_contains "and the divergence is logged" "$(logged)" "integrity diverged: config"
rm -f "$R/.silver-bullet.json"
verify
assert_eq "a deleted config diverges" "config" "$SB_IV_DIVERGED"
printf 'not json{' >"$R/.silver-bullet.json"
verify
assert_eq "a config that is not JSON diverges" "config" "$SB_IV_DIVERGED"
rm -f "$R/.silver-bullet.json"
ln -s "$R/CLAUDE.md" "$R/.silver-bullet.json"
verify
assert_eq "a symlinked config diverges" "config" "$SB_IV_DIVERGED"
rm -f "$R/.silver-bullet.json"
printf '{"sb_initiated":true,"skills":{"required_planning":["a","b"],"required_deploy":["a","b","c"],"required_deploy_devops":["d"]},"state":{"state_file":"custom/s"}}\n' >"$R/.silver-bullet.json"
verify
assert_eq "the original bytes verify again" "" "$SB_IV_DIVERGED"
mv "$R/silver-bullet.md" "$TL_TMP/md.bak"
verify
assert_eq "a moved silver-bullet.md diverges" "md" "$SB_IV_DIVERGED"
mv "$TL_TMP/md.bak" "$R/silver-bullet.md"
mv "$R/silver-bullet.md" "$TL_TMP/md.bak"
ln -s "$R/CLAUDE.md" "$R/silver-bullet.md"
verify
assert_eq "a symlinked silver-bullet.md diverges" "md" "$SB_IV_DIVERGED"
rm -f "$R/silver-bullet.md"
mv "$TL_TMP/md.bak" "$R/silver-bullet.md"
printf '{"x":1}\n' >"$R/.silver-bullet.prompt.json"
verify
assert_eq "a rewritten prompt file diverges" "prompt" "$SB_IV_DIVERGED"
printf '{}\n' >"$R/.silver-bullet.prompt.json"
printf 'more\n' >>"$R/CLAUDE.md"
printf 'new\n' >"$R/AGENTS.md"
printf 'plan\n' >"$R/.planning/STATE.md"
printf 'more\n' >>"$R/.planning/ROADMAP.md"
verify
assert_eq "instruction and planning files diverge by their names" "instr:CLAUDE.md instr:AGENTS.md plan:ROADMAP.md plan:STATE.md" "$SB_IV_DIVERGED"
sb_integrity_baseline "$R" entry instr:CLAUDE.md instr:AGENTS.md plan:ROADMAP.md plan:STATE.md
verify
assert_eq "a baseline of those entries accepts them" "" "$SB_IV_DIVERGED"

# ── the trivial marker ──────────────────────────────────────────────────────────────────────────
touch "$SD/trivial"
verify
assert_eq "a marker nobody blessed diverges" "trivial" "$SB_IV_DIVERGED"
assert_eq "and does not bypass" "false" "$SB_IV_TRIVIAL_OK"
sb_integrity_restore_safe
assert_file_absent "the gate removes it" "$SD/trivial"
assert_contains "and logs it" "$(logged)" "removed the unblessed trivial marker"
sb_integrity_restore_safe
ln -s "$TL_TMP/x" "$SD/trivial"
verify
sb_integrity_restore_safe
assert_eq "a symlink marker is removed too" "absent" "$([[ -e "$SD/trivial" || -L "$SD/trivial" ]] && echo present || echo absent)"
touch "$SD/trivial"
sb_integrity_baseline "$R" session
verify
assert_eq "a marker present at baseline time is blessed" "true" "$SB_IV_TRIVIAL_OK"
assert_eq "without a divergence" "" "$SB_IV_DIVERGED"
sb_integrity_restore_safe
assert_file_exists "and kept" "$SD/trivial"
rm -f "$SD/trivial"
sb_integrity_baseline "$R" session

# ── a sanctioned contract writer is running ─────────────────────────────────────────────────────
printf '{"skills":{"required_planning":["z"]}}\n' >"$R/.silver-bullet.json"
printf '# changed\n' >"$R/silver-bullet.md"
sb_contract_unlock_write silver-add
verify
assert_eq "silver-add accepts the JSON change" "md" "$SB_IV_DIVERGED"
assert_eq "and the live values are used" "z" "$SB_IV_REQUIRED_PLANNING"
sb_contract_unlock_write silver-init
verify
assert_eq "silver-init accepts both" "" "$SB_IV_DIVERGED"
printf '{"p":1}\n' >"$R/.silver-bullet.prompt.json"
verify
assert_eq "so does the prompt file" "" "$SB_IV_DIVERGED"
sb_integrity_baseline "$R" entry config md prompt
rm -f "$SD/contract-unlock"
verify
assert_eq "an entry baseline makes the record follow" "" "$SB_IV_DIVERGED"
assert_eq "with the new values" "z" "$SB_IV_REQUIRED_PLANNING"

# ── the record itself is not trusted ────────────────────────────────────────────────────────────
fresh
sb_integrity_baseline "$R" session
verify
assert_eq "baseline" "ok" "$SB_IV_STATUS"
cp "$(rec_of)" "$TL_TMP/old.rec"
sb_integrity_baseline "$R" session
rm -f "$(rec_of)"
verify
assert_eq "a deleted record is not trusted while its counter exists" "untrusted" "$SB_IV_STATUS"
assert_eq "it is named" "record" "$SB_IV_DIVERGED"
assert_eq "the lists fall back to the defaults" "" "$SB_IV_REQUIRED_PLANNING"
assert_eq "and nothing bypasses" "false" "$SB_IV_TRIVIAL_OK"
assert_contains "logged" "$(logged)" "the record was deleted"
cp "$TL_TMP/old.rec" "$(rec_of)"
verify
assert_eq "an older record put back is not trusted" "untrusted" "$SB_IV_STATUS"
assert_contains "logged as a rollback" "$(logged)" "an older record was put back"
rm -f "$(rec_of)" "$(rec_of).hwm"
sb_integrity_baseline "$R" session
awk -F'\t' -v OFS='\t' '$1 == "config" { $2 = "1-1" } { print }' "$(rec_of)" >"$(rec_of).tmp" && mv "$(rec_of).tmp" "$(rec_of)"
verify
assert_eq "a body edited without the key is not trusted" "untrusted" "$SB_IV_STATUS"
assert_contains "logged" "$(logged)" "the record was changed or the key is missing"
rm -f "$(rec_of)" "$(rec_of).hwm"
sb_integrity_baseline "$R" session
printf 'garbage\n' >"$(rec_of)"
verify
assert_eq "an unreadable record is not trusted" "untrusted" "$SB_IV_STATUS"
assert_contains "logged" "$(logged)" "the record is unreadable"
rm -f "$(rec_of)"
ln -s "$TL_TMP/real.rec" "$(rec_of)"
verify
assert_eq "a symlinked record is not trusted" "untrusted" "$SB_IV_STATUS"
assert_contains "logged" "$(logged)" "symbolic link"
sb_integrity_baseline "$R" session
assert_file_absent "a symlinked record is never written through" "$TL_TMP/real.rec"
rm -f "$(rec_of)" "$(rec_of).hwm"
sb_integrity_baseline "$R" session
printf 'x\n' > "$TL_TMP/hwm.target"
rm -f "$(rec_of).hwm"; ln -s "$TL_TMP/hwm.target" "$(rec_of).hwm"
sb_integrity_baseline "$R" session
assert_eq "a symlinked counter is never written through" "x" "$(cat "$TL_TMP/hwm.target")"
rm -f "$(rec_of)" "$(rec_of).hwm"
sb_integrity_baseline "$R" session
sed -i.orig '3s/.*/not-a-number/' "$(rec_of)" 2>/dev/null; rm -f "$(rec_of).orig"
sb_integrity_baseline "$R" session
assert_eq "a damaged counter is counted on from the stored maximum" "2" "$(sed -n 3p "$(rec_of)")"
printf '0\n' >"$(rec_of).hwm"
sb_integrity_baseline "$R" session
assert_eq "a counter that fell behind the record is overtaken, not reused" "3" "$(sed -n 3p "$(rec_of)")"
rm -f "$(rec_of)" "$(rec_of).hwm"
printf 'feature/a\n' >"$BR"
sb_integrity_baseline "$R" session
verify
assert_eq "same branch" "ok" "$SB_IV_STATUS"
printf 'feature/b\n' >"$BR"
verify
assert_eq "a record from another branch is not trusted" "untrusted" "$SB_IV_STATUS"
assert_contains "logged" "$(logged)" "another branch"
rm -f "$BR"
rm -f "$(rec_of)" "$(rec_of).hwm"
sb_integrity_baseline "$R" session
printf 'v1\ncksum\n1\n-\nd\nconfig\t-\t{}\n' >"$(rec_of)"
verify
assert_eq "an unkeyed record is a downgrade where keys are possible" "untrusted" "$SB_IV_STATUS"
assert_contains "logged" "$(logged)" "unkeyed"

# ── no python3: a plain checksum, honestly ────────────────────────────────────────────────────────
fresh
PATH="$NOPY" sb_integrity_baseline "$R" session
assert_eq "without python3 the record is a checksum" "cksum" "$(sed -n 2p "$(rec_of)")"
assert_contains "and says so" "$(logged)" "plain checksum"
PATH="$NOPY" sb_integrity_verify "$R" ""
assert_eq "it verifies without python3" "ok" "$SB_IV_STATUS"
printf 'more\n' >>"$R/CLAUDE.md"
PATH="$NOPY" sb_integrity_verify "$R" ""
assert_eq "and still detects a change" "instr:CLAUDE.md" "$SB_IV_DIVERGED"

# ── python3 gone after a keyed record was made ──────────────────────────────────────────────────
fresh
sb_integrity_baseline "$R" session
PATH="$NOPY" sb_integrity_verify "$R" ""
assert_eq "a keyed record cannot be verified without python3" "untrusted" "$SB_IV_STATUS"
assert_eq "and says why" "python3 is needed to verify the keyed record" "$SB_IV_WHY"

# ── writes that cannot happen ────────────────────────────────────────────────────────────────────
fresh
sb_integrity_baseline "$R" session
REALPY="$(command -v python3)"
tl_stub python3 "case \"\$*\" in *hmac*) exit 1 ;; esac; exec \"$REALPY\" \"\$@\""
before="$(cat "$(rec_of)")"
sb_integrity_baseline "$R" session
rm -f "$TL_BIN/python3"
assert_eq "a digest that cannot be computed leaves the record alone" "$before" "$(cat "$(rec_of)")"
fresh
sb_integrity_baseline "$R" entry config
assert_file_absent "an entry baseline never creates a record" "$(rec_of)"
sb_integrity_baseline "$R" session
printf 'garbage\n' >"$(rec_of)"
sb_integrity_baseline "$R" entry config
assert_eq "nor extends one that is not authentic" "garbage" "$(cat "$(rec_of)")"

tl_results
