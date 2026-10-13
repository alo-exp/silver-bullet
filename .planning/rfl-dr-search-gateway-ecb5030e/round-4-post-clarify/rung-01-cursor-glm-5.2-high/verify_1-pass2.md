model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 1/2 (`rung_1_verify_1`, post Policy F R1+R2 APPLY)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `ddc71a73810355206f57fd4267358478cea6e33622b7ae7c0617444a90f8b2a9` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "DR search gateway plan X must_search superseded consent site" --budget 2000` (226 nodes; plan is PRD not indexed as source — oriented via direct read)  
**APPLY ref:** [APPLY.md](APPLY.md) · **Prior verify:** [verify_1.md](verify_1.md) (SHA `265040b0…`, pre–Policy F R1+R2)

## Verdict

**VERIFY_PASS** — R1 and R2 APPLY edits are present; F1–F13 round-4 ACCEPT content remains intact at the pinned SHA.

## R1 — Historical §1.2 X `must_search: false` ledger superseded markers

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| `X stays must_search: false` ledger bullet has inline superseded | PASS | L73: `X stays \`must_search: false\` (superseded 2026-08-31; X is \`must_search: true\` per §1.2 lock)` |
| `X must_search: false` ledger bullets have inline superseded | PASS | L74–L77, L79–L84: each RFL ACCEPT “does not unwind …” tail includes `X \`must_search: false\` (superseded 2026-08-31; X is \`must_search: true\` per §1.2 lock)` |
| Facebook `must_search: false` unchanged | PASS | L54: “Facebook stays **not** must-search (cataloged exclude)”; L198: `Facebook: \`must_search: false\``; L339 test matrix still expects `facebook must_search=false` |

**Note:** L54 is the authoritative §1.2 X lock paragraph (not an RFL ACCEPT ledger bullet). It quotes the prior RFL phrase `does not unwind X \`must_search: false\`` inside “**supersedes** 2026-08-16 … and RFL …” and immediately locks `must_search: true` — paragraph-level supersession, not the ledger inline marker convention. All true historical ledger bullets (L73–L84) carry the required inline marker.

## R2 — Official-JSON `site:` fallbacks vs Serper/Brave consent

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Official-JSON Method B `site:` fallbacks = best-effort degrade | PASS | L219 §2.7 step 3: “Official-JSON channels’ Method B \`site:\` fallbacks (SE/GitHub/GitLab/YouTube/Reddit/PH) are **best-effort degrade**, not extra per-channel consent gates” |
| Missing Serper/Brave = recorded gap only | PASS | L219: “declining Serper (and Brave) makes those fallbacks a **recorded gap only**”; L218 §2.7 step 2 cross-ref on degrade without extra keys |

## F1–F13 evidence (still present)

| ID | Status | Evidence (plan) |
|----|--------|-----------------|
| F1 | PASS | L101 §1.4: “**Dedup (SB orchestrator, locked):** … Dedup lives in **`search_orchestrator.py`**, not the fork.” |
| F2 | PASS | L219 §2.7 step 3: “**\`site:\` dependency (locked):** … **transitively requires** Serper consent, or Brave if Serper is declined … consent UI must surface that dependency.” |
| F3 | PASS | L218 §2.7 step 2: “**xweb ban-risk (required copy, not skippable):** …”; L266 §2.8 xweb consent cross-ref |
| F4 | PASS | L90 §1.3: non-Cursor “prints manual URLs (the same obtain URLs as §2.8) … `search config set keys.<name> -` … writes `consented_channels`” |
| F5 | PASS | L120 §2.2 / L178 §2.5: one X row; `provider`/`bucket` string-or-list (`[x, xweb]`) |
| F6 | PASS | L420 §6.2: `--cache-dir` equal to fleet dir clobbers `last.json` edge documented |
| F7 | PASS | L324 §3.4: “**No binary fallback (Phase 1):** … `cargo install` fails; there is no cached-binary / mirror path.” |
| F8 | PASS | L660 §6.13: “**Phase 2+ (optional evaluate, not a commitment):** … `search serve` … Do not implement in Phase 1.” |
| F9 | PASS | L344 §4.4: alerts include “GitHub/GitLab PAT expiry, Stack Exchange key rotation, Reddit OAuth app-secret rotation …” |
| F10 | PASS | L462 §6.3: delete “… **and any future `qN_*` prefix** (`q4_*` …)” |
| F11 | PASS | L434 §6.3: “**Trade-off (acknowledged, not a Phase 1 change):** … simpler than one SQLite/sled WAL DB.” |
| F12 | PASS | L481 §6.4 known limit; L650 §6.13: “IDN / non-ASCII Discourse hosts (fail closed; see §6.4 sanitizer)” |
| F13 | PASS | L344 §4.4: “**Metrics (Phase 6 docs):** `search usage --json` plus `run_manifest` shards …” |

**Summary bullet (§1.2):** L85 round-4 post-clarify ACCEPT lead-in still enumerates all 13 items.

## Leftover gaps vs R1+R2 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak (CLEAN review only for streaks).
- Parent may proceed to `verify_2`.
