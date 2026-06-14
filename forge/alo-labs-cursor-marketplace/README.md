# alo-labs-cursor-marketplace

Public Cursor plugin marketplace for [Ālo Labs](https://alolabs.dev) plugins.

## Install Silver Bullet

1. In Cursor, add this marketplace:
   - **Source:** `https://github.com/alo-labs/alo-labs-cursor-marketplace`
2. Install the `silver-bullet` plugin from the marketplace.
3. In your project, run `/silver:init`.

For Silver Bullet development from a repository checkout, use:

```bash
bash scripts/install-cursor.sh
```

## Marketplace layout

```text
.cursor-plugin/
  marketplace.json   # indexes available plugins
```

Plugin content is fetched from the upstream source repository declared in each marketplace entry (`alo-exp/silver-bullet` for Silver Bullet).

## Version sync

Release bumps are pushed from the Silver Bullet source repo via:

```bash
scripts/sync-cursor-marketplace-version.sh <version>
```

That script is also invoked by `scripts/sync-release-marketplace-versions.sh` during release prep.
