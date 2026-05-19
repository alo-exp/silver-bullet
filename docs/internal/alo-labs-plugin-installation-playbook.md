# Alo Labs Plugin Installation Playbook

This playbook captures the install, hook, and cache hygiene rules that Silver Bullet had to tighten during this session. Treat it as the reusable pattern for any Alo Labs plugin that ships into Codex, Claude, or both.

The goal is simple:

- one canonical install identity per plugin
- no dependency on another host's private dirs or env
- no stale alias drift
- no hook payload split across multiple config files
- no hook activation outside the real project boundary

If a plugin only targets one host, ignore the other host-specific sections. The cross-host isolation rules still apply.

## 1. Keep the install identity canonical

Use a single canonical plugin id for the install surface.

- Local-source installs should still land under the canonical id.
- Do not introduce `*-local` compatibility ids unless there is a proven external contract that still depends on them.
- If a temporary alias exists during a migration, the installer should actively remove it once the canonical path is in place.

For Silver Bullet, the canonical Codex id is `silver-bullet@alo-labs-codex`, even when the source is local.

## 2. Keep host installs isolated

Codex installs must not depend on Claude paths or Claude env.
Claude installs must not depend on Codex paths or Codex env.

Rules of thumb:

- A Codex bundle should not require `${SB_RUNTIME_HOME_ROOT}` to exist.
- A Codex bundle should target lowercase `~/.codex` only. Treat `~/.Codex` as a legacy migration artifact, not an active install target.
- A Claude bundle should not require `~/.codex` to exist.
- Cross-host references may appear in docs or tests, but not in the live install surface unless they are explicitly host-specific and rewritten during install.

If a package needs host-specific rewriting, do it in the installer and verify the rewritten install tree, not the source tree.

## 3. Keep hook payloads in one place

Do not split hook payload definitions across multiple runtime config files.

- Keep the hook command payloads in the runtime hook manifest that the host actually executes.
- Keep trust or state metadata separate from the payload definition.
- If the host supports more than one hook representation, choose one payload source of truth and use the other only for state or compatibility metadata.
- Seed trust/state only after the final hook surface is stable. If another installer step can still add, remove, or reorder hooks after trust is written, the UI may flag the hooks for review again.
- Seed trust against the exact source each prefix represents. If the package-local hook bundle and the mirrored user hook files are both present, do not hash one file and apply that trust blob to every prefix. The package prefix should be trusted from the package-local `hooks/hooks.json`, while the host mirror prefixes should be trusted from their respective user hook files.

For Silver Bullet on Codex, the live rule is:

- `hooks.json` carries the hook payloads
- `config.toml` carries the trust/state layer

The installer should remove stale hook payloads from unrelated config files before it merges the current payload surface.

## 4. Merge hooks only at the real project boundary

Hooks should activate only when the current workspace is a genuine project root.

- If the installer cannot resolve a real project root, it should not auto-enable the plugin.
- If the workspace is not the project, do not inject plugin hook payloads into the host's user config.
- A subfolder inside a real project root may still activate, because it is still part of the project.

For Silver Bullet, the project-root check requires both:

- `.silver-bullet.json`
- `silver-bullet.md`

This rule prevents a plugin from bleeding its hooks into unrelated folders.

## 5. Keep the skill surface loadable

Only ship actual loadable skill files.

- Deprecated wrappers should be removed from the live skill surface, not merely hidden in docs.
- Empty parent directories do not matter to the picker; `SKILL.md` files do.
- If a hidden internal skill exists, mark it `user-invocable: false` and make it delegate to the canonical workflow it enforces.

If a plugin exposes a creative or exploratory surface, prefer one clear entry point over multiple overlapping skill names that do the same job.

## 6. Put enforcement behind the execution boundary

If a plugin enforces a development method, keep the real enforcement at the execution boundary.

- A hidden wrapper may prepare state or choose the method.
- The execution orchestrator should remain the source of truth for actual code-writing behavior.
- Do not make enforcement a user-facing picker item unless users genuinely need to invoke it directly.

Silver Bullet uses this pattern for TDD:

- `tdd` is hidden
- `tdd` delegates to `superpowers:test-driven-development`
- `gsd-execute-phase --tdd` is the real execution trigger for implementation work

## 7. Do not vendor dependency plugins into a parent bundle

If one Alo Labs plugin depends on another plugin:

- install the dependency from its own official source
- do not copy the dependency plugin's source tree into the parent package
- do not treat the parent bundle as a second source of truth for the dependency

If the dependency needs a Codex wrapper, create a separate wrapper package for that dependency instead of folding it into the parent plugin.

## 8. Recommended installer pipeline

When building or refreshing a host install, use this sequence:

1. If you are doing a clean reinstall, remove the existing plugin registry entry, hook-state entries, hook payloads, and cache roots for that plugin first.
2. If the versioned cache tree is missing after cleanup, bootstrap it from the local source snapshot before running the host installer. Do not assume the installer can create an empty versioned cache tree from nothing.
3. If the canonical plugin registry row was removed during uninstall, restore that row from the local snapshot before the normal sync pass. Do not assume the installer can invent a brand-new registry row for a fully wiped plugin.
4. Sync the source package surface into the generated install tree.
5. Rewrite host-specific path references for the target runtime.
6. Materialize the versioned cache tree and stable `current` alias.
7. If an uppercase `~/.Codex` mirror exists from an older install, back it up if needed and remove it as part of the migration. Do not keep uppercase and lowercase as two active install targets.
8. Remove stale aliases and deprecated registry ids.
9. Merge all hook payloads first, including any other installer-managed hook surfaces.
10. Seed trust/state once the hook set is final and stable.
11. Merge hook payloads only when the current workspace is a real project root.
12. Verify the live install in both the canonical host config and the non-project-root no-op path.

That sequence keeps the install idempotent and prevents stale surfaces from surviving a reinstall.

## 9. Verification checklist

Every Alo Labs plugin install should be checked with the same core questions:

- Does the canonical registry entry exist?
- Is the legacy alias gone?
- Does the live Codex install target resolve to lowercase `~/.codex` only, with no active dependence on uppercase `~/.Codex`?
- Does the live cache point at the expected versioned path?
- Are the host config mirrors synchronized?
- Are hook payloads present only where they should be?
- Is hook trust seeded after the final merged hook surface is stable, so the host does not re-flag hooks for review?
- Does each trust prefix hash the hook source it actually represents, instead of reusing one hook file for every prefix?
- Does the non-project-root install path stay clean?
- Are there any forbidden host-path references left in the install tree?
- Do the host-specific install tests pass?
- Does reinstalling produce the same state again?
- If the plugin was removed and reinstalled locally, does the fresh install rebuild the versioned cache, restore the canonical registry row if needed, and re-create the `current` alias from the local snapshot rather than relying on stale host state?

For Silver Bullet, the matching verification commands are:

- `bash tests/scripts/test-install-codex.sh`
- `bash tests/scripts/test-install-claude.sh`
- `git diff --check`

## 10. Silver Bullet reference implementation

If you want a concrete pattern to mirror, these are the key files from the Silver Bullet repo:

- `scripts/install-codex.sh`
- `tests/scripts/test-install-codex.sh`
- `tests/scripts/test-install-claude.sh`
- `hooks/hooks.json`
- `skills/tdd/SKILL.md`
- `skills/silver-feature/SKILL.md`
- `skills/silver-ui/SKILL.md`
- `skills/silver-bugfix/SKILL.md`

Use those as examples of how to keep the install surface canonical, isolated, and verifiable.
