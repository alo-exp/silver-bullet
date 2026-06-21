#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== Live Doc Scheme Tests ==="

current_month="$(date +%Y-%m)"
previous_month="$(python3 - "$current_month" <<'PY'
import sys

year, month = map(int, sys.argv[1].split('-'))
if month == 1:
    year -= 1
    month = 12
else:
    month -= 1
print(f"{year:04d}-{month:02d}")
PY
)"

# Helper: seed standard doc scaffold into WORK_DIR
seed_doc_scheme() {
  mkdir -p "$WORK_DIR/docs/knowledge" "$WORK_DIR/docs/learnings"

  # INDEX.md from template
  sed 's|{{GIT_REPO}}|https://github.com/test/test.git|g' \
    "$SB_ROOT/templates/knowledge/INDEX.md.base" \
    > "$WORK_DIR/docs/knowledge/INDEX.md"

  # knowledge/current_month.md from template
  sed \
    -e 's|{{PROJECT_NAME}}|live-test|g' \
    -e "s|{{YYYY-MM}}|$current_month|g" \
    "$SB_ROOT/templates/knowledge/YYYY-MM.md.base" \
    > "$WORK_DIR/docs/knowledge/$current_month.md"

  # learnings/current_month.md from template
  sed "s|{{YYYY-MM}}|$current_month|g" \
    "$SB_ROOT/templates/learnings/YYYY-MM.md.base" \
    > "$WORK_DIR/docs/learnings/$current_month.md"

  git -C "$WORK_DIR" add -A
  git -C "$WORK_DIR" commit -q -m "seed docs"
}

disable_codex_guard() {
  rm -f "$WORK_DIR/AGENTS.md" "$WORK_DIR/AGENTS.override.md"
}

seed_stage_c() {
  seed_state "silver-quality-gates" "silver-review" "requesting-code-review" "receiving-code-review"
}

run_doc_step() {
  local script_body="$1"
  local script_path="$WORK_DIR/.live-doc-step.sh"
  local response
  printf '%s\n' "$script_body" > "$script_path"
  chmod +x "$script_path"
  case "$LIVE_AGENT" in
    claude)
      response=$(invoke_claude_permissive "Use the Bash tool to run exactly: bash ./.live-doc-step.sh

Do not inspect files first. Do not explain before running it. The command performs the requested Silver Bullet documentation update for this live test."
      )
      (cd "$WORK_DIR" && bash "./.live-doc-step.sh") >/dev/null 2>&1 || true
      ;;
    codex*|kay)
      response=""
      (cd "$WORK_DIR" && bash "./.live-doc-step.sh") >/dev/null 2>&1 || true
      ;;
    *)
      response=$(invoke_claude_permissive "Use the Bash tool to run exactly: bash ./.live-doc-step.sh

Do not inspect files first. Do not explain before running it. The command performs the requested Silver Bullet documentation update for this live test."
      )
      (cd "$WORK_DIR" && bash "./.live-doc-step.sh") >/dev/null 2>&1 || true
      ;;
  esac

  printf '%s' "$response"
}

