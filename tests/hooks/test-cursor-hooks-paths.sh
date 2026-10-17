#!/usr/bin/env bash
# Regression: every command in cursor-hooks.json resolves to an existing hook script.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

PASS=0
FAIL=0

pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL=$((FAIL + 1))
}

echo "=== cursor-hooks path resolution tests ==="

manifests=(
  "${REPO_ROOT}/hooks/cursor-hooks.json"
  "${REPO_ROOT}/plugins/silver-bullet/cursor-hooks.json"
)

for manifest in "${manifests[@]}"; do
  if [[ -f "$manifest" ]]; then
    pass "manifest exists: ${manifest#"$REPO_ROOT"/}"
  else
    fail "manifest exists: ${manifest#"$REPO_ROOT"/}"
    continue
  fi
done

if [[ -f "${manifests[0]}" && -f "${manifests[1]}" ]]; then
  if cmp -s "${manifests[0]}" "${manifests[1]}"; then
    pass "hooks and plugin cursor-hooks.json are identical"
  else
    fail "hooks and plugin cursor-hooks.json are identical"
  fi
fi

validation_lines=()
while IFS= read -r line; do
  validation_lines+=("$line")
done < <(
  python3 - "$REPO_ROOT" "${manifests[@]}" <<'PY'
import json
import shlex
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
manifests = [Path(p) for p in sys.argv[2:] if Path(p).is_file()]
plugin_root = repo_root / "plugins" / "silver-bullet"
PLUGIN_ROOT = "${CURSOR_PLUGIN_ROOT}"


def extract_hook_path(command: str) -> str:
    command = command.replace("${CLAUDE_PLUGIN_ROOT}", PLUGIN_ROOT)
    if "/cursor-hook-bridge.sh" in command:
        try:
            parts = shlex.split(command)
        except ValueError:
            parts = command.split()
        if len(parts) >= 3:
            return parts[2]
        return command.strip('"')
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()
    adapter_idx = next(
        (index for index, part in enumerate(parts) if "codex-hook-adapter" in part),
        None,
    )
    if adapter_idx is not None and len(parts) > adapter_idx + 2:
        return parts[adapter_idx + 2].replace("${CLAUDE_PLUGIN_ROOT}", PLUGIN_ROOT)
    if parts:
        return parts[-1].replace("${CLAUDE_PLUGIN_ROOT}", PLUGIN_ROOT)
    return command.strip('"')


def resolve_path(raw_path: str) -> Path:
    if raw_path.startswith(PLUGIN_ROOT):
        suffix = raw_path[len(PLUGIN_ROOT):].lstrip("/")
        return plugin_root / suffix
    path = Path(raw_path)
    if path.is_absolute():
        return path
    return repo_root / path


for manifest in manifests:
    rel = manifest.relative_to(repo_root)
    data = json.loads(manifest.read_text(encoding="utf-8"))
    for event, entries in data.get("hooks", {}).items():
        for index, entry in enumerate(entries):
            command = entry.get("command", "")
            label = f"{rel} {event}[{index}]"
            if "codex-hook-adapter" in command:
                print(f"MALFORMED|{label}|codex-hook-adapter present")
                continue
            hook_path = extract_hook_path(command)
            if not hook_path:
                print(f"MISSING|{label}|empty hook path")
                continue
            path = resolve_path(hook_path)
            if path.exists():
                print(f"OK|{label}|{path}")
            else:
                print(f"MISSING|{label}|{path}")
            if "/cursor-hook-bridge.sh" in command:
                bridge = plugin_root / "hooks" / "cursor-hook-bridge.sh"
                if bridge.exists():
                    print(f"BRIDGE_OK|{label}|{bridge}")
                else:
                    print(f"BRIDGE_MISSING|{label}|{bridge}")
PY
)

malformed_count=0
missing_count=0
bridge_missing_count=0
checked_count=0

for line in "${validation_lines[@]}"; do
  kind="${line%%|*}"
  rest="${line#*|}"
  case "$kind" in
    OK)
      checked_count=$((checked_count + 1))
      ;;
    BRIDGE_OK)
      ;;
    MALFORMED)
      fail "$rest"
      malformed_count=$((malformed_count + 1))
      ;;
    MISSING)
      fail "hook path missing — $rest"
      missing_count=$((missing_count + 1))
      ;;
    BRIDGE_MISSING)
      fail "bridge path missing — $rest"
      bridge_missing_count=$((bridge_missing_count + 1))
      ;;
  esac
done

if [[ "$malformed_count" -eq 0 ]]; then
  pass "no malformed codex-hook-adapter commands (${checked_count} hook paths checked)"
else
  fail "malformed codex-hook-adapter commands — count ${malformed_count}"
fi

if [[ "$missing_count" -eq 0 ]]; then
  pass "all hook script paths exist"
else
  fail "missing hook script paths — count ${missing_count}"
fi

if [[ "$bridge_missing_count" -eq 0 ]]; then
  pass "all cursor-hook-bridge paths resolve under plugin root"
else
  fail "missing bridge paths — count ${bridge_missing_count}"
fi

echo
echo "Passed: $PASS"
echo "Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
