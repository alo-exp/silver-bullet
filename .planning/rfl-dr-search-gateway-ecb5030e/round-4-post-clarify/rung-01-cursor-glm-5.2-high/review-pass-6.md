model: glm-5.2-high

# Review pass 6 — Policy F re-review (streak 1/2)

- Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- SHA-256 verified: `1412d8c9d18e1e2204c8b5011906fc341fb19b1b7a77df9b708e51e47b175db4` (matches brief)
- Scope: residual-only (Policy G). Ledger rows I-1 … I-16 are ACCEPT+applied and are NOT re-reported below.
- Method: graphify CLI query (`DR search gateway plan allow-private X consent`) + full bird's-eye (48 headings mapped) then ant's-eye (all 779 lines / ~159 KB read in full via sandbox in line-range passes).

## Result: NOT CLEAN — 2 new residuals

Two new residuals found that are not exact duplicates of any ACCEPT+applied ledger row. Both are NIT-level documentation/rationale inconsistencies with no operative behavior gap (the operative contracts they reference are correct elsewhere in the plan).

---

### U1 — §2.2 probe rationale "upstream already exposes it" for `--cache-ttl` contradicts §6.2/§2.4/§4.1/§6.1/§8.4

- **Severity:** NIT
- **Location:** §2.2 (line 123), probe contract sentence.
- **Quote (§2.2):** "`--cache-ttl` is an argv lock only (upstream already exposes it; not a `wrong_binary` discriminator)."
- **Defect:** The parenthetical claims "upstream already exposes" `--cache-ttl`. In this plan "upstream" consistently denotes `paperfoot/search-cli` (§3.1 "upstream remote to paperfoot/search-cli"; §6 heading "Exact fork SRS (paperfoot/search-cli @ 7df7b345)"; §6.1 "Leave alone (upstream behavior, merge weekly)"). But `--cache-ttl` is a **Phase 1 fork addition**, not an upstream-exposed flag:
  - §6.2 (line 413) lists `--cache-ttl <SECS>` / `SEARCH_CACHE_TTL` under "**Add (global on `Cli`)**".
  - §2.4 (line 162) describes upstream TTL as the const `CACHE_TTL_SECS = 300` with "no `--cache-dir`" (no `--cache-ttl` flag).
  - §4.1 (line 329) lists `--cache-ttl` / `SEARCH_CACHE_TTL` under "Phase 1 must".
  - §6.1 (line 376) Modify list: "new global `--cache-dir` / `--quota-dir` / `--cache-ttl` only".
  - §8.4 (line 769) item 1: "add global `--cache-dir`...`--cache-ttl`/`SEARCH_CACHE_TTL`".
- **Operative impact:** none. The probe already rejects upstream 0.9.0 via `--cache-dir` + `--quota-dir` in `--help` + fork native + `cache_fingerprint_version` + `cached_entry_version` (same §2.2 sentence), so not using `--cache-ttl` as a discriminator is correct. Only the rationale "upstream already exposes it" is inaccurate.
- **Why this is not a duplicate:** No ledger row covers the `--cache-ttl` upstream-exposure rationale. I-16 covers `--allow-private` in the fingerprint; I-7 covers no-binary-fallback on a missing tag.
- **Minimal fix (reviewer does not apply; for triage):** replace the parenthetical with one that matches §6.2, e.g. "(added by the fork in Phase 1 alongside `--cache-dir`/`--quota-dir`; not a `wrong_binary` discriminator since the dir flags + fingerprint versions already discriminate upstream 0.9.0)".

---

### U2 — §6.13 grants the fork `SB_DR_FLEET_SLOTS` for "admission N", but admission is orchestrator-side (§2.2) and fork clear() is ceiling-10, not N

- **Severity:** NIT
- **Location:** §6.13 (line 660), fork non-goals / env allowlist.
- **Quote (§6.13):** "Fork **may** read `SB_DR_FLEET` and `SB_DR_FLEET_SLOTS` env (fleet TTL warning + **admission N**). Quiesce/clear is **always ceiling-10** (`0.lock`…`9.lock`), never `{N-1}`."
- **Defect:** The sentence grants the fork a read of `SB_DR_FLEET_SLOTS` and labels its purpose "admission N". But:
  - §2.2 (line 124) assigns admission to **`search_orchestrator.py`** (SB side): "`fleet-slots.lock/` is a directory ... acquired by `search_orchestrator.py` before each `search` spawn". The fork does not perform admission.
  - §6.3 (line 461) and §6.13 itself state the fork's `cache clear` quiesce/clear set is **always ceiling-10** (`0.lock`…`9.lock`), **never `{N-1}`** — i.e. the fork's only touch of `fleet-slots.lock/` does not use N.
  - No §6.3 / §6.4 / §8 fork behavior reads `SB_DR_FLEET_SLOTS` for any operative purpose. The fork's only `SB_DR_FLEET` use is the `cache_ttl_default_300s` warning (§6.3 / §6.6).
  - So the fork has no operative use for `SB_DR_FLEET_SLOTS`; the "admission N" parenthetical mis-attributes the orchestrator's admission role to the fork, and the grant is superfluous.
