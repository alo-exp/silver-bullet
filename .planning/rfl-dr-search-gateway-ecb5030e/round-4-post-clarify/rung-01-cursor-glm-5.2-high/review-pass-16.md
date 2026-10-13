model: glm-5.2-high

# Review pass 16 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `e0b487d4f815919a83c585d01d7d83f94a7122d3166487ac813b030b159f015e` (match — `shasum -a 256` confirmed before review; pinned SHA == on-disk SHA).
Scope: residual-only against ledger I-1…I-40 (all ACCEPT+applied), with AD1 / I-40 (L634 query-cache `.gitignore` preserve) closed this SHA. New findings only; I-1…I-40 not re-reported. This is the first re-review after the AD1 / I-40 ACCEPT-apply (streak reset to 0 / 2). The plan was re-read end-to-end (§1.2 ledger clauses, §1.3–§1.4, §2.1–§2.8, §3, §4.1–§4.4, §5, §6.1–§6.13, §7, §8.1–§8.4) and cross-checked independently; AD1 / I-40 spot-checked at its apply sites (§6.12 L634 and §1.2 L85 rollup).

Method: bird's-eye (§1.2 locked-decisions log vs operative §2/§4/§6/§8; cache/quota split; fleet-slots orchestrator-only + ceiling-10; superseded-annotation completeness across all §1.2 rung/round clauses; acquire-granularity per provider; fingerprint-field roster and ordering; warning-replay set; quiesce ceiling-10; `clear()` delete-set + preserve-set parity across every section that enumerates a preserve roster — §2.2 L125, §6.3 L462, §6.12 L634, §1.2 L85 rollup, §4.1 L330, §5 L351, §8.1 L736, §8.4 L773, plus the §1.2 rung-6/7/9/10 and round-2 rung-3/7 ledger clauses; reddit token lock in quiesce barrier; round-4 rung-1 ACCEPT coverage) then ant's-eye (line-by-line cross-section consistency across §2.1–§2.8, §3, §4.1, §4.3, §4.4, §5, §6.1–§6.13, §7, §8.1–§8.4). Graphify CLI run for orientation (`graphify query` on dr_search_gateway PRD plan §6.12 tests: clear() last.json.tmp, reddit-oauth-token.lock cache_clear_busy, reddit token-endpoint bucket isolation, X-union dedup, AD1 apply sites, L85 rollup, query-cache .gitignore preserve) — surfaced the AC1/AC2/AC3/AD1 finding nodes and prior W5/I-24, W6/I-25, AB1–AB4 nodes, all of which are in the applied ledger and excluded per Policy G. agentmemory capture deferred to the parent per rung contract.

Result: NOT CLEAN — 1 new residual class (AE1) at four sites, all NIT.

---

## AD1 / I-40 APPLY spot-check (this SHA)

AD1 / I-40 (L634 query-cache `.gitignore` preserve) is present and internally consistent at both apply sites.

AD1 / I-40 — §6.12 (line 634) `clear()` test preserve roster now seeds and asserts the query-cache `.gitignore`:

> …plus `fleet-slots.lock/` slot files (directory remains; **preserves** `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json` and query-cache `.gitignore` (seed `{cache_dir}/.gitignore` with `*` / `!.gitignore` and assert it remains)) **after** the quiesce barrier…

The `seed {cache_dir}/.gitignore with * / !.gitignore and assert it remains` clause is new vs pass-15 and closes the AD1 gap at the authoritative detailed test roster. Matches §6.3 (line 462) and §2.2 (line 125), both of which list the query-cache `.gitignore` preserve alongside `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`.

§1.2 L85 rollup (round-4 post-clarify rung 1 ACCEPTs) now carries the matching preserve lock at its tail:

> …`clear()` preserves query-cache `.gitignore`.

Consistent with the §6.12 line-634 roster. AD1 / I-40 is fully applied at its two named sites (§6.12 L634 and §1.2 L85).

---

## AE1 — NIT — four `clear()` preserve rosters omit the query-cache `.gitignore` preserve that §2.2 / §6.3 / §6.12 / §1.2 ledger clauses all list

The query-cache `.gitignore` preserve on `cache clear` is locked in eight places: §2.2 (L125), §6.3 (L462), §6.12 (L634, post-AD1), §1.2 L85 rollup (post-AD1), and the §1.2 rung-6 (L69), rung-7 (L70), rung-9 (L72), rung-10 (L73), round-2 rung-3 (L75), round-2 rung-7 (L76) ledger clauses. The canonical preserve set is: `{quota_dir}/buckets/` + `{quota_dir}/reddit-oauth-token.json` + query-cache `.gitignore` (+ preserve the `fleet-slots.lock/` directory while deleting its ceiling-10 contents).

