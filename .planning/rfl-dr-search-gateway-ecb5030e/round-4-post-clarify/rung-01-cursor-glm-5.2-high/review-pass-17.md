model: glm-5.2-high

# Review pass 17 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `201732f621e72585c3bf236a963309adab025e419a7d484b4602eb9a14462571` (match — `shasum -a 256` confirmed; pinned SHA == on-disk SHA).
Scope: residual-only vs ledger I-1…I-41 (all ACCEPT+applied). AE1 / I-41 (query-cache `.gitignore` preserve on `clear()` at §4.1 L330, §5 L351, §8.1 L736, §8.4 L773, plus §6.12 L634 and §1.2 L85 rollup) closed this SHA. New findings only; I-1…I-41 not re-reported. First re-review after AE1 / I-41 ACCEPT-apply (streak 0 / 2). Plan re-read end-to-end (§1.2 L65–L85, §1.3–§1.4, §2.1–§2.8, §3, §4.1–§4.4, §5, §6.1–§6.13, §7, §8.1–§8.4); AE1 / I-41 spot-checked at all eight named sites.

Method: bird's-eye (§1.2 locked-decisions log vs operative §2/§4/§6/§8; cache/quota split; fleet-slots orchestrator-only + ceiling-10; superseded-annotation completeness; acquire-granularity per provider; fingerprint-field roster and ordering; warning-replay set; quiesce ceiling-10; `clear()` delete-set + preserve-set parity across every clear() roster — §2.2 L125, §6.3 L462, §6.12 L634, §1.2 L85, §4.1 L330, §5 L351, §8.1 L736, §8.4 L773, §8.4 L781 test roster, plus §1.2 rung-6/7/9/10 and round-2 rung-3/7/8/9/10 ledger clauses; reddit token lock in quiesce; round-4 rung-1 ACCEPT coverage) then ant's-eye (line-by-line across §2.1–§2.8, §3, §4.1, §4.3, §4.4, §5, §6.1–§6.13, §7, §8.1–§8.4). Graphify CLI orientation (`graphify query` on plan §6.12 tests: clear() last.json.tmp, reddit-oauth-token.lock cache_clear_busy, reddit token-endpoint bucket isolation, X-union dedup, AE1 apply sites, L85 rollup, query-cache .gitignore preserve, future qN_* / q4_* sweep) — surfaced AE1/AD1/AC1–AC3 nodes and prior W5/I-24, W6/I-25, AB1–AB4 nodes, all in the applied ledger, excluded per Policy G. agentmemory capture deferred to parent per rung contract.

Result: NOT CLEAN — 1 new residual class (AF1) at five sites, NIT.

---

## AE1 / I-41 APPLY spot-check (this SHA)

AE1 / I-41 (query-cache `.gitignore` preserve on `clear()`) is present and internally consistent at all eight named sites. Verified via line scan (ctx_execute_file over the corpus) that each anchor line contains `.gitignore`:

- §2.2 L125 — `preserve {quota_dir}/buckets/ and query-cache .gitignore and {quota_dir}/reddit-oauth-token.json` ✓
- §4.1 L330 — `preserve {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json and query-cache .gitignore) after the quiesce barrier (§2.2)` ✓
- §5 L351 — `**preserve** {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json and query-cache .gitignore) after the §2.2 quiesce barrier` ✓
- §6.3 L462 — `Preserve {quota_dir}/buckets/ and query-cache .gitignore. Preserve {quota_dir}/reddit-oauth-token.json.` (capital P; case-sensitive scan missed it on first pass, confirmed by full-line dump) ✓
- §6.12 L634 — `preserves {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json and query-cache .gitignore (seed {cache_dir}/.gitignore with * / !.gitignore and assert it remains)` ✓
- §8.1 L736 — `preserve {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json and query-cache .gitignore` ✓
- §8.4 L773 — `preserve {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json and query-cache .gitignore` ✓
- §1.2 L85 rollup — `clear() preserves query-cache .gitignore. §4.1/§5/§8.1/§8.4 clear() preserve rosters include query-cache .gitignore.` ✓

AE1 / I-41 fully applied at its eight named sites. Preserve roster now consistent across operative spec (§2.2/§6.3/§6.12) and four summary rosters (§4.1/§5/§8.1/§8.4) plus §1.2 L85 rollup.

---

## AF1 — NIT — five `clear()` delete-set / test rosters omit the "future qN_* (q4_*)" sweep that §6.3 / §6.12 / §1.2 L85 rollup all lock

The "future qN_* prefix (q4_* …) so a fingerprint bump does not orphan files" deletion on `cache clear` is locked in three places: §6.3 L462 (operative spec), §6.12 L634 (authoritative test — `seed a q4_* fixture and assert removal`), and §1.2 L85 rollup (`cache clear also deletes future qN_*`). Canonical delete set: q3_* (json+inflight) + leftover q2_* + **future qN_* (q4_*)** + last.json + orphaned last.json.tmp.* + fleet-slots.lock/ ceiling-10 contents (after cache_clear_busy quiesce); preserve {quota_dir}/buckets/ + {quota_dir}/reddit-oauth-token.json + query-cache .gitignore.

