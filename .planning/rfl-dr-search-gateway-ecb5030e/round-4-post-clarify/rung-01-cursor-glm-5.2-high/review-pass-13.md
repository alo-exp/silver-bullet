model: glm-5.2-high

# Review pass 13 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `bd706ef2450092fcfe1e10aef788ffab290a8d761b6b87e0024c751155f6819c` (match — `shasum -a 256` confirmed before review).
Scope: residual-only against ledger I-1…I-32 (all ACCEPT+applied) plus the AA1–AA2 APPLY at this SHA. New findings only; I-1…I-32 not re-reported. This is the first re-review after the AA1–AA2 ACCEPT-apply (streak reset to 0). The plan was re-read end-to-end (§1.2 ledger clauses, §2.1–§2.8, §3, §4.1–§4.4, §5, §6.1–§6.13, §7, §8.1–§8.4) and cross-checked independently; AA1/AA2 spot-checked at their apply sites.

Method: bird's-eye (§1.2 locked-decisions log vs operative §2/§4/§6/§8; X-union one-row; cache/quota split; fleet-slots orchestrator-only; superseded-annotation completeness across all §1.2 rung/round clauses; acquire-granularity per provider; fingerprint-field roster and ordering; warning-replay set; quiesce ceiling-10; round-4 rung-1 ACCEPT coverage) then ant's-eye (line-by-line cross-section consistency across §2.1–§2.8, §3, §4.1, §4.3, §4.4, §5, §6.1–§6.13, §7, §8.1–§8.4). Graphify CLI run for orientation (`graphify query` on dr_search_gateway PRD plan §6.12 tests: cache_ttl_default_300s negative, serper/x acquire, doctor.rs behavior tests, max-chars emit truncation, brave acquire, reddit oauth lock, clap -p drift-guard, cache clear qN_*) — surfaced the AA1/AA2 finding nodes and the W5/I-24, W6/I-25 prior-find nodes, all of which are in the applied ledger and excluded per Policy G. agentmemory capture deferred to the parent per rung contract.

Result: NOT CLEAN — 4 new residuals (AB1 LOW, AB2 NIT, AB3 NIT, AB4 NIT).

---

## AA1 / AA2 APPLY spot-check (this SHA)

Both APPLYs are present and internally consistent at the locked sites.

AA1 — §6.12 (line 640) per-new-provider mock list now asserts acquire for all four request-path providers, not only brave/xweb:

> "...**x** official `search/recent` skips without bearer, `acquire("x", …, collector)` before HTTP; **xweb** unpaid HTTP skips without guest/cookies, acquires `xweb` bucket, never execs `twitter`/`opencli`/`bird`; **brave** `acquire("brave", …, collector)` before HTTP (bucket exists under `--quota-dir`); **serper** `acquire("serper", …, collector)` before POST"

This matches the operative locks: §6.4 (line 483) `x.rs` acquire; §6.4 (line 486) brave + serper on request path; §8.1 (line 732) `x.rs` Create acquire; §8.4 #8 (line 779) serper Modify acquire. The `x` and `serper` acquire assertions are new vs pass-12 and close the AA1 gap.

AA2 — §6.12 (line 645) `--json` snapshot now asserts both halves of the §6.3 (line 460) lock:

> "...`SB_DR_FLEET=1` + unset TTL emits `cache_ttl_default_300s` in `warnings`; a run without `SB_DR_FLEET` and with TTL unset must **not** emit `cache_ttl_default_300s`..."

The negative (human-run exemption) assertion is new vs pass-12 and closes the AA2 gap. §8.1 (line 737) `main.rs` Modify bullet still names only the positive case, but §8.1 is a file-change summary (not an exhaustive test roster); §6.3/§6.12 carry the full lock — no contradiction.

---

## Findings

### AB1 — LOW — §2.5/§1.2 lock X-union dedup (tweet id else canonical status URL) has no SB-orchestrator test in §3

§1.2 round-4 post-clarify rung 1 (line 85) locks:

> "X dedup in SB orchestrator (tweet id else canonical status URL)"

and §2.5 (line 101) makes the dedup operative and explicit:

> "**Dedup (SB orchestrator, locked):** each X leg is a separate `search` process ... Dedup lives in **`search_orchestrator.py`**, not the fork. Key: prefer tweet/status id; else canonical `x.com` / `twitter.com` status URL. xAI `-m social` hits join the same set when they carry an id or that URL; results without either stay undeduped (recorded)."

