#!/usr/bin/env bash
# Argument handling, dependency checks and gate logic of the small validate-* scripts:
# host-agnostic-core, host-skill-surface, launch-review, sentinel-skills-manifest.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

S="$TL_REPO_ROOT/scripts"
NOPY="$(tl_path_without python3)"

for name in validate-host-agnostic-core validate-host-skill-surface validate-launch-review validate-sentinel-skills-manifest; do
  script="$S/$name.sh"
  tl_run bash "$script" --help
  assert_eq "$name --help exits 0" 0 "$TL_STATUS"
  assert_contains "$name --help prints header" "$TL_OUT" "#!/usr/bin/env bash"
  tl_run bash "$script" --bogus
  assert_eq "$name unknown arg exits 2" 2 "$TL_STATUS"
  assert_contains "$name unknown arg message" "$TL_ERR" "$name: unknown argument: --bogus"
done

# options with no value are rejected explicitly (not a silent shift failure)
tl_run bash "$S/validate-host-agnostic-core.sh" --repo-root
assert_eq "agnostic --repo-root without value exits 2" 2 "$TL_STATUS"
assert_contains "agnostic --repo-root explained" "$TL_ERR" "--repo-root requires a value"
tl_run bash "$S/validate-host-skill-surface.sh" --repo-root
assert_eq "surface --repo-root without value exits 2" 2 "$TL_STATUS"
assert_contains "surface --repo-root explained" "$TL_ERR" "--repo-root requires a value"
tl_run bash "$S/validate-launch-review.sh" --file
assert_eq "launch --file without value exits 2" 2 "$TL_STATUS"
assert_contains "launch --file explained" "$TL_ERR" "--file requires a value"
for opt in --manifest --expected-count --release-tag; do
  tl_run bash "$S/validate-sentinel-skills-manifest.sh" "$opt"
  assert_eq "sentinel $opt without value exits 2" 2 "$TL_STATUS"
  assert_contains "sentinel $opt explained" "$TL_ERR" "$opt requires a value"
done

# python3 required
tl_run env PATH="$NOPY" bash "$S/validate-host-agnostic-core.sh" --repo-root "$TL_TMP"
assert_eq "agnostic without python3 exits 1" 1 "$TL_STATUS"
assert_contains "agnostic python3 message" "$TL_ERR" "validate-host-agnostic-core: python3 required"
tl_run env PATH="$NOPY" bash "$S/validate-host-skill-surface.sh" --repo-root "$TL_TMP"
assert_eq "surface without python3 exits 1" 1 "$TL_STATUS"
assert_contains "surface python3 message" "$TL_ERR" "validate-host-skill-surface: python3 required"

# --- launch review ---------------------------------------------------------
LR="$S/validate-launch-review.sh"
tl_run bash "$LR" --file "$TL_TMP/nope.md"
assert_eq "launch missing file exits 1" 1 "$TL_STATUS"
assert_contains "launch missing file message" "$TL_ERR" "validate-launch-review: missing $TL_TMP/nope.md"

cat >"$TL_TMP/lr-good.md" <<'MD'
---
# comment line
status: clean
discovery_clean_streak: 2
manifest_completion: "12/12"
git_clean: true
nested:
  status: dirty
orphan line without colon
---
body
MD
tl_run env PATH="$NOPY" bash "$LR" --file "$TL_TMP/lr-good.md"
assert_eq "launch without python3 exits 1" 1 "$TL_STATUS"
assert_contains "launch python3 message" "$TL_ERR" "validate-launch-review: python3 required"

tl_run bash "$LR" --file "$TL_TMP/lr-good.md"
assert_eq "launch good review passes" 0 "$TL_STATUS"
assert_contains "launch OK line" "$TL_OUT" "(status=clean, streak=2, manifest=12/12)"

printf 'no frontmatter here\n' >"$TL_TMP/lr-nofm.md"
tl_run bash "$LR" --file "$TL_TMP/lr-nofm.md"
assert_eq "launch no frontmatter exits 1" 1 "$TL_STATUS"
assert_contains "launch no frontmatter message" "$TL_ERR" "no YAML frontmatter in $TL_TMP/lr-nofm.md"

# single-quoted scalar, legacy streak key, alternative failure modes
cat >"$TL_TMP/lr-alt.md" <<'MD'
---
status: 'clean'
consecutive_clean_discovery_rounds: 3
manifest_completion: 5/5
git_clean: TRUE
---
MD
tl_run bash "$LR" --file "$TL_TMP/lr-alt.md"
assert_eq "launch legacy streak key + quoted status + TRUE passes" 0 "$TL_STATUS"
assert_contains "launch legacy streak reported" "$TL_OUT" "streak=3"

