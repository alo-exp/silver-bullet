model: glm-5.2-high

# Review pass 15 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `32b8f337499b1933a57bf6ad438929c4b2cdbe821f0fb6a77cae337ea2a5407b` (match — `shasum -a 256` confirmed before review).
Scope: residual-only against ledger I-1…I-39 (all ACCEPT+applied) plus the AC1–AC3 APPLY at this SHA. New findings only; I-1…I-39 not re-reported. This is the first re-review after the AC1–AC3 ACCEPT-apply (streak reset to 0). The plan was re-read end-to-end (§1.2 ledger clauses, §1.3–§1.4, §2.1–§2.8, §3, §4.1–§4.4, §5, §6.1–§6.13, §7, §8.1–§8.4) and cross-checked independently; AC1–AC3 spot-checked at their apply sites.

Method: bird's-eye (§1.2 locked-decisions log vs operative §2/§4/§6/§8; X-union one-row + dedup key; cache/quota split; fleet-slots orchestrator-only + ceiling-10; superseded-annotation completeness across all §1.2 rung/round clauses; acquire-granularity per provider; fingerprint-field roster and ordering; warning-replay set; quiesce ceiling-10; clear() delete-set + preserve-set parity across §2.2/§4.1/§6.3/§6.12/§8.1/§8.4; reddit token lock in quiesce barrier; round-4 rung-1 ACCEPT coverage) then ant's-eye (line-by-line cross-section consistency across §2.1–§2.8, §3, §4.1, §4.3, §4.4, §5, §6.1–§6.13, §7, §8.1–§8.4). Graphify CLI run for orientation (`graphify query` on dr_search_gateway PRD plan §6.12 tests: clear() last.json.tmp, reddit-oauth-token.lock cache_clear_busy, reddit token-endpoint bucket isolation, X-union dedup, AC1–AC3 apply sites, L85 rollup) — surfaced the AC1/AC2/AC3 finding nodes and prior W5/I-24, W6/I-25, AB1–AB4 nodes, all of which are in the applied ledger and excluded per Policy G. agentmemory capture deferred to the parent per rung contract.

Result: NOT CLEAN — 1 new residual (AD1 NIT).

---

## AC1–AC3 APPLY spot-check (this SHA)

All three APPLYs are present and internally consistent at the locked sites.

AC1 / I-37 — §6.12 (line 634) `clear()` test now seeds the orphaned `last.json.tmp.*` fixture and asserts removal:

> "…plus `last.json` plus orphaned `last.json.tmp.*` (seed `last.json.tmp.{pid}.{nanos}` / `{uuid}` and assert removal) plus `fleet-slots.lock/` slot files…"

The `last.json.tmp.{pid}.{nanos}` / `{uuid}` seed-and-assert-removal is new vs pass-14 and closes the AC1 gap. Matches §6.3 (line 462) "orphaned `last.json.tmp.*` (`last.json.tmp.{pid}.{nanos}` / `{uuid}` leftovers after a killed write…)", §4.1 (line 330), §8.1 (line 736), §8.4 (line 773).

AC2 / I-38 — §6.12 (line 635) `cache_clear_busy` test now covers both the held and absent `reddit-oauth-token.lock` cases:

> "…`cache clear` while a slot or `.inflight` is held **waits up to 30s then refuses** (`cache_clear_busy`, nonzero, no unlink) — must not admit N+1 / a second leader; held `reddit-oauth-token.lock` also drives `cache_clear_busy` / no-unlink; absent `reddit-oauth-token.lock` is unlockable (ENOENT; clear proceeds)"

The held-→-busy and absent-→-unlockable (ENOENT) assertions are new vs pass-14 and close the AC2 gap. Matches §6.3 (line 462) "wait until each `q3_*.inflight` and `reddit-oauth-token.lock` is unlockable… Absent `reddit-oauth-token.lock` is **unlockable** (do not require materialize; ENOENT counts as unlocked)" and §2.2 (line 125).

AC3 / I-39 — §6.12 (line 643) reddit OAuth test now asserts forced refreshes consume zero `reddit` search-bucket tokens:

> "…N concurrent acquires with remaining TTL ≥ 60s perform **zero** token-endpoint calls (re-read under lock; no stampede); forced refreshes (TTL < 60s) consume **zero** `reddit` search-bucket tokens (token-endpoint calls are not `acquire("reddit", …)`)"

The forced-refreshes-consume-zero-`reddit`-bucket-tokens assertion is new vs pass-14 and closes the AC3 gap. Matches §6.11 (line 622) "Token-endpoint calls are **not** counted against the `reddit` 100/min search bucket."

L85 rollup (§8.4 ten-line list, line 773) carries the matching `clear()` delete set + preserve set; AC1's `last.json.tmp.*` is present there ("+ orphaned `last.json.tmp.*`"). Consistent with the §6.12 line-634 roster except for the preserve omission filed as AD1 below.

### AD1 — NIT — §6.12 `clear()` test omits the query-cache `.gitignore` preserve that every operative spec section lists

The query-cache `.gitignore` preserve on `cache clear` is locked in eight places. §2.2 (line 125):

> "Still preserve `{quota_dir}/buckets/` and query-cache `.gitignore` **and** `{quota_dir}/reddit-oauth-token.json`."

§6.3 (line 462):

> "Preserve `{quota_dir}/buckets/` and query-cache `.gitignore`. Preserve `{quota_dir}/reddit-oauth-token.json`."

§1.2 rung 6 (line 69), rung 7 (line 70), rung 9 (line 72), rung 10 (line 73, "inner `.gitignore`"), round-2 rung 3 (line 75), and round-2 rung 7 (line 76) all repeat the query-cache `.gitignore` preserve. The inner `.gitignore` lives under the query-cache dir (`--cache-dir`), exactly the tree `cache::clear()` operates on (§6.3 line 453: "`.gitignore` — `*` + `!.gitignore` (query cache never committed)"), so a `clear()` that globs `*` or that removes `.gitignore` would orphan the ignore and let later `q3_*` files be git-added.

But §6.12 (line 634) — the authoritative detailed test roster where the preserve assertion would be pinned — lists only two preserves:

> "…plus `fleet-slots.lock/` slot files (directory remains; **preserves** `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`) **after** the quiesce barrier…"

No `.gitignore` preserve is asserted. A `clear()` that deletes the query-cache `.gitignore` would pass the §6.12 line-634 suite but violate §2.2/§6.3/§1.2 (all of which say preserve query-cache `.gitignore`). This is the same defect shape as the closed AC1 (the §6.12 detailed roster omitted the `last.json.tmp.*` removal that the spec required); here the roster omits the `.gitignore` preserve that the spec requires. The SB-side gitignore fixture at §4.3 (line 339) only asserts `_search-cache/` is ignored and `q3_*` not staged — it does not assert `cache clear` preserves the inner `.gitignore`, so it does not close this gap.

Why new vs I-1…I-39: pass-14's cross-section note explicitly described the `clear()` preserve set as "`{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`" and filed no finding for `.gitignore`; the only pass-14 findings were AC1 (`last.json.tmp.*` removal), AC2 (`reddit-oauth-token.lock` busy), AC3 (reddit bucket isolation) — none touch the `.gitignore` preserve. AC1's apply added the `last.json.tmp.*` seed but did not add the `.gitignore` preserve assertion. Not in the ledger.

Severity NIT: defense-in-depth sweep of the query-cache ignore; no Phase 1 correctness impact (a deleted `.gitignore` is inert until the next write), but the preserve lock is explicit in eight sections and the §6.12 line-634 detailed roster is the one that would pin the fixture — identical severity reasoning to the closed AC1.

Suggested remedy (reviewer files only; launcher triages): extend the §6.12 line-634 `clear()` test preserve assertion to also seed a `{cache_dir}/.gitignore` (containing `*` / `!.gitignore`) before clear and assert it remains after the quiesce-then-clear, pinning the query-cache `.gitignore` preserve alongside `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`.

---

## Cross-section consistency (re-verified, no further drift beyond AD1)

