#!/usr/bin/env bash
# Tests for scripts/validate-host-agnostic-core.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/validate-host-agnostic-core.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

write_skill() {
  local root="$1" dir="$2" body="${3:-# test}"
  mkdir -p "${root}/${dir}"
  cat >"${root}/${dir}/SKILL.md" <<EOF
---
name: ${dir##*/}
description: test
---
${body}
EOF
}

clean_root="$(mktemp -d)"
dirty_root="$(mktemp -d)"
cross_root="$(mktemp -d)"
trap 'rm -rf "$clean_root" "$dirty_root" "$cross_root"' EXIT

seed_clean() {
  local root="$1"
  mkdir -p "$root/skills/silver" "$root/templates" "$root/hooks/lib" "$root/scripts"
  write_skill "$root" "skills/silver" "# host-neutral skill"
  printf '# SB core\n\nUse SILVER_BULLET_RUNTIME and host installers.\n' >"$root/silver-bullet.md"
  printf '# runtime\nSILVER_BULLET_RUNTIME="claude"\n' >"$root/hooks/lib/runtime-paths.sh"
  cat >"$root/scripts/install-claude.sh" <<'EOF'
#!/usr/bin/env bash
echo claude-only installer
EOF
  cat >"$root/scripts/install-codex.sh" <<'EOF'
#!/usr/bin/env bash
echo codex-only installer
EOF
  cat >"$root/scripts/install-cursor.sh" <<'EOF'
#!/usr/bin/env bash
echo cursor-only installer
EOF
  chmod +x "$root/scripts/install-"*.sh
}

seed_clean "$clean_root"
seed_clean "$dirty_root"
write_skill "$dirty_root" "skills/foo" "Use codex native mirror paths here."

seed_clean "$cross_root"
cat >"$cross_root/scripts/install-claude.sh" <<'EOF'
#!/usr/bin/env bash
bash scripts/install-cursor.sh
EOF
chmod +x "$cross_root/scripts/install-claude.sh"

if bash "$SCRIPT" --repo-root "$clean_root" >/dev/null 2>&1; then
  pass "clean core fixture passes"
else
  fail "clean core fixture passes"
fi

if bash "$SCRIPT" --repo-root "$dirty_root" >/dev/null 2>&1; then
  fail "injected codex reference in skills/foo should fail"
else
  pass "injected codex reference in skills/foo fails"
fi

if bash "$SCRIPT" --repo-root "$cross_root" >/dev/null 2>&1; then
  fail "install-claude cross-reference to cursor should fail"
else
  pass "install-claude cross-reference to cursor fails"
fi

# --- R8-05: forms and places the scan used to miss -----------------------------
probe_root="$(mktemp -d)"
trap 'rm -rf "$clean_root" "$dirty_root" "$cross_root" "$probe_root"' EXIT
# expect_verdict <want-rc> <description> <needle-or-empty>: run on $probe_root.
expect_verdict() {
  local want="$1" desc="$2" needle="${3:-}" out rc=0
  out="$(bash "$SCRIPT" --repo-root "$probe_root" 2>&1)" || rc=$?
  if [[ "$rc" -eq "$want" && ( -z "$needle" || "$out" == *"$needle"* ) ]]; then
    pass "$desc"
  else
    fail "$desc (rc=$rc) $(printf '%s' "$out" | tail -3)"
  fi
  rm -rf "$probe_root"
  probe_root="$(mktemp -d)"
  seed_clean "$probe_root"
}
seed_clean "$probe_root"

for form in '"$HOME/.claude/settings.json"' '"${HOME}/.codex/config.toml"' '"$HOME"/.cursor/plugins'; do
  mkdir -p "$probe_root/hooks/lib"
  printf '#!/usr/bin/env bash\ncat %s\n' "$form" >"$probe_root/hooks/lib/probe-foreign.sh"
  expect_verdict 1 "hook library reading $form fails" 'hooks/lib/probe-foreign.sh:2: $HOME/.<host>'
done
printf '#!/usr/bin/env bash\nrm -rf "${HOME}/.cursor/x"\n' >"$probe_root/scripts/shared-helper.sh"
expect_verdict 1 "shared script with \${HOME}/.cursor fails" "scripts/shared-helper.sh:2"
# Grandfathered runtime-boundary file: the \$HOME form stays allowed there only.
mkdir -p "$probe_root/hooks/lib"
printf 'state="${SB_RUNTIME_STATE_DIR:-${HOME}/.cursor/.silver-bullet}"\n' >"$probe_root/hooks/lib/token-compression-tools-gate.sh"
expect_verdict 0 "allowlisted runtime file keeps its \$HOME default"

mkdir -p "$probe_root/skills/silver-x/scripts"
printf 'const p = "~/.claude/settings.json"; // Claude Code\n' >"$probe_root/skills/silver-x/scripts/probe.js"
expect_verdict 1 "a .js file under skills/ is scanned" "skills/silver-x/scripts/probe.js:1"
printf 'home = "~/.codex"\n' >"$probe_root/templates/probe.toml"
expect_verdict 1 "a .toml file under templates/ is scanned" "templates/probe.toml:1"
mkdir -p "$probe_root/skills/silver-x"
printf '\x00\x01binary ~/.claude\x00' >"$probe_root/skills/silver-x/blob.bin"
expect_verdict 0 "binary files are skipped"

mkdir -p "$probe_root/skills/silver-x/scripts"
printf '#!/usr/bin/env bash\necho "Claude Code at ~/.claude/settings.json"\n' >"$probe_root/skills/silver-x/scripts/agent-helper.sh"
expect_verdict 1 "skills/*/scripts/agent-* is not excluded by a substring match" "skills/silver-x/scripts/agent-helper.sh:2"
mkdir -p "$probe_root/skills/silver-x/scripts"
printf '#!/usr/bin/env bash\necho "Claude Code at ~/.claude/settings.json"\n' >"$probe_root/skills/silver-x/scripts/sync-helper.sh"
expect_verdict 1 "skills/*/scripts/sync-* is not excluded by a substring match" "skills/silver-x/scripts/sync-helper.sh:2"

printf '#!/usr/bin/env bash\nrm -rf "$HOME/.codex/plugins"  # validate-host\n' >"$probe_root/scripts/install-claude.sh"
expect_verdict 1 "a skip marker inside a comment does not exempt an installer line" "scripts/install-claude.sh:2: foreign host 'codex'"
printf '#!/usr/bin/env bash\nrm -rf "$HOME/.codex/plugins"; : validate-host\n' >"$probe_root/scripts/install-claude.sh"
expect_verdict 1 "an annotation word inside the code part (a no-op argument) does not exempt the line" "scripts/install-claude.sh:2: foreign host 'codex'"
printf '#!/usr/bin/env bash\n# Codex and Cursor installs live in their own scripts.\necho claude-only\n' >"$probe_root/scripts/install-claude.sh"
expect_verdict 0 "an installer comment may name other hosts"
printf '#!/usr/bin/env bash\nrender_agent_bundle "codex"\n' >"$probe_root/scripts/install-claude.sh"
expect_verdict 0 "a structural path marker in code (render_agent_bundle) still exempts the line"

if bash "$SCRIPT" --repo-root "$REPO_ROOT" >/dev/null 2>&1; then
  pass "live repo passes validate-host-agnostic-core"
else
  fail "live repo passes validate-host-agnostic-core"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
