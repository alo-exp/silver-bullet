# RFL rung 2 — review pass 7 (residual-only, Policy G)

- **Model:** Cursor Kimi K3 High (`kimi-k3-high` / `sb-kimi-k3-high`)
- **Confirmed SHA-256:** `f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6` (re-hashed `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md` via `shasum -a 256`, matches freeze)
- **Encoder brief:** `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-02-cursor-kimi-k3-high/brief-review-pass-7.md`
- **Method:** graphify CLI orientation query (surfaced only already-encoded ledger/verify nodes for this RFL), agentmemory session-note saved at pass start, then full re-read of the plan at the freeze SHA (all 784 lines, sequential 40-line chunked reads including frontmatter L1–L36), cross-checked against the issue ledger (I-1…I-64 plus aliases R2P3-1/2, R2P4-1/2/3, R2P5-1/2/3/4 — all ACCEPT/resolved at this SHA). Residual-only: no ledger rows re-reported. Spot-confirmed each pass-5 fix is still encoded in the text: §6.1 line 373 keeps the ban scoped to the `--x` shorthand and preserves the xAI leg's explicit `-m social -p xai` argv (R2P5-1 / I-61; restated at §6.2 line 421 and §6.13 line 660); §1.2 line 54 dedup clause reads "Dedup by tweet URL/id in the orchestrator (locked; §1.4)" with §1.4 line 101 "Dedup lives in `search_orchestrator.py`, not the fork", and a sweep for `or the fork` is zero-hit (R2P5-2 / I-62); §6.3 line 455 layout reads `buckets/{id}.lock` + `buckets/{id}.json`, and sweeps for `buckets/<host>` / `host.lock` / `host.json` are zero-hit (R2P5-3 / I-63); §7 mermaid line 697 Serper node reads `serper["Serper site: via -d (bare host) or -q (X / path-scoped)"]` (R2P5-4 / I-64); §1.2 line 85 rollup carries the rung-2 pass-5 ACCEPTs. Targeted sweeps also clean: `SEARCH_BRAVE_KEY` / `SEARCH_SERPER_KEY` appear only in do-not-contain/do-not-invent contexts (lines 65, 351, 575, 646); `${SB_REPO}` / `SB_REPO` only in never-clauses; `reddit_secret` / `SEARCH_KEYS_REDDIT_SECRET` only in never-clauses (lines 64, 571, 644); `--xweb` and "second `--x`" only in do-not-invent contexts; every historical X `must_search: false` carries an inline superseded marker (the line-198 Facebook row and the line-339 test assertion are the legitimate remaining `false`); `ProjectDirs` / `$HOME/.cache/search` appear only as never-clauses or the pinned unset human defaults (§6.2 line 412, §6.3 line 438, §6.8 line 542); bare `partial` hits are "partial gateway" / "partial JoinSet" prose, never a status value; `q2_*` appears only in clear() leftover delete-sets. Cross-section consistency re-verified: fingerprint field order with `--allow-private` last (§2.3 line 139, §4.1 line 330, §6.3 line 458, §8.4 line 776), intra-list `0x1F` + non-collision golden vectors (§4.3 line 338, §5 line 351, §6.12 line 636), `min(entry.ttl_secs, requested_ttl)` + `entry.count` hit rule (§2.2 line 125, §6.3 lines 461/464, §8.2 line 757), ceiling-10 quiesce/clear vs `0`…`{N-1}` admission (§1.2 line 73, §2.2 line 125, §6.3 line 463, §6.13 line 664), §2.2 line 120 bucket short-name list (12 ids) matches §6.4 host rows (12 buckets), §6.12 line 641 agent-info id set matches §2.2 line 124 probe native list, and every §2.8 **Signup —** row enumerated in the line-235 gate carries the `manual_only` stamp.

## Verdict: CLEAN

Zero valid ACCEPT-worthy findings remain at this SHA. All ledger rows (I-1…I-64, aliases R2P3/R2P4/R2P5) are encoded in the freeze text, and the fresh full-plan sweep surfaced no new residual at any severity (HIGH / MED / LOW / NIT).

---

## Considered, not filed (invalid)

Newly swept this pass:

- **Frontmatter line 27 (`phase-5-paid-social` todo) "xAI `-p xai`" shorthand without `-m social`:** Cursor plan task-list summary, not argv spec; the todo names the correct provider id and asserts no wrong mode. The operative xAI-leg contract (`-m social -p xai`, fleet never `--x`) is pinned at §1.2 line 54 leg B, §6.1 line 373, §6.2 line 421, §6.4 line 485 (R2P5-1 / I-61). Same bar as the pass-5/6 rejections of summary/diagram shorthand — REJECTED.
- **§2.1 line 115 "`search usage --json` once per DR run (Phase 6)" vs the M6 pre-run Serper check wired in Phase 3 (line 353):** no delivery conflict — `search usage` is upstream-existing (`src/usage.rs` leave-alone, §6.1 line 369), so the Phase 3 pre-check (§1.2 line 73 M6) can call it; the `(Phase 6)` tag denotes the ops-metrics formalization (§4.4 line 344, §5 line 356), not command availability — REJECTED.

Carried from pass 6 (unchanged at this SHA; re-verified):

