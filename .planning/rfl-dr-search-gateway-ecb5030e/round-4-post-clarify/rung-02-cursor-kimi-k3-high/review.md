# Rung 2 review — Cursor Kimi K3 High (Policy G pack)

- `model: kimi-k3-high`
- Freeze SHA-256 confirmed via `shasum -a 256`: `916d87f52b25688f7953c76c89b96802d9438eb8da537a8c16b927b98b2ee138` (matches pin; reviewed `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md` only).
- Encoder brief used: `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-02-cursor-kimi-k3-high/brief-review.md` (emitted by `python3 scripts/review-fix-ladder.py --write-review-brief --run-dir .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify`). Obeyed in full: residual-only = no ledger re-reports (I-1…I-44), all severities filed, nits filed, did not stop after one class.
- Method: Graphify CLI orientation (`graphify query` over clear() rosters / `qN_*` / fleet-slots quiesce / reddit lock / fingerprint families — surfaced only rung-1 ledger nodes W6/I-25, AC2/I-38, S1/I-16, AE1/I-41, i.e. already-encoded), then full end-to-end re-read of the plan (783 lines, bird then ant) via `ctx_execute_file` over the true line split, cross-checking §1.2 vs §2/§3/§4/§5/§6/§8. No ledger row re-filed; all findings below are new residuals at this freeze.

**Verdict: NOT CLEAN** — 6 new residuals (0 HIGH, 0 MED, 1 LOW, 5 NIT).

### K1
- **Severity:** NIT
- **Cite:** §6.4 L476 — "`serper` — capacity 50, refill 50/s (Starter 50 QPS)… Starter **2,500/day** pack total is **ops runbook only**".
- **Defect:** Misstates the Serper quota facts locked in §2.8 L247 ("**2,500 free queries**; Starter **$1.00/1k** / 50k credits / 50 QPS"). The 2,500 figure is the one-time free tier, not "Starter", and it is not "/day". Internal inconsistency between §6.4 and §2.8 on the same numbers.
- **Not a ledger re-report:** no I-row covers Serper pack/quota figures (I-9 is PAT/secret rotation alerts; I-13 is metrics scope).
- **Fix:** reword §6.4 to "free 2,500 queries / Starter 50k credits are ops runbook only (PRD §4.4)".

### K2
- **Severity:** NIT
- **Cite:** §3.2 L304 — "Partial keys → `partial` + `providers_missing`".
- **Defect:** Backtick-quoted status literal `partial` does not exist; §6.6 L530 locks `ResponseStatus: success | partial_success | no_results`, and every other section (§6.10 L617, §8.3 L764, §6.12 L647) uses `partial_success`.
- **Not a ledger re-report:** no I-row covers the §3.2 runtime-flow status literal.
- **Fix:** change `partial` to `partial_success` in §3.2.

### K3
- **Severity:** LOW
- **Cite:** §2.7 step 4 L220 — "write secrets into `search config set keys.*` (stdin `-`) and env".
- **Defect:** "and env" contradicts step 7 L228 ("Keys stay in search-cli `config.toml` 0600") and §1.4 L99 ("workers never see provider keys"). As written it is ambiguous whether keys are persisted into a shell environment/profile, which would violate the 0600-config-only storage lock and risks leaking keys into worker environments.
- **Not a ledger re-report:** no I-row covers the §2.7 step-4 write path (I-4 is the non-Cursor print-URL path).
- **Fix:** drop "and env", or qualify it as process-local env for the init session only, never persisted.

### K4
- **Severity:** NIT
- **Cite:** §2.2 L124 — probe requires "`search agent-info --json` listing at least one fork native (`stackexchange`, `github`, `hn`, `discourse`, `gitlab`, `youtube`, `registries`, `reddit`)".
- **Defect:** The enumerated fork-native set omits `x` and `xweb`, which ship in the same `v0.9.0-sb.1` tag the Phase 3 probe gates on (§5 Phase 2 L352; §6.12 L641 drift-guard requires `x,xweb` in agent-info). Functionally "at least one" still passes, but the enumeration is presented as the fork-native set and is inconsistent with §6.12/§5.
- **Not a ledger re-report:** I-17 covers `--cache-ttl` not being a `wrong_binary` discriminator; no row covers the probe's native-id enumeration.
- **Fix:** add `x`, `xweb` to the parenthetical (or mark it "e.g.").

### K5
- **Severity:** NIT
- **Cite:** §3.4 L316–L317 — `cargo install --git … --tag v0.9.0-sb.1 --locked` followed by `export SB_SEARCH_BIN=/usr/local/bin/search`.
- **Defect:** `cargo install` drops the binary in `~/.cargo/bin/search`, not `/usr/local/bin/search`; the example pairs the maintainer install path with a binary location it does not produce. §3.4 "Consume" also shows only the maintainer `cargo install --git` path while Q1/Q2 (§1.2 L52) locks GH Release binaries as the DR-host consume path.
- **Not a ledger re-report:** I-7 is "no binary fallback if git tag missing" — a different clause; no row covers the install-path/binary-location mismatch.
- **Fix:** point `SB_SEARCH_BIN` at `$(cargo install --root …)` / `~/.cargo/bin/search`, or show the GH Release binary install as the DR-host path.

### K6
- **Severity:** NIT
- **Cite:** §4.4 L344 — X alert: "X credit 0 → stamp official `-p x` missing and fall back to xAI then dedicated `site:x.com`".
- **Defect:** The X-credit-0 fallback chain omits the `-p xweb` leg. The locked chain everywhere else is official `-p x` → `-p xweb` → xAI `-m social` → dedicated `site:x.com` (§1.2 L54, §2.5 L178, §5 L358 "union of xweb / xAI / dedicated `site:x.com`").
- **Not a ledger re-report:** I-1/I-5 cover X dedup and the one-row catalog encoding; no row covers the §4.4 ops-alert chain completeness.
- **Fix:** "fall back to the remaining legs (xweb / xAI / dedicated `site:x.com`)".

## Leftover / borderline-not-filed

- **§7 mermaid (L690–L693):** quota subgraph omits the `reddit-oauth-token.json` node that lives under `SEARCH_QUOTA_DIR` — illustrative diagram, not normative text; not filed.
- **§6.12 L646 vs §5 Phase 1 L351:** the `config.example.toml` test in §6.12 includes X keys without phase-gating while §5 Phase 1 acceptance lists only the Phase 1 key set — §6.12 is the cumulative fork test list and §5 phases acceptance per phase; not a contradiction; not filed.
- **§2.3 L139 fingerprint summary** omits `--allow-private` — summary prose ("domains/filters"); the normative §4.1/§6.3/§8.4 texts all carry the `--allow-private` field (I-16/I-21 resolved); not filed.
- **§2.2 L125 "SB repo `.gitignore`"** is narrower than "researched project root" — the inner `{SEARCH_CACHE_DIR}/.gitignore` (`*` + `!.gitignore`) covers the general case and §5 Phase 3 matches; not filed.
