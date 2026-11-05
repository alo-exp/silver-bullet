# Site and Help-Center Publishing (maintainers)

Maintainer rules for work under `site/` (homepage, help center, changelog page, search index, OG cards). Moved here from `AGENTS.md`, which now links to this page. The help-center look and structure are described in [help-center-guidelines.md](help-center-guidelines.md).

## Authoring

- Help pages share `site/chrome.css`, `site/tokens.css` and the nav/footer fragments in `site/_chrome/`. `scripts/apply-site-chrome.py` rewrites every page's nav and footer from those fragments (it takes no options and edits files in place), and `hooks/site-chrome-guard.sh` blocks inline `<nav>`/`<footer>` edits.
- Add new help pages to `site/help/search.js` so search finds them.
- Website and help-center copy is written and reviewed by delegated subagents rather than by the parent agent alone; the maintainer's host-level subagent model policy lives in their global Cursor rules, not in this repository.

## Workflow catalog order

Workflow and atomic-flow listings on the homepage (`site/index.html`, both tabs) and in the help center (`site/help/workflows/`, reference tables, the composable-workflow concept page) follow typical software-delivery lifecycle order, top to bottom: entry/router → discovery/planning → primary delivery → fast/specialized paths → infrastructure → ship/release → reusable post-delivery gates → operations/learning. Atomic flows (`AF-*`) are ordered by capability class: orient/bootstrap → plan/specify → research → execute → verify/test → review → ship/deploy → document/process. This is a presentation order, not runtime composition order; `tests/scripts/test-site-structural-consistency.sh` checks it.

## Publishing

- Content under `site/` can be published as a direct commit to `main` without a patch release, version bump, tag or GitHub release. Do not bump `package.json` or plugin manifests, or run release automation, for a site-only publish unless a release was requested.
- Before pushing, run the site tests: `bash tests/scripts/test-site-doc-freshness.sh`, `bash tests/scripts/test-site-content-freshness.sh` and `bash tests/scripts/test-site-structural-consistency.sh`. The full suite is not required for site-only work.
- `.github/workflows/pages.yml` deploys GitHub Pages on pushes to `main` that touch `site/**`. CI (`ci.yml`) still runs on every push, but a site-only publish does not wait for it.
- Latency: the workflow's checkout and upload steps take seconds, but `actions/deploy-pages` can wait several minutes in GitHub's queue, and GitHub Pages serves `Cache-Control: max-age=600`, so `https://sb.alolabs.dev/` may show the old page for up to ten minutes after the workflow succeeds. Allow up to about fifteen minutes end to end.

## Announcing a publish

Do not report a change as live until the deployed page shows it. A pushed commit or a successful Pages workflow is not enough: fetch the public URL (for example `https://sb.alolabs.dev/` or the specific help page), confirm markers from the commit (hero copy, tab labels and counts, table rows, removed sections, CSS markers), and check the response headers (`Last-Modified`, `ETag`, `Cache-Control`, `Age`). If the content does not match yet, wait for `pages.yml` and fetch again, or report honestly that the deploy is pending, failed or cached.

The report names the commit SHA on `main`, what went live, an explicit **LIVE** or **NOT LIVE** status with the fetched evidence, the GitHub release URL if a release was cut, and whether the site tests passed.
