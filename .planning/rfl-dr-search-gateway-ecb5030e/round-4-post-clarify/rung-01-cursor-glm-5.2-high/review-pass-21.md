# Review pass 21 — RFL round-4-post-clarify, rung 1 (Cursor GLM 5.2 High)

- model: glm-5.2-high
- Plan: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- Confirmed freeze SHA-256: `916d87f52b25688f7953c76c89b96802d9438eb8da537a8c16b927b98b2ee138` (verified via `shasum -a 256` before review; matches pinned freeze).
- Encoder brief used: `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-01-cursor-glm-5.2-high/brief-review-21.md`, emitted by `python3 scripts/review-fix-ladder.py --write-review-brief --run-dir .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify`.
- Mode: **Policy G pack review** (residual-only). Filed all valid residuals at all severities (HIGH / MED / LOW / NIT). Did **not** re-report ledger rows I-1…I-44 / AH1 unless a residual defect remained in this freeze. Did **not** stop after one class or after AH1.

## Method

1. Graphify CLI orientation first (`graphify query` on the residual families: clear() rosters, qN_*, clap cache-ttl, quota-dir, X-union dedup, doctor, reddit oauth, fingerprint / `--allow-private`, acquire fail-closed, markdown sub-bullet line breaks, L85 section cites). Did not use MCP `query_graph` for retrieval.
2. Re-read the plan end-to-end (bird then ant) via `ctx_execute` line-numbered dumps over the true line split (long lines): §1.1, §1.2 (L50–86), §1.3, §1.4 (L95–103), §2.1–§2.8 (L104–277), §3 (L278–325), §4.1–§4.4 (L326–345), §5 (L346–359), §6.1–§6.13 (L360–667), §7 (L668–717), §8.1–§8.4 (L719–783). Native Read only on the generated numbered scratch file (not the durable plan); no plan edit.
3. Cross-checked §1.2 locked decisions against §2/§3/§4/§5/§6/§8 for every residual family.
4. Spot-checked latest ledger row AH1 / I-44: §1.2 L85 rollup cites `§4.3 X-union dedup test` (not §3); test substance is in §4.3 (L339). Then scanned the rest of the plan for further residuals — did not stop after AH1.
5. Targeted grep/regex spot-checks via `ctx_execute` (ceiling-10 vs `{N-1}`; q4_ fixture; `last.json.tmp.*` orphan; reddit-oauth-token.lock; `--allow-private`; `SEARCH_KEYS_REDDITSECRET` vs forbidden `SEARCH_KEYS_REDDIT_SECRET`; `must_search: false` superseded markers; §4.3 vs §3 X-union cite; §6.3/§6.4 sub-bullet line breaks).

## Ledger reconciliation (I-1…I-44 / AH1 — all ACCEPT/resolved at this SHA)

Every ledger row was re-verified against the section(s) that reference its family. All are resolved and internally consistent in this freeze:

