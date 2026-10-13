# Live-tab critique — what changed

The user’s current tab was treated as live. Prior V-loop 8/8 PASS was not used as a reason to skip. Run id unchanged: `run-57f38dfa25d83cc50d224e283d4692f3`. No 24/24 re-synthesize. No commit. COI ignored as a reason to demote Silver Bullet; superlatives still removed.

HTML+PDF regenerated from the same three files via `generate_spa_report.py --profile landscape` → `render_landscape_outputs()`.

Canonical SPA: [landscape/landscape-report.html](../landscape/landscape-report.html)  
Canonical PDF: [landscape/landscape-report.pdf](../landscape/landscape-report.pdf)

## User item → change

| Critique | What changed |
|---|---|
| Scoring formulas opaque (jitter ±0.28/±0.34/±0.36, unexplained divisors, hidden features.json) | **Report:** scoring section is a buyer rubric (Critical=5…Low=1; floor + ticks × points-per-tick + ranking_score ÷ spread; spread explained in plain language). Collision slotting documented as collision avoidance, not random jitter; amplitudes explicitly gone. **Engine (`skills/`):** removed `_slug_jitter()`, all `jitter_amp` keys, hashlib digest fallback. Unknown-market fallback copies APO profile. Mirrors synced (`agents/claude`, plugin skill-source, host-bundles). |
| Formulas not mapped to buyer priorities / not reproducible | Per-market axis table lists buyer meaning, axis features, floor, points-per-tick, ranking spread. Charts answer evidenced capabilities, not a 100-point brand score. `features.json` is the machine copy of matrix ticks, not a hidden set. |
| Inclusion ledger ≠ membership (sec18–23 vs 57/63/115–117) | Ledger rebuilt to match charts. Barkain / Cavekit / cc10x are **sdlc-plugins** core, not APO. Magic.dev and A.Team are **hard-excluded** rows, not cores. Conductor / AgentHub / Tembo / host runtimes are **adjacent**, labeled (aggregator / CRM / unplotted / host runtime). |
| Magic.dev in seed lists | One membership: hard-excluded `coding_agent`. Not SaaS core, not MQ/Wave, not a comparison-matrix column. Envelope quotes labeled as model error in the Consensus Resolution Table. |
| Zuvo missing (sec83) / no coverage matrix | Zuvo is sdlc-plugins **core** (https://zuvo.dev/ → MIT GitHub). Coverage completeness matrix present. Buying guidance **names Zuvo**. Catalog audit gaps emptied (alias `sdlc-plugin` no longer dumped as “Zuvo missing”). |
| Multi-market treated as contradiction | New **Multi-market membership** subsection: Silver Bullet = APO ∩ sdlc-plugins with explicit rationale. Adjacent-in-one / core-in-another stated explicitly. |
| Divergences listed but not resolved (sec108–118) | Consensus Resolution Table has **FINAL analyst decision + evidence** for: Magic.dev, Conductor, Silver Bullet completeness, secondary-pack overbroad negatives, AI-DLC AWS-not-IBM. Report voice follows those calls. Notable divergences = inter-model disagreement; table = analyst call. |
| Buying guidance uniquely-complete SB (sec85–87) | Removed. Plugin MQ Leaders = SB only is a **feature-gate fact** (hooks **and** ledger C4), not “most complete.” Explicit: this report does not call any vendor “most complete.” Spec-first shortlist is equal-standing OSS including Zuvo. |
| Coverage empty cells claimed complete | Honest remaining gaps kept: MetaGPT missing artifacts (all U); thin-evidence APO commercials; many C4 cells U; Critical-row fill needs a new DR. Zuvo is **not** a coverage gap. |
| Narrative order | Exec Summary (1-page) → 1 Problem → 2 Market → 3 Framework → 4 Findings → 5 Buying Guidance → 6 Future Outlook → 7 Source Reliability. |
| Adjacent silently duplicating core | Adjacent table is CRM / aggregator / host runtime / unplotted only. Coverage matrix is per-market core+adjacent, no global-adjacent duplicates. |
| Body font / links | SPA inject: Roboto Condensed **font-weight 300**; `#content a` no underline; links `target="_blank"` + `noopener noreferrer`. PDF already had weight 300. |
| PDF failed when HTML lived under `landscape/` | `write_sibling_landscape_pdf` now resolves the DR research root (has `landscape/` + `comparison/`), not the HTML parent. PDF is sibling `landscape-report.pdf?v=` + `Date.now()`. |

## Regen / open

- HTML+PDF **not skipped**. PDF bytes ≈ 1 070 946. Sources: md + chart-data.json + comparison.json.
- `open` on macOS for [landscape/landscape-report.html](../landscape/landscape-report.html) (system browser, file://).
- Research-root copies of HTML/PDF synced so they do not stale.

## Honest remaining gaps

- MetaGPT: APO core, missing `solutions/metagpt` artifacts; U cells; no ranking row.
- Thin-evidence APO commercials: Deepwork, Turboshovel, Workflow Manager (ticks are proxies).
- Many C4 cross-session cells are U (only Silver Bullet passes ledger C4).
- Critical-matrix fill is still thin — do not claim completeness; a new DR is required to thicken.
- `comparison.json` `winner` is still `silver-bullet` as the **tick-total ranking** (score 38). Report voice does not treat that as “most complete.”
