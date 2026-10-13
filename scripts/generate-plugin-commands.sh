#!/usr/bin/env bash
# Generate plugins/silver-bullet/commands/*.md stubs from composer skill frontmatter.
# The source tree keeps historical silver-* authoring names; public command
# routes are emitted under the sb namespace.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/skills"
OUT_DIR="${REPO_ROOT}/plugins/silver-bullet/commands"

# Composer routes with command stubs (extend as new top-level routes ship).
COMPOSERS=(silver silver-init silver-feature silver-ui silver-devops silver-bugfix silver-deep-research silver-deep-research-multi-ai silver-multi-ai-task silver-compare silver-release silver-fast silver-new-workflow silver-orchestrator silver-orient silver-execute silver-ship)

mkdir -p "$OUT_DIR"

# Codex may have materialized command stubs under this internal name during
# an older plugin migration. They are not source commands and must never be
# committed or copied into a refreshed package.
for migrated in "$OUT_DIR"/source-command-*.md; do
  [[ -e "$migrated" ]] && rm -f -- "$migrated"
done

# Cursor desktop derives command routes from plain-Markdown filenames.
# Migrate older colon-named stubs before regenerating so stale files cannot
# keep shadowing the safe names.
shopt -s nullglob
for legacy in "$OUT_DIR"/*.md; do
  legacy_name="$(basename "$legacy")"
  [[ "$legacy_name" == *:* ]] || continue
  safe_name="${legacy_name//:/-}"
  safe="${OUT_DIR}/${safe_name}"
  if [[ -e "$safe" ]]; then
    rm -f -- "$legacy"
  else
    mv -- "$legacy" "$safe"
  fi
done

for skill in "${COMPOSERS[@]}"; do
  src="${SKILLS_DIR}/${skill}/SKILL.md"
  if [[ ! -f "$src" ]]; then
    printf 'WARN: missing %s\n' "$src" >&2
    continue
  fi

  name_line="$(awk '/^---$/{f++;next} f==1 && /^name:/{print; exit}' "$src")"
  skill_name="${name_line#name: }"
  skill_name="${skill_name#\"}"
  skill_name="${skill_name%\"}"
  skill_name="${skill_name#silver-}"
  [[ "$skill_name" == "silver" ]] && cmd_name="sb" || cmd_name="$skill_name"

  desc_line="$(awk '/^---$/{f++;next} f==1 && /^description:/{print; exit}' "$src")"
  hint_line="$(awk '/^---$/{f++;next} f==1 && /^argument-hint:/{print; exit}' "$src")"
  description="${desc_line#description: }"
  description="${description#> }"
  description="${description%\"}"
  description="${description#\"}"
  argument_hint="${hint_line#argument-hint: }"
  argument_hint="${argument_hint%\"}"
  argument_hint="${argument_hint#\"}"
  [[ -z "$argument_hint" ]] && argument_hint="<task description>"

  codex_name="sb:${cmd_name}"
  [[ "$cmd_name" == "sb" ]] && codex_name="sb"

  # Cursor plugin commands require kebab-case frontmatter names and
  # filesystem-safe command filenames.
  safe_file_stem="${codex_name//:/-}"
  [[ -z "$description" || "$description" == ">" ]] && \
    description="Silver Bullet ${safe_file_stem} workflow"
  out="${OUT_DIR}/${safe_file_stem}.md"
  cat > "$out" <<EOF
---
name: "${safe_file_stem}"
description: ${description}
argument-hint: ${argument_hint}
---

Invoke the Silver Bullet \`${codex_name}\` workflow for this request. Follow the composable flow contracts in \`docs/composable-flows-contracts.md\` and record required skill markers through the host Skill tool. If the Skill tool cannot resolve this route by name, read the full instructions from \`skill-source/${safe_file_stem}/SILVER_SOURCE\` under the Silver Bullet plugin install root.
EOF
  printf 'Wrote %s\n' "$out"
  # Drop legacy Silver, bare-route, colon-named, and Codex-migrated command
  # stubs left by older generators.
  for legacy in \
    "${OUT_DIR}/${cmd_name}.md" \
    "${OUT_DIR}/${codex_name}.md" \
    "${OUT_DIR}/silver.md" \
    "${OUT_DIR}/silver-${cmd_name}.md" \
    "${OUT_DIR}/source-command-${cmd_name}.md"; do
    if [[ "$legacy" != "$out" && -f "$legacy" ]]; then
      rm -f -- "$legacy"
    fi
  done
done
for legacy in "$OUT_DIR"/silver*.md; do
  [[ -e "$legacy" ]] && rm -f -- "$legacy"
done

# Add the same Cursor metadata to retained routes that are not in the
# composer list, preserving their existing prompt bodies.
python3 - "$OUT_DIR" <<'PY'
import sys
from pathlib import Path

for path in sorted(Path(sys.argv[1]).glob("*.md")):
    lines = path.read_text(encoding="utf-8").splitlines()
    if lines and lines[0].strip() == "---":
        continue
    body = "\n".join(lines).strip()
    metadata = (
        "---\n"
        f'name: "{path.stem}"\n'
        f"description: Silver Bullet {path.stem} workflow\n"
        "argument-hint: <task description>\n"
        "---\n\n"
    )
    path.write_text(metadata + body + "\n", encoding="utf-8")

PY

printf 'Generated %s composer command stubs in %s\n' "${#COMPOSERS[@]}" "$OUT_DIR"
