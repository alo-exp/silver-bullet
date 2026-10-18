#!/usr/bin/env bash
# scripts/regenerate-site-certification-status.sh and scripts/export-enterprise-evidence.sh
# in temp trees with stub generators.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

R="$TL_REPO_ROOT"
NOJQ="$(tl_path_without jq)"

# ---------------- regenerate-site-certification-status.sh ----------------
RT="$TL_TMP/regen"
mkdir -p "$RT/scripts"
cp "$R/scripts/regenerate-site-certification-status.sh" "$RT/scripts/"
RS="$RT/scripts/regenerate-site-certification-status.sh"
GEN="$RT/scripts/enterprise-e2e-certification-status.sh"

tl_run bash "$RS"
assert_eq "regen: generator missing -> 1" 1 "$TL_STATUS"
assert_contains "regen: generator missing msg" "$TL_ERR" "FAIL: missing $GEN"
printf '#!/usr/bin/env bash\necho nope\n' >"$GEN"   # not executable
tl_run bash "$RS"
assert_eq "regen: generator not executable -> 1" 1 "$TL_STATUS"

cat >"$GEN" <<'EOS'
#!/usr/bin/env bash
# stub: records args/env, writes artifact unless NOWRITE=1
echo "args=$* rtk=${RTK_DISABLED:-}" >>"$(dirname "$0")/gen.log"
[[ "${NOWRITE:-}" == 1 ]] && exit 0
mkdir -p "$(dirname "$SB_CERT_ARTIFACT")"
printf '{"generated_at":"2026-01-01T00:00:00Z","sb_git_sha":"abc123","hosts":%s}\n' "${HOSTS_JSON:-[1,2,3]}" >"$SB_CERT_ARTIFACT"
EOS
chmod +x "$GEN"

tl_run env NOWRITE=1 bash "$RS"
assert_eq "regen: generator wrote nothing -> 1" 1 "$TL_STATUS"
assert_contains "regen: not written msg" "$TL_ERR" "generator did not write $RT/.planning/enterprise-e2e/CERTIFICATION-STATUS.json"

tl_run bash "$RS"
assert_eq "regen: ok" 0 "$TL_STATUS"
assert_contains "regen: ok line" "$TL_OUT" "OK: site certification mirror @ 2026-01-01T00:00:00Z (abc123)"
assert_contains "regen: canonical rel path" "$TL_OUT" "canonical: .planning/enterprise-e2e/CERTIFICATION-STATUS.json"
assert_contains "regen: site rel path" "$TL_OUT" "site copy: site/help/data/certification-status.json"
assert_eq "regen: generator invoked with --write --json and RTK disabled" "args=--write --json rtk=1" "$(tail -1 "$RT/scripts/gen.log")"
assert_eq "regen: mirror identical" "$(cat "$RT/.planning/enterprise-e2e/CERTIFICATION-STATUS.json")" "$(cat "$RT/site/help/data/certification-status.json")"

tl_run env HOSTS_JSON='[1]' bash "$RS"
assert_eq "regen: wrong host count fails validation" 1 "$TL_STATUS"

# jq missing: copies without validating
rm -rf "$RT/site"
tl_run env PATH="$NOJQ" bash "$RS"
assert_eq "regen: no jq ok" 0 "$TL_STATUS"
assert_contains "regen: no jq message" "$TL_OUT" "jq not installed — skipped validation"
assert_file_exists "regen: no jq copy made" "$RT/site/help/data/certification-status.json"

# redirected outputs; canonical and site copy being the same file (hard link) is not re-copied
RD="$TL_TMP/regen-out"; mkdir -p "$RD"
tl_run env SB_CERT_ARTIFACT="$RD/c.json" SB_CERT_SITE_COPY="$RD/s.json" bash "$RS"
assert_eq "regen: redirected ok" 0 "$TL_STATUS"
assert_file_exists "regen: redirected canonical" "$RD/c.json"
assert_file_exists "regen: redirected site copy" "$RD/s.json"
ln -f "$RD/c.json" "$RD/linked.json"
tl_run env SB_CERT_ARTIFACT="$RD/c.json" SB_CERT_SITE_COPY="$RD/linked.json" PATH="$NOJQ" bash "$RS"
assert_eq "regen: same-file copy skipped, no jq" 0 "$TL_STATUS"
assert_contains "regen: no jq message (same file)" "$TL_OUT" "jq not installed"