§3 (line 339) is the SB-side acceptance test roster (`test_must_search_catalog.py`, probe, two-orchestrator shard aggregation, `SEARCH_CACHE_DIR`/`SB_DR_PROJECT_ROOT` sharing, `cache_clear_busy` cross-`--cache-dir`, fleet-slots clamp, same-fingerprint single-flight, gitignore, Serper pre-run alert). It asserts **none** of the X-dedup contract: no fixture feeding two X legs (e.g. `-p x` + `-p xweb` + xAI) carrying the same tweet id / canonical status URL and asserting the orchestrator emits one row; no assertion that results without an id/URL stay undeduped-and-recorded. An implementer following §3 literally would add the catalog/probe/shard tests and leave the dedup key (tweet id else canonical URL, xAI join rule) without a regression test. A regression that drops dedup, or dedups by full URL only, or fails to join xAI hits, would not be caught.

Severity LOW: the dedup is "soft" (undropped results stay recorded, not a crash), but it is a distinctive locked SB-orchestrator behavior with no dedicated test.

Suggested remedy (reviewer files only; launcher triages): add a §3 SB orchestrator test that feeds two/three X-leg envelopes carrying the same tweet id and the same canonical `x.com`/`twitter.com` status URL (plus an xAI hit carrying the id), asserts one deduped row, and a second fixture where neither leg carries an id/URL asserts the rows stay undeduped and are recorded.

### AB2 — NIT — §6.12 clap help test asserts `--cache-dir` and `--quota-dir` but omits `--cache-ttl` (locked Phase 1 fork ADD)

§6.2 (line 414) locks `--cache-ttl <SECS>` / env `SEARCH_CACHE_TTL` as a global on `Cli`, and §1.2 round-4 post-clarify rung 1 (line 85) locks "`--cache-ttl` is a Phase 1 fork ADD". Fleet argv (§6.2 line 429; §3 line 339) **always** passes `--cache-ttl 86400`, so a fork regression that drops the `--cache-ttl` clap arg would reject every fleet invocation.

§6.12 (line 638) clap test asserts only two of the three global flags:

> "clap: unknown `-p discoursee` still `Config` exit 2; `--cache-dir` **and** `--quota-dir` appear in `--help`; **no** `--no-fanout` in help"

`--cache-ttl` presence in `--help` (and clap acceptance of `--cache-ttl <SECS>`) is not asserted. The two-process cache test (§6.12 line 635) names `--cache-dir` but not `--cache-ttl`, so it does not implicitly cover clap acceptance either. A regression removing `--cache-ttl` from `Cli` would not be caught by the §6.12 suite as written.

Severity NIT: the flag is locked and fleet depends on it; the gap is a one-line test omission (add `--cache-ttl` to the help-presence assertion and/or a clap-acceptance test).

Suggested remedy (reviewer files only): extend the §6.12 line 638 clap test to also assert `--cache-ttl` appears in `--help` (and/or that `search ... --cache-ttl 86400` is accepted by clap).

### AB3 — NIT — §6.12 reddit OAuth test does not assert the no-stampede invariant locked in §6.11

§6.11 (line 622) locks the double-check / no-stampede:

> "Refresh when remaining TTL < 60s or file missing. Under the exclusive lock, **re-read** the shared file and skip the token endpoint if remaining TTL is still ≥ 60s (double-check; one refresh, no stampede)."

§6.12 (line 643) reddit OAuth test is terse and does not assert the distinctive invariant:

> "reddit OAuth: shared token file + flock; refresh path; 401 retries once then Auth"

"shared token file + flock; refresh path" exercises the refresh code path but does not assert the **no-stampede** behavior that is the point of the I-23 lock: N concurrent acquires against a token file with remaining TTL ≥ 60s must hit the token endpoint **zero** times (re-read under lock → skip). A regression that always hits the token endpoint under the lock (skipping the re-read) would still pass "refresh path" and the 401-retry test.

Severity NIT: the positive refresh path is tested; only the no-stampede invariant lacks a dedicated assertion.

Suggested remedy (reviewer files only): add a §6.12 reddit OAuth test that holds the shared token file with TTL ≥ 60s remaining and asserts N concurrent acquires perform zero token-endpoint calls (re-read under lock → skip), mirroring the I-23 lock.

### AB4 — NIT — §6.12 `clear()` test exercises `q3_*` and `q2_*` but not the locked future-`qN_*` deletion

§6.3 (line 462) locks forward-compat deletion of any future fingerprint-bump prefix:

> "...After the `q3_` bump it must delete **all `q3_*`** (`q3_*.json` **and** `q3_*.inflight`), leftover `q2_*.json`, **and any future `qN_*` prefix** (`q4_*` …) so a fingerprint bump does not orphan files..."

§6.12 (line 634) `cache::` clear test lists only the existing prefixes:

> "...`clear()` with `--cache-dir` + `--quota-dir` removes `q3_*` (`q3_*.json` **and** `q3_*.inflight`) plus leftover `q2_*` plus `last.json` plus `fleet-slots.lock/` slot files..."

A `clear()` implementation that hardcodes the `q3_*` and `q2_*` prefixes (rather than a `q[0-9]_*` glob) would pass the §6.12 test but orphan `q4_*` (and beyond) on a future fingerprint bump — exactly the scenario §6.3 calls out. No fixture places a `q4_*` file and asserts its removal.