- Cache/quota split: §6.3 ↔ §6.2 ↔ §2.2 ↔ §4.4 ↔ §8.1 ↔ §8.4 — query cache under `--cache-dir`, quota under `--quota-dir` default `~/.config/silver-bullet/search-quota/`, never `$HOME/.cache/search`/ProjectDirs. Consistent.
- Fingerprint fields + ordering: §6.3 ↔ §6.12 ↔ §8.4 — query, mode, sorted `-p`, sorted canonicalized include/exclude, freshness, country, lang, `--allow-private` boolean **last**; `count`/TTL/`--max-chars` out; `-d` canonicalized before hash and `augment_query`; intra-list `0x1F`. Consistent.
- `clear()` delete set + quiesce: §6.3 ↔ §4.1 ↔ §8.1 ↔ §8.4 ↔ §5 Phase 1 — `q3_*` (json+inflight) + leftover `q2_*` + future `qN_*` + `last.json` + orphaned `last.json.tmp.*` + `fleet-slots.lock/` ceiling-10 contents after `cache_clear_busy` quiesce; preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`. Consistent across operative sections — except the §6.12 line-634 detailed roster omits the query-cache `.gitignore` preserve (filed as AD1). AC1's `last.json.tmp.*` and AC2's `reddit-oauth-token.lock` are now present in §6.12.
- Bucket fail-closed: §6.4 ↔ §6.6 ↔ §6.12 ↔ §8.1 ↔ §8.4 — `tokens = 0` + `updated_unix_ms = now` unconditionally, `bucket_fail_closed` and `bucket_fail_closed:{id}` on whichever envelope, no refill/calendar on that acquire. Consistent.
- Acquire granularity: github once-per-invocation (§6.4 L487 ↔ §6.10 L609 ↔ §8.1 L724); gitlab per-scope (§6.4 L477 ↔ §6.12 L640 ↔ §8.1 L725); registries per-HTTP (§6.4 L485 ↔ §6.12 L640 ↔ §8.1 L730 ↔ §4.4 L344); brave/x/serper/xweb on request path (§6.4 L483/L486 ↔ §6.12 L640 ↔ §8.1 L732/L733 ↔ §8.4 #8 L779). Consistent (AA1 closed the test asymmetry; AC1–AC3 did not regress it).
- Doctor: §4.4 ↔ §6.1 ↔ §6.12 ↔ §8.1 ↔ §8.4 #8 — honors `--quota-dir`, slot-exempt, `doctor_skip_requires_domain`, registries = 4 `acquire`, `doctor_rate_limited`, YouTube ping 1 of 100 fleet. Consistent.
- Reddit token: §6.11 ↔ §2.2 ↔ §6.3 — shared `{quota_dir}/reddit-oauth-token.json` + `.lock`, re-read under lock, absent lock unlockable, preserved on clear, token-endpoint calls off the `reddit` search bucket. Consistent — AC2 closed the busy/absent test gap and AC3 closed the bucket-isolation test gap.
- clap `-p` drift-guard: §6.7 ↔ §6.12 — `command_schemas.search.options` values match `KNOWN`/`build_providers` id set. Consistent.
- X union / one row: §1.2 ↔ §1.4 ↔ §2.5 ↔ §2.8 ↔ §3 — one X catalog row, list `provider`/`bucket` `[x, xweb]`, must-search, dedicated `site:x.com` last resort, dedup test. Consistent (AB1 closed the dedup test gap).
- Warning replay: §6.3 ↔ §6.6 ↔ §6.12 ↔ §8.1 — `bucket_fail_closed`, `bucket_fail_closed:{id}`, `cache_ttl_default_300s`, `doctor_rate_limited` stripped on cache hit; honesty warnings stay. Consistent (AA2 closed the negative-test gap; AC1–AC3 did not regress it).

---

Ledger I-1…I-39 (ACCEPT+applied) were excluded per Policy G and not re-reported above. The AC1–AC3 APPLY at this SHA was spot-checked in the plan text and is present and internally consistent (§6.12 line 634 `last.json.tmp.*` seed+removal; §6.12 line 635 held+absent `reddit-oauth-token.lock`; §6.12 line 643 forced-refreshes-consume-zero-`reddit`-bucket). The one finding above (AD1) is a new residual not in I-1…I-39 and not a duplicate of AC1–AC3 (different preserve target: query-cache `.gitignore` vs `last.json.tmp.*` removal).
