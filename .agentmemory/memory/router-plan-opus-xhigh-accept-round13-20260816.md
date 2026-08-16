# Decision — Opus Extra High ladder-3 ACCEPT (round-13, real xhigh, 2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 plan (clarify round-13). Stay on `main`. No commit. Max not started. No Fast.

Real Extra High reviewer: [`sb-opus-5-xhigh`](ae7acbea-65c5-4331-a0a9-7a19964c42e0). Parent verified none of the ten findings wrong. Prior wrong-vehicle Extra High remains in `opus-5-xhigh-ladder3/review.md`. Verbatim Extra High review saved to `opus-5-xhigh-ladder3/review-real-xhigh.md`.

## ACCEPT dispositions

- **H-1:** Row 35 same GST degrade as row 34. Missing git identity stamps `gst_stale`; Job continues. Row 35 dashboard-only / non-classifying. Identity fixture in `VAL/TST-RFL-621`.
- **H-2:** Add `.sb/` to every sparse-checkout / split-brain / merge-oracle / WBS-01 / launch-template ledger-omit enumeration. Extra-tree discriminator (row 33 vs 4/8) treats `.sb/` as ledger-omit.
- **H-3:** Classified-trivial is not a Job. Job step 1 / `blocked_knowledge_preread` / `pre_read_pending` are Job-scoped. FAST WBS: classify + wrap + FAST leaf + thin-capture only (no pre-read node). Graphify miss on FAST is not row 8. Reclassified durable work does run step 1 as a Job.
- **H-4:** FAST leaf hang/die/wrong-answer → Authorizer-admitted one re-dispatch of the same FAST leaf; second failure → `blocked_fast_leaf` (row 36; FAST-scoped, not a Job, not GST). Stops FAST `scope_complete` / user return, not GST. Do not use ESC-02 / Advisor/Val/Ver. Thin-capture AM-save failure stays `blocked_knowledge_postwrite` but FAST-scoped.
- **H-5:** WS1 must add `AF-agent-delegate` / wrapping WF `sb:agent-wrap` (`WF-SB-AGENT-WRAP`) to `docs/apo-catalog.json` with required `v_loop` `VL-AF-agent-delegate`. Public routes `sb:agent-wrap` / `sb:agent-delegate`. Class `nested_executor`.
- **M-1:** Classified-trivial exemption is generators + `check-apo-invariants.py`. Do not JSON-edit `AF-FAST-PATH`/`WF-SILVER-FAST`. Only FAST catalog JSON edit is `PP-SB-STARTUP-FAST.override_rules[0]` → `WF-SILVER-FEATURE`.
- **M-2:** GST UTC rollover: Active rows carry forward; Completed/Blocked stay on the day they terminated; tombstone consulted across current and previous day file. Pin in `VAL/TST-RFL-621`.
- **M-3:** GST helper write order: (1) if operator primary is git main-worktree, commit/push there; (2) else fetch+commit on `origin/main` without a second worktree that materializes ledger-omit dirs. Forbid dedicated main worktree copying `.planning/` / `.sb/` / etc.
- **M-4:** `[skip ci]` / `paths-ignore` scoped to push heartbeats on `main`. Do not suppress `pull_request` checks.
- **M-5:** CAS `git_user_id` still prefers email if set (identity stability). Published dashboard MUST NOT write raw `user.email` into `.sb/status/**`. Use `user.name` or a short hash of email. Helper refuse-write if payload would contain a raw email.

## KEEP REJECT (untouched)

ESC-02 no A; Authorizer not Approver; `process_v_verified`; FAST not a Job / not GST / quality-order exemption; wrap at `/sb`; BOA parallel; no `AF-meta-six-role`; no `AF-qa`; AM-first; current-month cap; team Graphify fan-out; GST degrade (`gst_stale`, Job continues, row 34 dashboard-only); B1 schema unchanged / exemption in checker+generators; AF-FAST-PATH only for classified-trivial; `AF-EXECUTE` must not run on FAST; PP-SB-STARTUP-FAST → `WF-SILVER-FEATURE`; Board-of-one unifier still launches.

Plan SHA-256 (both copies, byte-identical): `4f772f9f618ae42aa2ecd573c2c5a813af8d22c29f719f97a5f12106efee2d1d`
Prior frozen SHA (round-12): `0289df0c7d8e8982ecef041d5e9da7092b5a6a67b94863297c74c276785ec2af`