Four further sections enumerate a `clear()` preserve roster but list only `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`, omitting the query-cache `.gitignore`:

- **§4.1 (line 330):** preserve roster reads `preserve the directory; preserve {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json` after the quiesce barrier (§2.2) — no `.gitignore`.
- **§5 Phase 1 acceptance (line 351):** preserve roster reads `preserve the directory; **preserve** {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json` after the §2.2 quiesce barrier (`cache_clear_busy`, 30s, ceiling-10 slot lock) — no `.gitignore`.
- **§8.1 Modify `src/cache.rs` (line 736):** preserve roster reads `preserve {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json` after the `clear()` delete-set + quiesce — no `.gitignore`.
- **§8.4 ten-line file-change list, item 2 (line 773):** preserve roster reads `preserve {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json` after the `clear()` delete-set + quiesce — no `.gitignore`.

A `clear()` that globs `*` or removes `.gitignore` under the query-cache dir would orphan the ignore and let later `q3_*` files be git-added; the preserve lock exists precisely to prevent that. Each of these four rosters makes an explicit preserve claim that is incomplete vs the operative spec (§2.2 / §6.3 / §6.12 / §1.2 ledger clauses). An implementer or acceptance-test author following only §4.1, §5, §8.1, or §8.4 could write a `clear()` / acceptance test that deletes the query-cache `.gitignore` and still satisfy the roster as written. The §4.3 SB gitignore fixture (L339) only asserts `_search-cache/` is ignored and `q3_*` not staged — it does not assert `cache clear` preserves the inner `.gitignore`, so it does not close this gap.

Why new vs I-1…I-40: AD1 / I-40 was filed and applied only at §6.12 line-634 (with the §1.2 L85 rollup also updated). AD1's finding text enumerated the eight sections that *include* the `.gitignore` preserve (§2.2, §6.3, and six §1.2 ledger clauses) and filed the single omission at §6.12 L634; AD1 did not name §4.1 L330, §5 L351, §8.1 L736, or §8.4 L773. Pass-15's cross-section note described the preserve set across §6.3/§4.1/§8.1/§8.4/§5 as `preserve {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json` and called them `consistent across operative sections` — but that pass-15 summary itself omitted `.gitignore`, and §6.3 L462 actually *includes* `query-cache .gitignore`, so §4.1/§5/§8.1/§8.4 are in fact inconsistent with §6.3/§2.2. These four sites were never filed and are not in the ledger. Not a duplicate of AC1–AC3 (different preserve target: query-cache `.gitignore` vs `last.json.tmp.*` removal / reddit lock busy / reddit bucket isolation). One residual class, four sites, same defect shape and same remedy pattern as the closed AD1.

