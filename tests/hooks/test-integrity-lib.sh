#!/usr/bin/env bash
# hooks/lib/integrity.sh: the keyed integrity record, verified at every gate decision point.
# shellcheck disable=SC2034  # SB_CONTRACT_UNLOCK_WINDOW is read by the sourced library
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/integrity.sh
source "$TL_REPO_ROOT/hooks/lib/integrity.sh"

SD="$SB_RUNTIME_STATE_DIR"
BR="$TL_TMP/branch"
export SILVER_BULLET_BRANCH_FILE="$BR"
LOG="$SD/seal-events.log"
NOPY="$(tl_path_without python3 openssl)"
NOSSL="$(tl_path_without openssl)"
mkdir -p "$SD"

R="$TL_TMP/proj"
fresh() {
  rm -rf "$R" "$SD"/integrity-* "$SD/trivial" "$SD/seal.key" "$SD/unlock-hint" "$LOG" "$SD/state" "$SD/state.seal" "$SD/state.hwm" "$BR"
  mkdir -p "$R/.planning"
  git -C "$R" init -q
  printf '# SB\n' >"$R/silver-bullet.md"
  printf '{"sb_initiated":true,"skills":{"required_planning":["a","b"],"required_deploy":["a","b","c"],"required_deploy_devops":["d"],"required_release":["r"],"required_release_devops":["rd"]},"state":{"state_file":"custom/s"}}\n' >"$R/.silver-bullet.json"
  printf '{}\n' >"$R/.silver-bullet.prompt.json"
  printf 'rules\n' >"$R/CLAUDE.md"
  printf 'road\n' >"$R/.planning/ROADMAP.md"
  R="$(cd "$R" && pwd -P)"
  sb_integrity_forget
}
rec_of() { _sb_iv_rec_file "${1:-$R}"; }
logged() { [[ -f "$LOG" ]] && cat "$LOG" || true; }
verify() { sb_integrity_forget; sb_integrity_verify "${1:-$R}" ""; }
GOOD='{"sb_initiated":true,"skills":{"required_planning":["a","b"],"required_deploy":["a","b","c"],"required_deploy_devops":["d"],"required_release":["r"],"required_release_devops":["rd"]},"state":{"state_file":"custom/s"}}'

# ── project root ─────────────────────────────────────────────────────────────────────────────────
fresh
assert_eq "the project root of a subdirectory" "$R" "$(cd "$R/.planning" && sb_integrity_root)"
assert_eq "an explicit directory" "$R" "$(sb_integrity_root "$R/.planning")"
mkdir -p "$TL_TMP/bare"
assert_eq "outside a project there is none" "" "$(sb_integrity_root "$TL_TMP/bare")"
assert_eq "a directory that does not exist has none" "" "$(sb_integrity_record_root "$TL_TMP/does-not-exist")"

# ── an install that never ran a session (no key): the live files are all there is ──────────────────
verify
assert_eq "status none before the first baseline" "none" "$SB_IV_STATUS"
assert_eq "the live planning list is read" "a b" "$SB_IV_REQUIRED_PLANNING"
assert_eq "and the deploy list" "a b c" "$SB_IV_REQUIRED_DEPLOY"
assert_eq "and the devops deploy list" "d" "$SB_IV_REQUIRED_DEPLOY_DEVOPS"
assert_eq "and the release lists" "r rd" "$SB_IV_REQUIRED_RELEASE $SB_IV_REQUIRED_RELEASE_DEVOPS"
assert_eq "and the state file" "custom/s" "$SB_IV_STATE_FILE"
assert_eq "no marker, no bypass" "false" "$SB_IV_TRIVIAL_OK"
touch "$SD/trivial"
verify
assert_eq "an install without a key keeps the legacy marker" "true" "$SB_IV_TRIVIAL_OK"
rm -f "$SD/trivial"

