# Review pass 20 — Policy G pack review (residual-only)

- model: glm-5.2-high
- rung: round-4-post-clarify / rung-01-cursor-glm-5.2-high
- plan: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- Confirmed SHA-256: `146e0ccba885dee360a1874d471b6a8f0276c2626bfcfcc8a6668ea9e2ec3c3e` (matches pinned freeze; `shasum -a 256` verified before review)
- Encoder brief used: `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-01-cursor-glm-5.2-high/brief-review-20.md`, emitted by `python3 scripts/review-fix-ladder.py --write-review-brief --run-dir .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify`
- Method: **Policy G pack review** — re-read the plan end-to-end (bird then ant); filed **all** valid residuals at the freeze SHA across all severities (HIGH / MED / LOW / NIT); did **not** stop after one class, did not go MED-only, did not skip valid nits. Did not re-file ledger rows I-1…I-43 / AG1; only new residuals beyond the ledger are reported below.
- Tools: Graphify CLI orientation first (`graphify query` on residual families); `ctx_execute` over the true line split for plan analysis; native Read not used to edit (no edits made). agentmemory `memory_save` captured this hop.

## Verdict: NOT CLEAN

One new residual found (NIT). All 43 ledger rows (I-1…I-43) and AG1 are uniformly applied across §1.2 / §2 / §3 / §4 / §5 / §6 / §8; the plan is highly internally consistent at this freeze.

### AH1 — NIT — §1.2 L85 rollup cites wrong section for the X-union dedup test

- Cite: §1.2, line 85 (the "RFL round 4 post-clarify rung 1 ACCEPTs" rollup bullet) — clause "`§3 X-union dedup test`".
- Defect: The rollup claims the X-union dedup test lives in §3. §3 (Architecture, lines 278–325: mermaid + §3.1 repo split + §3.2 runtime + §3.3 provider drop-in + §3.4 consume) contains **no** dedup test. The X-union dedup test actually lives in **§4.3** (Tests), line 339: "X-union dedup test: two/three X-leg envelopes sharing a tweet id or canonical `x.com`/`twitter.com` status URL (plus an xAI hit carrying the id) emit one row; results without id/URL stay undeduped and recorded." The dedup contract itself is in §1.4 L101. So the rollup's `§3` reference is a citation typo (should be `§4.3`).
- Why not a ledger re-report: Ledger row I-33 ("§3 X-union dedup test (AB1)", ACCEPT, resolved) was about **adding** the X-union dedup test. The test substance is present and correct (in §4.3). This finding is a distinct, new defect — the **citation** in the §1.2 rollup points to the wrong section — not a re-report of "test missing."
- Severity: NIT. The operative spec (§4.3) is correct; only the §1.2 historical rollup summary mis-cites the section. A reader following the rollup's `§3` pointer finds no test.
- One-line fix: In §1.2 L85, change "`§3 X-union dedup test`" → "`§4.3 X-union dedup test`".

## Leftover / borderline-not-filed

- **`q2_` delete-set wording divergence (not filed):** §6.3 L463 writes "leftover `q2_*.json`" (with `.json` suffix) while §4.1 L330, §5 L351, §6.12 L636, §8.1 L738, and §8.4 L775 all write "leftover `q2_*`" (bare prefix). Per §6.3 L439, upstream cache files are only ever `q2_{16 hex FNV-1a}.json` — there is no `q2_` inflight or non-`.json` artifact. Therefore `q2_*` and `q2_*.json` match the identical file set; the divergence is cosmetic with **zero behavioral difference** and unambiguous intent (remove leftover q2_ files). Not filed as a residual — no defect in the operative contract.

## Consistency checks performed (all PASS at this freeze)

- `clear()` delete-set rosters uniform across §4.1 / §5 / §6.3 / §6.12 / §8.1 / §8.4: `q3_*` (json+inflight) + leftover `q2_*` + future `qN_*` (`q4_*` …) + `last.json` + orphaned `last.json.tmp.*` + `fleet-slots.lock/` ceiling-10 contents; preserve `{quota_dir}/buckets/`, `{quota_dir}/reddit-oauth-token.json`, query-cache `.gitignore` (I-10 / I-36 / I-37 / I-40 / I-41 / I-42).
- AG1 verified: §6.3 L461 `Phase 1 CachedEntry` and §6.4 L472 `Malformed/truncated {id}.json` each start on their own lines (no run-on into preceding bullet).
- §1.2 L85 rollup cross-checked vs §2/§3/§4/§6/§8 for: clap `--cache-ttl` in `--help` (§6.12 L640), reddit no-stampede (§6.11 L624, §6.12 L645), `clear()` future `qN_*` (§6.3 L463, §6.12 L636), `--allow-private` last `stable_hash` field (§6.3 L458), `-d` canonicalized before `augment_query` (§6.3 L458), `--quota-dir` human default `~/.config/silver-bullet/search-quota/` (§6.2 L413, §4.4 L344), `SB_DR_FLEET_SLOTS` orchestrator-only (§6.13 L664), `src/doctor.rs` on §8.1/§8.4 Modify checklists (§8.1 L745, §8.4 L781), `--max-chars` emit-truncation not in fingerprint (§6.3 L458, §6.12 L636), brave/serper/x/xweb acquire (§6.4 L485–488, §6.12 L642), token-endpoint not consuming reddit search bucket (§6.11 L624), held/absent reddit lock and `cache_clear_busy` (§2.2 L125, §6.12 L637). All consistent.
- X catalog encoding one row `provider/bucket: [x, xweb]` (§2.2 L120, §2.5 L178, §4.3 L339) consistent.
- Path-scoped Method B `-q` carries `site:host/path`, omit `-d` (§2.2 L120, §2.5 L189, §6.9 L595) consistent.
- Malformed `{id}.json` fail-closed `tokens = 0` + `updated_unix_ms = now` unconditionally, no refill/calendar, `bucket_fail_closed` + `bucket_fail_closed:{id}` (§6.4 L472–474, §6.6 L525, §8.2 L757) consistent.