- **§7 mermaid line 692 `slots["fleet-slots.lock/ 0.lock..N-1.lock"]` vs the ceiling-10 quiesce/clear set:** the label depicts the admission set (`0`…`{N-1}`, §2.2 line 125, §6.3 line 456); ceiling-10 materialization is the clear/quiesce-barrier contract pinned in prose (§1.2 line 73, §2.2 line 125, §6.3 line 463, §6.13 line 664) — REJECTED.
- **§7 mermaid missing edges (no `p3 --> q3`, no `p4 --> q3`/`bkt`, no `p2 --> official`):** illustrative edge set; cache/bucket usage for every provider is pinned in §6.3/§6.4 prose — REJECTED.
- **§3 overview mermaid line 287 `buckets[host_buckets]`:** coarse LR overview node label consistent with the plan's own "per-host token buckets" terminology (§2.1 line 110, §6.1 line 389); the not-a-hostname lock governs bucket ids/filenames (§2.2 line 120, §6.4 line 470) and the operative §6.3 layout uses `{id}` (R2P5-3) — REJECTED.
- **§2.4 line 156 CLI-contract example pairs `-p serper` with `--cache-ttl 86400`:** the example carries no `-d`/`site:` token — it illustrates argv shape, not a `site:` spawn; the actual Method B examples at §6.9 lines 598–601 use 21600 — REJECTED.
- **§1.2 line 59 "Source consent + autonomous signup (init)" bullet vs the `manual_only` creation default:** the bullet self-qualifies in-line (existing-account check first; CAPTCHA/2FA/ToS/payment pauses); operative gate at §2.7 step 5 line 224 and the §2.8 line-235 gate — REJECTED (pass-4 reasoning).
- **§6.4 line 470 bare `{id}.json` (only the `.lock` carries the full `{quota_dir}/buckets/` prefix):** same-line scope under `buckets/` is unambiguous — shorthand, not a path ambiguity — REJECTED.
- **§6.4 line 481 `stackexchange` capacity 30 / refill 30/s vs the 10k/day Stack Apps cap (§2.3 line 133):** design choice, not an internal contradiction; the provider also honors API `backoff` — REJECTED.
- **§2.8 line 232 "'Autonomous' = host agent after email connect" definition:** same self-qualified gated model as §1.2 line 59; the line-235 gate immediately follows — REJECTED.
- **§2.8 line 267 xAI row carries no `signup_automation` stamp:** no-new-signup row; line-235 gate ("**No signup** rows omit the field") + M-3 fail-closed cover it — REJECTED.
- **§2.5 line 178 X row `method: official_api` while the xweb leg is unofficial HTTP:** the row text discloses the mix; one-row list encoding is the locked catalog shape (I-5) — REJECTED.
- **§6.2 line 412 `ProjectDirs::from("", "", "search").cache_dir()` else `$HOME/.cache/search`:** fallback prose for the unset human default; §6.3 line 438 shows ProjectDirs already covers the Linux case — REJECTED.
- **§6.5 line 508 `filter_support` guidance omits reddit/x/xweb:** enumerates the contested arms only; `registry.rs` `known` test forces an arm to exist — REJECTED.
- **§6.1 line 369 `src/doctor.rs` under the "Leave alone" heading:** bounded-patch pattern, carried on the §8.1/§8.4 Modify checklists per I-19 — REJECTED.
- **§3 overview mermaid (lines 280–291) omits `fleet-slots.lock/` and the reddit token:** coarse LR overview; §7 is the detailed diagram — REJECTED.
- **§7 mermaid `official[… se …]` abbreviation for `stackexchange`:** diagram shorthand; canonical id pinned in §6.4/§6.12 — REJECTED.
- **§3.2 line 304 "`partial_success` + `providers_missing`":** SB-side recorded-gap field per §8.3 line 764, not an envelope-field claim — REJECTED.
- **§2.6 line 210 glossary "OAuth client: Reddit (and optional later X …)":** definitional aside, not scheduling — REJECTED.
- **§2.3 line 139 fingerprint summary order vs §6.3 line 458 field order:** summary prose; §6.3 + golden vectors authoritative — REJECTED.
- **§3.3 line 309 "agent-info is derived, not a separate registry":** hardcoded `-p` `values` drift-guard carried at §6.7/§6.12 per I-24 — REJECTED.
- **§2.2 line 124 / §3.2 line 304 "-p allowlist" phrasing:** shorthand; one-`-p`-per-process lock pinned at §2.2 line 125, §6.9 line 606, §6.10 line 619 — REJECTED.
- **§7 mermaid `procs` subgraph shows no X-leg process:** illustrative process set; X union argv pinned in §1.4/§2.5/§6.9 — REJECTED.
- **§8.4 item 10 test summary omits the `--allow-private` fingerprint and brave/serper acquire tests:** ten-line summary list; §6.12 lines 636/642 is the authoritative roster and carries both — REJECTED.
- **§5 Phase 3 line 353 "catalog `bucket` = fork short ids (including `registries`)" not naming `x`/`xweb`:** example parenthetical; §4.3 line 339 asserts bucket-equality including `registries`, `x`, and `xweb` — REJECTED.

## Leftover

None parked. No valid residuals found at this SHA — verdict is CLEAN.
