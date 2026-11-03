#!/usr/bin/env bash
# R13-13: the release payload (scripts/build-plugin-payload.sh) leaves out research/,
# .planning transcripts, graphify-out/graph.json, .agentmemory and *.bak, and keeps every
# runtime file, including .planning/scripts/phase-lock.sh that the phase-lock hooks call.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
BUILD="$TL_REPO_ROOT/scripts/build-plugin-payload.sh"
git_id=(-c user.name=Tests -c user.email=tests@example.invalid -c commit.gpgsign=false)

# --- the attribute rules, on a small repository that carries the real .gitattributes -----------
R="$TL_TMP/repo"
mkdir -p "$R"
git init -q -b main "$R"
cp "$TL_REPO_ROOT/.gitattributes" "$R/.gitattributes"
for f in hooks/hooks.json scripts/a.sh templates/t.md skills/s/SKILL.md .claude-plugin/plugin.json \
  .planning/scripts/phase-lock.sh .planning/scripts/lib/x.sh docs/d.md \
  research/r/paper.pdf .planning/notes.md .planning/rfl-1/run.md .planning/rfl-1/transcript.txt \
  .agentmemory/memory/m.md graphify-out/graph.json graphify-out/GRAPH_REPORT.md .planning/old.plan.md.bak; do
  mkdir -p "$R/$(dirname "$f")"
  echo "$f" >"$R/$f"
done
git -C "$R" add -A
git "${git_id[@]}" -C "$R" commit -q -m payload

# Run from the fixture repository: the script archives the repository it lives in.
mkdir -p "$R/scripts"
cp "$BUILD" "$R/scripts/build-plugin-payload.sh"
tl_run bash "$R/scripts/build-plugin-payload.sh" "$TL_TMP/out/payload.tar.gz" HEAD
assert_eq "build exits 0" 0 "$TL_STATUS"
assert_contains "build reports the file" "$TL_OUT" "Wrote $TL_TMP/out/payload.tar.gz"
listing="$(tar -tzf "$TL_TMP/out/payload.tar.gz")"
for kept in hooks/hooks.json scripts/a.sh templates/t.md skills/s/SKILL.md .claude-plugin/plugin.json \
  .planning/scripts/phase-lock.sh .planning/scripts/lib/x.sh docs/d.md graphify-out/GRAPH_REPORT.md; do
  assert_contains "payload keeps $kept" "$listing" "$kept"
done
for dropped in research/r/paper.pdf .planning/notes.md .planning/rfl-1/run.md .planning/rfl-1/transcript.txt \
  .agentmemory/memory/m.md graphify-out/graph.json .planning/old.plan.md.bak; do
  assert_eq "payload drops $dropped" "0" "$(printf '%s\n' "$listing" | grep -cxF "$dropped" || true)"
done

# --- argument handling -------------------------------------------------------------------------------
tl_run bash "$BUILD"
assert_eq "no output path is a usage error" 64 "$TL_STATUS"
tl_run bash "$BUILD" --bogus
assert_eq "an option instead of the output path is a usage error" 64 "$TL_STATUS"
tl_run bash "$R/scripts/build-plugin-payload.sh" "$TL_TMP/out/nope.tar.gz" no-such-ref
assert_eq "unknown ref fails" 1 "$TL_STATUS"
tl_run bash "$R/scripts/build-plugin-payload.sh" "$TL_TMP/out/extra.tar.gz" HEAD -- --prefix=silver-bullet/
assert_eq "extra git-archive arguments are passed through" 0 "$TL_STATUS"
assert_contains "prefix applied" "$(tar -tzf "$TL_TMP/out/extra.tar.gz")" "silver-bullet/hooks/hooks.json"
tl_run bash "$R/scripts/build-plugin-payload.sh" "$TL_TMP/out/extra2.tar.gz" -- --prefix=p/
assert_eq "default ref with extra arguments" 0 "$TL_STATUS"
assert_contains "default ref archived" "$(tar -tzf "$TL_TMP/out/extra2.tar.gz")" "p/hooks/hooks.json"

# --- the real repository: the heavy trees are not in its payload ---------------------------------------
real="$(git -C "$TL_REPO_ROOT" archive --worktree-attributes HEAD | tar -t)"
for dropped in graphify-out/graph.json research/ .agentmemory/; do
  assert_eq "real payload has no $dropped" "0" "$(printf '%s\n' "$real" | grep -c "^${dropped}" || true)"
done
assert_eq "real payload has no .planning transcripts" "0" "$(printf '%s\n' "$real" | grep -cE '^\.planning/[^s]|^\.planning/s[^c]' || true)"
assert_contains "real payload keeps .planning/scripts/phase-lock.sh" "$real" ".planning/scripts/phase-lock.sh"
assert_contains "real payload keeps hooks/hooks.json" "$real" "hooks/hooks.json"
assert_eq "real payload has no *.bak" "0" "$(printf '%s\n' "$real" | grep -c '\.bak$' || true)"

tl_results
