#!/usr/bin/env bash
# sb-doctor.sh core checks D1-D9 and D12, argument parsing and the JSON/text summary,
# against a staged repo (tests/lib/h-doctor-stage.sh) with a Claude install in the
# sandboxed HOME. Each scenario breaks one thing in an otherwise passing install.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-doctor-stage.sh"
cd "$TL_TMP"
unset SB_DOCTOR_FIX SB_DOCTOR_FIX_SCOPE SB_DOCTOR_DEEP SB_DOCTOR_DRY_RUN SB_DOCTOR_FORMAT SB_DOCTOR_RECONCILER SB_DOCTOR_ASSUME_YES SB_DOCTOR_STUB_HOST_INSTALL
hd_stage
C='SILVER_BULLET_RUNTIME=claude'
run() { hd_run "$C" "$@"; }
J='SB_DOCTOR_FORMAT=json'
REG="$HOME/.claude/plugins/installed_plugins.json"

# ---------- happy path ----------
hd_happy claude
run -- "$HD_PROJ"
assert_eq "healthy install exits 0" "0" "$TL_STATUS"
assert_contains "overall pass" "$TL_OUT" "OVERALL: PASS"
assert_contains "summary counts" "$TL_OUT" "Silver Bullet doctor: 26 PASS, 1 WARN, 0 FAIL"
assert_contains "D1" "$TL_OUT" "PASS: D1 — jq on PATH (jq-"
assert_contains "D2" "$TL_OUT" "PASS: D2 — silver-bullet@alo-labs version $HD_VER (install: $HOME/.claude/plugins/cache/alo-labs/silver-bullet/$HD_VER, registry: $REG)"
assert_contains "D3" "$TL_OUT" "PASS: D3 — current symlink → $HOME/.claude/plugins/cache/alo-labs/silver-bullet/$HD_VER"
assert_contains "D5" "$TL_OUT" "PASS: D5 — project activated"
assert_contains "D6" "$TL_OUT" "PASS: D6 — config_version $HD_VER (template $HD_VER)"
assert_contains "D9" "$TL_OUT" "PASS: D9 — scripts/workflows.sh executable; docs/workflows/ present"
assert_contains "D12" "$TL_OUT" "PASS: D12 — $HOME/.claude/.silver-bullet writable"
pwd_out="$(cd "$HD_PROJ" && env "$C" bash "$HD_ST/scripts/sb-doctor.sh" 2>&1)"
assert_contains "project root defaults to PWD" "$pwd_out" "PASS: D5 — project activated"

# ---------- arguments and summary formats ----------
hd_run "$C" -- --help
assert_eq "help exits 0" "0" "$TL_STATUS"
assert_contains "help shows the usage header" "$TL_OUT" "Usage:"
assert_contains "help lists --deep" "$TL_OUT" "--deep          Bounded expensive probes (read-only)"
assert_contains "help lists --fix" "$TL_OUT" "--fix[=SCOPE]   Apply repair: local|host|packages|all (default all)"
run -- -h
assert_eq "-h exits 0" "0" "$TL_STATUS"
run -- --fix=bogus "$HD_PROJ"
assert_eq "invalid fix scope exits 2" "2" "$TL_STATUS"
assert_contains "invalid fix scope message" "$TL_ERR" "ERROR: --fix scope must be local|host|packages|all"
hd_run "$C" "$J" -- --dry-run --deep --fix=local "$HD_PROJ"
assert_eq "json summary schema" "2.0.0" "$(jq -r '.schema' <<<"$TL_OUT")"
assert_eq "json flags" "true|true|local" "$(jq -r '"\(.deep)|\(.dry_run)|\(.fix_scope)"' <<<"$TL_OUT")"
assert_eq "json fix not applied in dry-run" "false" "$(jq -r '.fix_applied' <<<"$TL_OUT")"
assert_eq "json carries the reconciler payload" "graphify" "$(jq -r '.reconciler.components[0].component' <<<"$TL_OUT")"
assert_contains "json lines include checks" "$(jq -r '.lines | join("\n")' <<<"$TL_OUT")" "PASS: D1 — jq on PATH"
assert_eq "json mode prints only the summary document" "{" "${TL_OUT%%$'\n'*}"
hd_run "$C" "$J" -- "$HD_PROJ"
assert_eq "json fix scope defaults to all" "all" "$(jq -r '.fix_scope' <<<"$TL_OUT")"
hd_run "$C" "$J" -- --fix --dry-run "$HD_PROJ"
assert_eq "--fix defaults to scope all" "all" "$(jq -r '.fix_scope' <<<"$TL_OUT")"
hd_run "$C" "$J" SB_DOCTOR_FIX_SCOPE=packages -- --fix --dry-run "$HD_PROJ"
assert_eq "--fix keeps the scope from the environment" "packages" "$(jq -r '.fix_scope' <<<"$TL_OUT")"
hd_run "$C" "$J" SB_DOCTOR_FIX=1 SB_DOCTOR_DRY_RUN=1 SB_DOCTOR_DEEP=1 -- "$HD_PROJ"
assert_eq "environment switches" "true|true" "$(jq -r '"\(.deep)|\(.dry_run)"' <<<"$TL_OUT")"
hd_run "$C" "$J" STUB_RECON_JSON= -- "$HD_PROJ"
assert_eq "json reconciler is null when it printed nothing" "null" "$(jq -r '.reconciler' <<<"$TL_OUT")"