Five further sections enumerate a clear() delete-set (or test) roster but list only q3_* + q2_* + last.json + orphaned last.json.tmp.* + fleet-slots.lock/ contents, omitting the future qN_* / q4_* sweep:

- §4.1 L330 — `cache clear deletes q3_* json+inflight, leftover q2_*, last.json, orphaned last.json.tmp.*, and fleet-slots.lock/ contents` — no qN_* / q4_*.
- §5 L351 — `cache::clear deletes q3_*.json and q3_*.inflight, leftover q2_*, last.json, orphaned last.json.tmp.*, and fleet-slots.lock/ slot-file contents` — no qN_* / q4_*.
- §8.1 L736 (src/cache.rs Modify) — `clear() all q3_* (json + inflight) + leftover q2_ + last.json + orphaned last.json.tmp.* + fleet-slots.lock/ ceiling-10 contents` — no qN_* / q4_*.
- §8.4 L773 (ten-line file-change list, item 2) — `clear() deletes q3_* + leftover q2_* + last.json + orphaned last.json.tmp.* + fleet-slots.lock/ ceiling-10 contents` — no qN_* / q4_*.
- §8.4 L781 (ten-line file-change list, item 10 tests) — `clear() q3_ + leftover q2_* + last.json + orphaned last.json.tmp.* + slot-file contents after cache_clear_busy quiesce` — no q4_* fixture (the §6.12 L634 `seed a q4_* fixture and assert removal` test is not mirrored here).

A clear() that globs only q3_* + q2_* would leave q4_* (and any later qN_*) files orphaned after a fingerprint bump; the future-prefix sweep exists precisely to prevent that. Each of these five rosters makes an explicit delete-set claim that is incomplete vs the operative spec (§6.3 L462) and the authoritative test (§6.12 L634). An implementer following only §8.1 (file-by-file src/cache.rs Modify spec) or §8.4 ("ten-line file-change list for the fork implementer") could ship a clear() that fails the §6.12 L634 q4_* fixture test — the test would catch it, but the summary rosters as written are partial. §8.4 is explicitly the implementer's quick-reference checklist, so the omission is more than cosmetic for that site.

Why new vs I-1…I-41: AE1 / I-41 was filed and applied for the **preserve** roster (query-cache .gitignore) at §4.1 L330, §5 L351, §8.1 L736, §8.4 L773 (four sites) plus §6.12 L634 and §1.2 L85. AE1's finding text scoped itself to the preserve roster: "four further sections enumerate a clear() preserve roster but list only {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json, omitting the query-cache .gitignore." AE1 did not touch the **delete** set. AD1 / I-40 was the §6.12 L634 .gitignore preserve only. The qN_* / q4_* delete-sweep requirement was locked at round-4 rung-1 (§1.2 L85: `cache clear also deletes future qN_*`) and operative §6.3 L462, but the omission of that sweep from the §4.1/§5/§8.1/§8.4 delete rosters (and the §8.4 L781 test roster) was never filed. Review pass-16's cross-section note asserted `q3_* (json+inflight) + leftover q2_* + future qN_* + last.json + orphaned last.json.tmp.* + fleet-slots.lock/ ceiling-10 contents … Consistent across operative sections — except §4.1 L330, §5 L351, §8.1 L736, and §8.4 L773 each omit the query-cache .gitignore preserve (filed as AE1)` — that note claimed `future qN_*` was consistent across §4.1/§5/§8.1/§8.4, but the line scan (ctx_execute_file over the corpus) shows those four sites contain q3_/q2_/last.json.tmp/fleet-slots but **no** qN_ and **no** q4_. Pass-16's consistency claim for qN_* was incorrect; the omission is real and was not in the ledger. Not a duplicate of AC1–AC3 (different roster: future-prefix delete sweep vs last.json.tmp.* removal / reddit lock busy / reddit bucket isolation) and not a duplicate of AD1/AE1 (different roster: delete set vs preserve set). One residual class, five sites, same defect shape (summary roster omits a locked item) and same remedy pattern as AE1.

