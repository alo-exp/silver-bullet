# RFL rung 2 — review pass 5 (residual-only, Policy G)

- **Model:** Cursor Kimi K3 High (`kimi-k3-high` / `sb-kimi-k3-high`)
- **Confirmed SHA-256:** `44bf064c33810669bf945f91a4e05afa24e5c82fef36a43dabe499f159d28fc4` (re-hashed `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md` via `shasum -a 256`, matches freeze)
- **Encoder brief:** `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-02-cursor-kimi-k3-high/brief-review-pass-5.md`
- **Method:** graphify CLI orientation query (surfaced only already-encoded ledger/verify nodes), then full re-read of the plan at the freeze SHA (all 784 lines, sequential chunked reads including frontmatter L1–L36), cross-checked against the issue ledger (I-1…I-60 plus aliases R2P3-1/2 and R2P4-1/2/3 — all ACCEPT/resolved at this SHA). Residual-only: no ledger rows re-reported. Verified each ledger fix is actually encoded in the text (spot-confirmed: §6.3 line 459 and §6.9 line 595 now carry the locked X `site:x.com`-in-`-q` exception to the bare-host `-d` rule (R2P4-1); §2.8 line 271 X `search/all` row now stamps `signup_automation: manual_only` (R2P4-2); frontmatter line 3 overview now reads "drives signup under per-row `signup_automation` gates (creation defaults `manual_only`; existing-account check first)" — no autonomous-signup overclaim (R2P4-3); §2.2 line 120 bucket short-names include `x`/`xweb` (R2P3-1); §6.8 line 572 xweb envs load via `resolve_keys`, not figment `split("_")` (R2P3-2); §1.2 line 85 rollup carries the rung-2 pass-1/2/3/4 ACCEPTs; §2.7 step 3 `site:`→Serper/Brave consent dependency; §2.7 step 2 xweb ban-risk required copy; §4.4 X-credit-0 alert falls back to `-p xweb` / xAI / dedicated `site:x.com`; §4.1/§5/§8.1/§8.4 `clear()` rosters include future `qN_*`, orphaned `last.json.tmp.*`, and query-cache `.gitignore`; §6.12 serper/x/xweb/brave acquire tests, `--allow-private` fingerprint test, human-run `cache_ttl_default_300s` negative test; §7 mermaid quota subgraph has `reddit-oauth-token.json` + `.lock` and the providers node includes `x`/`xweb`; §6.3/§6.4 sub-bullets on their own lines; every §2.8 **Signup —** row enumerated in the line-235 gate now carries the `manual_only` stamp).

## Verdict: NOT CLEAN

Four valid residuals remain at this SHA (one LOW, three NIT).

---

## R2P5-1 — LOW — §6.1 "Fleet never passes `--x` / `-m social`" forbids the locked xAI union leg's explicit `-m social -p xai` argv

- **Cite:** §6.1 line 373: "- `Mode::Social` + `--x` → `-m social -p xai` (`main.rs` ~299–302). Fleet never passes `--x` / `-m social`. **Do not** add `--xweb` or a second `--x`; unpaid path is `-p xweb` only." Against the locked X union leg B: §1.2 line 54 ("**(3) B xAI:** if `XAI_API_KEY` configured, same binary `search` with `-m social -p xai` (fleet never passes `--x`)"), §1.4 line 101 ("Search-cli `-m social` (xAI) is an **X-channel leg**, not the default mode for other channels"), §2.5 line 178 ("`-p xai` with `-m social` when `XAI_API_KEY` is configured (fleet never `--x`)"), §2.8 line 267 ("Do **not** use `-m social` as the default mode for non-X channels").
- **Defect:** every other lock scopes the prohibition to the `--x` **shorthand** (which force-overwrites `mode = Social` + `providers = ["xai"]` after parse, §6.2 line 421) or to `-m social` as a *default mode for non-X channels*. §6.1 line 373's "Fleet never passes `--x` / `-m social`" reads as an outright ban on `-m social`, which contradicts leg B — the orchestrator **does** spawn `search … -m social -p xai` for the xAI leg when `XAI_API_KEY` is configured. An implementer coding the orchestrator argv builder from §6.1 could omit the xAI leg or "correct" it to `-p xai` without `-m social`.
- **Why not a ledger re-report:** no ledger row (I-1…I-60, R2P3-1/2, R2P4-1/2/3) covers the §6.1 line-373 wording. The 2026-08-31 X locks (§1.2/§1.4/§2.5/§2.8) and the "do not invent `--xweb` / second `--x`" rows pin the shorthand ban and the leg-B argv, but none repaired the overbroad "`/ -m social`" clause in §6.1.
- **Fix:** scope line 373 to the shorthand, e.g. "Fleet never passes `--x` (the shorthand that forces `-m social -p xai`); the X union's xAI leg passes explicit `-m social -p xai` (§1.2 leg B). `-m social` is never the default mode for non-X channels."