# ---------- D1: jq ----------
NJ="$(hr_path_without jq)"
tl_run env PATH="$NJ" "$C" bash "$HD_ST/scripts/sb-doctor.sh" "$HD_PROJ"
assert_eq "missing jq exits 1" "1" "$TL_STATUS"
assert_contains "missing jq is reported" "$TL_OUT" "FAIL: D1 — jq missing — SB hooks fail-open without jq"
assert_contains "missing jq still prints the summary" "$TL_OUT" "OVERALL: FAIL"
tl_run env PATH="$NJ" "$C" "$J" bash "$HD_ST/scripts/sb-doctor.sh" "$HD_PROJ"
assert_eq "missing jq with json format exits 1" "1" "$TL_STATUS"
assert_contains "missing jq falls back to the text summary" "$TL_OUT" "OVERALL: FAIL"

# ---------- D2: plugin registry ----------
setreg() { printf '%s\n' "$1" >"$REG"; }
setreg "{\"plugins\":{\"silver-bullet@alo-labs\":{\"version\":\"$HD_VER\",\"installPath\":\"/x\"}}}"
run -- "$HD_PROJ"
assert_contains "object-style registry entry" "$TL_OUT" "PASS: D2 — silver-bullet@alo-labs version $HD_VER (install: /x,"
setreg "{\"plugins\":{\"silver-bullet@alo-labs-codex\":{\"version\":\"$HD_VER\"}}}"
run -- "$HD_PROJ"
assert_contains "falls back to the codex registry id" "$TL_OUT" "PASS: D2 — silver-bullet@alo-labs version $HD_VER (install: unknown,"
setreg "{\"plugins\":{\"silver-bullet@silver-bullet\":[{\"version\":\"$HD_VER\"}]}}"
run -- "$HD_PROJ"
assert_contains "falls back to the plain registry id" "$TL_OUT" "PASS: D2 — silver-bullet@alo-labs version $HD_VER"
setreg '{"plugins":{"silver-bullet@alo-labs":[{"version":"0.1.0"}]}}'
run -- "$HD_PROJ"
assert_eq "old plugin version exits 1" "1" "$TL_STATUS"
assert_contains "old plugin version fails D2" "$TL_OUT" "FAIL: D2 — plugin version 0.1.0 < template config_version $HD_VER"
setreg '{"plugins":{"silver-bullet@alo-labs":[{"version":"99.0.0-rc.1"}]}}'
run -- "$HD_PROJ"
assert_contains "pre-release suffix is ignored when comparing" "$TL_OUT" "PASS: D2 — silver-bullet@alo-labs version 99.0.0-rc.1"
setreg '{"plugins":{"silver-bullet@alo-labs":[{"version":"latest"}]}}'
run -- "$HD_PROJ"
assert_eq "non-numeric plugin version does not abort the audit" "1" "$TL_STATUS"
assert_contains "non-numeric plugin version fails D2" "$TL_OUT" "FAIL: D2 — plugin version latest < template config_version $HD_VER"
assert_contains "audit continues after a non-numeric version" "$TL_OUT" "OVERALL: FAIL"
assert_not_contains "no arithmetic errors on a non-numeric version" "$TL_ERR" "value too great for base"
setreg '{"plugins":{"silver-bullet@alo-labs":[{"version":"v99.1.2"}]}}'
run -- "$HD_PROJ"
assert_contains "v-prefixed version compares numerically" "$TL_OUT" "PASS: D2 — silver-bullet@alo-labs version v99.1.2"
setreg '{"plugins":{}}'
run -- "$HD_PROJ"
assert_contains "no plugin entry" "$TL_OUT" "FAIL: D2 — no silver-bullet plugin entry in $REG"
setreg '{"plugins":{"silver-bullet@alo-labs":[{"version":null}]}}'
run -- "$HD_PROJ"
assert_contains "null plugin version" "$TL_OUT" "FAIL: D2 — no silver-bullet plugin entry in $REG"
rm -f -- "${REG:?}"
run -- "$HD_PROJ"
assert_contains "registry missing" "$TL_OUT" "FAIL: D2 — plugin registry missing: $REG"

