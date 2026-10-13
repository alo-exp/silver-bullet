model: glm-5.2-high

# Review pass 14 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `39673cb6a7cd07a12a57d816c283a839805d727fae6b0bdaba506253f1e91847` (match — `shasum -a 256` confirmed before review).
Scope: residual-only against ledger I-1…I-36 (all ACCEPT+applied) plus the AB1–AB4 APPLY at this SHA. New findings only; I-1…I-36 not re-reported. This is the first re-review after the AB1–AB4 ACCEPT-apply (streak reset to 0). The plan was re-read end-to-end (§1.2 ledger clauses, §2.1–§2.8, §3, §4.1–§4.4, §5, §6.1–§6.13, §7, §8.1–§8.4) and cross-checked independently; AB1–AB4 spot-checked at their apply sites.

Method: bird's-eye (§1.2 locked-decisions log vs operative §2/§4/§6/§8; X-union one-row + dedup; cache/quota split; fleet-slots orchestrator-only; superseded-annotation completeness across all §1.2 rung/round clauses; acquire-granularity per provider; fingerprint-field roster and ordering; warning-replay set; quiesce ceiling-10; clear() delete-set parity across §4.1/§6.3/§6.12/§8.1/§8.4; reddit token lock in quiesce barrier; round-4 rung-1 ACCEPT coverage) then ant's-eye (line-by-line cross-section consistency across §2.1–§2.8, §3, §4.1, §4.3, §4.4, §5, §6.1–§6.13, §7, §8.1–§8.4). Graphify CLI run for orientation (`graphify query` on dr_search_gateway PRD plan §6.12 tests: cache_ttl help, reddit no-stampede, clear qN_*, X-union dedup, AB1–AB4 apply sites) — surfaced the AA1/AA2/AB1–AB4 finding nodes and prior W5/I-24, W6/I-25 nodes, all of which are in the applied ledger and excluded per Policy G. agentmemory capture deferred to the parent per rung contract.

Result: NOT CLEAN — 3 new residuals (AC1 NIT, AC2 NIT, AC3 NIT).

---

## AB1–AB4 APPLY spot-check (this SHA)

All four APPLYs are present and internally consistent at the locked sites.

AB1 — §3 (line 339) SB test roster now carries the X-union dedup contract:

> "X-union dedup test: two/three X-leg envelopes sharing a tweet id or canonical `x.com`/`twitter.com` status URL (plus an xAI hit carrying the id) emit one row; results without id/URL stay undeduped and recorded."

Matches the operative locks: §1.4 (line 101) `Dedup (SB orchestrator, locked)` key = tweet/status id else canonical `x.com`/`twitter.com` URL, xAI join rule, undeduped-and-recorded fallback; §2.5 (line 178) one X row, list `provider`/`bucket`. The dedup-key assertion and the undeduped-recorded assertion are new vs pass-13 and close the AB1 gap.

AB2 — §6.12 (line 638) clap help test now lists all three global flags:

> "clap: unknown `-p discoursee` still `Config` exit 2; `--cache-dir`, `--quota-dir`, **and** `--cache-ttl` appear in `--help`; **no** `--no-fanout` in help"

`--cache-ttl` presence in `--help` is new vs pass-13 and closes the AB2 gap. Matches §6.2 (line 414) `--cache-ttl <SECS>` / `SEARCH_CACHE_TTL` global on `Cli` and §1.2 round-4 rung-1 "`--cache-ttl` is a Phase 1 fork ADD". Fleet argv (§6.2 line 429; §3 line 339) still always passes `--cache-ttl 86400`, so the flag is load-bearing.

AB3 — §6.12 (line 643) reddit OAuth test now asserts the no-stampede invariant:

> "reddit OAuth: shared token file + flock; refresh path; 401 retries once then Auth; N concurrent acquires with remaining TTL ≥ 60s perform **zero** token-endpoint calls (re-read under lock; no stampede)"

The "zero token-endpoint calls" / no-stampede assertion is new vs pass-13 and closes the AB3 gap. Matches §6.11 (line 622) double-check re-read under the exclusive lock.

AB4 — §6.12 (line 634) `clear()` test now seeds a future-prefix fixture:

> "…plus any future `qN_*` prefix (seed a `q4_*` fixture and assert removal) plus `last.json` plus `fleet-slots.lock/` slot files…"

The `q4_*` fixture-and-assert-removal is new vs pass-13 and closes the AB4 gap. Matches §6.3 (line 462) "and any future `qN_*` prefix (`q4_*` …) so a fingerprint bump does not orphan files".

### AC1 — NIT — §6.12 `clear()` test omits the orphaned `last.json.tmp.*` removal that every operative spec section lists

§6.3 (line 462) locks the clear() delete set explicitly:

> "…plus `last.json`, and orphaned `last.json.tmp.*` (`last.json.tmp.{pid}.{nanos}` / `{uuid}` leftovers after a killed write; `q3_` temps already match `q3_*`) under the query-cache dir."

