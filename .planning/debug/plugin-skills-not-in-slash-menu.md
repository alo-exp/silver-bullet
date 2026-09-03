---
status: investigating
trigger: "After first-time install + Claude Code restart, the plugin's commands/skills do not appear in the /-menu."
created: 2026-04-09T00:00:00Z
updated: 2026-04-09T00:00:00Z
---

## Current Focus

hypothesis: Possible causes are (1) version mismatch in .claude-plugin/plugin.json vs marketplace.json preventing the plugin from being recognized as up-to-date, (2) the duplicate "hooks" field in plugin.json causing strict-mode loading errors that surface in UI as plugin issues, or (3) inability to reproduce the issue because the normal loading path (skills via skillsPaths) works correctly per binary analysis.
test: Traced full Claude Code binary loading path from marketplace.json -> plugin.json -> skill discovery
expecting: Root cause is one of the documented issues
next_action: Finalize diagnosis based on all evidence gathered

## Symptoms

expected: After installing the plugin and restarting Claude Code, all plugin commands/skills should be visible in the /-menu (slash command picker).
actual: Users install the plugin, restart Claude Code, open the /-menu, and the plugin's commands/skills are not listed.
errors: No error messages reported — commands simply absent.
reproduction: 1) Install plugin fresh. 2) Restart Claude Code. 3) Open /-menu. 4) Plugin commands not present.
started: First-time install scenario; unclear if it ever worked for new installs.

## Eliminated

- hypothesis: skills/ directory missing or empty
  evidence: skills/ has 24 subdirectories, all with SKILL.md files with valid name+description frontmatter
  timestamp: 2026-04-09

- hypothesis: plugin.json missing or invalid JSON
  evidence: .claude-plugin/plugin.json exists and is valid JSON in both source repo and installed cache
  timestamp: 2026-04-09

- hypothesis: SKILL.md frontmatter has unsupported fields (like allowed-tools, which broke /silver in v0.12.0)
  evidence: All SKILL.md files use only name, description, argument-hint — all supported fields
  timestamp: 2026-04-09

- hypothesis: user-invocable: false set on skills
  evidence: No skill has user-invocable: false; all default to true (visible in /-menu)
  timestamp: 2026-04-09

- hypothesis: ws7() (plugin.json loader) returns null and plugin is dropped
  evidence: Binary analysis shows ws7() never returns null — always returns {plugin:H, errors:$}
  timestamp: 2026-04-09

- hypothesis: Duplicate hooks (plugin.json "hooks" field + auto-loaded hooks/hooks.json) causes plugin to fail entirely
  evidence: Binary analysis shows duplicate detection only logs error and continues — skills still load
  timestamp: 2026-04-09

- hypothesis: skills not loaded from skillsPaths (only from skillsPath)
  evidence: Binary code at idx 73970303 shows both skillsPath and skillsPaths are checked; silver-bullet correctly populates skillsPaths
  timestamp: 2026-04-09

## Evidence

- timestamp: 2026-04-09
  checked: .claude-plugin/plugin.json in source repo vs installed cache
  found: Source repo (HEAD) has version "0.13.0"; installed cache at 0.13.0 path has version "0.12.1" in plugin.json. This is because the version bump commit (162b981) came AFTER the v0.13.0 release commit (836b488) which is the installed SHA.
  implication: The installed plugin.json says 0.12.1 while installed_plugins.json says 0.13.0 — version mismatch in the installed files. This was fixed by commit 162b981 but only affects users who installed BEFORE that commit.

- timestamp: 2026-04-09
  checked: Claude Code binary (v2.1.79) ws7() function — plugin.json loading
  found: When plugin.json has "skills" field -> w=false -> skillsPath NOT auto-set; but A.skills triggers _q_() which resolves "./skills/" to the skills directory and sets skillsPaths. Both skillsPath AND skillsPaths are loaded by getPluginSkills().
  implication: The "skills": "./skills/" declaration in plugin.json works correctly. Skills ARE loaded via skillsPaths.