# ---------- D2/D4: Codex skills-only surface ----------
hd_happy codex
CX="$HOME/.codex"
CXR=(SILVER_BULLET_RUNTIME=codex)
cx() { hd_run "${CXR[@]}" "$@"; }
cx -- "$HD_PROJ"
assert_contains "codex registry entry" "$TL_OUT" "PASS: D2 — silver-bullet@alo-labs version"
assert_contains "codex D4 via config.toml" "$TL_OUT" "PASS: D4 — Codex config.toml references silver-bullet hooks"
mkdir -p "$CX/skills/silver" "$CX/skills/silver:agent-codex"
touch "$CX/skills/silver/SKILL.md" "$CX/skills/silver:agent-codex/SKILL.md"
rm -f -- "${CX:?}/plugins/installed_plugins.json" "${CX:?}/config.toml"
cx -- "$HD_PROJ"
assert_contains "skills-only D2 without a registry" "$TL_OUT" "PASS: D2 — Codex skills-only Silver Bullet surface active"
assert_contains "skills-only D4" "$TL_OUT" "PASS: D4 — Codex skills-only surface active; SB hooks intentionally absent"
echo '{"plugins":{}}' >"$CX/plugins/installed_plugins.json"
cx -- "$HD_PROJ"
assert_contains "skills-only D2 with an empty registry" "$TL_OUT" "PASS: D2 — Codex skills-only Silver Bullet surface active"
echo '{"plugins":{"silver-bullet@elsewhere":[{"version":"0.0.0"}]}}' >"$CX/plugins/installed_plugins.json"
cx -- "$HD_PROJ"
assert_contains "a registered plugin ends the skills-only mode" "$TL_OUT" "FAIL: D4 — Codex config.toml missing SB hook entries"
echo '{"plugins":{}}' >"$CX/plugins/installed_plugins.json"
echo '[hooks.state."silver-bullet@alo-labs-codex:x"]' >"$CX/config.toml"
cx -- "$HD_PROJ"
assert_contains "hook state in config.toml satisfies D4" "$TL_OUT" "PASS: D4 — Codex config.toml references silver-bullet hooks"
printf '[other]\n' >"$CX/config.toml"
cx -- "$HD_PROJ"
assert_contains "unrelated config.toml keeps skills-only" "$TL_OUT" "PASS: D4 — Codex skills-only surface active"
echo '[plugins."silver-bullet@alo-labs-codex"]' >"$CX/config.toml"
cx -- "$HD_PROJ"
assert_contains "plugin entry in config.toml is not skills-only" "$TL_OUT" "PASS: D4 — Codex config.toml references silver-bullet hooks"
rm -f -- "${CX:?}/config.toml"
echo '{"hooks":"silver-bullet"}' >"$CX/hooks.json"
cx -- "$HD_PROJ"
assert_contains "hooks.json mentioning silver-bullet is not skills-only" "$TL_OUT" "FAIL: D4 — Codex config.toml missing SB hook entries"
rm -f -- "${CX:?}/hooks.json"
rm -f -- "${CX:?}/skills/silver:agent-codex/SKILL.md"
cx -- "$HD_PROJ"
assert_contains "missing agent skill is not skills-only" "$TL_OUT" "FAIL: D2 — "
rm -f -- "${CX:?}/skills/silver/SKILL.md"
cx -- "$HD_PROJ"
assert_contains "missing silver skill is not skills-only" "$TL_OUT" "FAIL: D2 — "
hd_happy claude

# ---------- D3: plugin cache ----------
CUR="$HOME/.claude/plugins/cache/alo-labs/silver-bullet"
rm -f -- "${CUR:?}/$HD_VER/hooks/hooks.json"
run -- "$HD_PROJ"
assert_contains "hooks.json missing in cache" "$TL_OUT" "FAIL: D3 — hooks/hooks.json missing under $CUR/$HD_VER"
rm -f -- "${CUR:?}/current"
run -- "$HD_PROJ"
assert_contains "missing current symlink" "$TL_OUT" "FAIL: D3 — broken or missing current symlink at $CUR/current"
ln -s "$TL_TMP/nowhere" "$CUR/current"
run -- "$HD_PROJ"
assert_contains "dangling current symlink" "$TL_OUT" "FAIL: D3 — broken or missing current symlink"
hd_happy claude

