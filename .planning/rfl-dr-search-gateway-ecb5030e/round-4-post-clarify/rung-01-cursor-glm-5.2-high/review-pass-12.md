model: glm-5.2-high

# Review pass 12 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `f08aef058f38cd592b98f0739b414ec93a64644245ab3ab7045f6df6f2d13c71` (match — `shasum -a 256` confirmed before review).
Scope: residual-only against ledger I-1…I-30 (all ACCEPT+applied) plus the Y1 APPLY at this SHA. New findings only; I-1…I-30 not re-reported. This is the second consecutive CLEAN attempt (streak 1/2) — pass 11 was not rubber-stamped; the plan was re-read end-to-end (§1.2 ledger clauses, §2.1–§2.8, §3, §4.1–§4.4, §5, §6.1–§6.13, §7, §8.1–§8.4) and cross-checked independently.

Method: bird's-eye (§1.2 locked-decisions log vs operative §2/§4/§6/§8; X-union one-row; cache/quota split; fleet-slots orchestrator-only; superseded-annotation completeness across all §1.2 rung/round clauses; acquire-granularity per provider; fingerprint-field roster; warning-replay set; quiesce ceiling-10) then ant's-eye (line-by-line cross-section consistency across §2.1, §2.2, §2.3, §2.4–§2.8, §3, §4.1, §4.3, §4.4, §5, §6.1, §6.2, §6.3, §6.4, §6.5, §6.6, §6.7, §6.8, §6.9, §6.10, §6.11, §6.12, §6.13, §7, §8.1, §8.2, §8.3, §8.4). Graphify CLI run for orientation (`graphify query` on dr_search_gateway PRD plan: search-cli Rust fork cache fingerprint, doctor.rs quota-dir, fleet-slots SB_DR_FLEET_SLOTS orchestrator-only, augment_query site: path-scoped, bucket acquire collector, reddit oauth token lock, clap -p values drift-guard, max-chars emit truncation, brave acquire, cache_clear_busy quiesce ceiling-10) — surfaced the Y1/U2/I-18 supersede cluster and the W5/I-24, W6/I-25 prior-find nodes, all of which are in the applied ledger and excluded per Policy G. agentmemory capture deferred to the parent per rung contract.

Result: NOT CLEAN — 2 new residuals (AA1 LOW, AA2 NIT).

---

## Findings

### AA1 — LOW — §6.12 per-provider acquire test list omits `serper.rs` and `x.rs` while asserting `brave` and `xweb`

§6.4 (line 486) locks the acquire contract for four existing/new providers on the request path before HTTP:

> "Call `bucket::acquire(..., collector)` from each new provider **and** from `serper.rs` **and** `brave.rs` on the request path before HTTP."

and §6.4 (line 483) locks `x.rs`:

> "`x.rs` calls `acquire("x", …, collector)` before HTTP."

§8.4 #8 reaffirms the serper lock:

> "8. `src/providers/serper.rs` — bucket acquire only (keep `augment_query` `site:`)…"

§8.1 (line 732) reaffirms the `x.rs` lock:

> "- **Create** `src/providers/x.rs` — struct `X`; official v2 `search/recent`; bearer; `acquire("x", …, collector)`"

§6.12 (line 640) per-new-provider mock test list asserts acquire explicitly for `brave` and `xweb` but **not** for `serper` or `x`:

> "...**brave** `acquire("brave", …, collector)` before HTTP (bucket exists under `--quota-dir`)"
> "**xweb** unpaid HTTP skips without guest/cookies, acquires `xweb` bucket, never execs `twitter`/`opencli`/`bird`"
> "**x** official `search/recent` skips without bearer"   ← asserts is_configured skip only; no acquire assertion
> (serper.rs is not in the "per new provider mock" list at all — it is a Modify, not a Create)

The general `bucket::` test block (§6.12 line 637) tests acquire *mechanics* (429, cold-start, malformed, youtube calendar, discourse sanitization/IDN) but does **not** assert that `serper.rs` or `x.rs` actually call `acquire` on the request path. An implementer following §6.12 literally would add brave + xweb acquire tests and the two-process `-p serper` cache test (line 635, which tests caching, not acquire), leaving `serper.rs` and `x.rs` acquire — both locked behaviors — without a dedicated regression test.

This is the same class of gap as I-26 (brave acquire test), which was ACCEPT+applied and is therefore not re-filed. I-26 was brave-specific; the parallel serper and x gaps were not in the ledger and are not duplicates of I-26.

Severity LOW: missing test for two locked acquire-on-request-path behaviors; a regression that drops the `serper.rs`/`x.rs` acquire call would not be caught by the §6.12 suite as written.

Suggested remedy (reviewer files only; launcher triages): extend the §6.12 per-provider mock list to assert `serper.rs` calls `acquire("serper", …, collector)` before POST and `x.rs` calls `acquire("x", …, collector)` before HTTP, mirroring the existing brave/xweb assertions.

### AA2 — NIT — §6.12 tests only the positive `cache_ttl_default_300s` case; no negative test for the human-run exemption

§6.3 (line 460) locks a defense-in-depth warning **and** a human exemption:

> "**Defense-in-depth:** if `SB_DR_FLEET=1` and neither `--cache-ttl` nor `SEARCH_CACHE_TTL` is set (effective TTL = 300), append envelope `warnings` string `cache_ttl_default_300s`. Human runs without `SB_DR_FLEET` do not warn."

§6.12 (line 645) tests only the positive fleet case:

> "`SB_DR_FLEET=1` + unset TTL emits `cache_ttl_default_300s` in `warnings`"

There is no §6.12 test for the negative half of the lock — a human run (no `SB_DR_FLEET`) with `--cache-ttl`/`SEARCH_CACHE_TTL` unset must **not** emit `cache_ttl_default_300s`. Without a negative test, a regression that drops the `SB_DR_FLEET` guard and warns unconditionally on every unset-TTL run would not be caught.