# ── baseline, then verify ───────────────────────────────────────────────────────────────────────
sb_integrity_baseline "$R" session
assert_file_exists "the record is written" "$(rec_of)"
assert_file_exists "with its counter" "$(rec_of).hwm"
assert_file_exists "and the install has its key" "$SD/seal.key"
assert_eq "the record is keyed" "hmac" "$(sed -n 2p "$(rec_of)")"
assert_eq "its counter starts at 1" "1" "$(sed -n 3p "$(rec_of)")"
verify
assert_eq "status ok" "ok" "$SB_IV_STATUS"
assert_eq "nothing diverged" "" "$SB_IV_DIVERGED"
assert_eq "the recorded planning list" "a b" "$SB_IV_REQUIRED_PLANNING"
assert_eq "the recorded devops deploy list" "d" "$SB_IV_REQUIRED_DEPLOY_DEVOPS"
assert_eq "the recorded release lists" "r rd" "$SB_IV_REQUIRED_RELEASE $SB_IV_REQUIRED_RELEASE_DEVOPS"
assert_eq "the recorded state file" "custom/s" "$SB_IV_STATE_FILE"
sb_integrity_baseline "" session
sb_integrity_baseline "$R" session
assert_eq "every baseline raises the counter" "2" "$(sed -n 3p "$(rec_of)")"

# ── the cache: one verification per process ───────────────────────────────────────────────────────
verify
printf '{"x":1}\n' >"$R/.silver-bullet.prompt.json"
sb_integrity_verify "$R" ""
assert_eq "a second verify of the same project in one process is the cached answer" "" "$SB_IV_DIVERGED"
sb_integrity_forget
sb_integrity_verify "$R" ""
assert_eq "until the cache is dropped" "prompt" "$SB_IV_DIVERGED"
printf '{}\n' >"$R/.silver-bullet.prompt.json"

# ── a project of a live install that has no record is unbaselined ──────────────────────────────────
R2="$TL_TMP/proj2"
mkdir -p "$R2"
git -C "$R2" init -q
printf '# SB\n' >"$R2/silver-bullet.md"
printf '%s\n' "$GOOD" >"$R2/.silver-bullet.json"
R2="$(cd "$R2" && pwd -P)"
verify "$R2"
assert_eq "no record on a live install: unbaselined" "unbaselined" "$SB_IV_STATUS"
assert_eq "named" "record" "$SB_IV_DIVERGED"
assert_eq "the lists fall back to the defaults, not to the live config" "" "$SB_IV_REQUIRED_PLANNING"
assert_eq "the marker does not bypass" "false" "$SB_IV_TRIVIAL_OK"
assert_contains "and says why" "$SB_IV_WHY" "not baselined"
touch "$SD/trivial"
verify "$R2"
assert_eq "a marker is no bypass there" "false" "$SB_IV_TRIVIAL_OK"
rm -f "$SD/trivial"
if sb_integrity_strict; then tl_pass "strict"; else tl_fail "strict"; fi
sb_integrity_baseline "$R2" entry config
assert_file_absent "an entry baseline never creates a record" "$(rec_of "$R2")"
sb_integrity_baseline "$R2" unlock silver-init
assert_file_absent "nor does an unlock" "$(rec_of "$R2")"
printf '%s\n' "$GOOD" >"$SD/state-x"
assert_eq "the trusted state of an unbaselined project is empty" "" "$(cd "$R2" && sb_integrity_state_contents "$SD/state")"
sb_integrity_baseline "$R2" session
verify "$R2"
assert_eq "a session start makes it ok" "ok" "$SB_IV_STATUS"
if sb_integrity_strict; then tl_fail "not strict"; else tl_pass "not strict once baselined"; fi
printf 'inst-x\n' >"$SD/state"
sb_state_seal_write "$SD/state"
assert_eq "its sealed state is trusted" "inst-x" "$(cd "$R2" && sb_integrity_state_contents "$SD/state")"
printf 'inst-x\ninst-y\n' >"$SD/state"
assert_eq "an unsealed line is not" "inst-x" "$(cd "$R2" && sb_integrity_state_contents "$SD/state")"
rm -f "$SD/state" "$SD/state.seal" "$SD/state.hwm" "$SD/state-x"
cd "$TL_TMP"

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
printf '%s\n' "$GOOD" >"$R/.silver-bullet.json"
verify
assert_eq "the original bytes verify again" "" "$SB_IV_DIVERGED"
jq '.sb_enforcement_tier = 2 | .recommended_tools.graphify.optimization.score = 7' "$R/.silver-bullet.json" >"$R/t.json"
jq -S . "$R/t.json" >"$R/.silver-bullet.json"
rm -f "$R/t.json"
verify
assert_eq "a tier, tool timestamps and re-formatting are not a change of the contract" "" "$SB_IV_DIVERGED"
mv "$R/silver-bullet.md" "$TL_TMP/md.bak"
verify
assert_eq "a moved silver-bullet.md diverges" "md" "$SB_IV_DIVERGED"
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

