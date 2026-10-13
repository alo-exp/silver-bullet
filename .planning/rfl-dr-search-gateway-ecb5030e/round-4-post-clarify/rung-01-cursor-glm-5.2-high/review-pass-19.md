# Review pass 19 — Policy G pack (residual-only)

- model: glm-5.2-high
- rung: round-4-post-clarify / rung-01-cursor-glm-5.2-high
- reviewer: Cursor GLM 5.2 High (sb-glm-5-2-high)
- mode: review-only (no triage, no APPLY, no plan edit, no commit, no branch switch)

## Freeze confirmation

- Plan: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- Pinned SHA-256: `e8d4de532ef111fac2dd44ca7fce43e9345e970a3a6a320a09492e1944329c2e`
- `shasum -a 256` output: `e8d4de532ef111fac2dd44ca7fce43e9345e970a3a6a320a09492e1944329c2e  /Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- SHA matches the pinned freeze. Review proceeds on this digest only.

## Encoder brief

Used the encoder-produced brief in full:
`.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-01-cursor-glm-5.2-high/brief-review-19.md`, emitted by `python3 scripts/review-fix-ladder.py --write-review-brief --run-dir .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify`.

Policy G (brief + `skills/silver-review-fix-ladder/SKILL.md` L163–L181) restated:
- Residual-only = do **not** re-report ledger rows I-1…I-42; file **all** valid residuals at this freeze SHA, **all** severities (HIGH/MED/LOW/NIT). Valid nits must be filed.
- CLEAN only if nothing valid remains beyond the ledger.
- FORBIDDEN: stopping after one class, MED-only, or skipping valid nits.

## Method (Policy G pack)

1. Graphify CLI orientation first (`graphify query` on the residual families: clear() rosters, qN_* future sweep, clap cache-ttl, quota-dir, X-union dedup, doctor, reddit oauth, fingerprint / --allow-private, acquire fail-closed). Did **not** use MCP `query_graph` for retrieval.
2. Re-read the plan end-to-end (bird then ant). The plan is 780 raw lines: YAML frontmatter lines 1–36, markdown body lines 38–780 (note: the native Read tool skips the frontmatter, so Read-line N = raw-line N+37; citations below use **raw** line numbers matching the brief's L85/L330/L351/L736/L773 references). Used `ctx_execute_file` over the true line split because several body lines are 1400–5720 chars long and native Read truncates at ~4k tokens.
3. Cross-checked §1.2 locked decisions (raw L65–L85, the full ledger incl. the round-4-post-clarify rung-1 ACCEPT at L85) against §2.1–2.8, §3, §4.1–4.4, §5, §6.1–6.13, §7, §8.1–8.4.
4. Spot-checked the latest ledger row (AF1 / I-42) at L85, L330, L351, L736, L773, then scanned the rest of the plan for **further** residuals. Did **not** stop after AF1.
5. Did **not** re-file I-1…I-42; no ledger row was re-reported. Verified each is encoded in the operative sections (see coverage map below).

## Ledger coverage map (verified encoded — not re-filed)

| Ledger IDs | Family | Encoded at (raw lines) |
|---|---|---|
| I-1..I-5 (F1–F5) | X dedup / site: consent / xweb copy / non-Cursor init / one X row | §1.4 L101, §2.5 L178, §2.7 L218, §2.8 L265–266, §1.3 L90 |
| I-6..I-9 (F6–F9) | last.json clobber / no binary fallback / search serve P2+ / ops alerts | §6.2 L420, §3.4 L324, §6.13 L661, §4.4 L344 |
| I-10..I-13 (F10–F13) | clear() future qN_* / flat-file vs SQLite / IDN / metrics | §4.1 L330, §6.3 L434/L462, §6.4 L481, §4.4 L344 |
| I-14..I-16 (R1,R2,S1) | inline superseded / official-json degrade / --allow-private in hash | §1.4 L101, §2.5 L169, §6.3 L458 |
| I-17..I-19 (U1,U2,V1) | --cache-ttl fork ADD / SB_DR_FLEET_SLOTS orch-only / doctor.rs Modify | §6.2 L414, §6.13 L662, §6.1 L369, §8.1 L743, §8.4 L779 |
| I-20..I-26 (W1–W7) | quota-dir default / --allow-private last field / -d canonicalize / reddit TTL under lock / clap -p drift / absent reddit lock / brave acquire test | §6.2 L413, §6.3 L458, §6.3 L459, §6.11 L622, §6.12 L639, §6.12 L635, §6.12 L640 |
| I-27..I-29 (X1–X3) | §4.4 doctor fleet quota / --max-chars test / doctor.rs behavior tests | §4.4 L344, §6.12 L634, §6.12 L641 |
| I-30..I-32 (Y1,AA1,AA2) | SB_DR_FLEET_SLOTS fork-read superseded / serper+x acquire / cache_ttl_default_300s negative | §6.13 L662, §6.12 L640, §6.12 L645 |
| I-33..I-36 (AB1–AB4) | X-union dedup test / clap --cache-ttl in --help / reddit no-stampede / clear() future qN_* | §4.3 L339, §6.12 L638, §6.12 L643, §6.12 L634 |
| I-37..I-39 (AC1–AC3) | clear() orphaned last.json.tmp.* / held reddit lock busy / token-endpoint not reddit bucket | §6.12 L634, §6.12 L635, §6.12 L643 |
| I-40..I-42 (AD1,AE1,AF1) | clear() preserves .gitignore / §4.1+§5+§8.1+§8.4 preserve rosters / §4.1+§5+§8.1+§8.4 delete-set future qN_* | §4.1 L330, §5 L351, §6.3 L462, §6.12 L634, §8.1 L736, §8.4 L773 |

All five `clear()` rosters (§4.1 L330, §5 L351, §6.3 L462, §8.1 L736, §8.4 L773) and the §6.12 L634 test consistently include: `q3_*` (json+inflight) + leftover `q2_*` + **future `qN_*` prefix (`q4_*` …)** + `last.json` + **orphaned `last.json.tmp.*`** + `fleet-slots.lock/` ceiling-10 contents, and **preserve** `{quota_dir}/buckets/` + `{quota_dir}/reddit-oauth-token.json` + query-cache `.gitignore`. No roster omits the future `qN_*` sweep or the `.gitignore` preserve.

## Verdict: NOT CLEAN

One new residual finding (AG1, NIT). All ledger rows I-1…I-42 are encoded; no ledger row was re-filed.

---

### AG1 — NIT — Two markdown sub-bullets run-on into the preceding bullet (rendering defect)

- **Severity:** NIT
- **Cite 1:** §6.3, raw L460 — the `- **Phase 1 CachedEntry:**` sub-bullet is embedded mid-line after `… This does **not** relax the argv lock.` instead of starting on its own line. The literal ` - **Phase 1 `CachedEntry`:**` appears at char offset 444 of L460, preceded by `lock.` (no newline).
- **Cite 2:** §6.4, raw L470 — the `- **Malformed/truncated `{id}.json`:**` sub-bullet is embedded mid-line after `… (do **not** start at `tokens = 0.0`).` instead of starting on its own line.
- **Why not a ledger re-report:** Neither I-1…I-42 nor any prior review-pass finding covers markdown line-break / run-on formatting. The ledger items address technical contract gaps (clear() rosters, fingerprint fields, acquire fail-closed, etc.); this is a distinct presentation defect class. The technical content of both sub-bullets is correct and complete — only the line break separating the sub-bullet from its predecessor is missing, so each renders as inline text within the preceding bullet rather than as its own bullet.
- **Impact:** Cosmetic / rendering. The `Phase 1 CachedEntry` schema (`{ version, timestamp, count, ttl_secs, response }`) and the `Malformed/truncated {id}.json` fail-closed rule still parse correctly as prose, but lose their visual bullet separation, making the spec harder to skim for an implementer.
- **One-line fix:** Insert a newline before each stray ` - **…` on L460 and L470 so each sub-bullet starts on its own line (e.g. `…argv lock.\n- **Phase 1 CachedEntry:**…` and `…tokens = 0.0`).\n- **Malformed/truncated `{id}.json`:**…`).

