#!/usr/bin/env bash
# Generate plugins/silver-bullet/commands/*.md stubs from composer skill frontmatter.
# The source tree keeps historical silver-* authoring names; public command
# routes are emitted under the sb namespace. The stubs are Cursor's slash
# commands and this script's output is final: no later packaging step
# rewrites them, so the committed stubs are exactly what it writes.
#
# Usage:
#   bash scripts/generate-plugin-commands.sh           # regenerate in place
#   bash scripts/generate-plugin-commands.sh --check   # exit 1 when the committed stubs drift
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/skills"
OUT_DIR="${REPO_ROOT}/plugins/silver-bullet/commands"

CHECK=0
case "${1:-}" in
  "") ;;
  --check) CHECK=1 ;;
  *)
    printf 'Usage: %s [--check]\n' "${0##*/}" >&2
    exit 2
    ;;
esac

# Composer routes with command stubs (extend as new top-level routes ship).
COMPOSERS=(silver silver-init silver-feature silver-ui silver-devops silver-bugfix silver-deep-research silver-deep-research-multi-ai silver-multi-ai-task silver-compare silver-release silver-fast silver-new-workflow silver-orchestrator silver-orient silver-execute silver-ship)

# generate <out-dir>: write the stubs into <out-dir>, migrating or removing
# stubs left by older generators. Routes that are not composers (for example
# the hand-written sb-doctor.md) keep their bodies.
generate() {
  python3 - "$SKILLS_DIR" "$1" "${COMPOSERS[@]}" <<'PY'
import json
import re
import sys
from pathlib import Path

skills_dir = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
composers = sys.argv[3:]
BLOCK = {">", ">-", ">+", "|", "|-", "|+"}


def frontmatter(path: Path) -> dict[str, str]:
    """Top-level scalar keys, with quoted values and block scalars (folded
    `>` or literal `|`) read in full and folded onto one line."""
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    meta: dict[str, str] = {}
    i = 1
    while i < len(lines) and lines[i].strip() != "---":
        match = re.match(r"^([A-Za-z0-9_-]+):[ \t]*(.*)$", lines[i])
        i += 1
        if not match:
            continue
        key, value = match.group(1), match.group(2).strip()
        if value in BLOCK:
            parts = []
            while i < len(lines) and (not lines[i].strip() or lines[i][0] in " \t"):
                parts.append(lines[i].strip())
                i += 1
            value = " ".join(part for part in parts if part)
        elif len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        meta[key] = value
    return meta


def quote(value: str) -> str:
    # A JSON string is a valid YAML double-quoted scalar.
    return json.dumps(value, ensure_ascii=False)


def remove(path: Path) -> None:
    if path.is_file():
        path.unlink()


out_dir.mkdir(parents=True, exist_ok=True)

# Codex may have materialized command stubs under this internal name during an
# older plugin migration; they are not source commands.
for path in sorted(out_dir.glob("source-command-*.md")):
    path.unlink()

# Cursor desktop derives command routes from plain-Markdown filenames and
# rejects colons: migrate older colon-named stubs so stale files cannot keep
# shadowing the safe names.
for legacy in sorted(out_dir.glob("*:*.md")):
    safe = legacy.with_name(legacy.name.replace(":", "-"))
    if safe.exists():
        legacy.unlink()
    else:
        legacy.rename(safe)

written = 0
for skill in composers:
    src = skills_dir / skill / "SKILL.md"
    if not src.is_file():
        print(f"WARN: missing {src}", file=sys.stderr)
        continue
    meta = frontmatter(src)
    raw_name = meta.get("name") or skill
    route = raw_name.removeprefix("silver-")
    cmd_name = "sb" if route == "silver" else route
    codex_name = "sb" if cmd_name == "sb" else f"sb:{cmd_name}"
    stem = codex_name.replace(":", "-")
    description = meta.get("description") or f"Silver Bullet {stem} workflow"
    argument_hint = meta.get("argument-hint") or "<task description>"
    out = out_dir / f"{stem}.md"
    out.write_text(
        "---\n"
        f"name: {quote(stem)}\n"
        f"description: {quote(description)}\n"
        f"argument-hint: {quote(argument_hint)}\n"
        "---\n"
        "\n"
        f"Invoke the Silver Bullet `{codex_name}` workflow for this request. Follow the composable flow "
        "contracts in `docs/composable-flows-contracts.md` and record required skill markers through the "
        "host Skill tool. If the Skill tool cannot resolve this route by name, read the full instructions "
        f"from `cursor-skill-source/{stem}/SILVER_SOURCE` under the Silver Bullet plugin install root.\n",
        encoding="utf-8",
    )
    written += 1
    print(f"Wrote {out}")
    # Drop legacy Silver, bare-route, colon-named and Codex-migrated stubs.
    for legacy_name in (f"{cmd_name}.md", f"{codex_name}.md", "silver.md", f"silver-{cmd_name}.md"):
        if out_dir / legacy_name != out:
            remove(out_dir / legacy_name)

for legacy in sorted(out_dir.glob("silver*.md")):
    legacy.unlink()

# Retained routes that are not composers get the same Cursor metadata; their
# prompt bodies are kept.
for path in sorted(out_dir.glob("*.md")):
    text = path.read_text(encoding="utf-8")
    if text.split("\n", 1)[0].strip() == "---":
        continue
    path.write_text(
        "---\n"
        f"name: {quote(path.stem)}\n"
        f"description: {quote(f'Silver Bullet {path.stem} workflow')}\n"
        f"argument-hint: {quote('<task description>')}\n"
        "---\n\n" + text.strip() + "\n",
        encoding="utf-8",
    )
PY
}

if [[ "$CHECK" -eq 0 ]]; then
  generate "$OUT_DIR"
  printf 'Generated %s composer command stubs in %s\n' "${#COMPOSERS[@]}" "$OUT_DIR"
  exit 0
fi

# --check: regenerate a copy of the committed stubs and compare both ways.
work="$(mktemp -d "${TMPDIR:-/tmp}/sb-commands-check.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/commands"
cp -R "$OUT_DIR/." "$work/commands/" 2>/dev/null || true
generate "$work/commands" >/dev/null
drift=0
while IFS= read -r name; do
  printf 'DRIFT: plugins/silver-bullet/commands/%s\n' "$name" >&2
  drift=$((drift + 1))
done < <(
  { (cd "$OUT_DIR" 2>/dev/null && find . -type f) ; (cd "$work/commands" && find . -type f) ; } |
    sed 's|^\./||' | sort -u |
    while IFS= read -r name; do
      cmp -s "$OUT_DIR/$name" "$work/commands/$name" || printf '%s\n' "$name"
    done
)
if [[ "$drift" -gt 0 ]]; then
  printf 'Command stubs drift: %d file(s) — run: bash scripts/generate-plugin-commands.sh\n' "$drift" >&2
  exit 1
fi
printf 'Command stubs fresh (%s composer routes)\n' "${#COMPOSERS[@]}"