# ── the unlock is an entry of the record, and it never blesses a drift that was there before ───────
printf '{"skills":{"required_planning":["z"]}}\n' >"$R/.silver-bullet.json"
printf '# changed\n' >"$R/silver-bullet.md"
verify
assert_eq "no unlock: both diverge" "config md" "$SB_IV_DIVERGED"
sb_integrity_baseline "$R" unlock silver-add
verify
assert_eq "a drift that predates the skill is not adopted by it: no unlock" "config md" "$SB_IV_DIVERGED"
assert_eq "and no skill is unlocked" "" "$SB_IV_UNLOCK_SKILL"
assert_contains "the refusal is logged" "$(logged)" "contract skill silver-add got no unlock: config changed before it ran"
sb_integrity_baseline "$R" session
printf '%s\n' "$GOOD" >"$R/.silver-bullet.json"
printf '# SB\n' >"$R/silver-bullet.md"
sb_integrity_baseline "$R" session
sb_integrity_baseline "$R" unlock silver-add
verify
assert_eq "silver-add on a clean project is unlocked" "silver-add" "$SB_IV_UNLOCK_SKILL"
jq '._github_project = {"number":1}' "$R/.silver-bullet.json" >"$R/t.json" && mv "$R/t.json" "$R/.silver-bullet.json"
verify
assert_eq "a change to a key the skill is declared to write is expected" "" "$SB_IV_DIVERGED"
assert_eq "and the live values are used" "a b" "$SB_IV_REQUIRED_PLANNING"
jq '.skills.required_planning = []' "$R/.silver-bullet.json" >"$R/t.json" && mv "$R/t.json" "$R/.silver-bullet.json"
verify
assert_eq "a change to any other key is still a drift, unlock or not" "config" "$SB_IV_DIVERGED"
assert_eq "and the recorded list applies" "a b" "$SB_IV_REQUIRED_PLANNING"
sb_integrity_verify "$R" ""
SB_IV_UNLOCK_SKILL=silver-add
sb_integrity_baseline "$R" adopt
verify
assert_eq "adopting does not adopt the other key" "config" "$SB_IV_DIVERGED"
printf '%s\n' "$GOOD" >"$R/.silver-bullet.json"
jq '._github_project = {"number":2}' "$R/.silver-bullet.json" >"$R/t.json" && mv "$R/t.json" "$R/.silver-bullet.json"
verify
SB_IV_UNLOCK_SKILL=silver-add
sb_integrity_baseline "$R" adopt
SB_CONTRACT_UNLOCK_WINDOW=-1
verify
assert_eq "adopting what the skill is declared to write keeps it accepted after the window" "" "$SB_IV_DIVERGED"
SB_CONTRACT_UNLOCK_WINDOW=7200
sb_integrity_baseline "$R" session
sb_integrity_baseline "$R" unlock silver-init
printf '# SB 2\n' >"$R/silver-bullet.md"
printf '{"skills":{"required_planning":["q"]}}\n' >"$R/.silver-bullet.json"
verify
assert_eq "silver-init may write any key and the md" "" "$SB_IV_DIVERGED"
SB_IV_UNLOCK_SKILL=silver-init
sb_integrity_baseline "$R" adopt
SB_CONTRACT_UNLOCK_WINDOW=-1
verify
assert_eq "its writes are adopted" "" "$SB_IV_DIVERGED"
assert_eq "once the window has lapsed" "" "$SB_IV_UNLOCK_SKILL"
printf '{"skills":{"required_planning":["y"]}}\n' >"$R/.silver-bullet.json"
verify
assert_eq "a later change diverges" "config" "$SB_IV_DIVERGED"
SB_CONTRACT_UNLOCK_WINDOW=7200
# a diverged prompt file is expected while a JSON skill runs, and the trivial helper needs a project
fresh
sb_integrity_baseline "$R" session
sb_integrity_baseline "$R" unlock silver-add
printf '{"x":2}\n' >"$R/.silver-bullet.prompt.json"
verify
assert_eq "the prompt file is among the files a JSON skill may write" "" "$SB_IV_DIVERGED"
sb_integrity_baseline "$R" session
if (cd "$TL_TMP" && sb_integrity_trivial_ok "$TL_TMP/bare"); then tl_fail "no project"; else tl_pass "outside a project the marker helper says no"; fi
if sb_integrity_trivial_ok "$R"; then tl_fail "no marker"; else tl_pass "a project without a blessed marker says no"; fi
touch "$SD/trivial"
sb_integrity_baseline "$R" session
if sb_integrity_trivial_ok "$R"; then tl_pass "a blessed marker says yes"; else tl_fail "blessed"; fi
rm -f "$SD/trivial"
sb_integrity_baseline "$R" session
# a second skill may start while the first one's own keys are mid-change (that is its work, not a predating drift)
fresh
sb_integrity_baseline "$R" session
sb_integrity_baseline "$R" unlock silver-add
jq '._github_project = {"number":9}' "$R/.silver-bullet.json" >"$R/t.json" && mv "$R/t.json" "$R/.silver-bullet.json"
sb_integrity_baseline "$R" unlock silver-init
verify
assert_eq "silver-add's declared key does not stop the next skill's unlock" "silver-init" "$SB_IV_UNLOCK_SKILL"
sb_integrity_baseline "$R" session
# an unlock written into the record without the key is not a record any more
sb_integrity_baseline "$R" session
sb_integrity_baseline "$R" unlock silver-init
cp "$(rec_of)" "$TL_TMP/rec.keep"
awk -F'\t' -v OFS='\t' '$1 == "unlock" { $2 = "silver-init"; $3 = 9999999999 } { print }' "$(rec_of)" >"$(rec_of).tmp" && mv "$(rec_of).tmp" "$(rec_of)"
verify
assert_eq "an unlock edited into the record without the key is not trusted" "untrusted" "$SB_IV_STATUS"
cp "$TL_TMP/rec.keep" "$(rec_of)"
sb_integrity_baseline "$R" session
printf 'silver-init 9999999999\n' >"$SD/contract-unlock"
printf '{"skills":{"required_planning":["q"]}}\n' >"$R/.silver-bullet.json"
verify
assert_eq "a plain contract-unlock file means nothing" "config" "$SB_IV_DIVERGED"
printf '%s\n' "$GOOD" >"$R/.silver-bullet.json"
printf '# SB\n' >"$R/silver-bullet.md"
rm -f "$SD/contract-unlock"
sb_integrity_baseline "$R" session

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
rm -f "$(rec_of).hwm"
verify
assert_eq "a record and counter both deleted on a live install: unbaselined, not trusted" "unbaselined" "$SB_IV_STATUS"
assert_eq "so the live config is not read" "" "$SB_IV_REQUIRED_PLANNING"
cp "$TL_TMP/old.rec" "$(rec_of)"
printf '5\n' >"$(rec_of).hwm"
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
printf 'x\n' >"$TL_TMP/hwm.target"
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
printf 'v2\ncksum\n1\n-\nd\nconfig\t-\t{}\n' >"$(rec_of)"
verify
assert_eq "an unkeyed record is a downgrade where keys are possible" "untrusted" "$SB_IV_STATUS"
assert_contains "logged" "$(logged)" "unkeyed"

