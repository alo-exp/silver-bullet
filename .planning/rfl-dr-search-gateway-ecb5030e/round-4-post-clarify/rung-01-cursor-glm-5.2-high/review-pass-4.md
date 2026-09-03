model: glm-5.2-high

# Review pass 4 — Policy F re-review (streak 1/2)

- Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- SHA-256 verified: `ddc71a73810355206f57fd4267358478cea6e33622b7ae7c0617444a90f8b2a9` (matches brief)
- Scope: residual-only (Policy G). Ledger rows I-1 … I-15 are ACCEPT+applied and are NOT re-reported below.
- Method: graphify query (`DR search gateway plan X xweb Serper consent`) + full bird's-eye (§1–§8 headings) then ant's-eye (every section, line-by-line). 779 lines / ~158 KB read in full via sandbox.

## Result: NOT CLEAN — 1 new residual

One new residual found that is not an exact duplicate of any ACCEPT+applied ledger row.

---

### S1 — `--allow-private` omitted from cache fingerprint leaks private-network results from a human writer into fleet reader cache hits

- **Severity:** LOW
- **Location:** §6.3 "Cache — layout, fingerprint, TTL, multi-process" (Phase 1 target, fingerprint `stable_hash` feeds); §4.1; §6.12 test list; §8.4 item 2.
- **Quote (§6.3):** "Do not put `--max-chars` or `--allow-private` in the hash (missing High+ item 10 M-4): `--max-chars` truncation is applied at **emit** … `--allow-private`: fleet **never** passes it (default false)."
- **Defect:** The fingerprint omits `--allow-private`, so a `q3_{hash}` entry is shared between a writer that passed `--allow-private` and a reader that did not. The plan's rationale ("fleet never passes it (default false)") only covers the **fleet-as-writer** direction. It does **not** cover the **human-as-writer → fleet-as-reader** direction. A human running `search … --allow-private --cache-dir "$SEARCH_CACHE_DIR"` in the same project cache dir the fleet uses writes an entry whose `response` may contain private-network URLs/snippets (the whole point of `--allow-private` is to admit private-IP / local-network results the default refuses). A later fleet invocation (no `--allow-private`) with the same query/providers/domains hits that entry and emits those private-network results to DR workers — a cross-contamination leak the fleet's `default false` was meant to prevent. The same shared `--cache-dir` is explicitly in scope (§6.2 `--last` edge note documents the human-reuses-fleet-cache-dir surprise; §4.1 cache is shared across 5–10 fleet processes and any human in that project).
- **Why this is not a duplicate:** I-6 (F6) covers `last.json` clobber when a human reuses the fleet cache dir — a *write* collision on `last.json`. S1 is a *read* contamination via the `q3_` fingerprint, a different mechanism and a different file (`q3_{hash}.json`, not `last.json`). No ledger row covers the `--allow-private` fingerprint field.
- **Minimal fix (reviewer does not apply; for triage):** either (a) include `--allow-private` in `stable_hash` (one extra boolean field; breaks no fleet hit because fleet always false), or (b) keep it out of the hash but reject a cache *hit* when the reader did not pass `--allow-private` and the stored entry was written with it (store an `allow_private: bool` on `CachedEntry`; treat as a hard miss on mismatch), or (c) document the leak as accepted and add a test that a human `--allow-private` entry does not satisfy a fleet reader (currently the §6.12 test list asserts the opposite intent — "fingerprint identical" across TTL — and never asserts `--allow-private` isolation).

---

## Clean areas (verified, no residual)

For transparency on the surfaces re-checked in this pass with no new finding:

- §1.2 / §1.4 / §2.2 X union + dedup (I-1, I-5, I-14 applied): one X row, list-valued `provider`/`bucket`, inline supersede notes on historical `must_search:false` are consistent.
- §2.7 step 3 `site:` transitive Serper/Brave consent dependency (I-2 applied) and xweb ban-risk required copy (I-3 applied): present and non-skippable.
- §2.7 step 4 non-Cursor print-URL path (I-4 applied): present.
- §3.4 / §6.13 no binary fallback on missing tag (I-7 applied) and `search serve` Phase 2+ evaluate-only (I-8 applied): present.
- §4.4 / §6.13 ops PAT/secret rotation alerts (I-9 applied): present.
- §6.3 `clear()` deletes future `qN_*` (I-10 applied): "and any future `qN_*` prefix (`q4_*` …)" present.
- §6.3 flat-file vs SQLite trade-off (I-11 applied) and IDN Discourse fail-closed (I-12 applied): present.
- §4.4 metrics = `search usage` + `run_manifest` shards (I-13 applied): present.
- §2.7 / §2.8 official-JSON `site:` fallbacks best-effort degrade (I-15 applied): present.
- Bucket rates (§6.4) vs §2.3 limits: serper 50/s, brave 50/s, github 10/min, gitlab 10/min (per-scope acquire), youtube 100 calendar PT, stackexchange 30/s + backoff, hn 1/s, discourse 0.5/s, reddit 100/min, registries 4 cap/1/s, x 10/min, xweb 2/2-min — all internally consistent with §2.3.
- Fingerprint (§6.3): `0x1F` intra-list delimiter, `-d` canonicalization, count/TTL/`--max-chars`/`--allow-private` exclusions, `CachedEntry.version`, `ttl_secs` `min()` rule, missing-`ttl_secs`→300 distinct fixture — all consistent across §4.1 / §6.3 / §6.12 / §8.4.
- Multi-process: globally-unique tmp+rename for `q3_` and `last.json`, `.inflight` single-flight, follower `try_lock` on leader death, quiesce-then-clear `cache_clear_busy` 30s ceiling-10, `fleet-slots.lock/` N-slot FD_CLOEXEC — consistent across §2.2 / §4.1 / §6.3 / §6.4 / §8.2.
- Probe contract (§2.2 / §4.2): `--cache-dir` + `--quota-dir` in `--help`, fork native, `cache_fingerprint_version:"q3"`, `cached_entry_version:1`; `wrong_binary` manifest pin (`channels_attempted=[]`, not stuffed into `channels_skipped_no_consent`) — consistent.
- Collector (§6.5 / §6.10): `Arc<DiagnosticCollector>` on `SearchOpts`, cloned into each `JoinSet::spawn`, `bucket::acquire(..., collector)` 5th arg, trait return type unchanged, cache-hit strips request-scoped warnings — consistent.
- Envelope (§6.6): additive `ErrorResponse.warnings`, no renames, `bucket_fail_closed` + `bucket_fail_closed:{id}` on success or error — consistent.

## Notes

- Reviewer is review-only (Policy F). No ACCEPT/REJECT, no triage, no edits to the plan.
- No nested reviewer subagents were spawned. No Fast mode used.
- This is pass 4; it is NOT claimed as a streak — that determination belongs to the ladder orchestrator, not this reviewer.
