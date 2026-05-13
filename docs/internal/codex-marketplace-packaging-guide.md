# Codex Marketplace Packaging Guide for Alo Labs Plugins

This guide explains how to package an Alo Labs plugin for Codex when the plugin is
already maintained elsewhere, or when it only ships Claude-oriented artifacts today.
The shared marketplace lives at `https://github.com/alo-labs/codex-plugins`.

## Core rule

Codex packaging is a thin compatibility layer.

- The source plugin repo remains authoritative for skills, hooks, templates, docs, and
  any other core artifacts.
- The Alo Labs Codex marketplace holds only packaging glue: manifest metadata,
  install-time fetch logic, and any Codex-specific adaptation needed to expose the
  upstream plugin cleanly.
- Do not vendor upstream plugin content into the marketplace repo unless the upstream
  project explicitly ships a Codex-ready artifact that is meant to be mirrored there.

## When to create a Codex package

Create a Codex package in the marketplace when:

1. The plugin is useful in Codex.
2. The upstream project does not already publish a Codex package.
3. The plugin has a clear installable surface that Codex can consume, even if the
   upstream project was originally built for Claude.

If the upstream project already publishes Codex packaging, prefer the upstream source
of truth and add only a marketplace entry or pointer if needed.

## Package model

Think in three layers:

1. **Upstream plugin repo**  
   Owns the real content and release history.
2. **Alo Labs Codex marketplace**  
   Owns discovery, manifesting, and thin compatibility wrappers.
3. **Local Codex install cache**  
   Holds the materialized result after installation.

The marketplace should not become a second source tree for plugin logic.

## Recommended package layout

Keep each Codex wrapper in its own package directory under the marketplace repo.
A practical layout is:

```text
third-party-plugins/<publisher>/<plugin-name>/
  .codex-plugin/
    plugin.json
  scripts/
    install.sh
    sync-upstream.sh
  README.md
  LICENSE
```

Use the existing repo convention if one already exists, but keep the same separation:
manifest, installer glue, and no vendored upstream core files.

## What the wrapper may contain

The wrapper can include:

- Codex manifest files
- Marketplace metadata
- Install scripts
- Minimal shim logic to fetch or assemble upstream content
- Small adaptation files that are specific to Codex packaging

The wrapper should not include:

- Copied upstream skills
- Copied upstream hooks
- Copied upstream templates
- Copied upstream project docs
- A second, forked implementation of the plugin

## How install-time fetching should work

When a plugin has no native Codex package:

1. The wrapper identifies the upstream source repo.
2. The installer fetches the needed upstream tree at install time.
3. The installer materializes the files into the Codex plugin cache or install target.
4. The marketplace repo keeps only the wrapper, not the fetched payload.

Use a deterministic source when possible:

- pin a tag
- pin a release branch
- or pin a commit SHA

Avoid unbounded "latest" fetches unless that is the upstream project’s explicit install
contract and the wrapper can tolerate drift.

## Dependency policy

For Alo Labs plugins that depend on other plugins:

- First-party dependencies should be installed from their own official source repos
  or official installers.
- The Codex package for the parent plugin should not bundle those dependencies.
- If a dependency does not have Codex packaging, create a separate Codex wrapper in
  the shared marketplace and fetch the dependency from its upstream source during
  installation.

That keeps ownership clear and prevents the parent package from silently absorbing
another project’s content.

## Versioning rules

Keep versions in sync with the upstream plugin whenever possible.

- Bump the marketplace package when the upstream plugin changes in a way that affects
  Codex behavior.
- Treat the marketplace manifest as install metadata, not as a forked release branch.
- Preserve upstream attribution and license information.

## Testing checklist

Before publishing a new Codex package, verify the following:

1. A clean Codex environment can install the package from the Alo Labs marketplace.
2. The package installs without depending on local repo state.
3. The package materializes the expected upstream content.
4. The package does not copy unrelated project artifacts into the marketplace repo.
5. Re-running the install is idempotent.
6. If the package depends on other plugins, those dependencies install from their own
   official source paths.

For Claude-first upstream plugins, also confirm that the Codex wrapper respects the
Claude-originated structure instead of rewriting the plugin from scratch.

## What not to do

- Do not create a second marketplace for the same Alo Labs package family.
- Do not copy upstream plugin contents into the SB repo.
- Do not vendor dependency plugins into a parent package.
- Do not invent a Codex surface that the runtime does not expose.
- Do not mix project-instance artifacts with plugin artifacts.

## Mental model to keep

The marketplace is a registry of installable Codex packages, not a mirror of every
plugin’s source tree. The wrapper belongs in the marketplace; the real content belongs
upstream.

## Related install playbook

For the concrete install and hook hygiene checklist that came out of the Silver Bullet
Codex cleanup work, see
[docs/internal/alo-labs-plugin-installation-playbook.md](docs/internal/alo-labs-plugin-installation-playbook.md).