Severity NIT: the positive path is tested; only the negative exemption lacks a guard test.

Suggested remedy (reviewer files only): add a §6.12 assertion that a run without `SB_DR_FLEET` and with TTL unset does **not** contain `cache_ttl_default_300s` in `warnings`.

---

## Y1 APPLY spot-check (this SHA)

Y1 (the only APPLY at this SHA) is present and internally consistent. §1.2 rung 10 H1 (line 73) now reads:

> "Fork may read `SB_DR_FLEET` for the TTL warning only (**superseded** for slots by item 10 M-2 / I-18: `SB_DR_FLEET_SLOTS` is orchestrator-only; the fork does **not** read it)."

This matches the operative sections:
- §6.13 (line 662): "Fork **may** read `SB_DR_FLEET` for the fleet TTL warning only. `SB_DR_FLEET_SLOTS` is **orchestrator-only** (`search_orchestrator.py` admission N); the fork does **not** read it. Quiesce/clear is **always ceiling-10** (`0.lock`…`9.lock`), never `{N-1}`."
- §1.2 missing High+ item 10 ACCEPTs (line 84) M-2 clause: "`SB_DR_FLEET_SLOTS` is orchestrator-only (admission N); the fork does not read it."
- §1.2 round 4 post-clarify rung 1 ACCEPTs (line 85): "§1.2 H1 `SB_DR_FLEET_SLOTS` fork-read is superseded (I-18); fork does not read it."
- §2.2 (line 125) and §6.9 (line 604) both place `SB_DR_FLEET_SLOTS` on the orchestrator side only.

The earlier "Fork may read `SB_DR_FLEET_SLOTS`" string is gone from line 73. The superseded-annotation pattern mirrors the other annotated clauses in §1.2 (rung 2 fleet-slots path, rung 3 buckets path, rung 6 last.json tmp, rung 10 M6 X `must_search: false`, round-2 rung 1/3/7/8 superseded markers). No §1.2 ledger clause remains with an un-annotated contradiction against a later lock.

## Cross-section consistency (re-verified, no further drift)

- Cache/quota split: §6.3 (lines 448–457) ↔ §6.2 (lines 412–413) ↔ §2.2 (line 125) ↔ §4.4 (line 344) ↔ §8.1 (line 736) ↔ §8.4 (line 773) — query cache under `--cache-dir`, quota under `--quota-dir` default `~/.config/silver-bullet/search-quota/`, never `$HOME/.cache/search`/ProjectDirs. Consistent.
- Fingerprint fields: §6.3 (line 458) ↔ §6.12 (line 634) ↔ §8.4 (line 773) — `--allow-private` in (last, boolean), `count`/TTL/`--max-chars` out, `-d` canonicalized before hash and `augment_query`, intra-list `0x1F`. Consistent.
- `clear()` delete set + quiesce: §6.3 (line 462) ↔ §6.12 (line 634) ↔ §8.1 (line 736) ↔ §8.4 (line 773) ↔ §5 Phase 1 (line 351) — `q3_*` (json+inflight) + leftover `q2_*` + `last.json` + orphaned `last.json.tmp.*` + `fleet-slots.lock/` ceiling-10 contents after `cache_clear_busy` quiesce; preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`. Consistent.
- Bucket fail-closed: §6.4 (line 470) ↔ §6.6 (line 523) ↔ §6.12 (line 637) ↔ §8.1 (line 736) ↔ §8.4 (line 773) — `tokens = 0` + `updated_unix_ms = now` unconditionally, `bucket_fail_closed` and `bucket_fail_closed:{id}` on whichever envelope, no refill/calendar on that acquire. Consistent.
- Acquire granularity: github once-per-invocation (§6.4 L487 ↔ §6.10 L609 ↔ §8.1 L724); gitlab per-scope (§6.4 L477 ↔ §6.12 L640 ↔ §8.1 L725); registries per-HTTP (§6.4 L485 ↔ §6.12 L640 ↔ §8.1 L730 ↔ §4.4 L344). Consistent — except the test asymmetry filed as AA1.
- Doctor: §4.4 (line 344) ↔ §6.1 (line 369) ↔ §6.12 (line 641) ↔ §8.1 (line 743) ↔ §8.4 #8 (line 779) — honors `--quota-dir`, slot-exempt, `doctor_skip_requires_domain`, registries = 4 `acquire`, `doctor_rate_limited`, YouTube ping 1 of 100 fleet. Consistent.
- Reddit token: §6.11 (line 622) ↔ §2.2 (line 125) ↔ §6.3 (line 462) — shared `{quota_dir}/reddit-oauth-token.json` + `.lock`, re-read under lock, absent lock unlockable, preserved on clear. Consistent.
- clap `-p` drift-guard: §6.7 (line 534) ↔ §6.12 (line 639) — `command_schemas.search.options` values match `KNOWN`/`build_providers` id set. Consistent.
- X union / one row: §1.2 (line 65) ↔ §2.5 (line 178) ↔ §2.8 (lines 263–267) — one X catalog row, list `provider`/`bucket` `[x, xweb]`, must-search, dedicated `site:x.com` last resort. Consistent.

---

Ledger I-1…I-30 (ACCEPT+applied) were excluded per Policy G and not re-reported above. The Y1 APPLY at this SHA was spot-checked in the plan text and is present and internally consistent (§1.2 line 73 superseded annotation matches §6.13 line 662, item 10 M-2 line 84, and the round-4 post-clarify rung-1 ACCEPTs line 85). The two findings above (AA1, AA2) are new residuals not in I-1…I-30 and not duplicates of Y1.