# ---------------- export-enterprise-evidence.sh ----------------
ET="$TL_TMP/exp"
mkdir -p "$ET/scripts" "$ET/docs"
cp "$R/scripts/export-enterprise-evidence.sh" "$ET/scripts/"
EX="$ET/scripts/export-enterprise-evidence.sh"
PROJ="$TL_TMP/proj"; mkdir -p "$PROJ/.planning" "$PROJ/docs/sessions"
echo '{"evidence_records":[1],"intent_ledgers":[2],"composition_logs":[3],"v_loop_rollups":[4],"other":5}' >"$ET/docs/apo-catalog.json"
echo '{"ts":"x"}' >"$PROJ/.planning/orchestrator-composition-log.jsonl"
cat >"$PROJ/docs/sessions/s1.md" <<'EOM'
# Session
## Summary
ignored
## Active Intent Ledger
- claim one
## Next
after
EOM
echo 'plain' >"$PROJ/docs/sessions/not-md.txt"
echo 'target' >"$TL_TMP/outside.md"; ln -s "$TL_TMP/outside.md" "$PROJ/docs/sessions/link.md"
echo '{"enterprise_policy":{"p":1},"hooks":{"evidence_schema":{"s":2},"other":3},"orchestrator_mode":"parent","secret":"no"}' >"$PROJ/.silver-bullet.json"
# certification generator stub that writes to SB_CERT_ARTIFACT
printf '#!/usr/bin/env bash\necho "{\\"cert\\":true}" >"$SB_CERT_ARTIFACT"\n' >"$ET/scripts/enterprise-e2e-certification-status.sh"
chmod +x "$ET/scripts/enterprise-e2e-certification-status.sh"

OUT="$TL_TMP/out.zip"
unz() { unzip -p "$OUT" "$1"; }

tl_run env PATH="$NOJQ" bash "$EX" "$PROJ" "$OUT"
assert_eq "export: jq missing -> 1" 1 "$TL_STATUS"; assert_contains "export: jq msg" "$TL_ERR" "FAIL: jq required"
tl_run env PATH="$(tl_path_without zip)" bash "$EX" "$PROJ" "$OUT"
assert_eq "export: zip missing -> 1" 1 "$TL_STATUS"; assert_contains "export: zip msg" "$TL_ERR" "FAIL: zip required"

tl_run bash "$EX" "$PROJ" "$OUT"
assert_eq "export: ok" 0 "$TL_STATUS"
assert_contains "export: ok line" "$TL_OUT" "OK: enterprise evidence export → $OUT"
assert_contains "export: files line" "$TL_OUT" "files: "
assert_eq "export: catalog excerpt" '{"evidence_records":[1],"intent_ledgers":[2],"composition_logs":[3],"v_loop_rollups":[4]}' "$(unz evidence/apo-audit-entities.json | jq -c .)"
assert_eq "export: certification via generator" '{"cert":true}' "$(unz evidence/CERTIFICATION-STATUS.json | jq -c .)"
assert_eq "export: composition log copied" '{"ts":"x"}' "$(unz evidence/orchestrator-composition-log.jsonl)"
assert_eq "export: intent ledger extracted" "## Active Intent Ledger
- claim one
## Next" "$(unz evidence/session-logs/s1-intent-ledger.md)"
assert_eq "export: policy snapshot" '{"enterprise_policy":{"p":1},"hooks":{"evidence_schema":{"s":2}},"orchestrator_mode":"parent"}' "$(unz evidence/project-policy-snapshot.json | jq -c .)"
listing="$(unzip -Z1 "$OUT")"
assert_not_contains "export: symlinked session log skipped" "$listing" "link-intent-ledger.md"
assert_not_contains "export: non-md skipped" "$listing" "not-md"
assert_contains "export: manifest present" "$listing" "manifest.json"
assert_eq "export: manifest fields" '{"schema_version":1,"generator":"scripts/export-enterprise-evidence.sh","project_root":"'"$PROJ"'","sb_git_sha":"unknown"}' \
  "$(unz manifest.json | jq -c '{schema_version,generator,project_root,sb_git_sha}')"