## R2P5-2 — NIT — §1.2 rung-2 bullet still permits X dedup "or the fork if one process unions" against the locked "orchestrator, not the fork"

- **Cite:** §1.2 line 54: "Dedup by tweet URL/id in the orchestrator (preferred) or the fork if one process unions." Against §1.4 line 101: "**Dedup (SB orchestrator, locked):** each X leg is a separate `search` process … Dedup lives in **`search_orchestrator.py`**, not the fork." and §2.5 line 178: "Dedup is the SB orchestrator contract in §1.4 (not the fork)."
- **Defect:** the line-54 parenthetical leaves a fork-side dedup path open that the later locked text flatly forbids. For the fleet the clause is vacuous (one `-p` per process; each X leg is a separate process, so no single process ever unions X legs), so the only reading it sanctions is an unsanctioned human/ fused `-p x,xweb` process doing in-fork dedup — which §1.4/§2.5 rule out. Two locked paragraphs disagree in strictness.
- **Why not a ledger re-report:** I-1 (F1) locked and encoded orchestrator-side dedup at §1.4/§4.3/§1.2-line-85; no ledger row addresses the surviving "(preferred) or the fork" parenthetical inside the rung-2 §1.2 bullet itself.
- **Fix:** strike "or the fork if one process unions" from line 54 (or annotate it superseded by the §1.4 lock), leaving "Dedup by tweet URL/id in the orchestrator (locked; §1.4)".

## R2P5-3 — NIT — §6.3 quota layout names bucket files `buckets/<host>.*` where the operative contract is `{id}` (and bucket ids are locked as *not* API hostnames)

- **Cite:** §6.3 line 455: "- `buckets/<host>.lock` + `buckets/<host>.json`". Against §6.4 line 470: "Files: `{quota_dir}/buckets/{id}.lock` (flock inode) and `{id}.json`", and §2.2 line 120: "`bucket` is the fork token-bucket **id** from §6.4 (short names: `stackexchange`, `github`, `gitlab`, `youtube`, `serper`, `brave`, `hn`, `reddit`, `registries`, `x`, `xweb`, `discourse-<sanitized-host>`). It is **not** an API hostname (`api.stackexchange.com` is wrong)."
- **Defect:** most bucket ids are provider short names, not hosts (`serper`, `brave`, `registries`, `x`, `xweb`, …); only `discourse-<host>` embeds a host. The `<host>` placeholder in the §6.3 layout sketch undercuts the explicit not-a-hostname lock and could steer an implementer toward host-derived filenames (e.g. `api.stackexchange.com.lock`) that collide with the §6.4 `{id}` contract and the SB catalog-equality test (§4.3 line 339).
- **Why not a ledger re-report:** I-5 / rung-3 locked catalog `bucket` values to fork short ids and §2.2 line 120 carries that lock; no ledger row covers the §6.3 layout line's `<host>` placeholder.
- **Fix:** change line 455 to "`buckets/{id}.lock` + `buckets/{id}.json`" (matching §6.4 line 470).

## R2P5-4 — NIT — §7 mermaid Serper node "Serper site via -d" omits the two locked `-q` exceptions

- **Cite:** §7 mermaid line 697: `serper[Serper site via -d]`. Against the locked exceptions: §6.3 line 459 / §6.9 line 595 ("**Locked X complement exception (2026-08-31):** the dedicated X Serper last-resort leg carries `site:x.com` in `-q` and **omits `-d`**") and the path-scoped exception (§6.9 line 595: "`site:linkedin.com/posts` … append the full `site:host/path` token to `-q` … **omit `-d`**"; example line 601).
- **Defect:** §7 is the "Exact fork architecture" diagram and its only Serper mechanism label asserts the bare-host `-d` path unqualified. Two locked legs (dedicated X `site:x.com`; all path-bearing `site_query` rows) carry `site:` in `-q` with no `-d`. The ladder has already held §7 to this accuracy bar (K7 quota-token node, K11 provider ids — both ACCEPTed), so the stale mechanism label is a same-class residual.
- **Why not a ledger re-report:** K7/K11 (I-51/I-55) added missing §7 nodes for the reddit token and `x`/`xweb` providers; no ledger row covers the Serper node label. R2P4-1 repaired the §6.3/§6.9 prose rule, not the §7 diagram.
- **Fix:** relabel, e.g. `serper["Serper site: via -d (bare host) or -q (X / path-scoped)"]`, or add a one-line note under the diagram naming the two `-q` exceptions.

