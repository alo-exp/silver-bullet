# Plan delta — OmniRoute / `/sb:agent-*` opt-in by-reference alignment (2026-08-25)

Planning-only. No product code. Git stayed on `main`. Both freeze copies stayed byte-identical. YAML: prior 26 todos remain `pending`; added 5 pending omni todos. KEEP REJECT stayed closed. No new §6 A/B/C.

## Copies

| Path | SHA-256 | Bytes |
|------|---------|-------|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `dde658d822848f38466384ce081df7c6e3070fc0393b083ea208322c7a8b5960` | 608795 |
| [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) | same | same |

Start pair (confirmed before edits): `cd7db06bc17f72df16a95800dbff90c9d9f22e084a377f3f6d2c96c703889f87` / 592212 bytes.

## Companion omni plan (source of alignment — not swallowed)

| Path | SHA-256 | Bytes | Repo copy |
|------|---------|-------|-----------|
| [`/Users/shafqat/.cursor/plans/omni_agent_opt-in_67f2f73a.plan.md`](/Users/shafqat/.cursor/plans/omni_agent_opt-in_67f2f73a.plan.md) | `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26` | 7284 | **none** (no `.planning/omni_agent_opt-in_67f2f73a.plan.md`) |

Owns: Graphify-style `recommended_tools` consent (`omniroute` + five `agent_*`), transport-first slug grammar, `/sb:init` 1.1h–1.1m after LeanCTX, `install-omniroute-sb.sh`, thin `agent-omni-delegate.sh`, doctor `--fix`, SKILL/D17/tests. Public prefix in this freeze is `/sb` (omni draft used `/silver:`; composed, not a dual-prefix window).

## YAML todos

| Metric | Before | After |
|--------|--------|-------|
| Todo count | 26 | **31** |
| Status | all `pending` | all `pending` (none completed) |
| Added ids | — | `omni-agent-opt-in-schema`, `omni-agent-slug-resolver`, `omni-agent-install-configure`, `omni-agent-doctor`, `omni-agent-docs-tests` |

Frontmatter stayed compact (one-line `content:` with pointer to omni SHA + freeze section).

## Alignment map (omni section → freeze heading)

| Omni section | Freeze heading |
|--------------|----------------|
| Consent model / `recommended_tools` keys | Glossary; FR-17; Hosts, runtimes, five-tool → **OmniRoute and `/sb:agent-*` opt-in**; §5.3 ### 6 **WS6 OmniRoute / agent-host opt-in**; Appendix D |
| Slug grammar / `omni/` vs `<host>/` / unprefixed | Glossary **agent slug**; LS-agent-pin; §4.6 pointer; YAML `omni-agent-slug-resolver` |
| `/silver:init` 1.1h–1.1m after LeanCTX | `/sb:init` in §2.3 + Appendix D; WS6 named slice (not before WS0/WS0b) |
| `/silver:doctor` checks + `--fix` | §5.3 ### 7; §5.4 Doctor; YAML `omni-agent-doctor` |
| Call sites (skills, `rfl_launcher_policy.py`, delegates) | WS2 host-surfaces callout; LS-agent-pin; no `/sb:agent-omni` public command |
| Tests (slug, consent, compression off, skill-scenario) | §5.4 coverage map; Appendix B/C (`test-agent-slug.sh`, `test-agent-host-consent.sh`, `test-omniroute-install.sh`) |
| Out of scope (Omni compression/memory; 14-model Pi allowlist; tagging) | Non-goals; §6 composed note |

## Conflicts resolved (composed, not dropped)

| Tension | Resolution |
|---------|------------|
| Omni `/silver:agent-*` vs freeze `/sb` only | Public names are `/sb:agent-*` / `/sb:init` / `/sb:doctor`. Implementation files may still be `skills/silver-*` until catalog rename. KR-no-dual-silver holds. |
| Omni as “router” vs exclusive `/sb` | OmniRoute is **routing-only infra** (HTTP `:20128`), **not** a second public process router. |
| Consent keys vs five preference keys / Authorizer | `omniroute` + `agent_*` are Graphify-style `recommended_tools`, **not** role keys, **not** Authorizer. |
| `omni/` slug vs pin / `sb:agent-wrap` | Pin stays `host_native` \| `/sb:agent-{cursor,codex,claude,opencode,pi}`. `omni/` is slug transport via thin delegate. **No** public `/sb:agent-omni`. **No** `sb:agent-wrap`. |
| Five-tool vs Omni compression/memory | Omni compression/memory **off**; five-tool owns those surfaces. |
| Sequence vs WS0/WS0b | Named **WS6** slice + WS2/WS7 callouts. **Not** before WS0/WS0b. Does not insert a numbered WS that breaks WS0 → WS0b → WS1–7 → WS8 → docs-release. |
| KR-cursor-mvp-first (no Orchestrator-as-parent adapters) | Omni is opt-in for existing `/sb:agent-*` **leaves**, not Codex/Claude/OpenCode as Orchestrator parent. |

## New open question

**None.** §6 records “Companion omni-agent opt-in — composed (no new clarify)”. No A/B/C.

## Completeness

Freeze still contains prior tokens (`/sb:fast`, FAST short order, `/sb:improve` always a Job, `WF-DEEP-RESEARCH`, `/sb:deep-research`, `/sb:legacy-dr`, WS0/WS0b/WS8, KEEP REJECT themes) **plus** omni plan path, omni SHA-256, and omni public/config surfaces (`recommended_tools.omniroute`, five `agent_*`, slug forms, install/delegate scripts, `docs/OMNIROUTE.md`).