# a record belongs to its project root
rm -f "$(rec_of)" "$(rec_of).hwm"
sb_integrity_baseline "$R" session
R3="$TL_TMP/proj3"
rm -rf "$R3"; mkdir -p "$R3/.planning"
git -C "$R3" init -q
cp "$R/silver-bullet.md" "$R/.silver-bullet.json" "$R/.silver-bullet.prompt.json" "$R/CLAUDE.md" "$R3/"
cp "$R/.planning/ROADMAP.md" "$R3/.planning/"
R3="$(cd "$R3" && pwd -P)"
cp "$(rec_of "$R")" "$(rec_of "$R3")"
cp "$(rec_of "$R").hwm" "$(rec_of "$R3").hwm"
verify "$R3"
assert_eq "a record copied to another project whose files are identical does not verify" "untrusted" "$SB_IV_STATUS"
rm -f "$(rec_of "$R3")" "$(rec_of "$R3").hwm"

# ── no openssl, no python3 ──────────────────────────────────────────────────────────────────────
fresh
sb_integrity_baseline "$R" session
sb_integrity_forget
PATH="$NOSSL" sb_integrity_verify "$R" ""
assert_eq "a record made with openssl verifies with python3 alone" "ok" "$SB_IV_STATUS"
rm -f "$(rec_of)" "$(rec_of).hwm"
PATH="$NOSSL" sb_integrity_baseline "$R" session
sb_integrity_forget
sb_integrity_verify "$R" ""
assert_eq "and the other way round" "ok" "$SB_IV_STATUS"
sb_integrity_forget
PATH="$NOPY" sb_integrity_verify "$R" ""
assert_eq "a keyed record cannot be verified without a digest tool" "untrusted" "$SB_IV_STATUS"
assert_eq "and says why" "openssl or python3 is needed to verify the keyed record" "$SB_IV_WHY"
fresh
PATH="$NOPY" sb_integrity_baseline "$R" session
assert_eq "without either the record is a checksum" "cksum" "$(sed -n 2p "$(rec_of)")"
assert_contains "and says so" "$(logged)" "plain checksum"
sb_integrity_forget
PATH="$NOPY" sb_integrity_verify "$R" ""
assert_eq "it verifies without them" "ok" "$SB_IV_STATUS"
printf 'more\n' >>"$R/CLAUDE.md"
sb_integrity_forget
PATH="$NOPY" sb_integrity_verify "$R" ""
assert_eq "and still detects a change" "instr:CLAUDE.md" "$SB_IV_DIVERGED"

# ── writes that cannot happen ────────────────────────────────────────────────────────────────────
fresh
sb_integrity_baseline "$R" session
before="$(cat "$(rec_of)")"
tl_stub openssl 'exit 1'
sb_integrity_baseline "$R" session
rm -f "$TL_BIN/openssl"
assert_eq "a digest that cannot be computed leaves the record alone" "$before" "$(cat "$(rec_of)")"
fresh
sb_integrity_baseline "$R" session
printf 'garbage\n' >"$(rec_of)"
sb_integrity_baseline "$R" entry config
assert_eq "an entry baseline does not extend a record that is not authentic" "garbage" "$(cat "$(rec_of)")"

tl_results