# ---------- D4: hook manifests per host ----------
echo '{}' >"$HOME/.claude/settings.json"
run -- "$HD_PROJ"
assert_contains "claude settings without hooks" "$TL_OUT" "FAIL: D4 — Claude settings.json missing SB hook entries"
hd_happy codex
rm -f -- "${HOME:?}/.codex/config.toml"
cx -- "$HD_PROJ"
assert_contains "codex config.toml missing" "$TL_OUT" "FAIL: D4 — Codex config.toml missing SB hook entries"
hd_happy cursor
CU=(SILVER_BULLET_RUNTIME=cursor)
cu() { hd_run "${CU[@]}" "$@"; }
cu -- "$HD_PROJ"
assert_contains "cursor hooks via the bridge" "$TL_OUT" "PASS: D4 — Cursor hooks.json references silver-bullet via cursor-hook-bridge.sh"
echo '{"hooks":"silver-bullet"}' >"$HOME/.cursor/hooks.json"
cu -- "$HD_PROJ"
assert_contains "cursor hooks without the bridge" "$TL_OUT" "FAIL: D4 — Cursor hooks.json has silver-bullet entries without cursor-hook-bridge.sh"
echo '{}' >"$HOME/.cursor/hooks.json"
cu -- "$HD_PROJ"
assert_contains "cursor hooks without silver-bullet" "$TL_OUT" "FAIL: D4 — Cursor hooks.json missing SB hook entries"
rm -f -- "${HOME:?}/.cursor/hooks.json"
cu -- "$HD_PROJ"
assert_contains "cursor hooks.json missing" "$TL_OUT" "FAIL: D4 — Cursor hooks.json missing SB hook entries"
hd_run SILVER_BULLET_RUNTIME=opencode -- "$HD_PROJ"
assert_contains "unsupported host runtime" "$TL_OUT" "FAIL: D4 — unsupported host runtime: opencode"
assert_contains "foreign-host checks are N/A" "$TL_OUT" "PASS: D13 — cross-host contamination check N/A (host=opencode)"

# ---------- D5 / D6 / D9: project ----------
hd_happy claude
rm -f -- "${HD_PROJ:?}/silver-bullet.md"
run -- "$HD_PROJ"
assert_contains "missing silver-bullet.md" "$TL_OUT" "FAIL: D5 — missing .silver-bullet.json or silver-bullet.md under $HD_PROJ"
echo '# SB' >"$HD_PROJ/silver-bullet.md"
hd_cfg "{\"sb_initiated\":false,\"config_version\":\"$HD_VER\"}"
run -- "$HD_PROJ"
assert_contains "sb_initiated false" "$TL_OUT" "FAIL: D5 — sb_initiated is not true in $HD_PROJ/.silver-bullet.json"
hd_cfg '{"sb_initiated":true,"config_version":"0.1.0"}'
run -- "$HD_PROJ"
assert_contains "stale project config" "$TL_OUT" "FAIL: D6 — project config_version 0.1.0 < template $HD_VER"
hd_cfg "{\"sb_initiated\":true,\"version\":\"$HD_VER\"}"
run -- "$HD_PROJ"
assert_contains "version key accepted" "$TL_OUT" "PASS: D6 — config_version $HD_VER"
hd_cfg '{"sb_initiated":true}'
run -- "$HD_PROJ"
assert_contains "config without a version" "$TL_OUT" "FAIL: D6 — project config_version 0.0.0 < template $HD_VER"
hd_cfg '{"sb_initiated":true,"config_version":"abc"}'
run -- "$HD_PROJ"
assert_eq "non-numeric project version does not abort" "1" "$TL_STATUS"
assert_contains "non-numeric project version" "$TL_OUT" "FAIL: D6 — project config_version abc < template $HD_VER"
rm -f -- "${HD_PROJ:?}/.silver-bullet.json"
run -- "$HD_PROJ"
assert_contains "no config to compare" "$TL_OUT" "FAIL: D6 — no .silver-bullet.json to compare"
hd_happy claude
rm -rf -- "${HD_PROJ:?}/docs/workflows"
run -- "$HD_PROJ"
assert_contains "workflow tracker incomplete" "$TL_OUT" "FAIL: D9 — workflow tracker incomplete"
hd_happy claude
chmod -x "$HD_PROJ/scripts/workflows.sh"
run -- "$HD_PROJ"
assert_contains "workflows.sh not executable" "$TL_OUT" "FAIL: D9 — workflow tracker incomplete"

