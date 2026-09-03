# RFL rung 2 — review pass 2 (residual-only, Policy G)

- **Model:** Cursor Kimi K3 High (`kimi-k3-high` / `sb-kimi-k3-high`)
- **Confirmed SHA-256:** `9b79d0144559ac6abbe360f39f7c894742295bb0f1e245124b21606559099a21` (re-hashed this pass; matches freeze)
- **Encoder brief:** `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-02-cursor-kimi-k3-high/brief-review-pass-2.md`
- **Method:** graphify CLI orientation query, then full plan re-read (all 783 lines, paged) of `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`; every ledger row (I-1…I-50, K1–K6) spot-checked against its encoding site; four prior-hop leftovers evaluated against the freeze.

## Verdict: NOT CLEAN

Five valid residuals at this SHA (1 LOW, 4 nit). No ledger rows re-reported — all findings below are defects **not** on the ledger.

## New findings

### K7 — nit — §7 mermaid quota subgraph omits the Reddit token node

- **Cite:** §7 mermaid, lines 690–693: `subgraph quota ["SEARCH_QUOTA_DIR"]` contains only `bkt["buckets/*.lock + *.json"]` and `slots["fleet-slots.lock/ 0.lock..N-1.lock"]`.
- **Defect:** §6.3 (line 457) and §6.11 (line 624) place `{quota_dir}/reddit-oauth-token.json` **and** `{quota_dir}/reddit-oauth-token.lock` under `SEARCH_QUOTA_DIR`, and the quiesce barrier (§2.2 line 125, §6.3 line 463) waits on `reddit-oauth-token.lock`. The "Exact fork architecture" diagram models the quota dir without the token file/lock, so a fork implementer reading §7 gets an incomplete on-disk layout for the quota dir.
- **Why not a ledger re-report:** I-23/W4 (TTL double-check), I-25/W6 (absent lock unlockable), I-38/AC2 (held lock drives `cache_clear_busy`) are behavior/text encodings in §6.3/§6.11/§6.12 — none touched the §7 diagram. No ledger row cites §7 mermaid.
- **Fix:** add a `tok["reddit-oauth-token.json + .lock"]` node to the §7 `quota` subgraph (optionally also to the §3 high-level `quota` node, line 286–287, which likewise shows only `buckets`).

### K8 — LOW — §6.12 `config.example.toml` test bundles Phase 2 X keys with no phase-gating

- **Cite:** §6.12 line 646: the `config.example.toml` comment test requires `SEARCH_KEYS_X` / `SEARCH_KEYS_XWEB_GUEST` (and `X_BEARER_TOKEN` / `X_GUEST_TOKEN` / `XWEB_COOKIES` per §6.8) **in the same assertion** as the Phase 1 key set. Contrast §6.8 line 572 ("Phase 2: `x` bearer … Phase 2 unpaid: `xweb_guest_token` / `xweb_cookies`"), §6.8 line 575 (locked **Phase 1** regression test lists only BRAVE/SERPER/GITHUB/GITLAB/STACKEXCHANGE/YOUTUBE/REDDIT/REDDITSECRET), and §5 Phase 1 acceptance (line 351, same Phase 1-only set; Phase 2 acceptance at line 352 has no `config.example.toml` X-key test).
- **Defect:** the §6.12 test as written can only pass after Phase 2 lands `keys.x` / `keys.xweb_*`, yet it is not phase-gated and contradicts the locked Phase 1 regression-test scope in §6.8/§5. A fork implementer adding §6.12 tests with Phase 1 (cache/bucket/clap tests are Phase 1) either fails CI or prematurely documents Phase 2 keys.
- **Why not a ledger re-report:** K3 was §2.7 step-4 key persistence; I-17 was `--cache-ttl` phase labeling; no ledger row covers the X-key phase-gating of the §6.12 `config.example.toml` test.
- **Fix:** split line 646: Phase 1 assertion keeps the §6.8/§5 locked set; move the `SEARCH_KEYS_X` / `SEARCH_KEYS_XWEB_GUEST` / `X_BEARER_TOKEN` / `X_GUEST_TOKEN` / `XWEB_COOKIES` assertions to a Phase 2-gated test (or annotate "Phase 2").

### K9 — nit — §2.3 fingerprint summary omits `--allow-private`

