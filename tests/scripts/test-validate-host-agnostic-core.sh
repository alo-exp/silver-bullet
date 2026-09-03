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

if bash "$SCRIPT" --repo-root "$REPO_ROOT" >/dev/null 2>&1; then
  pass "live repo passes validate-host-agnostic-core"
else
  fail "live repo passes validate-host-agnostic-core"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
