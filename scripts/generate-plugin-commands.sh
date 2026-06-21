#!/usr/bin/env bash
# Generate plugins/silver-bullet/commands/*.md stubs from composer skill frontmatter.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/skills"
OUT_DIR="${REPO_ROOT}/plugins/silver-bullet/commands"

# Composer routes with command stubs (extend as new top-level routes ship).
COMPOSERS=(silver silver-feature silver-ui silver-devops silver-bugfix silver-research silver-release silver-fast)

mkdir -p "$OUT_DIR"

title_case() {
  python3 - "$1" <<'PY'
import sys
s = sys.argv[1].replace("-", " ")
print(" ".join(w[:1].upper() + w[1:] for w in s.split()))
PY
}

for skill in "${COMPOSERS[@]}"; do
  src="${SKILLS_DIR}/${skill}/SKILL.md"
  if [[ ! -f "$src" ]]; then
    printf 'WARN: missing %s\n' "$src" >&2
    continue
  fi

  name_line="$(awk '/^---$/{f++;next} f==1 && /^name:/{print; exit}' "$src")"
  desc_line="$(awk '/^---$/{f++;next} f==1 && /^description:/{print; exit}' "$src")"
  hint_line="$(awk '/^---$/{f++;next} f==1 && /^argument-hint:/{print; exit}' "$src")"

  skill_name="${name_line#name: }"
  skill_name="${skill_name#\"}"
  skill_name="${skill_name%\"}"
  skill_name="${skill_name#silver-}"
  [[ "$skill_name" == "silver" ]] && cmd_name="silver" || cmd_name="$skill_name"

  description="${desc_line#description: }"
  description="${description#> }"
  description="${description%\"}"
  description="${description#\"}"

  argument_hint="${hint_line#argument-hint: }"
  argument_hint="${argument_hint%\"}"
  argument_hint="${argument_hint#\"}"
  [[ -z "$argument_hint" ]] && argument_hint="<task description>"

  codex_name="silver:${cmd_name}"
  [[ "$cmd_name" == "silver" ]] && codex_name="silver"
  title="$(title_case "$cmd_name")"
  [[ "$cmd_name" == "silver" ]] && title="Silver"

  out="${OUT_DIR}/${cmd_name}.md"
  cat > "$out" <<EOF
---
name: "${codex_name}"
title: "${title}"
description: ${description}
argument-hint: ${argument_hint}
---

Invoke the Silver Bullet \`${skill}\` workflow for this request. Follow the composable flow contracts in \`docs/composable-flows-contracts.md\` and record required skill markers through the host Skill tool.
EOF
  printf 'Wrote %s\n' "$out"
done

printf 'Generated %s composer command stubs in %s\n' "${#COMPOSERS[@]}" "$OUT_DIR"