# template version sources
hd_happy claude
mkdir -p "$HD_PROJ/templates"
printf '{"config_version":"0.9.9"}\n' >"$HD_PROJ/templates/silver-bullet.config.json.default"
run -- "$HD_PROJ"
assert_contains "project template overrides the repo template" "$TL_OUT" "PASS: D6 — config_version $HD_VER (template 0.9.9)"
rm -rf -- "${HD_PROJ:?}/templates"
rm -f -- "${HD_ST:?}/templates/silver-bullet.config.json.default"
hd_cfg '{"sb_initiated":true,"config_version":"1.2.3"}'
run -- "$HD_PROJ"
assert_contains "package.json version when no template exists" "$TL_OUT" "PASS: D6 — config_version 1.2.3 (template 1.2.3)"
rm -f -- "${HD_ST:?}/package.json"
run -- "$HD_PROJ"
assert_contains "0.0.0 when neither template nor package.json exists" "$TL_OUT" "(template 0.0.0)"
hd_stage
hd_happy claude

# ---------- D7: template parity ----------
run STUB_RC_PARITY=1 -- "$HD_PROJ"
assert_contains "parity failure" "$TL_OUT" "FAIL: D7 — template parity test failed"
rm -f -- "${HD_ST:?}/tests/scripts/test-silver-bullet-template-parity.sh"
run -- "$HD_PROJ"
assert_contains "parity script missing" "$TL_OUT" "WARN: D7 — parity test script not found; skipped"
printf 'exit 0\n' >"$HD_ST/tests/scripts/test-silver-bullet-template-parity.sh"
run -- "$HD_PROJ"
assert_contains "non-executable parity script still runs" "$TL_OUT" "PASS: D7 — silver-bullet.md template parity test passed"

# ---------- D8: Cursor rule ----------
hd_happy cursor
rm -f -- "${HD_PROJ:?}/.cursor/rules/silver-orchestrator.mdc"
cu -- "$HD_PROJ"
assert_contains "cursor orchestrator rule missing" "$TL_OUT" "FAIL: D8 — .cursor/rules/silver-orchestrator.mdc missing"
echo x >"$HD_PROJ/.cursor/rules/silver-orchestrator.mdc"
cu -- "$HD_PROJ"
assert_contains "cursor orchestrator rule present" "$TL_OUT" "PASS: D8 — .cursor/rules/silver-orchestrator.mdc present"

# ---------- D12: state directory ----------
hd_happy claude
rm -rf -- "${HOME:?}/.claude/.silver-bullet"
: >"$HOME/.claude/.silver-bullet"
run -- "$HD_PROJ"
assert_eq "unusable state dir exits 1" "1" "$TL_STATUS"
assert_contains "unusable state dir is reported, not fatal" "$TL_OUT" "FAIL: D12 — $HOME/.claude/.silver-bullet not writable"
assert_contains "audit continues after D12" "$TL_OUT" "PASS: D17"
rm -f -- "${HOME:?}/.claude/.silver-bullet"
# runtime-paths.sh absent: the Claude home is derived from the runtime name
rm -f -- "${HD_ST:?}/hooks/lib"
mkdir -p "$HD_ST/hooks/lib"
for f in "$TL_REPO_ROOT"/hooks/lib/*; do
  [[ "${f##*/}" == runtime-paths.sh ]] || ln -s "$f" "$HD_ST/hooks/lib/${f##*/}"
done
hd_happy claude
run -- "$HD_PROJ"
assert_contains "fallback D12" "$TL_OUT" "PASS: D12 — $HOME/.silver-bullet writable (fallback)"
assert_contains "fallback runtime paths drive D4" "$TL_OUT" "PASS: D4 — Claude settings.json references silver-bullet hooks"
rm -rf -- "${HOME:?}/.silver-bullet"
: >"$HOME/.silver-bullet"
run -- "$HD_PROJ"
assert_contains "unusable fallback state dir" "$TL_OUT" "FAIL: D12 — state dir not writable"
rm -f -- "${HOME:?}/.silver-bullet"
if [[ "$(id -u)" -eq 0 ]]; then
  echo "SKIP: read-only state directory (needs a non-root user)"
else
  mkdir -p "$HOME/.silver-bullet"
  chmod 555 "$HOME/.silver-bullet"
  run -- "$HD_PROJ"
  assert_contains "read-only fallback state dir" "$TL_OUT" "FAIL: D12 — state dir not writable"
  chmod 755 "$HOME/.silver-bullet"
fi

tl_results