cat >"$TL_TMP/lr-bad.md" <<'MD'
---
status:
discovery_clean_streak: lots
manifest_completion: soon
git_clean: "true"
---
MD
tl_run bash "$LR" --file "$TL_TMP/lr-bad.md"
assert_eq "launch bad review exits 1" 1 "$TL_STATUS"
assert_contains "launch empty status" "$TL_ERR" "status must be 'clean' (got '')"
assert_contains "launch non-int streak counts as 0" "$TL_ERR" "discovery_clean_streak must be >= 2 (got 0)"
assert_contains "launch bad manifest format" "$TL_ERR" "manifest_completion must look like N/N (got 'soon')"
assert_contains "launch quoted true is a string, not true" "$TL_ERR" "git_clean must be true (got 'true')"

# --- sentinel manifest -----------------------------------------------------
SM="$S/validate-sentinel-skills-manifest.sh"
mkrows() { # mkrows FILE COUNT [status] [open] [tag]
  jq -n --argjson n "$2" --arg st "${3:-clean}" --argjson op "${4:-0}" --arg tag "${5:-v1}" \
    '[range($n) | {skill:("s\(.)"), status:$st, findings_open:$op, release_tag:$tag}]' >"$1"
}
tl_run bash "$SM" --manifest "$TL_TMP/absent.json"
assert_eq "sentinel missing manifest exits 1" 1 "$TL_STATUS"
assert_contains "sentinel missing message" "$TL_ERR" "validate-sentinel-skills-manifest: missing $TL_TMP/absent.json"

mkrows "$TL_TMP/m3.json" 3
tl_run env PATH="$(tl_path_without jq)" bash "$SM" --manifest "$TL_TMP/m3.json" --expected-count 3
assert_eq "sentinel without jq exits 1" 1 "$TL_STATUS"
assert_contains "sentinel jq message" "$TL_ERR" "validate-sentinel-skills-manifest: jq required"

echo '{not json' >"$TL_TMP/broken.json"
tl_run bash "$SM" --manifest "$TL_TMP/broken.json"
assert_eq "sentinel invalid JSON exits 1" 1 "$TL_STATUS"
assert_contains "sentinel invalid JSON message" "$TL_ERR" "invalid JSON in $TL_TMP/broken.json"

tl_run bash "$SM" --manifest "$TL_TMP/m3.json" --expected-count 4
assert_eq "sentinel count mismatch exits 1" 1 "$TL_STATUS"
assert_contains "sentinel count message" "$TL_ERR" "expected 4 rows, found 3"

tl_run bash "$SM" --manifest "$TL_TMP/m3.json" --expected-count 3
assert_eq "sentinel clean manifest passes" 0 "$TL_STATUS"
assert_contains "sentinel OK line" "$TL_OUT" "OK — 3/3 clean rows in $TL_TMP/m3.json"

tl_run bash "$SM" --manifest "$TL_TMP/m3.json" --expected-count 3 --release-tag v1
assert_eq "sentinel matching release tag passes" 0 "$TL_STATUS"
tl_run bash "$SM" --manifest "$TL_TMP/m3.json" --expected-count 3 --release-tag v2
assert_eq "sentinel release tag mismatch exits 1" 1 "$TL_STATUS"
assert_contains "sentinel tag mismatch row listed" "$TL_ERR" "s0: status=clean findings_open=0 release_tag=v1"

mkrows "$TL_TMP/dirty.json" 2 dirty 3
tl_run bash "$SM" --manifest "$TL_TMP/dirty.json" --expected-count 2
assert_eq "sentinel dirty rows exit 1" 1 "$TL_STATUS"
assert_contains "sentinel dirty heading" "$TL_ERR" "incomplete or dirty rows:"
assert_contains "sentinel dirty row detail" "$TL_ERR" "s1: status=dirty findings_open=3"

# findings_open > 0 on an otherwise clean status, and rows missing fields entirely
mkrows "$TL_TMP/open.json" 1 clean 2
tl_run bash "$SM" --manifest "$TL_TMP/open.json" --expected-count 1
assert_eq "sentinel open findings exit 1" 1 "$TL_STATUS"
echo '{"a":{}}' >"$TL_TMP/missing-fields.json"
tl_run bash "$SM" --manifest "$TL_TMP/missing-fields.json" --expected-count 1
assert_eq "sentinel row without fields exit 1" 1 "$TL_STATUS"
assert_contains "sentinel falls back to key and 'missing'" "$TL_ERR" "a: status=missing findings_open=missing"

tl_results