- **I-1 (F1) X-union dedup in SB orchestrator** — §1.4 L101 (dedup contract, `search_orchestrator.py`), §4.3 L339 (test), §1.2 L85 cites §4.3. ✓
- **I-2 (F2) site: rows require Serper/Brave consent** — §2.7 L219. ✓
- **I-3 (F3) xweb ban-risk required copy at init** — §2.7 L218. ✓
- **I-4 (F4) Non-Cursor init: URLs + search config** — §2.7 L220. ✓
- **I-5 (F5) One X row; list provider/bucket** — §2.2 L120, §2.5 L178, §4.3 L339. ✓
- **I-6 (F6) last.json clobber** — §6.2 L420. ✓
- **I-7 (F7) No binary fallback if git tag missing** — §3.4 L324. ✓
- **I-8 (F8) search serve Phase 2+ evaluate only** — §6.13 L663. ✓
- **I-9 (F9) Ops alerts PAT/secret rotation** — §4.4 L344. ✓
- **I-10 (F10) cache clear deletes future qN_*** — §4.1 L330, §5 L351, §6.3 L463, §8.1 L738, §8.4 L775. ✓
- **I-11 (F11) Flat-file vs SQLite acknowledged** — §6.3 L434. ✓
- **I-12 (F12) IDN Discourse known limit** — §6.13 L653, §6.4 L483. ✓
- **I-13 (F13) Metrics = usage + run_manifest** — §4.4 L344. ✓
- **I-14 (R1) Inline superseded on historical X must_search:false** — §1.2 (12 inline markers). ✓
- **I-15 (R2) Official-JSON site: fallbacks best-effort degrade** — §2.7 L219. ✓
- **I-16 (S1) --allow-private in cache fingerprint** — §6.3 L458, §4.1 L330, §6.12 L636. ✓
- **I-17 (U1) --cache-ttl Phase 1 fork ADD** — §1.2 L85, §2.2 L124, §6.2 L414. ✓
- **I-18 (U2) SB_DR_FLEET_SLOTS orchestrator-only** — §6.13 L664, §1.2 L73. ✓
- **I-19 (V1) src/doctor.rs on §8.1/§8.4 Modify** — §8.1 L745, §8.4 L781. ✓
- **I-20 (W1) Human --quota-dir default** — §6.2 L413, §4.4 L344, §6.12 L643. ✓
- **I-21 (W2) --allow-private last stable_hash field** — §6.3 L458. ✓
- **I-22 (W3) -d canonicalized before augment_query** — §6.3 L458. ✓
- **I-23 (W4) Reddit refresh double-checks TTL under lock** — §6.11 L624. ✓
- **I-24 (W5) clap -p values drift-guard** — §6.12 L641. ✓
- **I-25 (W6) Absent reddit lock unlockable** — §6.12 L637, §6.3 L463. ✓
- **I-26 (W7) Brave bucket acquire test in §6.12** — §6.12 L642. ✓
- **I-27 (X1) §4.4 doctor risk shared fleet quota** — §4.4 L344. ✓
- **I-28 (X2) --max-chars emit/truncation test in §6.12** — §6.12 L636. ✓
- **I-29 (X3) doctor.rs behavior tests in §6.12** — §6.12 L643. ✓
- **I-30 (Y1) §1.2 H1 SB_DR_FLEET_SLOTS fork-read superseded** — §1.2 L73. ✓
- **I-31 (AA1) §6.12 serper/x acquire tests** — §6.12 L642. ✓
- **I-32 (AA2) Human-run cache_ttl_default_300s negative test** — §6.12 L647. ✓
- **I-33 (AB1) §3 X-union dedup test → §4.3** — §4.3 L339. ✓
- **I-34 (AB2) clap --cache-ttl in --help** — §6.12 L640. ✓
- **I-35 (AB3) Reddit OAuth no-stampede test** — §6.12 L645. ✓
- **I-36 (AB4) clear() removes future qN_*** — §6.3 L463, §6.12 L636. ✓
- **I-37 (AC1) clear() removes orphaned last.json.tmp.*** — §6.3 L463, §6.12 L636, §8.4 L783. ✓
- **I-38 (AC2) Held reddit lock drives cache_clear_busy** — §6.12 L637, §6.3 L463. ✓
- **I-39 (AC3) Token-endpoint does not consume reddit search bucket** — §6.11 L624, §6.12 L645. ✓
- **I-40 (AD1) clear() preserves query-cache .gitignore** — §4.1 L330, §6.3 L463. ✓
- **I-41 (AE1) §4.1/§5/§8.1/§8.4 clear() preserve rosters include .gitignore** — §4.1 L330, §5 L351, §8.1 L738, §8.4 L775. ✓
- **I-42 (AF1) §4.1/§5/§8.1/§8.4 clear() delete-set rosters include future qN_*** — §4.1 L330, §5 L351, §8.1 L738, §8.4 L775. ✓
- **I-43 (AG1) §6.3/§6.4 markdown sub-bullets on own lines** — §6.3 L446–464, §6.4 L466–488 (verified each sub-bullet starts on its own line). ✓
- **I-44 / AH1 §1.2 L85 cites §4.3 for X-union dedup test** — §1.2 L85 reads `§4.3 X-union dedup test`; regex confirms `§4.3 X-union`=1 and `§3 X-union`=0. ✓

## Result

**CLEAN.**

Zero new valid residuals beyond the ledger. No `### AI*` finding headings are filed.

The re-read found no defect beyond the 44 ledger rows + AH1 that are already ACCEPT/resolved at this freeze SHA. Every residual family the brief named is internally consistent across all sections that reference it. The `{N-1}.lock` references (8) are all in the admission try-lock context (`Admission still try-locks 0…{N-1} only`), which is the locked design and is distinct from the ceiling-10 quiesce/clear barrier — not a residual. The 4 `SEARCH_KEYS_REDDIT_SECRET` occurrences are all in forbid-contexts (`must not` / `never` / `do not document`), consistent with `redditsecret` (no underscore) being the contract. AH1 is confirmed resolved: §1.2 L85 cites §4.3 (not §3) and the X-union dedup test substance is in §4.3 L339.

## Leftover / borderline-not-filed

None. No borderline items were withheld.

## Did not APPLY

Review-only. No triage, no APPLY, no plan edit, no commit, no git branch switch.
