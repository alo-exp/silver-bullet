#!/usr/bin/env bash
# Verifies SB Codex skill frontmatter is parseable by a real YAML parser.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

assert_command() {
  local label="$1"
  shift
  if "$@"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

parse_frontmatter_tree() {
  local root="$1"
  ruby - "$root" <<'RUBY'
require "yaml"

root = ARGV.fetch(0)
failures = []

patterns = ["SKILL.md", "SILVER_SOURCE", "SILVER_SOURCE.md", "SILVER_SKILL.md"]
patterns.flat_map { |pattern| Dir[File.join(root, "**", pattern)] }.sort.each do |path|
  text = File.read(path)
  frontmatter = text.match(/\A---\n(.*?)\n---/m)&.[](1)
  next unless frontmatter

  begin
    parsed = YAML.safe_load(frontmatter, permitted_classes: [], aliases: false)
    unless parsed.is_a?(Hash) && parsed["name"].to_s.strip != ""
      failures << "#{path}: missing non-empty name"
    end
  rescue Psych::SyntaxError => e
    failures << "#{path}: #{e.message.lines.first.strip}"
  end
end

if failures.empty?
  exit 0
end

warn failures.join("\n")
exit 1
RUBY
}

echo "=== Codex skill YAML frontmatter tests ==="

assert_command "plugin SB skills have YAML-parseable frontmatter" \
  parse_frontmatter_tree "$REPO_ROOT/plugins/silver-bullet/skill-source"

assert_command "canonical repo skills have YAML-parseable frontmatter" \
  parse_frontmatter_tree "$REPO_ROOT/skills"

assert_command "Codex agent bundle skills have YAML-parseable frontmatter" \
  parse_frontmatter_tree "$REPO_ROOT/host-bundles/codex"

assert_command "Codex generated skills have YAML-parseable frontmatter" \
  parse_frontmatter_tree "$REPO_ROOT/plugins/silver-bullet/.generated-skills"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
