# Per-package scope notes (authoritative; see packages.json for finding ids)

## F2 input-analysis — owns hooks/lib/tool-input.sh, hooks/lib/tool-input/**, hooks/lib/completion-audit/classify.sh, new hooks/lib/shell-analysis.sh
Also covers: keyword part of R1-13; classification parts of R1-27, R2-20, R2-21.
- Payload via stdin/private temp file, parsed once per hook; clear "parse failed" and "python3 unavailable" signals.
- One Python shell analyzer: bash-like tokenizing (quotes incl $'..', escapes, comments only at word start, newlines,
  ; && || | & ( ) { } $( ) backticks, here-docs), literal var tracking (G=git; $G commit), unwrap env/command/builtin/
  exec/nohup/nice/time/timeout/stdbuf/xargs/sh|bash -c/eval literal/find -exec/rtk; git global opts (-C -c alias.*
  --git-dir ...) + repo aliases; actions: commit-creating, push (incl tags), PR create/merge (gh pr create|new|merge,
  gh api POST/PUT/PATCH to pulls/merges/releases/refs/contents, gh aliases, hub), release, deploy-like (program/subcommand
  based; read-only mentions of "deploy" are NOT deploy), write targets (redirects, tee cp mv install rsync ln dd sed -i
  perl -i truncate touch rm curl -o wget -O tar -x unzip git apply/checkout --/restore/reset --hard/clean/stash pop/mv/rm,
  patch, find -delete); dynamic paths kept as dynamic; opaque writers (python -c, node -e, awk system/>, sed w/e).
- Read-only verdict = allowlist. Opaque results with reasons + could_be_delivery hint. MCP GitHub tool classification.
- Keep every existing consumer contract (classify.sh functions, helper CLIs). classify = highest tier across segments.
- Do NOT edit consumer gates (completion-audit.sh, dev-cycle-check.sh, ci-status-check.sh, pr-traceability.sh,
  roadmap-freshness.sh, phase-archive.sh, orchestrator-parent.sh, enterprise-policy.sh).
- Tests: big table-driven bypass corpus (red->green) + big honest-command corpus (no false positives), 300 KiB payload, python3-missing.

## H2 installers — owns install-claude/codex/cursor(+lib dirs), install-cursor-sb-agents(+lib), strip-cursor-sb-hooks.py,
prune-claude-settings.py, prune-stale-claude-user-hooks.sh, post-release-uninstall.sh, generate-cursor-hooks.py (both),
generated cursor-hooks.json files (regenerate only), .codex/hooks.json.
Rules: atomic writes keeping mode/symlinks, backup before destructive change, idempotent, remove only SB-owned entries
(ownership marker/manifest), never rm -rf a possibly-empty path, no global git config change without opt-in, TOML edited
structurally. Tests seed foreign user data and assert it survives install/reinstall/upgrade/uninstall. Sandbox HOME only.

## H3 release-ci — owns .github/**, Makefile, requirements*, package.json, .gitignore, .gitattributes, .cursorignore,
SECURITY.md, new .github/CODEOWNERS, sync-*marketplace* scripts, sync-release-marketplace-versions.sh, agent-plugins-common.sh,
run-release-live-matrix.sh, run-rc-validation-matrix.sh, post-release-*.sh, validate-github-release-notes.sh,
verify-release-*-ci.sh, check-repo-invariants.sh, docs/RELEASE.md, CHANGELOG [Unreleased] only.
needs-user (do NOT implement): R13-02, R7-30 (marketplace pinning), R13-11 (private data; don't delete .planning/,
research/, .agentmemory/, SETUP_REPORT.md). Not yours: R13-08/09/10/20. Never invent action SHAs (no network) — keep
tags and report needs-user. make setup -> venv. Report the test that writes E2E rows into the checkout (owned by H10).

## H4a toolgates-consent — owns the opt-in gate hooks/recorders in hooks/ (graphify/agentmemory/rtk/context-mode/
context-mode-read-deny/leanctx/alumnium/stack-compression-*/token-compression-tools-gate, record-* for those) and their
hooks/lib libs incl recommended-tools*.sh, stack-optimizer.sh, graphify-am-global.sh, rtk-compat.sh, rtk-cm-global.sh,
plus a new consent lib. Not e2e-matrix-routing.sh (G3) nor shell_unwrap_rtk.py (F2).
Trust model: committed .silver-bullet.json is untrusted — may disable/prefer, never opt user in to installs/global
changes/new blocking gates, never supplies executed commands/fetched URLs/out-of-root paths. Consent is per-user outside
the repo (record what/when; Bash API + CLI for scripts; H4b adopts it). Existing project-config opt-in is not consent:
one-time notice; gates inactive until confirmed. Install/repair commands only from SB's plugin registry; no eval/bash -c
of config. Strict validation (version regex before numeric compare, health_url localhost http(s) only after --, paths via
F1 containment helper sb_runtime_state_path when available). Cheap short-circuit when nothing consented. Document API.

