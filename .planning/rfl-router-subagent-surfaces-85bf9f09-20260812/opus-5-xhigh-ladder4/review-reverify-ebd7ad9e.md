# RFL Ladder 4 — Opus Extra High re-verify (`sb-opus-5-xhigh`), SHA `ebd7ad9e`

- **Branch:** `main` (no checkout, no edits to plan copies, no commit, no nested Task, no Max, no Fast)
- **Role:** REVIEWER ONLY
- **Plan hash (repo copy) — start:** `ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e`
- **Plan hash (`~/.cursor/plans` copy) — start:** `ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e`
- **Plan hash (repo copy) — end:** `ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e`
- **Plan hash (`~/.cursor/plans` copy) — end:** `ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e`
- **Hash status:** MATCH against the frozen SHA on both copies, at start and at end. No drift during review.
- **Tooling:** Graphify ran first (`graphify query "router subagent surfaces Executor remint launch_id revoke fence liveness row 1"`, 153 nodes) and oriented me to the plan, CLARIFY brief, ladder-3/4 review artifacts, and the round-16/31 agentmemory decision records before any Read. The **agentmemory MCP server is not registered** in this session (no `memory_save` tool resolves in the server catalog), so session notes could not be saved via MCP — stating this once, as instructed; this review file is the durable record. Native Grep is denied by the local toolstack, so sweeps ran through the Context Mode sandbox (`ctx_execute`).

---

## Round-33 landing check

| Item | Verdict | Evidence |
|---|---|---|
| **L251** cites row 1; no liveness/pid oracle at the `VAL/TST-RFL-625` ownership site | **PASS** | L251 |
| **L253** cites row 1; live-but-fenced not row 1 | **PASS** | L253 |
| **L265** cites row 1; live-but-fenced not row 1 | **PASS** | L265 |
| **L669** (row 40) no longer contradicts row 1 on liveness | **PASS** | L669 |
| Live-spec sweep — no surviving un-narrowed old-Executor→row-1 | **PASS** | see sweep below |
| **n-1** supersession pointers on append-only logs | **PASS** | plan L80 (2/2); CLARIFY L1102, L1144, L1149 (3/3) |

### L251 / L253 / L265 / L669 — PASS

All four now carry the identical accepted formulation, replacing the round-32 text *"a still-running old Executor after remint is `blocked_corrupt_state` (row 1)"*:

> "conflicting payload on the **old** `launch_id` stays blocked (CORR-17 fence); **observable post-revoke effects after remint are `blocked_corrupt_state` (row 1 — cite row 1); a live-but-fenced old Executor is not row 1**; the new `launch_id` carries the re-bound closure"

Verified by exact-phrase census: `live-but-fenced old Executor is not row 1` occurs at exactly **L251, L253, L265, L669**; `row 1 — cite row 1` occurs at exactly **L251, L253, L265, L669**. Both counts are 4/4 with no fifth site and no omission.

Each specific sub-requirement:

- **L251 — no liveness/pid oracle.** The narrowing clause now precedes the fixture assignment in the same sentence chain, so an implementer reaches *"a live-but-fenced old Executor is not row 1"* **before** *"WFM-01 / `VAL/TST-RFL-625` owns the fixture."* The construction that previously licensed a pid oracle is gone; nothing on L251 conditions row 1 on process liveness.
- **L669 — no self-contradiction inside the failure-mode table.** Row 40 (L669) and canonical row 1 (L630) now agree: L630 says *"**\"Process/session still live\" alone is not a row-1 match**"* and L669 says *"a live-but-fenced old Executor is not row 1"*. The round-32 intra-table contradiction on row 1's trigger is resolved.
- **Limb (b) semantics preserved.** All four restatements defer to the canonical cell (*"cite row 1"*) rather than re-deriving the trigger, which is the structurally safer of the two remedies offered — future canonical edits cannot desynchronize them.

### Live-spec sweep — PASS

Repo-sandbox sweep of both documents for `still-running`, `still running`, `still live`, `pid still exists`, `remains running`:

**Plan** — matches at L80, L630, L737, L859 only.
- **L630 / L737 / L859** are the canonical row-1 cell and the two fixture rows; each match is inside the *correct* narrowing (*"…alone is not a row-1 match"*, *"must not treat \"pid still exists\" as FAIL"*). These are the intended occurrences, not survivals.
- **L80** carries 2 un-narrowed historical statements and **2** `superseded round-33` pointers — 1:1, no orphan.

**CLARIFY** — un-narrowed statements at L1102, L1144, L1149; each has a `superseded round-33` pointer (3 statements / 3 pointers, plus the n-1 accept text at L1211). L1173/L1175/L1203 are the round-32/33 accepts and already state the narrowed rule.

Secondary sweep for differently-worded liveness oracles (`process-death`, `kill/killing the old`, `terminate the old`, `old process`, `stopped acknowledg*`) surfaced no un-narrowed live-spec statement. L695 (`blocked_offline_quiescence`, durable stopped acknowledgments) is the OFF-01 feature specification itself, and OFF-01 is consistently post-MVP at L30, L675, L705, L718, L720, L772, L784, L802, L873 — no MVP process-death oracle leaks in.

**No un-narrowed old-Executor→row-1 statement survives anywhere in the live spec.**

---

## Round-32 spot-check (re-verified on this SHA)

| Item | Verdict | Evidence |
|---|---|---|
| **M-1** canonical cell — limb (b) = observable post-revoke effects only | **PASS** (was PARTIAL on `3af884ef`; completed by round-33 H-1) | L630 canonical cell intact and unmodified; both limbs pinned in `VAL/TST-RFL-625` / WFM-01 |
| **M-2** canonical row-1 remediation cell, all five exits | **PASS** | L630 remediation cell |
| **N-1** one canonical citation form `VAL/TST-RFL-604` | **PASS** | L27, L80, L716, L772, L863 |
| **N-2** `context_refs_hash` not-a-`prompt_hash`-input carve-out | **PASS** | L263, L433, L592 |
| **N-3** VALP-01 traceability includes `VAL/TST-RFL-615` cycle fixtures | **PASS** | L868 (+ L727) |

- **M-1 / L630** still reads: limb (a) *"failure to complete revocation … before the replacement `launch_id` is admitted"*; limb (b) *"**observable post-revoke effects** after remint … write/callback/effect attempts under the old `launch_id` that hit the CORR-17 fence or an equivalent attested receipt"*, then *"**\"Process/session still live\" alone is not a row-1 match**"* and *"Timeout, disconnect, missing process, or lease silence cannot prove abandonment (L598) and cannot prove limb (b)."* Untouched by round-33, as the addendum required (CLARIFY L1207: *"Do not change the canonical cell."*).
- **M-2 / L630** remediation cell retains all five exits: cycle class (Advisor remint/recompose, L122/L727, not store repair); revoke-before-admit (do not admit until revoke succeeds, or fail-close without admitting); observable stale-Executor effects (*"CORR-17 fence holds; replacement `launch_id` proceeds; do **not** require killing the old process at MVP"*); corrupt store / helper-write / sole-writer / CAS / split-brain (quarantine + reviewed repair); `sb:<route>` collision (non-colliding route id).
- **N-1** — the only bare `TST-RFL-604` is at L863, in the traceability table's **Test-ID column** paired with `VAL/TST-RFL-604` in the Validation-ID column. Column form, not a competing prose citation.
- **N-2** — L263 *"**Launcher** may omit `context_refs_hash` on `launch_intent` (not inner-prompt bytes; **not a `prompt_hash` input**)"*; L433 *"Envelope metadata (`remaining_depth`, `worktree_cwd`, `context_refs_hash`) is **not** inner-prompt bytes and is **not** hashed into `prompt_hash`"*; L592 *"`context_refs_hash` is likewise **not** inner-prompt bytes and **not** a `prompt_hash` input"*. Parity with `worktree_cwd` (L241, L435) and `remaining_depth` (L435) intact; inner-only lock unchanged.
- **N-3** — L868 VALP-01 row and L727 testing row both pin self-cycle FAIL / mutual-cycle FAIL / shared-DAG PASS under `VAL/TST-RFL-615`.

### Internal line-cite integrity — PASS