---

## Leftover / borderline-not-filed

- **AG1 borderline note:** Both run-on defects are purely cosmetic markdown rendering nits with no technical-content impact. Filed under Policy G's "valid nits must be filed" rule, but flagged as low-confidence / borderline — triage may REJECT if the bar for this rung excludes presentation-only nits. If that bar applies, the plan is effectively CLEAN of technical residuals.
- No other residuals found. Specifically checked and cleared (no defect beyond ledger): §6.12 L644 `config.example.toml` test naming `SEARCH_KEYS_X` / `SEARCH_KEYS_XWEB_GUEST` + `X_BEARER_TOKEN` / `X_GUEST_TOKEN` / `XWEB_COOKIES` is consistent with §6.8 L570 and §8.4 L775 (X keys are Phase 2; §5 Phase-1 acceptance L351 is the Phase-1 subset — no contradiction, just phased); reddit `redditsecret` / `SEARCH_KEYS_REDDITSECRET` naming consistent across §6.8 L569, §6.12 L642, §8.4 L775; youtube calendar-reset + fail-closed-for-the-day consistent across §6.4 L471, §8.2 L755; `--max-chars` not-in-hash + emit-truncation consistent across §6.3 L458, §6.12 L634; `cache_clear_busy` machine-wide + `{quota_dir}` suggestion consistent across §2.2 L125, §4.4 L344, §6.3 L462.

## Return to parent

- Verdict: **NOT CLEAN**
- Findings: AG1 (NIT) — two markdown run-on sub-bullets at §6.3 L460 and §6.4 L470
- SHA: `e8d4de532ef111fac2dd44ca7fce43e9345e970a3a6a320a09492e1944329c2e` (confirmed)
- Leftover: AG1 is borderline cosmetic; no other residuals. No APPLY performed.
