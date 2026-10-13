model: glm-5.2-high

# Review pass 10 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `763b4ada2509833124c682bfa58c3308a41bd0d01a2f77242d4af3491364dcdb` (match — `shasum -a 256` confirmed before review).
Scope: residual-only against ledger I-1…I-29 (all ACCEPT+applied) plus the X1–X3 APPLY at this SHA. New findings only; I-1…I-29 not re-reported.

Method: bird's-eye (§1→§8 structure, §1.2 locked-decisions log vs operative §2/§4/§6/§8, X-union, cache/quota split, fleet-slots) then ant's-eye (line-by-line cross-section consistency across §4.4, §6.2, §6.3, §6.4, §6.6, §6.11, §6.12, §6.13, §8.1, §8.4). Graphify query run for orientation (`DR search gateway plan residual defects: doctor quota-dir, max-chars fingerprint, fleet slots, cache clear, reddit token, bucket fail-closed, X must_search`); agentmemory capture deferred to the parent per rung contract.

Result: NOT CLEAN — 1 new residual (1 LOW).

---

## Y1 — LOW — §1.2 rung 10 H1 still says "Fork may read `SB_DR_FLEET_SLOTS`", contradicting the I-18 lock (§6.13 + item 10 M-2)

- §1.2 rung 10 ACCEPTs (line 73), **Quiesce (H1)** clause: "`… materialize + exclusive-lock `0.lock`…`9.lock` (clamp ceiling 10, not only files that already exist). Fork may read `SB_DR_FLEET_SLOTS` (same porous env as `SB_DR_FLEET`); still must not read SB catalogs. …`"
- §1.2 missing High+ item 10 ACCEPTs (line 84), **Quiesce N (M-2)** clause: "`… Fork may read `SB_DR_FLEET` for the TTL warning only. `SB_DR_FLEET_SLOTS` is orchestrator-only (admission N); the fork does not read it. Quiesce/clear is always ceiling-10 (`0.lock`…`9.lock`), never `{N-1}`. …`"
- §6.13 (line 662) explicit non-goals: "`… Fork may read `SB_DR_FLEET` for the fleet TTL warning only. `SB_DR_FLEET_SLOTS` is orchestrator-only (`search_orchestrator.py` admission N); the fork does not read it. …`"
- §2.2 (line ~125) and §6.9 (line 604) both place `SB_DR_FLEET_SLOTS` on the orchestrator side only (`search_orchestrator.py` admission N; `SB_DR_FLEET_SLOTS` clamp 5–10).

After I-18 (SB_DR_FLEET_SLOTS orchestrator-only) was applied, the operative sections — §6.13 (line 662) and the item 10 M-2 clause (line 84) — were updated to state "the fork does not read it". The earlier rung 10 H1 clause (line 73) was **not** amended with a "superseded by item 10 M-2 / I-18" annotation and still reads "Fork may read `SB_DR_FLEET_SLOTS`". Other superseded clauses in §1.2 do carry inline "superseded by …" markers (e.g. rung 3 `fleet-slots.lock` path, rung 6 `buckets/` path, rung 10 M6 `X must_search: false`); this one does not. An implementer reading §1.2 rung 10 H1 in isolation could conclude the fork is permitted to read `SB_DR_FLEET_SLOTS`, directly contradicting §6.13 / item 10 M-2 / §2.2 / §6.9. Fix: add an inline "superseded by item 10 M-2 (I-18); fork does not read `SB_DR_FLEET_SLOTS`" annotation to the line 73 clause (or strike "Fork may read `SB_DR_FLEET_SLOTS` …"), mirroring the superseded-annotation pattern used elsewhere in §1.2.

---

Ledger I-1…I-29 (ACCEPT+applied) were excluded per Policy G and not re-reported above. The X1–X3 APPLY at this SHA was spot-checked in the plan text and is present and internally consistent:
- X1 §4.4 (line 344): "unset-flag `--quota-dir` default is `~/.config/silver-bullet/search-quota/` (same as fleet); a bare `search doctor` spends **fleet** bucket tokens. Do not invent a `$HOME/.cache/search` quota default" — matches §6.2 (line 413) / §6.3 (line 454) / §2.2 (line 125).
- X2 §6.12 (line 634, cache:: unit tail): "`--max-chars` is **not** a fingerprint field (same query + `-p` + `-d` + two `--max-chars` values → same `q3_`; stored body untruncated; emit truncates to the reader's `--max-chars`)" — matches §6.3 (line 458) "Do not put `--max-chars` in the hash … truncation is applied at emit … stored body is untruncated" and §8.4 line 2 "not `--max-chars`".
- X3 §6.12 (line 641, doctor bullet): "doctor: honors `--quota-dir` (does not invent a `$HOME/.cache/search` quota default); `doctor_skip_requires_domain` for discourse (no placeholder host); registries doctor ping = 4 `acquire`; `RateLimited` → `doctor_rate_limited` (not false-unhealthy); YouTube doctor ping spends 1 of 100 under `--quota-dir`" — matches §4.4 (line 344), §6.1 (line 369), §8.1 `src/doctor.rs` Modify (line 745), §8.4 line 8.