Round-33 edits were in-line (no line insertions), so numbering is stable. All 11 distinct internal `L###` self-citations were resolved against their targets: **L120, L122, L175, L239, L251, L253, L265, L598, L669, L727, L746** — every one lands on the intended content. In particular the KEEP REJECT anchor **L598** still contains *"Timeout, disconnect, missing process, or lease silence is insufficient to prove abandonment."* (later in that line), so the L630 and L80 cross-references to L598 resolve correctly. The new L80 cites to L251/L253/L265/L669 also resolve.

---

## KEEP REJECT

**Intact — nothing reopened, nothing amended from this rung.** Verified present and unchanged on this SHA:

`nested_executor` lock-only (L118/L120/L122/L541/L750/L752/L758); B1 `docs/apo-catalog.schema.json` unchanged (L80/L259/L752); public `sb` / `sb:` / `/sb` only (L24/L48/L259/L568); catalog generated from APO (L9/L96/L175/L752); unlimited NW nesting is a **tree** (L80/L122/L630); cycles fail-closed via DFS **tri-color / recursion-stack** (L80/L122/L263/L433/L592/L630/L727/L868); in-plan Executor mint (L251/L253/L667/L727/L737); remint **mints a new `launch_id`** (L18/L80/L124/L243/L251/L253/L265/L289/L326/L669/L730/L737/L859/L861); `hooks/lib/wbs-projector.sh` exclusive packet writer (L48/L241/L457/L738/L762 — admission *requests*, is not a second writer); FAST not a Job / not GST / classify-not-mint / `AF-FAST-PATH` only; Authorizer **not an Approver** (L261); ESC-02 no A (L124/L259/L642/L661); `prompt_hash` inner-only (L263/L433/L592); launcher **may omit** `context_refs_hash` (L120/L263/L433/L592); **L598** no abandonment-by-silence; OFF-01 post-MVP; **limb (b)** = observable post-revoke effects only; live-but-fenced is **not** row 1.

The round-33 CLARIFY addendum's **KEEP REJECT (unchanged)** block at CLARIFY L1203 matches the plan state and adds nothing new. No finding below reopens any KEEP REJECT item.

---

## Findings

**0 Blockers, 0 Highs, 0 Mediums, 2 nits (both cosmetic, both non-blocking).**

Round-32's High H-1 is **closed**. Round-32's nit n-1 is **closed**. No new defect survives at Medium or above.

### nit n-1 — Authoring directive left inside normative prose

L251, L253, L265, L669 read *"…are `blocked_corrupt_state` (row 1 — cite row 1)"*. The parenthetical *"cite row 1"* is an instruction to the editor/implementer that has been carried into the normative sentence, and it sits redundantly beside the `(row 1)` classification it is telling the reader to use. Semantics are unambiguous and the deferral to the canonical cell is exactly the accepted remedy, so this changes no behaviour. If ever touched, *"(row 1 — see the canonical row-1 cell)"* or simply *"(row 1)"* would read cleaner. Not worth a dedicated edit round on its own.

### nit n-2 — Self-referential markdown links to agent UUIDs do not resolve (pre-existing)

Plan L80 and CLARIFY L1201 render worker ids as `[aea56ad4-ca9e-46d6-9899-18b58346b5cd](aea56ad4-ca9e-46d6-9899-18b58346b5cd)`, a relative link whose target does not exist in `.planning/`. Same pattern for `d7a996e8-…` and earlier rounds. This is consistent house style across rounds 25–33, predates round-33, and is cosmetic only — noted for completeness, not as a regression, and explicitly not a reason to hold the freeze.

---

## Verdict

**CLEAN** — 0 Blockers, 0 Highs, 0 Mediums, 2 cosmetic nits.

- Round-33 landings: **all PASS** (L251, L253, L265, L669; live-spec sweep clean; n-1 supersession pointers 1:1 in both documents).
- Round-32 spot-check: **M-1 PASS** (upgraded from PARTIAL — round-33 H-1 completed it), **M-2 PASS**, **N-1 PASS**, **N-2 PASS**, **N-3 PASS**.
- Internal `L###` self-citations: **all resolve**, including the L598 KEEP REJECT anchor.
- KEEP REJECT: **intact**, nothing reopened, nothing amended.
- Hash: `ebd7ad9e…` on both copies, matching the frozen SHA at start and at end.

VERDICT: CLEAN