- **Cite:** §2.3 line 139: "Cache fingerprint: provider + normalized query (lowercase, stable `site:` order) + domains/filters. **Not** `count` … **Not** effective TTL …".
- **Defect:** the locked fingerprint (item 10 M-4; §4.1 line 330; §6.3 line 458; §8.4 line 775) includes the `--allow-private` boolean as the **last** field (and `mode`, inherited from upstream). §2.3 is the non-functional summary a reader consults for the hash contract; it enumerates the exclusions (`count`, TTL) while omitting a contested **inclusion** that was explicitly locked to stop human `--allow-private` writes poisoning fleet `q3_` hits. Stale relative to the S1/W2 resolutions.
- **Why not a ledger re-report:** I-16/S1 and I-21/W2 were encoded at §4.1/§6.3/§8.4; the §2.3 summary line was not part of those fixes and no ledger row cites §2.3 line 139.
- **Fix:** amend §2.3 line 139 to "provider + mode + normalized query (lowercase, stable `site:` order) + domains/filters + `--allow-private` boolean" (keeping the existing **Not** `count` / **Not** TTL clauses).

### K10 — nit — §2.2 / §5 Phase 3 "SB repo `.gitignore`" phrasing mis-targets the root ignore

- **Cite:** §2.2 line 125: "Phase 3 adds `.planning/research/_search-cache/` to the SB repo `.gitignore`." Same phrasing at §5 Phase 3 line 353: "SB root `.gitignore` lists `.planning/research/_search-cache/`".
- **Defect:** `SEARCH_CACHE_DIR` is the **researched project's** git toplevel (`git rev-parse --show-toplevel` of the researched project, §1.2/§2.2), which in general is not the SB repo. The general never-commit mechanism is the orchestrator-written inner `{SEARCH_CACHE_DIR}/.gitignore` (`*` + `!.gitignore`); a root-`.gitignore` addition only helps when the researched project is the SB repo itself. As written, the Phase 3 step reads as though ignoring in the SB repo covers fleet runs — it does not for any other researched project.
- **Why not a ledger re-report:** no ledger row covers the gitignore targeting; I-40/AD1 and I-41/AE1 were about `clear()` preserving the query-cache `.gitignore`, a different defect.
- **Fix:** rephrase to "adds `.planning/research/_search-cache/` to the researched project's root `.gitignore` when one exists (and to the SB repo's own `.gitignore` for SB self-runs); the orchestrator-written inner `.gitignore` remains the primary guard."

### K11 — nit — §7 mermaid providers subgraph omits `x` / `xweb`

- **Cite:** §7 mermaid line 695: `official[github gitlab se hn discourse youtube registries reddit]`.
- **Defect:** `x` (official) and `xweb` (unpaid native) are Phase 2 MVP must-search providers — §2.5 line 178, §6.1 line 390, §6.12 line 641 (`agent-info` names include `x,xweb`), §8.1 lines 734–735. The "Exact fork architecture" provider node enumerates the other eight new providers and omits both X legs, inconsistent with the rest of the freeze.
- **Why not a ledger re-report:** I-48/K4 fixed the §2.2 probe native list; I-5 fixed the catalog row encoding; no ledger row cites the §7 diagram provider list.
- **Fix:** change the node to `official[github gitlab se hn discourse youtube registries reddit x xweb]`.

## Evaluated-not-filed leftovers

None. All four prior-hop leftovers were judged **valid** at this SHA and are filed above:

1. §7 mermaid quota-node omission → **K7** (valid).
2. §6.12 X-key phase-gating vs §5 Phase 1 → **K8** (valid).
3. §2.3 fingerprint summary omits `--allow-private` → **K9** (valid).
4. §2.2 "SB repo `.gitignore`" phrasing → **K10** (valid).

## Ledger re-report check

Spot-checked encodings for I-1…I-50 / K1–K6 at this SHA (§1.2 line 85 rollup, §2.2 probe list, §2.7 step 3/4, §3.2 `partial_success`, §3.4 `SB_SEARCH_BIN`, §4.3/§4.4, §5 Phase 1, §6.3/§6.4 sub-bullets and preserve rosters, §6.12 test roster, §8.1/§8.4 doctor.rs rows): all present as resolved. No ledger defect recurs; nothing above restates a ledger row.

## Leftover

None parked. Everything valid found this pass is filed (K7–K11).