Severity NIT (per AD1's severity reasoning): defense-in-depth sweep of the query-cache ignore; no Phase 1 correctness impact (a deleted `.gitignore` is inert until the next write), but the preserve lock is explicit in §2.2/§6.3 and these four rosters each make a partial preserve claim. §5 L351 is an acceptance-test roster, so the gap is slightly more than cosmetic, but the operative spec (§6.3/§2.2) is correct and authoritative; severity stays NIT to match AD1.

Suggested remedy (reviewer files only; launcher triages): extend each of the four preserve rosters to add `and query-cache .gitignore` alongside `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`, matching §6.3 L462 / §6.12 L634 / §2.2 L125. Concretely: §4.1 L330, §5 L351, §8.1 L736, and §8.4 L773 each gain `and query-cache .gitignore`; for §5 L351 and §8.1 L736 where a test is in scope, also add the matching `seed {cache_dir}/.gitignore with * / !.gitignore and assert it remains` assertion as already pinned at §6.12 L634.

---

## Cross-section consistency (re-verified, no further drift beyond AE1)

- Cache/quota split: §6.3 ↔ §6.2 ↔ §2.2 ↔ §4.4 ↔ §8.1 ↔ §8.4 — query cache under `--cache-dir`, quota under `--quota-dir` default `~/.config/silver-bullet/search-quota/`, never `$HOME/.cache/search`/ProjectDirs. Consistent.
- Fingerprint fields + ordering: §6.3 ↔ §6.12 ↔ §8.4 — query, mode, sorted `-p`, sorted canonicalized include/exclude, freshness, country, lang, `--allow-private` boolean **last**; `count`/TTL/`--max-chars` out; `-d` canonicalized before hash and `augment_query`; intra-list `0x1F`; GitLab `scope` / SE `site`/`sort` out. Consistent.
- `clear()` delete set + quiesce: §6.3 ↔ §4.1 ↔ §8.1 ↔ §8.4 ↔ §5 Phase 1 — `q3_*` (json+inflight) + leftover `q2_*` + future `qN_*` + `last.json` + orphaned `last.json.tmp.*` + `fleet-slots.lock/` ceiling-10 contents after `cache_clear_busy` quiesce; preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`. Consistent across operative sections — except §4.1 L330, §5 L351, §8.1 L736, and §8.4 L773 each omit the query-cache `.gitignore` preserve (filed as AE1). AD1's `last.json.tmp.*`, AC2's `reddit-oauth-token.lock` busy/absent, and AC3's reddit bucket isolation are present in §6.12.
- Bucket fail-closed: §6.4 ↔ §6.6 ↔ §6.12 ↔ §8.1 ↔ §8.4 — `tokens = 0` + `updated_unix_ms = now` unconditionally, `bucket_fail_closed` and `bucket_fail_closed:{id}` on whichever envelope, no refill/calendar on that acquire. Consistent.
- Acquire granularity: github once-per-invocation (§6.4 L487 ↔ §6.10 L609 ↔ §8.1 L724); gitlab per-scope (§6.4 L477 ↔ §6.12 L640 ↔ §8.1 L725); registries per-HTTP (§6.4 L485 ↔ §6.12 L640 ↔ §8.1 L730 ↔ §4.4 L344); brave/x/serper/xweb on request path (§6.4 L483/L486 ↔ §6.12 L640 ↔ §8.1 L732/L733 ↔ §8.4 #8 L779). Consistent (AA1 closed the test asymmetry; AC1–AC3 / AD1 did not regress it).
- Doctor: §4.4 ↔ §6.1 ↔ §6.12 ↔ §8.1 ↔ §8.4 #8 — honors `--quota-dir`, slot-exempt, `doctor_skip_requires_domain`, registries = 4 `acquire`, `doctor_rate_limited`, YouTube ping 1 of 100 fleet. Consistent.
- Reddit token: §6.11 ↔ §2.2 ↔ §6.3 — shared `{quota_dir}/reddit-oauth-token.json` + `.lock`, re-read under lock, absent lock unlockable, preserved on clear, token-endpoint calls off the `reddit` search bucket. Consistent — AC2 closed the busy/absent test gap and AC3 closed the bucket-isolation test gap; the `reddit-oauth-token.json` preserve itself is present in all four AE1 sites (only the `.gitignore` preserve is missing there).
- clap `-p` drift-guard: §6.7 ↔ §6.12 — `command_schemas.search.options` values match `KNOWN`/`build_providers` id set. Consistent.
- X union / one row: §1.2 ↔ §1.4 ↔ §2.5 ↔ §2.8 ↔ §3 — one X catalog row, list `provider`/`bucket` `[x, xweb]`, must-search, dedicated `site:x.com` last resort, dedup test. Consistent (AB1 closed the dedup test gap).
- Warning replay: §6.3 ↔ §6.6 ↔ §6.12 ↔ §8.1 — `bucket_fail_closed`, `bucket_fail_closed:{id}`, `cache_ttl_default_300s`, `doctor_rate_limited` stripped on cache hit; honesty warnings stay. Consistent (AA2 closed the negative-test gap; AC1–AC3 / AD1 did not regress it).

---

Ledger I-1…I-40 (ACCEPT+applied) were excluded per Policy G and not re-reported above. The AD1 / I-40 APPLY at this SHA was spot-checked in the plan text and is present and internally consistent (§6.12 line 634 seeds `{cache_dir}/.gitignore` with `*` / `!.gitignore` and asserts it remains; §1.2 L85 rollup ends with `clear() preserves query-cache .gitignore`). The one finding above (AE1, four sites) is a new residual not in I-1…I-40 and not a duplicate of AC1–AC3 or AD1 (different sites: §4.1 L330, §5 L351, §8.1 L736, §8.4 L773 vs AD1's §6.12 L634; same preserve target as AD1 — query-cache `.gitignore` — but at four previously-unfiled rosters).