# checksums are real sha256 sums of the staged files
sum_line="$(unz checksums.sha256 | grep 'evidence/orchestrator-composition-log.jsonl')"
want="$(printf '{"ts":"x"}\n' | sha256sum | awk '{print $1}')"
assert_eq "export: checksum value" "$want	evidence/orchestrator-composition-log.jsonl" "$sum_line"

# sha256sum fallback when shasum is missing; zipinfo missing -> fallback note; sb git sha when SB is a repo
tl_git_repo "$ET" >/dev/null 2>&1
tl_run env PATH="$(tl_path_without shasum zipinfo)" bash "$EX" "$PROJ" "$OUT"
assert_eq "export: no shasum/zipinfo ok" 0 "$TL_STATUS"
assert_contains "export: zipinfo fallback" "$TL_OUT" "files: (zip created)"
assert_match "export: git sha recorded" '^[0-9a-f]{12}$' "$(unz manifest.json | jq -r .sb_git_sha)"
assert_eq "export: checksum identical with sha256sum" "$want	evidence/orchestrator-composition-log.jsonl" "$(unz checksums.sha256 | grep 'evidence/orchestrator-composition-log.jsonl')"

# failing certification generator -> falls back to the tracked artifact (copied when present, ignored otherwise)
printf '#!/usr/bin/env bash\nexit 1\n' >"$ET/scripts/enterprise-e2e-certification-status.sh"
# (a fresh zip path: zip updates an existing archive in place and would keep stale entries)
rm -f "$OUT"
tl_run bash "$EX" "$PROJ" "$OUT"
assert_eq "export: generator failure, no tracked artifact -> still ok" 0 "$TL_STATUS"
assert_not_contains "export: no cert entry" "$(unzip -Z1 "$OUT")" "CERTIFICATION-STATUS.json"
mkdir -p "$ET/.planning/enterprise-e2e"; echo '{"tracked":true}' >"$ET/.planning/enterprise-e2e/CERTIFICATION-STATUS.json"
tl_run bash "$EX" "$PROJ" "$OUT"
assert_eq "export: fallback copies tracked artifact" '{"tracked":true}' "$(unz evidence/CERTIFICATION-STATUS.json | jq -c .)"

# minimal project: no catalog, no cert script, no logs/sessions/config; default output dir and timestamped name
EM="$TL_TMP/exp-min"; mkdir -p "$EM/scripts"; cp "$EX" "$EM/scripts/"
PM="$TL_TMP/proj-min"; mkdir -p "$PM"
tl_run bash "$EM/scripts/export-enterprise-evidence.sh" "$PM"
assert_eq "export: minimal ok" 0 "$TL_STATUS"
zipf="$(ls "$PM"/dist/enterprise-evidence-*.zip)"
assert_match "export: default zip name" 'enterprise-evidence-[0-9]{8}T[0-9]{6}Z\.zip$' "$zipf"
assert_not_contains "export: minimal has no evidence entries" "$(unzip -Z1 "$zipf")" "evidence/apo-audit-entities.json"
assert_contains "export: minimal still has manifest" "$(unzip -Z1 "$zipf")" "manifest.json"
# an unparseable project config does not abort the export
echo '{bad' >"$PM/.silver-bullet.json"
tl_run bash "$EM/scripts/export-enterprise-evidence.sh" "$PM" "$TL_TMP/min2.zip"
assert_eq "export: bad project config tolerated" 0 "$TL_STATUS"
# symlinked composition log and sessions dir are not followed
PL2="$TL_TMP/proj-links"; mkdir -p "$PL2/.planning" "$TL_TMP/real-sessions"
echo '{}' >"$TL_TMP/real.jsonl"; ln -s "$TL_TMP/real.jsonl" "$PL2/.planning/orchestrator-composition-log.jsonl"
mkdir -p "$PL2/docs"; ln -s "$TL_TMP/real-sessions" "$PL2/docs/sessions"
tl_run bash "$EM/scripts/export-enterprise-evidence.sh" "$PL2" "$TL_TMP/links.zip"
assert_eq "export: symlinks ok" 0 "$TL_STATUS"
assert_not_contains "export: symlinked log not bundled" "$(unzip -Z1 "$TL_TMP/links.zip")" "orchestrator-composition-log"
assert_not_contains "export: symlinked sessions not bundled" "$(unzip -Z1 "$TL_TMP/links.zip")" "session-logs"

tl_results