§4.1 (line 330), §8.1 (line 736), §8.4 (line 773) all repeat "`orphaned last.json.tmp.*`" in the clear() delete set, and §8.4 (line 781) item 10 (tests) even claims the test covers it:

> "…`clear()` `q3_` + leftover `q2_*` + `last.json` + orphaned `last.json.tmp.*` + slot-file contents after `cache_clear_busy` quiesce…"

But §6.12 (line 634) — the authoritative detailed test roster where the fixture would be specified — omits it:

> "…`clear()` with `--cache-dir` + `--quota-dir` removes `q3_*` (`q3_*.json` **and** `q3_*.inflight`) plus leftover `q2_*` plus any future `qN_*` prefix (seed a `q4_*` fixture and assert removal) plus `last.json` plus `fleet-slots.lock/` slot files (directory remains; **preserves** `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`) **after** the quiesce barrier…"

No `last.json.tmp.*` fixture is seeded and no removal is asserted in §6.12. A `clear()` that globs only `q[0-9]_*` and `last.json` (forgetting the separate `last.json.tmp.*` prefix — which does **not** match `q3_*`, as §6.3 itself calls out) would pass the §6.12 suite but orphan killed-write temps, violating §6.3/§4.1/§8.1/§8.4. The §8.4 line-781 summary asserts the test exists; §6.12 line-634 does not specify it — drift between the two test descriptions.

Severity NIT: defense-in-depth sweep of killed-write leftovers; no Phase 1 correctness impact (temps are inert), but the lock is explicit in four sections and the §6.12 detailed roster is the one that would pin the fixture.

Suggested remedy (reviewer files only; launcher triages): extend the §6.12 line-634 `clear()` test to also seed a `last.json.tmp.{pid}.{nanos}` (and/or `last.json.tmp.{uuid}`) leftover under `--cache-dir` and assert it is removed alongside `q3_*`/`q2_*`/`q4_*`/`last.json`, pinning the `last.json.tmp.*` glob.

### AC2 — NIT — §6.12 `cache_clear_busy` test omits `reddit-oauth-token.lock` (held → busy; absent → not busy)

§6.3 (line 462) makes `reddit-oauth-token.lock` part of the quiesce barrier and locks the absent-lock behavior (I-25, ACCEPT+applied):

> "…wait until each `q3_*.inflight` **and** `reddit-oauth-token.lock` is unlockable; timeout **30s** → named error **`cache_clear_busy`**, nonzero, leave files. … Absent `reddit-oauth-token.lock` is **unlockable** (do not require materialize; ENOENT counts as unlocked)."

§2.2 (line 125) carries the same barrier. But §6.12 (line 635) `cache_clear_busy` test names only slots and `q3_*.inflight`:

> "…`cache clear` while a slot or `.inflight` is held **waits up to 30s then refuses** (`cache_clear_busy`, nonzero, no unlink) — must not admit N+1 / a second leader"

Two locked behaviors go untested: (a) a held `reddit-oauth-token.lock` (a concurrent reddit token refresh) must drive `cache_clear_busy` / no-unlink; (b) an **absent** `reddit-oauth-token.lock` must **not** drive `cache_clear_busy` (ENOENT counts as unlocked — the I-25 invariant). A `clear()` that requires materializing `reddit-oauth-token.lock` before quiesce (failing busy when absent), or that skips it from the wait set entirely, would pass §6.12 line-635 but violate §6.3 line-462.

Severity NIT: the slot/`inflight` busy path is tested; only the reddit-token-lock half of the barrier (both held and absent) lacks a dedicated assertion.

Suggested remedy (reviewer files only): add a §6.12 `cache_clear_busy` fixture that holds `reddit-oauth-token.lock` and asserts `cache_clear_busy`/no-unlink, and a second fixture where `reddit-oauth-token.lock` is absent (with slots/`inflight` unlockable) and asserts clear proceeds (no `cache_clear_busy`), pinning the I-25 ENOENT-unlocked rule.

### AC3 — NIT — §6.12 reddit OAuth test does not assert token-endpoint calls are not counted against the `reddit` search bucket

§6.11 (line 622) locks the bucket accounting explicitly:

> "Token-endpoint calls are **not** counted against the `reddit` 100/min search bucket."

§6.12 (line 643) reddit OAuth test asserts the refresh path, 401 retry, and the no-stampede (zero token-endpoint calls under TTL ≥ 60s), but does not assert the bucket-accounting invariant:

> "reddit OAuth: shared token file + flock; refresh path; 401 retries once then Auth; N concurrent acquires with remaining TTL ≥ 60s perform **zero** token-endpoint calls (re-read under lock; no stampede)"

A regression where `reddit.rs` calls `bucket::acquire("reddit", …)` on the token-refresh path (consuming the 100/min search bucket for OAuth) would still pass the §6.12 line-643 test — the no-stampede assertion counts token-endpoint calls, not `reddit`-bucket acquires. The §6.4 (line 482) `reddit` bucket (capacity 100, refill 100/min) is the search bucket; the lock exists precisely to keep OAuth off it.

