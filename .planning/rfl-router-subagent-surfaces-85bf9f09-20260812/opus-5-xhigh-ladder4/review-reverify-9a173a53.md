# RFL Ladder 4 — Opus Extra High — RE-VERIFY on `9a173a53…` — PARENT ACCEPT

**Reviewer:** Opus Extra High (`sb-opus-5-xhigh` / [`99a0dd63-44bb-4e09-b2e7-6ffd2be3e1f4`](99a0dd63-44bb-4e09-b2e7-6ffd2be3e1f4)). Review-only at review time. No Fast. No Max.
**Branch:** `main`
**Frozen SHA-256 at re-verify:** `9a173a53f04eec56bc139d1e1ae67f7cdc3c0530a9860f71e6253a67e346e7be`
**Parent ACCEPT (round-30):** B-1 / H-1 / H-2 / H-3 / M-1 / M-2 incorporated together with GPT Max H-1 / H-2 / H-3 / M-1. Round-29 landings present. Max **not** re-launched. Extra High **not** re-launched. No commit.

**Hash gate: PASS.** Both plan copies hashed to `9a173a53f04eec56bc139d1e1ae67f7cdc3c0530a9860f71e6253a67e346e7be` at review start and end. Branch `main`.

**Round-29 landed check: PASS.** Named lock generator + hand-authored `nested_executor` table + `tests/scripts/test-router-contract-locks.sh` (create-it); composition remint **mints a new `launch_id`**; WS3 `context-refs-snapshot` + `VAL/TST-RFL-626`; GPT cycle fail-closed; hash-correctness; snapshot canonical bytes. KEEP REJECT intact (`nested_executor` lock-only; schema unchanged; public `/sb`; catalog generated; unlimited **tree** nesting; cycles fail-closed; in-plan Executor mint; row 40 remint new `launch_id`; `wbs-projector.sh` exclusive packet writer).

## VERDICT: NOT CLEAN

### Blocker B-1 — projector sole writer (accepted)

Route snapshot persist through `hooks/lib/wbs-projector.sh`. Admission **requests** the projector; it does **not** write packet paths. Amend every “sole writer” / allowlist / “sole writers unchanged” / row-1 helper-write contradiction (plan ~L48/L173/L429/L457/L542/L612/L705/L729/L738/L762/L764/L856). Do **not** carve admission as an extra allowlisted packet writer. Same lock as GPT Max H-1.

### High H-1 — `context_refs_hash` stamp vs compare (accepted)

- **Launcher** may omit `context_refs_hash` on `launch_intent`.
- **At admit**, projector copies live `context_refs` into the snapshot, then stamps `context_refs_hash` as SHA-256 of that snapshot’s canonical encoding.
- Admission **does not** row-4 on pre-admit live-doc drift. Drift in the author→admit window is **refresh**: re-copy + re-stamp, then proceed.
- Row-4 `omitted or mismatched` applies **after** stamp: consume / nested launch must present the stamped hash and it must match a **recompute of the durable snapshot** (independent source = snapshot bytes, not the live files). Missing snapshot or hash≠snapshot → row 4.
- Do **not** make admission hash-then-compare the snapshot it just wrote as a self-satisfying check, and do **not** require the launcher to pre-hash live files.

### High H-2 — live-file read is cooperative, not a physical jail (accepted)

Cursor Task cannot PreToolUse-jail reads (same limit as L239 writes). Downgrade “child reading live files instead of that snapshot” from a claimed physical row-4 rail to a **cooperative child obligation**: child prompt/receipt **binds** snapshot paths; Verification-loop is the detection surface. `VAL/TST-RFL-626` negative fixture (GPT Max M-1) proves the bound prompt/receipt cites snapshot paths **and not** live `context_refs` paths — not a path-jail on Read.

### High H-3 — name the lock generator; fix L175 (accepted)

Lock emitter is `scripts/generate-router-contract-locks.py` (or a named function in that script). Add it to WS1 **named source surfaces** and to the L746 named regen command. Rewrite Proposed architecture ~L175 so **that** script emits `contracts/public-workflow-routes.lock.json` and `contracts/apo-hierarchy.lock.json` — not “Generators” / catalog builders / `generate-apo-artifacts.py`. Hand-authored `nested_executor` table stays hand-authored; generator does not invent that table. `tests/scripts/test-router-contract-locks.sh` remains create-it + committed-locks baseline.

### Medium M-1 — snapshot encoding: regular files only (accepted)

Admit copy **resolves nothing as a preserved symlink**. Copy **regular file bytes** only (follow symlink once to regular-file contents, then store a regular file in the snapshot — no symlink left in the snapshot tree). Non-regular entries (dirs already skipped; fifo/socket/device; dangling symlink; symlink loops) → fail-close row 4 / `blocked_corrupt_state` as appropriate. Hash covers the stored regular-file bytes, never a link string.

### Medium M-2 — snapshot GC tied to resumability (accepted)

Do **not** leave “GC = packet lifecycle” undefined. Snapshots **survive while `launch_id` is resumable** (parent-proxy consult continuation, ESC-02 re-dispatch, `plan_revision` under the same id). GC only after fence release **and** child terminality for that `launch_id`. A missing snapshot for a still-resumable id is row 4 / corrupt, not successful GC.

Parent ACCEPT 2026-08-16 (round-30): Opus B-1 / H-1 / H-2 / H-3 / M-1 / M-2 incorporated with GPT Max H-1 / H-2 / H-3 / M-1. Round-30 SHA: `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e`. Max not re-launched. Extra High not re-launched.
