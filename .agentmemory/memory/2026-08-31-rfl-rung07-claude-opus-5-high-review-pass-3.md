---
type: decision
date: 2026-08-31
rung: rung-07-pi-claude-opus-5-high
freeze-sha256: 4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7
---

# RFL rung-07 Claude Opus 5 High — review pass 3 (NOT CLEAN, R7c-F01..F16)

RFL rung-07 Pi Claude Opus 5 High review pass 3 on .planning/spec_template_world_class.plan.md at post-R7b-APPLY pin 4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7 (both twins hashed equal). Residual-only Policy G. Verdict NOT CLEAN: 16 findings R7c-F01..R7c-F16 (1 HIGH, 7 MED, 5 LOW, 3 nit).
HIGH R7c-F01: Invariants precedence branch (3) ASK has no non-interactive terminal and makes two pinned brief-less Wave 6 fixtures (R5-F01 migrate PASS, R7b-F06 decision-count install) unreachable; decision-count got a non-fatal brief-less rule while invariant-count got a blocking one.
MED: F02 decision-count has no live DEC-nn equality (unlike invariant-count) so installed value can be false; F03 invariant-count equality gates on an undefined MUST/MUST NOT bullet grammar (invariants are the only core structured content with no ID); F04 the R7b-F14 dedicated QA-01,SLO-01 parser fixture (infra-devops/headless-service) necessarily carries required security CTRL-01 which then fails the neither-branch rule; F05 malformed prior spec-version on augment paths 2/4b has no seed or bump rule despite "tree is total"; F06 conditionally-required fifth ontology class cannot be expressed in software-kinds.yaml which R7b-F07 made the sole machine source; F07 retained .spec-kind-migration.md is a fixed path with no accumulation rule so a second migration overwrites the first; F08 SCAN normalization "collapse non-alphanumerics to -" ambiguous on runs/trim/whitespace and unresolvable = fail-closed REQ-F71.
LOW: F09 SCAN <line-or-id> line half has no base/stability rule contradicting stable-ID contract; F10 named QC-string test L437 assert list omits SPEC-F70/REQ-F71/REQ-F72/XART-F03/SCAN fixtures though R7b-F11 extended the rg line; F11 world-class-min fixture asserts (L361) omit core YAML keys R7b-F13 added to template asserts (L359); F12 Wave 4 verify never asserts Invariants turn is always-on; F13 Wave 1 requires REQUIREMENTS template to carry both a measurable NFR Metric row and None identified.
NIT: F14 conditionally-required ontology row emits bare ISSUE with no SPEC-F* code (should be SPEC-F74); F15 pack table Default class column uses non-enum vocabulary (kind-gated) and R7b-F07 de-normativized only Notes; F16 "in practice only cli" restated normatively six times, recreating second-source-of-truth vs catalog.
Confirmed R7b-F01..F16 all landed in freeze text; R7b-F17 REJECT not re-filed. Output: .planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/review-rerun-3.md. Review-only: no triage/APPLY/edit/commit/verify/outcome-record. Handoff Triage=Composer 2.5, Fix=Grok 4.6 High.