---

## Considered, not filed (invalid)

- **§2.8 line 267 xAI row carries no `signup_automation` stamp:** the row is explicitly "(leg B, no new signup if key exists)" — a no-new-signup row, and the line-235 gate ("**No signup** rows omit the field") plus the M-3 fail-closed-to-`manual_only` rule cover it; the gate's enumeration does not list xAI, so there is no row/enumeration mismatch (contrast R2P4-2, where the gate *did* enumerate X `search/all`). REJECTED.
- **§2.5 line 178 X row `method: official_api` while the xweb leg is unofficial HTTP:** the row text itself discloses the mix ("(official) **plus** … (unpaid native)"); `method` distinguishes fork-native `-p` providers from `search_cli_site` / `paid_api`, and the one-row list encoding is the locked catalog shape (I-5). Defensible — REJECTED.
- **§6.2 line 412 "`ProjectDirs::from("", "", "search").cache_dir()` else `$HOME/.cache/search`":** fallback prose for the unset human default; §6.3 line 438 (macOS `~/Library/Caches/search` vs `~/.cache/search`) shows ProjectDirs already covers the Linux case. Not a contradiction — REJECTED.
- **§6.5 line 508 `filter_support` guidance omits reddit/x/xweb:** rejected in pass 4 (enumerates the contested arms only; `registry.rs` `known` test forces an arm to exist); unchanged at this SHA — REJECTED.
- **§6.1 line 369 `src/doctor.rs` under the "Leave alone" heading:** rejected in pass 4 (bounded-patch pattern, carried on the §8.1/§8.4 Modify checklists per I-19); unchanged — REJECTED.
- **§3 overview mermaid (lines 280–291) omits `fleet-slots.lock/` and the reddit token:** rejected in pass 3 (coarse LR overview; §7 is the detailed diagram); unchanged — REJECTED.
- **§7 mermaid `official[… se …]` abbreviation for `stackexchange`:** rejected in pass 3 (diagram shorthand; canonical id pinned in §6.4/§6.12); unchanged — REJECTED.
- **§3.2 line 304 "`partial_success` + `providers_missing`":** rejected in pass 3 (SB-side recorded-gap field per §8.3 line 764, not an envelope-field claim); unchanged — REJECTED.
- **§2.6 line 210 glossary "OAuth client: Reddit (and optional later X …)":** rejected in pass 4 (definitional aside, not scheduling); unchanged — REJECTED.
- **§2.3 line 139 fingerprint summary order vs §6.3 line 458 field order:** rejected in pass 4 (summary prose; §6.3 + golden vectors authoritative); unchanged — REJECTED.
- **§3.3 line 309 "agent-info is derived, not a separate registry":** rejected in pass 4 (hardcoded `-p` `values` drift-guard carried at §6.7/§6.12 per I-24); unchanged — REJECTED.
- **§2.2 line 124 / §3.2 line 304 "-p allowlist" phrasing:** rejected in pass 4 (shorthand; one-`-p`-per-process lock pinned at §2.2 line 125, §6.9 line 606, §6.10 line 619); unchanged — REJECTED.
- **§7 mermaid `procs` subgraph shows no X-leg process:** illustrative process set (`pN["search -p youtube ..."]`); the diagram does not claim exhaustiveness and the X union argv is pinned in §1.4/§2.5/§6.9 — REJECTED.
- **§8.4 item 10 test summary omits the `--allow-private` fingerprint and brave/serper acquire tests:** ten-line summary list; §6.12 (lines 636, 642) is the authoritative test roster and carries both — REJECTED.
- **§5 Phase 3 line 353 "catalog `bucket` = fork short ids (including `registries`)" not naming `x`/`xweb`:** example parenthetical; §4.3 line 339 asserts bucket-equality including `registries`, `x`, and `xweb` — REJECTED.

## Leftover

None parked. All valid residuals found at this SHA are filed above (R2P5-1, R2P5-2, R2P5-3, R2P5-4).
