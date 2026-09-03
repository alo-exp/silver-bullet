model: glm-5.2-high

# Review pass 11 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `f08aef058f38cd592b98f0739b414ec93a64644245ab3ab7045f6df6f2d13c71` (match — `shasum -a 256` confirmed before review).
Scope: residual-only against ledger I-1…I-30 (all ACCEPT+applied) plus the Y1 APPLY at this SHA. New findings only; I-1…I-30 not re-reported.

Method: bird's-eye (§1→§8 structure; §1.2 locked-decisions log vs operative §2/§4/§6/§8; X-union; cache/quota split; fleet-slots; superseded-annotation completeness across all §1.2 rung/round clauses) then ant's-eye (line-by-line cross-section consistency across §2.1, §2.2, §2.4–§2.8, §3, §4.4, §5, §6.2, §6.3, §6.4, §6.5, §6.6, §6.7–§6.10, §6.11, §6.12, §6.13, §7, §8.1, §8.4). Graphify CLI run for orientation (`dr_search_gateway PRD plan: search-cli Rust, doctor.rs, fleet quota, SB_DR_FLEET_SLOTS, augment_query, cache-ttl, allow-private, max-chars, brave acquire, reddit TTL lock, clap -p drift-guard`); agentmemory capture deferred to the parent per rung contract.

Result: CLEAN — zero new residuals.

---

## Y1 APPLY spot-check (this SHA)

Y1 (the only APPLY at this SHA) is present and internally consistent. §1.2 rung 10 H1 (line 73) now reads:

> "Fork may read `SB_DR_FLEET` for the TTL warning only (**superseded** for slots by item 10 M-2 / I-18: `SB_DR_FLEET_SLOTS` is orchestrator-only; the fork does **not** read it)."

This matches the operative sections:
- §6.13 (line 662): "Fork **may** read `SB_DR_FLEET` for the fleet TTL warning only. `SB_DR_FLEET_SLOTS` is **orchestrator-only** (`search_orchestrator.py` admission N); the fork does **not** read it. Quiesce/clear is **always ceiling-10** (`0.lock`…`9.lock`), never `{N-1}`."
- §1.2 missing High+ item 10 ACCEPTs (line 84) M-2 clause: "`SB_DR_FLEET_SLOTS` is orchestrator-only (admission N); the fork does not read it."
- §1.2 round 4 post-clarify rung 1 ACCEPTs (line 85): "§1.2 H1 `SB_DR_FLEET_SLOTS` fork-read is superseded (I-18); fork does not read it."
- §2.2 (line 125) and §6.9 (line 604) both place `SB_DR_FLEET_SLOTS` on the orchestrator side only.

The earlier "Fork may read `SB_DR_FLEET_SLOTS`" string is gone from line 73. The superseded-annotation pattern now mirrors the other annotated clauses in §1.2 (rung 2 fleet-slots path, rung 3 buckets path, rung 6 last.json tmp, rung 10 M6 X `must_search: false`, round-2 rung 1/3/7/8 superseded markers). No §1.2 ledger clause remains with an un-annotated contradiction against a later lock.

## Cross-section consistency (no drift found)

Verified across the operative surface:
- Cache/quota split: §6.3 (lines 448–457) ↔ §6.2 (lines 412–413) ↔ §2.2 (line 125) ↔ §4.4 (line 344) ↔ §8.1 (line 736) ↔ §8.4 (line 773) — query cache under `--cache-dir`, quota under `--quota-dir` default `~/.config/silver-bullet/search-quota/`, never `$HOME/.cache/search`/ProjectDirs. Consistent.
- Fingerprint fields: §6.3 (line 458) ↔ §6.12 (line 634) ↔ §8.4 (line 773) — `--allow-private` in (last, boolean), `count`/TTL/`--max-chars` out, `-d` canonicalized before hash and `augment_query`, intra-list `0x1F`. Consistent.
- `clear()` delete set + quiesce: §6.3 (line 462) ↔ §6.12 (line 634) ↔ §8.1 (line 736) ↔ §8.4 (line 773) ↔ §5 Phase 1 (line 351) — `q3_*` (json+inflight) + leftover `q2_*` + `last.json` + orphaned `last.json.tmp.*` + `fleet-slots.lock/` ceiling-10 contents after `cache_clear_busy` quiesce; preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`. Consistent.
- Bucket fail-closed: §6.4 (line 470) ↔ §6.6 (line 523) ↔ §6.12 (line 637) ↔ §8.1 (line 723) — `tokens = 0` + `updated_unix_ms = now` unconditionally, `bucket_fail_closed` and `bucket_fail_closed:{id}` on whichever envelope, no refill/calendar on that acquire. Consistent.
- Doctor: §4.4 (line 344) ↔ §6.12 (line 641) ↔ §8.1 (line 743) ↔ §8.4 (line 779) — honors `--quota-dir`, slot-exempt, `doctor_skip_requires_domain`, registries = 4 `acquire`, `doctor_rate_limited`, YouTube ping 1 of 100 fleet. Consistent.
- Reddit token: §6.11 (line 622) ↔ §2.2 (line 125) ↔ §6.3 (line 462) — shared `{quota_dir}/reddit-oauth-token.json` + `.lock`, re-read under lock, absent lock unlockable, preserved on clear. Consistent.
- Brave bucket: §6.4 (line 475) ↔ §6.12 (line 640) ↔ §8.1 (line 742) — `acquire("brave", …, collector)` before HTTP, fleet-critical. Consistent.
- clap `-p` drift-guard: §6.12 (line 639) ↔ §8.1 (line 737) — `command_schemas.search.options` values match `KNOWN`/`build_providers` id set. Consistent.
- X union / one row: §1.2 (line 50) ↔ §2.5 (line 178) ↔ §2.8 (lines 263–267) — one X catalog row, list `provider`/`bucket` `[x, xweb]`, must-search, dedicated `site:x.com` last resort. Consistent.

No contradictions, no stale defaults after the Y1 APPLY, no cross-section drift, and no missing test for any newly locked behavior (Y1 only annotated an existing lock; it introduced no new behavior requiring a new test).

---

Ledger I-1…I-30 (ACCEPT+applied) were excluded per Policy G and not re-reported above. The Y1 APPLY at this SHA was spot-checked in the plan text and is present and internally consistent (§1.2 line 73 superseded annotation matches §6.13 line 662, item 10 M-2 line 84, and the round-4 post-clarify rung-1 ACCEPTs line 85).