Severity NIT (per AE1's severity reasoning, applied to the delete set): defense-in-depth sweep of future-prefix orphans; no Phase 1 correctness impact (Phase 1 prefix is q3_; a q4_ bump is post-Phase-1 and the §6.12 L634 q4_* fixture test would catch an implementer who runs the fork tests), but the delete-set lock is explicit in §6.3/§6.12 and these five rosters each make a partial delete-set claim. §8.4 L773/L781 is the implementer's quick-reference checklist, so the gap is slightly more than cosmetic for that site, but the operative spec (§6.3 L462) and authoritative test (§6.12 L634) are correct; severity stays NIT to match AE1.

Suggested remedy (reviewer files only; launcher triages): extend each of the four delete-set rosters to add `and any future qN_* prefix (q4_* …)` alongside q3_* + leftover q2_*, matching §6.3 L462 / §6.12 L634 / §1.2 L85 rollup. Concretely: §4.1 L330, §5 L351, §8.1 L736, and §8.4 L773 each gain `and any future qN_* prefix (q4_* …)` in the delete-set enumeration. For §8.4 L781 (item 10 test roster), add `q4_* fixture assert removal` to the clear() test summary so the implementer checklist mirrors §6.12 L634.

---

## Cross-section consistency (re-verified, no further drift beyond AF1)

- Cache/quota split: §6.3 ↔ §6.2 ↔ §2.2 ↔ §4.4 ↔ §8.1 ↔ §8.4 — query cache under --cache-dir, quota under --quota-dir default ~/.config/silver-bullet/search-quota/, never $HOME/.cache/search/ProjectDirs. Consistent.
- Fingerprint fields + ordering: §6.3 ↔ §6.12 ↔ §8.4 ↔ §4.1 ↔ §2.3 — query, mode, sorted -p, sorted canonicalized include/exclude, freshness, country, lang, --allow-private boolean **last**; count/TTL/--max-chars out; -d canonicalized before hash and augment_query; intra-list 0x1F; GitLab scope / SE site/sort out. Consistent.
- clear() delete set + quiesce: §6.3 ↔ §4.1 ↔ §8.1 ↔ §8.4 ↔ §5 — q3_* (json+inflight) + leftover q2_* + last.json + orphaned last.json.tmp.* + fleet-slots.lock/ ceiling-10 contents after cache_clear_busy quiesce; preserve {quota_dir}/buckets/ and {quota_dir}/reddit-oauth-token.json and query-cache .gitignore. Preserve roster consistent (AE1 closed it) — except §4.1 L330, §5 L351, §8.1 L736, §8.4 L773, and §8.4 L781 each omit the future qN_* / q4_* delete sweep (filed as AF1). AD1's last.json.tmp.*, AC2's reddit-oauth-token.lock busy/absent, and AC3's reddit bucket isolation are present in §6.12.
- Bucket fail-closed: §6.4 ↔ §6.6 ↔ §6.12 ↔ §8.1 ↔ §8.4 — tokens = 0 + updated_unix_ms = now unconditionally, bucket_fail_closed and bucket_fail_closed:{id} on whichever envelope, no refill/calendar on that acquire. Consistent.
- Acquire granularity: github once-per-invocation (§6.4 L487 ↔ §6.10 L609 ↔ §8.1 L724); gitlab per-scope (§6.4 L477 ↔ §6.12 L640 ↔ §8.1 L725); registries per-HTTP (§6.4 L485 ↔ §6.12 L640 ↔ §8.1 L730 ↔ §4.4 L344); brave/x/serper/xweb on request path (§6.4 L483/L486 ↔ §6.12 L640 ↔ §8.1 L732/L733 ↔ §8.4 #8 L779). Consistent (AA1 closed the test asymmetry; AC1–AC3 / AD1 / AE1 did not regress it).
- Doctor: §4.4 ↔ §6.1 ↔ §6.12 ↔ §8.1 ↔ §8.4 #8 — honors --quota-dir, slot-exempt, doctor_skip_requires_domain, registries = 4 acquire, doctor_rate_limited, YouTube ping 1 of 100 fleet. Consistent.
- Reddit token: §6.11 ↔ §2.2 ↔ §6.3 — shared {quota_dir}/reddit-oauth-token.json + .lock, re-read under lock, absent lock unlockable, preserved on clear, token-endpoint calls off the reddit search bucket. Consistent (AC2 closed busy/absent test gap; AC3 closed bucket-isolation test gap; the reddit-oauth-token.json preserve is present in all four AE1 sites — only the .gitignore preserve was missing there, now closed).
- clap -p drift-guard: §6.7 ↔ §6.12 — command_schemas.search.options values match KNOWN/build_providers id set. Consistent.
- X union / one row: §1.2 ↔ §1.4 ↔ §2.5 ↔ §2.8 ↔ §3 — one X catalog row, list provider/bucket [x, xweb], must-search, dedicated site:x.com last resort, dedup test. Consistent (AB1 closed the dedup test gap).
- Warning replay: §6.3 ↔ §6.6 ↔ §6.12 ↔ §8.1 — bucket_fail_closed, bucket_fail_closed:{id}, cache_ttl_default_300s, doctor_rate_limited stripped on cache hit; honesty warnings stay. Consistent (AA2 closed the negative-test gap; AC1–AC3 / AD1 / AE1 did not regress it).

---

Ledger I-1…I-41 (ACCEPT+applied) were excluded per Policy G and not re-reported above. The AE1 / I-41 APPLY at this SHA was spot-checked in the plan text and is present and internally consistent at all eight named sites (§4.1 L330, §5 L351, §8.1 L736, §8.4 L773, §2.2 L125, §6.3 L462, §6.12 L634, §1.2 L85 rollup — each carries the query-cache `.gitignore` preserve). The one finding above (AF1, five sites) is a new residual not in I-1…I-41 and not a duplicate of AC1–AC3, AD1, or AE1 (different roster: future-prefix **delete** sweep vs `last.json.tmp.*` removal / reddit lock busy / reddit bucket isolation / query-cache `.gitignore` **preserve**; same operative clear() roster family but a different roster item never previously filed).