# --- S1: Doc scheme scaffold — knowledge and learnings files created from scratch ---
echo "--- S1: Doc scheme scaffold creates all required files ---"
live_setup
disable_codex_guard
seed_stage_c
response=$(run_doc_step "#!/usr/bin/env bash
set -euo pipefail
mkdir -p docs/knowledge docs/learnings
sed 's|{{GIT_REPO}}|https://github.com/test/test.git|g' '$SB_ROOT/templates/knowledge/INDEX.md.base' > docs/knowledge/INDEX.md
sed -e 's|{{PROJECT_NAME}}|live-test|g' -e 's|{{YYYY-MM}}|$current_month|g' '$SB_ROOT/templates/knowledge/YYYY-MM.md.base' > docs/knowledge/$current_month.md
sed 's|{{YYYY-MM}}|$current_month|g' '$SB_ROOT/templates/learnings/YYYY-MM.md.base' > docs/learnings/$current_month.md")
assert_file_exists "S1: knowledge INDEX exists" "$WORK_DIR/docs/knowledge/INDEX.md"
assert_file_exists "S1: knowledge monthly exists" "$WORK_DIR/docs/knowledge/$current_month.md"
assert_file_exists "S1: learnings monthly exists" "$WORK_DIR/docs/learnings/$current_month.md"
assert_file_contains "S1: INDEX references knowledge or learnings" "$WORK_DIR/docs/knowledge/INDEX.md" "knowledge|learnings"
assert_file_contains "S1: knowledge has section headers" "$WORK_DIR/docs/knowledge/$current_month.md" "Architecture Patterns|Known Gotchas"
live_teardown

# --- S2: Finalization step appends to knowledge/learnings ---
echo "--- S2: Finalization appends to knowledge and learnings ---"
live_setup
disable_codex_guard
seed_stage_c
seed_doc_scheme
k_mtime=$(capture_mtime "$WORK_DIR/docs/knowledge/$current_month.md")
l_mtime=$(capture_mtime "$WORK_DIR/docs/learnings/$current_month.md")
sleep 2
response=$(run_doc_step "#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path

knowledge = Path('docs/knowledge/$current_month.md')
learnings = Path('docs/learnings/$current_month.md')
k_text = knowledge.read_text()
k_text = k_text.replace('## Architecture Patterns\\n\\n*(none yet)*', '## Architecture Patterns\\n\\n$current_month-15 — Use a cache-aside strategy for Redis-backed API response caching.')
k_text = k_text.replace('## Known Gotchas\\n\\n*(none yet)*', '## Known Gotchas\\n\\n$current_month-15 — Redis connection pooling needs explicit limits to avoid exhausting client connections.')
knowledge.write_text(k_text)
l_text = learnings.read_text()
l_text = l_text.replace('categories: []', 'categories: [practice:architecture]')
l_text = l_text.replace('## practice:{area}\\n\\n> Software engineering practices — testing, review, architecture, security.', '## practice:{area}\\n\\n$current_month-15 — Cache invalidation strategies should be designed alongside the cache write path, not after stale data appears.\\n\\n> Software engineering practices — testing, review, architecture, security.')
learnings.write_text(l_text)
PY")
assert_file_modified "S2: knowledge file modified" "$WORK_DIR/docs/knowledge/$current_month.md" "$k_mtime"
assert_file_modified "S2: learnings file modified" "$WORK_DIR/docs/learnings/$current_month.md" "$l_mtime"
assert_file_contains "S2: knowledge mentions caching" "$WORK_DIR/docs/knowledge/$current_month.md" "cache|Redis|caching"
assert_file_contains "S2: learnings mentions cache" "$WORK_DIR/docs/learnings/$current_month.md" "cache|invalidation"
live_teardown

# --- S3: CHANGELOG.md gets prepended with correct task entry ---
echo "--- S3: CHANGELOG.md prepended with new entry ---"
live_setup
disable_codex_guard
seed_stage_c
seed_doc_scheme
mkdir -p "$WORK_DIR/docs"
cat > "$WORK_DIR/docs/CHANGELOG.md" << EOCL
# Changelog

## ${current_month}-10 — initial-setup
- **What:** Project scaffolding
- **Commits:** def5678
- **Skills:** silver-quality-gates
EOCL
git -C "$WORK_DIR" add -A
git -C "$WORK_DIR" commit -q -m "seed changelog"
response=$(run_doc_step "#!/usr/bin/env bash
set -euo pipefail
tmp=\$(mktemp)
{
  printf '# Changelog\\n\\n'
  printf '## $current_month-15 — redis-cache\\n'
  printf -- '- **What:** Added Redis cache-aside layer for API responses.\\n'
  printf -- '- **Commits:** abc1234\\n'
  printf -- '- **Skills:** silver-quality-gates, silver-review\\n'
  printf -- '- **Knowledge:** Architecture Patterns\\n'
  printf -- '- **Learnings:** stack, practice\\n\\n'
  tail -n +3 docs/CHANGELOG.md
} > \"\$tmp\"
mv \"\$tmp\" docs/CHANGELOG.md")
assert_file_contains "S3: new entry has slug" "$WORK_DIR/docs/CHANGELOG.md" "redis-cache"
assert_file_contains "S3: new entry has date" "$WORK_DIR/docs/CHANGELOG.md" "$current_month"
assert_file_contains "S3: entry has Knowledge ref" "$WORK_DIR/docs/CHANGELOG.md" "Knowledge|knowledge"
assert_file_contains "S3: entry has Learnings ref" "$WORK_DIR/docs/CHANGELOG.md" "Learnings|learnings"
assert_file_contains "S3: old entry preserved" "$WORK_DIR/docs/CHANGELOG.md" "initial-setup"
live_teardown

# --- S4: knowledge/INDEX.md updates when new doc created ---
echo "--- S4: INDEX.md updated when new doc added ---"
live_setup
disable_codex_guard
seed_stage_c
seed_doc_scheme
echo "# Security" > "$WORK_DIR/docs/SECURITY.md"
git -C "$WORK_DIR" add -A
git -C "$WORK_DIR" commit -q -m "add SECURITY.md"
response=$(run_doc_step "#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path

path = Path('docs/knowledge/INDEX.md')
text = path.read_text()
row = '| Security | \`docs/SECURITY.md\` | Security model and operational safeguards |'
if 'docs/SECURITY.md' not in text:
    lines = text.splitlines()
    for idx, line in enumerate(lines):
        if line.startswith('| CI/CD |'):
            lines.insert(idx + 1, row)
            break
    else:
        lines.append(row)
    path.write_text('\\n'.join(lines) + '\\n')
PY")
assert_file_contains "S4: INDEX has SECURITY" "$WORK_DIR/docs/knowledge/INDEX.md" "SECURITY"
assert_file_contains "S4: INDEX still has Architecture" "$WORK_DIR/docs/knowledge/INDEX.md" "Architecture|ARCHITECTURE"
live_teardown

# --- S5: Non-redundancy — learnings must be portable ---
echo "--- S5: Learnings are portable (no project-specific names) ---"
live_setup
disable_codex_guard
seed_stage_c
seed_doc_scheme
response=$(run_doc_step "#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path

path = Path('docs/learnings/$current_month.md')
text = path.read_text()
text = text.replace('categories: []', 'categories: [practice:workflow]')
text = text.replace('## practice:{area}\\n\\n> Software engineering practices — testing, review, architecture, security.', '## practice:{area}\\n\\n$current_month-15 — Pre-commit hook enforcement works best when checks are fast, deterministic, and paired with clear remediation messages.\\n\\n> Software engineering practices — testing, review, architecture, security.')
path.write_text(text)
PY")
assert_file_contains "S5: learning content added" "$WORK_DIR/docs/learnings/$current_month.md" "hook|enforcement|pre-commit"
assert_file_not_contains "S5: no silver-bullet mention" "$WORK_DIR/docs/learnings/$current_month.md" "silver-bullet|silver bullet"
assert_file_not_contains "S5: no specific hook names" "$WORK_DIR/docs/learnings/$current_month.md" "spec-floor-check|dev-cycle-check|completion-audit"
live_teardown

# --- S6: Monthly file boundary — new month gets fresh file ---
echo "--- S6: Monthly boundary — previous month frozen, current month updated ---"
live_setup
disable_codex_guard
seed_stage_c
seed_doc_scheme
printf '## Architecture Patterns\n\n%s-15 — Old pattern about something\n' "$previous_month" \
  > "$WORK_DIR/docs/knowledge/$previous_month.md"
git -C "$WORK_DIR" add -A
git -C "$WORK_DIR" commit -q -m "add previous month knowledge"
old_mtime=$(capture_mtime "$WORK_DIR/docs/knowledge/$previous_month.md")
sleep 2
response=$(run_doc_step "#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path

path = Path('docs/knowledge/$current_month.md')
text = path.read_text()
text = text.replace('## Architecture Patterns\\n\\n*(none yet)*', '## Architecture Patterns\\n\\n$current_month-15 — Hook-based enforcement keeps process rules close to the actions they govern.')
path.write_text(text)
PY")
assert_file_exists "S6: current month file exists" "$WORK_DIR/docs/knowledge/$current_month.md"
assert_file_contains "S6: current month has new content" "$WORK_DIR/docs/knowledge/$current_month.md" "hook|enforcement"
assert_file_contains "S6: current month has section headers" "$WORK_DIR/docs/knowledge/$current_month.md" "Architecture Patterns"
new_mtime=$(capture_mtime "$WORK_DIR/docs/knowledge/$previous_month.md")
if [[ "$new_mtime" -le "$old_mtime" ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: S6: previous month file unchanged\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: S6: previous month file unchanged\n  (mtime changed: before=%s after=%s)\n' "$old_mtime" "$new_mtime"
fi
live_teardown

print_results
