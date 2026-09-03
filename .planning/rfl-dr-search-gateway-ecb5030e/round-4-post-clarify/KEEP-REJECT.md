# Launcher-only — do not paste into reviewer briefs

Parent asks the user (`decision_class: locked`) before APPLY that would unwind a prior product decision. Reviewers are **not** told to KEEP REJECT or keep these locks.

## Product locks (2026-08-31 + re-clarify)

- Runtime: one public MIT `alo-exp/search-cli` fork gateway. Recommendation **C**. Not agent-reach as runtime. Not a second Python engine (`search_gateway.py`).
- X is **must-search** (`must_search: true`, `mvp: true`). Offer at init.
- X union: official `-p x` (`search/recent`) + unpaid in-fork `-p xweb` + xAI `-p xai` (fleet **never** `--x`) + dedicated Serper `site:x.com` last-resort. Dedup by tweet id/URL.
- Do not invent `--xweb` or a second `--x` (upstream `--x` = `-m social -p xai`).
- No exec `twitter` / `opencli` / `bird`; no desktop Chrome fleet; no Nitter; no scrape google.com.
- Facebook stays `must_search: false`. Locked-out: SourceHut, Codeberg, Papers with Code, Discord, Slack, Anthropic Help.
- Plan §1.2 historical RFL ACCEPT rows (cache, quota, redditsecret, fleet slots, collector, catalogs enum, `signup_automation: manual_only`, …) remain in force.

## Forbidden reject reasons (Policy A)

Do not REJECT as advisory / doc-only / non-gating / nice-to-have / CLEAN-so-ignore. REJECT only if wrong, KEEP REJECT collision, or would unwind a lock above without user decision.