Severity NIT: forward-compat defense-in-depth; no Phase 1 correctness impact (`q4_*` does not exist yet), but the lock is explicit and the test does not exercise it.

Suggested remedy (reviewer files only): add a §6.12 `clear()` fixture that seeds a `q4_dummy.json` and asserts it is removed alongside `q3_*`/`q2_*`, pinning the `qN_*` glob.

---

## Cross-section consistency (re-verified, no further drift)

- Cache/quota split: §6.3 (lines 448–457) ↔ §6.2 (lines 412–413) ↔ §2.2 (line 125) ↔ §4.4 (line 344) ↔ §8.1 (line 736) ↔ §8.4 (line 773) — query cache under `--cache-dir`, quota under `--quota-dir` default `~/.config/silver-bullet/search-quota/`, never `$HOME/.cache/search`/ProjectDirs. Consistent.
- Fingerprint fields + ordering: §6.3 (line 458) ↔ §6.12 (line 634) ↔ §8.4 (line 773) — query, mode, sorted `-p`, sorted canonicalized include/exclude, freshness, country, lang, `--allow-private` boolean **last**; `count`/TTL/`--max-chars` out; `-d` canonicalized before hash and `augment_query`; intra-list `0x1F`. The shared golden-vector fixture pins the exact hex (and therefore field order); `--allow-private` true vs false differ. Consistent.
- `clear()` delete set + quiesce: §6.3 (line 462) ↔ §6.12 (line 634) ↔ §8.1 (line 736) ↔ §8.4 (line 773) ↔ §5 Phase 1 (line 351) — `q3_*` (json+inflight) + leftover `q2_*` + `last.json` + orphaned `last.json.tmp.*` + `fleet-slots.lock/` ceiling-10 contents after `cache_clear_busy` quiesce; preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`. Consistent — except the `qN_*` forward-compat test gap filed as AB4.
- Bucket fail-closed: §6.4 (line 470) ↔ §6.6 (line 523) ↔ §6.12 (line 637) ↔ §8.1 (line 736) ↔ §8.4 (line 773) — `tokens = 0` + `updated_unix_ms = now` unconditionally, `bucket_fail_closed` and `bucket_fail_closed:{id}` on whichever envelope, no refill/calendar on that acquire. Consistent.
- Acquire granularity: github once-per-invocation (§6.4 L487 ↔ §6.10 L609 ↔ §8.1 L724); gitlab per-scope (§6.4 L477 ↔ §6.12 L640 ↔ §8.1 L725); registries per-HTTP (§6.4 L485 ↔ §6.12 L640 ↔ §8.1 L730 ↔ §4.4 L344); brave/x/serper/xweb on request path (§6.4 L483/L486 ↔ §6.12 L640 ↔ §8.1 L732/L733 ↔ §8.4 #8 L779). Consistent (AA1 closed the test asymmetry).
- Doctor: §4.4 (line 344) ↔ §6.1 (line 369) ↔ §6.12 (line 641) ↔ §8.1 (line 743) ↔ §8.4 #8 (line 779) — honors `--quota-dir`, slot-exempt, `doctor_skip_requires_domain`, registries = 4 `acquire`, `doctor_rate_limited`, YouTube ping 1 of 100 fleet. Consistent.
- Reddit token: §6.11 (line 622) ↔ §2.2 (line 125) ↔ §6.3 (line 462) — shared `{quota_dir}/reddit-oauth-token.json` + `.lock`, re-read under lock, absent lock unlockable, preserved on clear. Consistent — except the no-stampede test gap filed as AB3.
- clap `-p` drift-guard: §6.7 (line 534) ↔ §6.12 (line 639) — `command_schemas.search.options` values match `KNOWN`/`build_providers` id set. Consistent.
- X union / one row: §1.2 (line 65) ↔ §2.5 (line 178) ↔ §2.8 (lines 263–267) — one X catalog row, list `provider`/`bucket` `[x, xweb]`, must-search, dedicated `site:x.com` last resort. Consistent — except the dedup test gap filed as AB1.
- Warning replay: §6.3 (line 460) ↔ §6.6 (line 523) ↔ §6.12 (line 645) ↔ §8.1 (line 737) — `bucket_fail_closed`, `bucket_fail_closed:{id}`, `cache_ttl_default_300s`, `doctor_rate_limited` stripped on cache hit; honesty warnings stay. Consistent (AA2 closed the negative-test gap).

---

Ledger I-1…I-32 (ACCEPT+applied) were excluded per Policy G and not re-reported above. The AA1–AA2 APPLY at this SHA was spot-checked in the plan text and is present and internally consistent (§6.12 line 640 x/serper acquire; §6.12 line 645 cache_ttl_default_300s negative). The four findings above (AB1, AB2, AB3, AB4) are new residuals not in I-1…I-32 and not duplicates of AA1/AA2.