Severity NIT: the positive refresh/no-stampede path is tested; only the bucket-isolation invariant lacks a dedicated assertion. A separate bucket for OAuth is not in scope; the lock is "do not consume the search bucket," which is testable.

Suggested remedy (reviewer files only): add a §6.12 reddit OAuth assertion that N forced token refreshes (driven via TTL < 60s) consume **zero** `reddit` search-bucket tokens (no `bucket::acquire("reddit", …)` on the refresh path), mirroring the §6.11 line-622 lock.

---

## Cross-section consistency (re-verified, no further drift)

- Cache/quota split: §6.3 ↔ §6.2 ↔ §2.2 ↔ §4.4 ↔ §8.1 ↔ §8.4 — query cache under `--cache-dir`, quota under `--quota-dir` default `~/.config/silver-bullet/search-quota/`, never `$HOME/.cache/search`/ProjectDirs. Consistent.
- Fingerprint fields + ordering: §6.3 ↔ §6.12 ↔ §8.4 — query, mode, sorted `-p`, sorted canonicalized include/exclude, freshness, country, lang, `--allow-private` boolean **last**; `count`/TTL/`--max-chars` out; `-d` canonicalized before hash and `augment_query`; intra-list `0x1F`. Consistent.
- `clear()` delete set + quiesce: §6.3 ↔ §4.1 ↔ §8.1 ↔ §8.4 ↔ §5 Phase 1 — `q3_*` (json+inflight) + leftover `q2_*` + future `qN_*` + `last.json` + orphaned `last.json.tmp.*` + `fleet-slots.lock/` ceiling-10 contents after `cache_clear_busy` quiesce; preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`. Consistent across operative sections — except the §6.12 line-634 detailed roster omits `last.json.tmp.*` (filed as AC1) and the §6.12 line-635 busy test omits `reddit-oauth-token.lock` (filed as AC2).
- Bucket fail-closed: §6.4 ↔ §6.6 ↔ §6.12 ↔ §8.1 ↔ §8.4 — `tokens = 0` + `updated_unix_ms = now` unconditionally, `bucket_fail_closed` and `bucket_fail_closed:{id}` on whichever envelope, no refill/calendar on that acquire. Consistent.
- Acquire granularity: github once-per-invocation (§6.4 L487 ↔ §6.10 L609 ↔ §8.1 L724); gitlab per-scope (§6.4 L477 ↔ §6.12 L640 ↔ §8.1 L725); registries per-HTTP (§6.4 L485 ↔ §6.12 L640 ↔ §8.1 L730 ↔ §4.4 L344); brave/x/serper/xweb on request path (§6.4 L483/L486 ↔ §6.12 L640 ↔ §8.1 L732/L733 ↔ §8.4 #8 L779). Consistent (AA1 closed the test asymmetry; AB1–AB4 did not regress it).
- Doctor: §4.4 ↔ §6.1 ↔ §6.12 ↔ §8.1 ↔ §8.4 #8 — honors `--quota-dir`, slot-exempt, `doctor_skip_requires_domain`, registries = 4 `acquire`, `doctor_rate_limited`, YouTube ping 1 of 100 fleet. Consistent.
- Reddit token: §6.11 ↔ §2.2 ↔ §6.3 — shared `{quota_dir}/reddit-oauth-token.json` + `.lock`, re-read under lock, absent lock unlockable, preserved on clear. Consistent — except the no-stampede test gap closed by AB3 and the bucket-isolation gap filed as AC3.
- clap `-p` drift-guard: §6.7 ↔ §6.12 — `command_schemas.search.options` values match `KNOWN`/`build_providers` id set. Consistent.
- X union / one row: §1.2 ↔ §2.5 ↔ §2.8 ↔ §3 — one X catalog row, list `provider`/`bucket` `[x, xweb]`, must-search, dedicated `site:x.com` last resort, dedup test. Consistent (AB1 closed the dedup test gap).
- Warning replay: §6.3 ↔ §6.6 ↔ §6.12 ↔ §8.1 — `bucket_fail_closed`, `bucket_fail_closed:{id}`, `cache_ttl_default_300s`, `doctor_rate_limited` stripped on cache hit; honesty warnings stay. Consistent (AA2 closed the negative-test gap; AB2 did not regress it).

---

Ledger I-1…I-36 (ACCEPT+applied) were excluded per Policy G and not re-reported above. The AB1–AB4 APPLY at this SHA was spot-checked in the plan text and is present and internally consistent (§3 line 339 X-union dedup test; §6.12 line 638 `--cache-ttl` in `--help`; §6.12 line 643 reddit no-stampede; §6.12 line 634 `q4_*` clear fixture). The three findings above (AC1, AC2, AC3) are new residuals not in I-1…I-36 and not duplicates of AB1–AB4.