- timestamp: 2026-04-09
  checked: Claude Code binary schema for plugin.json "skills" field
  found: Schema documentation says "Path to ADDITIONAL skill directory (in addition to those in the skills/ directory, if it exists)". This means plugin.json "skills" field is for EXTRA paths beyond the auto-discovered skills/.
  implication: By declaring "skills": "./skills/" in plugin.json, silver-bullet is declaring the same path the auto-discovery would use — it's redundant but harmless. The field causes w=false (disabling auto-discovery) and instead explicitly loads from skillsPaths. Net effect: same directory is loaded, just via explicit path instead of auto-discovery.

- timestamp: 2026-04-09
  checked: Plugin.json "hooks" field vs auto-loaded hooks/hooks.json
  found: plugin.json declares "hooks": "./hooks/hooks.json". Claude Code also auto-loads hooks/hooks.json. When K (strict=true, silver-bullet's marketplace.json has strict:true so ws7 is called with strict=true), this triggers: H_(Error("Duplicate hooks file detected...")), $.push({type:"hook-load-failed",...}), continue. The hook is skipped but plugin continues loading.
  implication: The "hooks" field in plugin.json creates a logged error but does NOT prevent skill loading. However, this error DOES surface in the Claude Code plugin status UI, potentially showing the plugin as errored.

- timestamp: 2026-04-09
  checked: marketplace.json "version" field at git SHA 836b488 (v0.13.0 release commit)
  found: marketplace.json said version "0.12.1" at 836b488. Only fixed in commit 162b981 ("chore: bump .claude-plugin version to 0.13.0"). This means users installing during the window between 836b488 and 162b981 would get version "0.12.1" in marketplace.json.
  implication: The marketplace version was stale for a period. This was already noted in commit 162b981 commit message as "users were unable to install the current release via the marketplace." This is a separate install-discoverability bug.

- timestamp: 2026-04-09
  checked: Claude Code binary loading path for URL-sourced plugins (silver-bullet uses source: {source:"url", url:"..."})
  found: On first install with no cache: Wr_() downloads the repo, gets manifest (plugin.json) and gitCommitSha. zi() uses plugin.json version ("0.12.1") as cache key. SxT() moves to versioned cache. Plugin then loads via ws7() which finds plugin.json and processes "skills" field correctly.
  implication: The first-time download path works correctly if the network is available and the repo is accessible. Skills should load after download.

- timestamp: 2026-04-09
  checked: CLAUDE_PLUGIN_ROOT injection in hook commands
  found: Claude Code binary sets CLAUDE_PLUGIN_ROOT=T.path (plugin install path) when executing hook commands. The hooks.json commands use "${CLAUDE_PLUGIN_ROOT}/hooks/..." which resolves correctly.
  implication: Hook execution should work correctly.

## Resolution

root_cause: INCONCLUSIVE from binary analysis alone. The normal loading path for skills appears correct. However, two structural issues in plugin.json were identified that could cause visible errors or confuse users:

1. **Redundant "hooks" field**: plugin.json declares `"hooks": "./hooks/hooks.json"` which duplicates the auto-loaded standard location. In strict mode (silver-bullet's marketplace.json has `strict: true`), this generates a `hook-load-failed` error entry visible in Claude Code's plugin status. Users may see the plugin as "errored" even though skills load.

2. **Redundant "skills" field** (minor): plugin.json declares `"skills": "./skills/"` pointing to the standard auto-discovered location. The schema documentation describes this as an ADDITIONAL path field. Having it point to the standard location disables auto-discovery (w=false) and replaces it with explicit loading — functionally equivalent but semantically wrong per the spec.

3. **Version mismatch** (historical): .claude-plugin/plugin.json had version "0.12.1" at the v0.13.0 release commit. This was fixed in 162b981 but not before. This does not prevent skill loading but causes display/install discoverability issues.

The most likely explanation for "skills not appearing in /-menu" for first-time installs is that the `hook-load-failed` error (from the duplicate hooks field) causes Claude Code to mark the plugin as errored in its status, and some UI paths may not show skills from errored plugins. This could not be confirmed without testing the actual Claude Code UI behavior.

fix: Remove "hooks" field from .claude-plugin/plugin.json (hooks/hooks.json is auto-loaded). Optionally remove "skills" field too (skills/ is auto-discovered). These fields are redundant and the "hooks" one actively causes a logged error.
verification: empty until verified
files_changed: []