## H5 packaging-doctor — owns sync-codex-package.sh, sync-cursor-package.sh, sync-runtime-mirrors.sh, sync-templates.sh,
render-agent-bundle.py, codex-sanitize-package.sh, generate-plugin-commands.sh, validate-plugin-mirror.sh,
validate-host-*.sh, lib/agent-bundle-paths.sh, lib/codex-cli.sh, opencode-cli.sh, pi-cli.sh, plugin-cache-version.sh,
lib/host-install-guides/**, smoke-isolation functions of pre-release-host-isolation.sh (NOT sb_smoke_rc_markers_complete),
smoke/picker scripts, sb-doctor.sh, sb-diagnostics.sh, generated mirrors (regenerate only).
Not yours: R8-07/08/13/14/15/16/18/19/26. Validators must detect real drift (prove by seeded breakage). R10b-04: colon
paths — change naming only if host loading contracts allow, else needs-user with trade-off. Never tell agent to bypass consent.

## H8a deep-research — owns skills/silver-deep-research/**, skills/silver-multi-ai-task/**, scripts/lib/multi-ai-opencode-worker.sh
Least privilege workers + data-delimited untrusted content (don't edit scripts/lib/agent-host-exec.sh — G6; record needs).
Process-group kills. Claim support must not pass fabrications; fix tests pinning defects. SSRF blocking incl redirects,
bounded reads, atomic writes/locks, relative paths in artifacts, shared category-pack module importable from both skills.

## H8b multi-ai-research — owns skills/silver-deep-research-multi-ai/** (incl assets/landscape-preview.template.html)
Fix every XSS sink (node test with hostile entries). Remove all hard-wired Silver Bullet/APO literals and SB special cases;
APO content only as data in an APO category pack applied when chosen; never overwrite existing need_profile.json/scope.md;
licences real (SB is BUSL-1.1). Never delete user data; output only in the run dir. SSRF/redirect/limits for link checks.
Pin versions; SRI only if computable locally else needs-user. Don't edit H8a-owned shared modules; record needs.

## H4b toolstack-scripts — BASE = fix/H4a-toolgates-consent (adopt H4a's consent API: hooks/lib/user-consent.sh, scripts/sb-consent.sh, docs/CONSENT.md)
Owns: scripts/lib/recommended-tools/**, scripts/lib/global-toolstack/**, scripts/lib/five_tool_runtime/**, optimize-*.sh,
reconcile-recommended-tools.sh, install-leanctx-sb.sh, install-global-toolstack.sh, install-recommended-tools-*.sh,
graphify-am-global-setup.sh, enable-alumnium.sh, enable-rtk-context-mode.sh, sb-optimize-stack.sh, sb-verify-synergy.sh,
validate-graphify-artifacts.sh, install-omniroute-launchagent.sh, start-minimax-openai-proxy.sh, minimax-openai-proxy.mjs,
scripts/lib/merge-leanctx-mcp-config.py, merge-token-compression-config.py, verify-leanctx-wire-proxy-ordering.py,
rtk-cm-hosts.json, context-mode-cursor-hooks.json, cursor-cli-allowlist.json.
Also: finish R5-04 consumers (reconcile engine/probes; sb-doctor.sh/sb-diagnostics.sh consent reads are H5's files — minimal
edits only, list them); fix the 13 tests listed in fix-H4a-toolgates-consent.json known_failing_until_h4b using
tests/lib/consent-helpers.sh. Never eval/bash -c config strings; installs only from SB registry, pinned where possible;
no curl|sh without explicit user consent + pinned version/checksum; config writers atomic, symlink-preserving, backed up,
idempotent, consent-scoped; Codex TOML edited structurally (reuse scripts/lib/sb_host_config.py from H2 if present on base,
else implement minimal structural editing); no mapfile (Bash 3.2).