- **Operative impact:** none. The fork does not actually perform admission; this is a mis-worded allowlist entry + mis-attribution. No operative contract is broken because §2.2 / §6.3 correctly assign admission and ceiling-10 clear.
- **Why this is not a duplicate:** No ledger row covers the fork `SB_DR_FLEET_SLOTS` env allowlist or the "admission N" attribution. I-8 covers `search serve` Phase 2+ evaluate-only; I-13 covers metrics = usage + run_manifest.
- **Minimal fix (reviewer does not apply; for triage):** drop `SB_DR_FLEET_SLOTS` from the fork's porous env allowlist (the fork has no operative use for it), or reword to "`SB_DR_FLEET_SLOTS` is orchestrator-only; the fork does not read it" — and keep "Quiesce/clear is always ceiling-10, never `{N-1}`" as the fork's only `fleet-slots.lock/` rule.

---

## Clean areas (verified, no new residual)

For transparency on the surfaces re-checked in this pass with no new finding beyond U1/U2:

- §1.2 / §1.4 / §2.2 X union + dedup (I-1, I-5, I-14 applied): one X row, list-valued `provider`/`bucket` `[x, xweb]`, inline supersede notes on historical `must_search:false`, dedup key (tweet id else canonical status URL) — consistent.
- §2.7 step 3 `site:` transitive Serper/Brave consent dependency (I-2 applied) and xweb ban-risk required copy (I-3 applied): present and non-skippable.
- §2.7 step 4 non-Cursor print-URL path (I-4 applied): present.
- §3.4 / §6.13 no binary fallback on missing tag (I-7 applied) and `search serve` Phase 2+ evaluate-only (I-8 applied): present.
- §4.4 / §6.13 ops PAT/secret rotation alerts (I-9 applied): present.
- §6.3 `clear()` deletes future `qN_*` (I-10 applied): "and any future `qN_*` prefix (`q4_*` …)" present.
- §6.3 flat-file vs SQLite trade-off (I-11 applied) and IDN Discourse fail-closed (I-12 applied): present.
- §4.4 metrics = `search usage` + `run_manifest` shards (I-13 applied): present.
- §2.7 / §2.8 official-JSON `site:` fallbacks best-effort degrade (I-15 applied): present.
- §4.1 / §6.3 / §6.12 / §8.4 `--allow-private` in `stable_hash` (I-16/S1 applied): all four locations present with the human-writer → fleet-reader leak direction explicitly covered; fleet-to-fleet fingerprints stay identical.
- Bucket rates (§6.4) vs §2.3 limits: serper 50/s, brave 50/s, github 10/min, gitlab 10/min (per-scope acquire), youtube 100 calendar PT, stackexchange 30/s + backoff, hn 1/s, discourse 0.5/s, reddit 100/min, registries 4 cap/1/s, x 10/min, xweb 2/2-min — internally consistent with §2.3.
- Fingerprint (§6.3): `0x1F` intra-list delimiter, `-d` canonicalization, count/TTL/`--max-chars` exclusions, `--allow-private` inclusion, `CachedEntry.version`, `ttl_secs` `min()` rule, missing-`ttl_secs`→300 distinct fixture — consistent across §4.1 / §6.3 / §6.12 / §8.4.
- Multi-process: globally-unique tmp+rename for `q3_` and `last.json`, `.inflight` single-flight, follower `try_lock` on leader death, quiesce-then-clear `cache_clear_busy` 30s ceiling-10, `fleet-slots.lock/` N-slot FD_CLOEXEC — consistent across §2.2 / §4.1 / §6.3 / §6.4 / §8.2.
- Probe contract (§2.2 / §4.2 / §6.7): `--cache-dir` + `--quota-dir` in `--help`, fork native, `cache_fingerprint_version:"q3"`, `cached_entry_version:1`; `wrong_binary` manifest pin (`channels_attempted=[]`, not stuffed into `channels_skipped_no_consent`) — consistent.
- Collector (§6.5 / §6.10): `Arc<DiagnosticCollector>` on `SearchOpts`, cloned into each `JoinSet::spawn`, `bucket::acquire(..., collector)` 5th arg, trait return type unchanged, cache-hit strips request-scoped warnings — consistent.
- Envelope (§6.6): additive `ErrorResponse.warnings`, no renames, `bucket_fail_closed` + `bucket_fail_closed:{id}` on success or error, `cache_ttl_default_300s` + `doctor_rate_limited` not replayed on hit — consistent.
- GitHub acquire-once-per-invocation (§6.4 / §6.10 / §8.1), GitLab per-scope acquire, registries per-subrequest acquire — consistent.
- Reddit OAuth shared token file under `{quota_dir}/reddit-oauth-token.json` + flock, refresh <60s, one 401 retry, preserved on clear (§6.11 / §6.3 / §8.2) — consistent.

## Notes

- Reviewer is review-only (Policy F). No ACCEPT/REJECT, no triage, no edits to the plan.
- No nested reviewer subagents were spawned. No Fast mode used.
- This is pass 6; it is NOT claimed as a streak — that determination belongs to the ladder orchestrator, not this reviewer.
