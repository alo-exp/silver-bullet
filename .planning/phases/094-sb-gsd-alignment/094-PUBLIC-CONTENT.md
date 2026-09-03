# Phase 94.01 Public Content Refresh Evidence

## Surfaces Reviewed

- `README.md`
- `site/index.html`
- `site/sb-vs-gsd/index.html`
- `site/help/index.html`
- `site/help/reference/index.html`
- `site/help/search.js`
- `site/help/concepts/*`
- `site/help/workflows/*`
- `site/compare/index.html`
- `.claude-plugin/plugin.json`
- `plugins/silver-bullet/.codex-plugin/plugin.json`
- `package.json`
- `.silver-bullet.json`
- `templates/silver-bullet.config.json.default`

## Updates Made

- Made dark-theme/APO/SB+GSD positioning consistent across current public pages.
- Refreshed Help Center workflow wording so GSD owns lifecycle execution and helper plugins are contextual.
- Added or corrected SB-vs-GSD positioning where public pages described workflow composition.
- Updated all current version surfaces to `v0.35.0`.
- Reworded the comparison page category summary so it no longer says Superpowers leads planning.

## Clean Pass Evidence

### Pass 1

Command:

```bash
rg -n "0\.34\.0|v0\.34\.0|0\.33\.0|v0\.33\.0" README.md site docs package.json .claude-plugin/plugin.json plugins/silver-bullet/.codex-plugin/plugin.json .silver-bullet.json templates/silver-bullet.config.json.default --glob '!docs/audits/**' --glob '!docs/superpowers/**'
```

Result: no matches in active public surfaces.

### Pass 2

Same command rerun.

Result: no matches in active public surfaces.

JSON validation:

```bash
jq empty .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json templates/silver-bullet.config.json.default package.json .silver-bullet.json plugins/silver-bullet/.codex-plugin/plugin.json
```

Result: all valid.

## Public Content Verdict

Current public content reflects v0.35.0 positioning and does not expose stale SB/GSD/Superpowers ownership claims in active surfaces.
