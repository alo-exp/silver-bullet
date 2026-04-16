#!/usr/bin/env bash
# ensure-model-routing.sh — DISABLED (2026-04-16). See comment block below for rationale.
#
# Original purpose: reapply GSD agent model: directives if a GSD update wiped them.
# Discontinued: SB must not modify third-party plugin source files.
#
# Called by: hooks/session-start — call is commented out as of 2026-04-16.
# Replacement: GSD-native model_overrides config. See backlog 999.19.
# Compat:    bash 3.2+ (macOS default) — no associative arrays used.

set -euo pipefail
trap 'exit 0' ERR

# ── DISABLED (2026-04-16) ─────────────────────────────────────────────────────
# Model routing via frontmatter injection into GSD agent files is discontinued.
# Reason: SB must not modify third-party plugin source files. Patching
# ~/.claude/agents/gsd-*.md creates a tug-of-war with GSD's update system:
# GSD wipes model: lines on upgrade, SB re-injects them each session.
#
# GSD-native replacement: use model_overrides in .planning/config.json or
# .gsd/defaults.json. GSD v1.36.0 balanced profile already routes
# gsd-planner → opus. For gsd-security-auditor, add model_overrides config.
#
# Code preserved below for reference only.
exit 0

umask 0077

AGENTS_DIR="${HOME}/.claude/agents"
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"

# Canary check — gsd-planner must have model: opus; if not, all directives are stale.
CANARY="${AGENTS_DIR}/gsd-planner.md"
if [[ ! -f "$CANARY" ]] || grep -q "^model: opus" "$CANARY" 2>/dev/null; then
  exit 0   # Already correct or agents dir absent — nothing to do.
fi

# ── Model tier lookup (bash 3.2 compatible — case statement, no assoc arrays) ──
# Opus: only gsd-planner and gsd-security-auditor.
# Rationale: architectural reasoning (planner) and adversarial threat modelling
# (security-auditor) are the only tasks where reasoning depth measurably changes
# outcome quality. All other agents default to Sonnet for cost efficiency.
model_for_agent() {
  local name="$1"
  case "$name" in
    gsd-planner|gsd-security-auditor) echo "opus" ;;
    *)                                 echo "sonnet" ;;
  esac
}

# ── Patch a single agent file ─────────────────────────────────────────────────
patch_agent() {
  local name="$1"
  local model="$2"
  local file="${AGENTS_DIR}/${name}.md"

  # Safety: only patch files that already exist.
  [[ -f "$file" ]] || return 0

  # Security: validate the resolved path stays within AGENTS_DIR.
  local resolved
  resolved="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  [[ "$resolved" == "${AGENTS_DIR}/"* ]] || return 0

  # If model: line already present (any value), replace it in-place.
  if grep -q "^model:" "$file" 2>/dev/null; then
    sed -i.bak "s/^model:.*$/model: ${model}/" "$file" && rm -f "${file}.bak"
    return 0
  fi

  # No model: line — insert into frontmatter using Python (available alongside jq).
  python3 - "$file" "$model" << 'PYEOF'
import sys, re

path, model = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()

# Find frontmatter block (between first and second ---)
fm = re.match(r'^(---\n)(.*?)(---\n)', content, re.DOTALL)
if not fm:
    sys.exit(0)

body = fm.group(2)
# Insert after tools: line if present, else after description: line, else append.
if re.search(r'^tools:', body, re.MULTILINE):
    body = re.sub(r'(?m)^(tools:)', 'model: ' + model + r'\n\1', body, count=1)
elif re.search(r'^description:', body, re.MULTILINE):
    body = re.sub(r'(?m)^(description:.*\n)', r'\1' + 'model: ' + model + '\n', body, count=1)
else:
    body += 'model: ' + model + '\n'

with open(path, 'w') as f:
    f.write(fm.group(1) + body + fm.group(3) + content[fm.end():])
PYEOF
}

# ── Apply to all gsd-*.md files ───────────────────────────────────────────────
patched=0
for agent_file in "${AGENTS_DIR}"/gsd-*.md; do
  [[ -f "$agent_file" ]] || continue
  name=$(basename "$agent_file" .md)
  model=$(model_for_agent "$name")
  patch_agent "$name" "$model"
  patched=$((patched + 1))
done

# Audit trail in SB state dir.
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true
printf '[%s] ensure-model-routing: reapplied model directives to %d agents (GSD update detected)\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$patched" \
  >> "${SB_STATE_DIR}/model-routing-patch.log" 2>/dev/null || true

exit 0
