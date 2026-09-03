# Inclusion ledger (3-of-7)

Generated: 2026-08-14 · Reviewer: `act-on-critique-artifacts` · Run: `run-57f38dfa25d83cc50d224e283d4692f3` (not re-derived)

Compact decision table (P/F/U). Magic.dev is **hard-excluded** even if proxy ticks meet 3-of-7. Zuvo added as sdlc-plugins coverage close.

| Vendor | Market | C1 Life | C2 Plug | C3 Gate | C4 State | C5 Spec | C6 Enf | C7 Proc | Evidence cite | Final decision |
|---|---|---|---|---|---|---|---|---|---|---|
| Augment Code (Cosmos) | `agentic-sdlc-saas` | P | P | U | U | P | U | P | solutions/augment-cosmos/features.json:Workflow composition | included-core |
| Devin | `agentic-sdlc-saas` | P | P | U | U | F | P | P | solutions/devin/features.json:Workflow composition | included-core |
| Factory.ai | `agentic-sdlc-saas` | P | P | U | U | P | P | P | solutions/factory-ai/features.json:Workflow composition | included-core |
| Magic.dev | `agentic-sdlc-saas` | P | P | F | U | F | F | P | solutions/magic-dev/features.json:Workflow composition | hard-excluded |
| Tembo | `agentic-sdlc-saas` | F | F | F | F | U | F | U | envelopes: Satisfies 2 of 7 inclusion criteria at most | adjacent |
| AI-DLC | `apo` | P | U | U | U | U | U | U | solutions/ai-dlc/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| ATeam | `apo` | P | P | F | U | P | U | P | solutions/ateam/features.json:Workflow composition | hard-excluded |
| AgentHub | `apo` | P | P | U | U | P | U | P | solutions/agenthub/features.json:Workflow composition | adjacent |
| AgentSys | `apo` | P | P | F | U | P | U | P | solutions/agentsys/features.json:Workflow composition | included-core |
| Barkain Workflow Orchestrator | `apo` | P | P | U | U | U | U | P | solutions/barkain-workflow-orchestrator/features.json:Workflow composition | included-core |
| Cavekit v3.1 | `apo` | P | P | F | U | F | U | P | solutions/cavekit-v31/features.json:Workflow composition | included-core |
| Deepwork | `apo` | P | P | F | U | U | U | P | solutions/deepwork/features.json:Workflow composition | included-core |
| Director | `apo` | P | P | U | U | U | U | P | solutions/director/features.json:Workflow composition | included-core |
| MetaGPT | `apo` | U | U | U | U | U | U | U | solutions/metagpt/features.json/scr.md (insufficient evidence) | included-core |
| Silver Bullet | `apo` | P | P | P | P | P | P | P | solutions/silver-bullet/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Turboshovel | `apo` | P | P | F | U | U | U | P | solutions/turboshovel/features.json:Workflow composition | included-core |
| Workflow Manager | `apo` | P | P | U | U | F | U | P | solutions/workflow-manager/features.json:Workflow composition | included-core |
| cc10x | `apo` | P | P | P | U | U | P | P | solutions/cc10x/features.json:Workflow composition | included-core |
| BMAD-METHOD | `sdlc-plugins` | P | P | P | U | U | P | P | solutions/bmad/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Claude Harness | `sdlc-plugins` | P | P | P | U | F | P | P | solutions/claude-harness/features.json:Workflow composition | included-core |
| GSD (Get Shit Done) | `sdlc-plugins` | P | P | P | U | U | P | P | solutions/gsd/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| GitHub Spec Kit | `sdlc-plugins` | P | P | P | U | F | P | P | solutions/spec-kit/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Oh My Pi (OMP) | `sdlc-plugins` | P | P | P | U | P | P | P | solutions/oh-my-pi/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Ruflo (formerly Claude Flow) | `sdlc-plugins` | P | P | P | U | P | P | P | solutions/ruflo/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Silver Bullet | `sdlc-plugins` | P | P | P | P | P | P | P | solutions/silver-bullet/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| SuperClaude | `sdlc-plugins` | P | P | P | U | U | P | P | solutions/superclaude/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Superpowers | `sdlc-plugins` | P | P | P | U | U | P | P | solutions/superpowers/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Zuvo | `sdlc-plugins` | P | P | P | U | P | U | P | solutions/zuvo/features.json:Workflow composition | included-core |

## Per-criterion rows

### Augment Code (Cosmos) (`augment-cosmos`) — agentic-sdlc-saas

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/augment-cosmos/features.json:Workflow composition | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/augment-cosmos/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | unknown | solutions/augment-cosmos/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/augment-cosmos/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | pass | solutions/augment-cosmos/features.json:Parent/child agent delegation | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/augment-cosmos/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/augment-cosmos/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |

### Devin (`devin`) — agentic-sdlc-saas

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/devin/features.json:Workflow composition | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/devin/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | unknown | solutions/devin/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/devin/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | fail | solutions/devin/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/devin/features.json:Automated review loops | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/devin/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |

### Factory.ai (`factory-ai`) — agentic-sdlc-saas

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/factory-ai/features.json:Workflow composition | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/factory-ai/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | unknown | solutions/factory-ai/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/factory-ai/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | pass | solutions/factory-ai/features.json:Parent/child agent delegation | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/factory-ai/features.json:Automated review loops | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/factory-ai/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |

### Magic.dev (`magic-dev`) — agentic-sdlc-saas

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/magic-dev/features.json:Workflow composition | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/magic-dev/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | fail | solutions/magic-dev/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/magic-dev/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | fail | solutions/magic-dev/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | fail | solutions/magic-dev/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/magic-dev/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |

### Tembo (`tembo`) — agentic-sdlc-saas

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | fail | envelopes: Satisfies 2 of 7 inclusion criteria at most | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | fail | envelopes: Satisfies 2 of 7 inclusion criteria at most | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | fail | envelopes: Satisfies 2 of 7 inclusion criteria at most | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | fail | envelopes: Satisfies 2 of 7 inclusion criteria at most | medium | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | envelopes: agent claims medium + identity risk | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | fail | envelopes: Satisfies 2 of 7 inclusion criteria at most | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | unknown | envelopes: agent claims medium + identity risk | low | 2026-07-22 | address-all-non-coi-pass |

### AI-DLC (`ai-dlc`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/ai-dlc/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | unknown | solutions/ai-dlc/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | unknown | solutions/ai-dlc/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/ai-dlc/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/ai-dlc/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/ai-dlc/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | unknown | solutions/ai-dlc/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |

### ATeam (`ateam`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/ateam/features.json:Workflow composition | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/ateam/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | fail | solutions/ateam/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/ateam/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | pass | solutions/ateam/features.json:Parent/child agent delegation | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/ateam/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/ateam/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |

### AgentHub (`agenthub`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/agenthub/features.json:Workflow composition | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/agenthub/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | unknown | solutions/agenthub/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/agenthub/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | pass | solutions/agenthub/features.json:Parent/child agent delegation | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/agenthub/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/agenthub/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |

### AgentSys (`agentsys`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/agentsys/features.json:Workflow composition | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/agentsys/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | fail | solutions/agentsys/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/agentsys/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | pass | solutions/agentsys/features.json:Parent/child agent delegation | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/agentsys/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/agentsys/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |

### Barkain Workflow Orchestrator (`barkain-workflow-orchestrator`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/barkain-workflow-orchestrator/features.json:Workflow composition | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/barkain-workflow-orchestrator/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | unknown | solutions/barkain-workflow-orchestrator/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/barkain-workflow-orchestrator/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/barkain-workflow-orchestrator/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/barkain-workflow-orchestrator/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/barkain-workflow-orchestrator/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |

### Cavekit v3.1 (`cavekit-v31`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/cavekit-v31/features.json:Workflow composition | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/cavekit-v31/features.json:Skill/plugin marketplace,IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | fail | solutions/cavekit-v31/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/cavekit-v31/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | fail | solutions/cavekit-v31/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/cavekit-v31/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/cavekit-v31/features.json:IDE-native integration,Skill/plugin marketplace | low | 2026-07-22 | address-all-non-coi-pass |

### Deepwork (`deepwork`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/deepwork/features.json:Workflow composition | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/deepwork/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | fail | solutions/deepwork/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/deepwork/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/deepwork/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/deepwork/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/deepwork/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |

### Director (`director`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/director/features.json:Workflow composition | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/director/features.json:Skill/plugin marketplace,IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | unknown | solutions/director/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/director/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/director/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/director/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/director/features.json:IDE-native integration,Skill/plugin marketplace | low | 2026-07-22 | address-all-non-coi-pass |

### MetaGPT (`metagpt`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | unknown | solutions/metagpt/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | unknown | solutions/metagpt/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | unknown | solutions/metagpt/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/metagpt/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/metagpt/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/metagpt/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | unknown | solutions/metagpt/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |

### Silver Bullet (`silver-bullet`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/silver-bullet/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/silver-bullet/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/silver-bullet/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | pass | solutions/silver-bullet/scr.md + features.json | high | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | pass | solutions/silver-bullet/features.json:Parent/child agent delegation | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/silver-bullet/features.json:Automated review loops,Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/silver-bullet/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### Turboshovel (`turboshovel`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/turboshovel/features.json:Workflow composition | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/turboshovel/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | fail | solutions/turboshovel/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/turboshovel/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/turboshovel/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/turboshovel/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/turboshovel/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |

### Workflow Manager (`workflow-manager`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/workflow-manager/features.json:Workflow composition | low | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/workflow-manager/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | unknown | solutions/workflow-manager/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/workflow-manager/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | fail | solutions/workflow-manager/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | unknown | solutions/workflow-manager/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/workflow-manager/features.json:IDE-native integration | low | 2026-07-22 | address-all-non-coi-pass |

### cc10x (`cc10x`) — apo

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/cc10x/features.json:Workflow composition | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/cc10x/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/cc10x/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/cc10x/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/cc10x/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/cc10x/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/cc10x/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### BMAD-METHOD (`bmad`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/bmad/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/bmad/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/bmad/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/bmad/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/bmad/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/bmad/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/bmad/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### Claude Harness (`claude-harness`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/claude-harness/features.json:Workflow composition | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/claude-harness/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/claude-harness/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/claude-harness/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | fail | solutions/claude-harness/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/claude-harness/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/claude-harness/features.json:IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |

### GSD (Get Shit Done) (`gsd`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/gsd/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/gsd/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/gsd/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/gsd/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/gsd/scr.md + features null | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/gsd/features.json:Automated review loops,Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/gsd/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### GitHub Spec Kit (`spec-kit`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/spec-kit/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/spec-kit/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/spec-kit/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/spec-kit/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | fail | solutions/spec-kit/features.json (supported=false) | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/spec-kit/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/spec-kit/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### Oh My Pi (OMP) (`oh-my-pi`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/oh-my-pi/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/oh-my-pi/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/oh-my-pi/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/oh-my-pi/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | pass | solutions/oh-my-pi/features.json:Parent/child agent delegation | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/oh-my-pi/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/oh-my-pi/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### Ruflo (formerly Claude Flow) (`ruflo`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/ruflo/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/ruflo/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/ruflo/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/ruflo/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | pass | solutions/ruflo/features.json:Parent/child agent delegation | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/ruflo/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/ruflo/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### Silver Bullet (`silver-bullet`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/silver-bullet/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/silver-bullet/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/silver-bullet/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | pass | solutions/silver-bullet/scr.md + features.json | high | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | pass | solutions/silver-bullet/features.json:Parent/child agent delegation | medium | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/silver-bullet/features.json:Automated review loops,Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/silver-bullet/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### SuperClaude (`superclaude`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/superclaude/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/superclaude/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/superclaude/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/superclaude/scr.md (keyword hint only — not feature-verified) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/superclaude/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/superclaude/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/superclaude/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### Superpowers (`superpowers`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/superpowers/features.json:Workflow composition,Prebuilt SDLC templates | medium | 2026-07-22 | address-all-non-coi-pass |
| Plugin / skill / hook packaging | pass | solutions/superpowers/features.json:Skill/plugin marketplace,IDE-native integration | medium | 2026-07-22 | address-all-non-coi-pass |
| Deterministic quality gates | pass | solutions/superpowers/features.json:Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Cross-session state | unknown | solutions/superpowers/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Specialist agent orchestration | unknown | solutions/superpowers/features.json/scr.md (insufficient evidence) | low | 2026-07-22 | address-all-non-coi-pass |
| Quality / release enforcement claim | pass | solutions/superpowers/features.json:Automated review loops,Hook-enforced gates | medium | 2026-07-22 | address-all-non-coi-pass |
| Process layer above host runtime | pass | solutions/superpowers/features.json:IDE-native integration,Skill/plugin marketplace | medium | 2026-07-22 | address-all-non-coi-pass |

### Zuvo (`zuvo`) — sdlc-plugins

| Criterion | Status | Source | Confidence | Date | Reviewer |
|-----------|--------|--------|------------|------|----------|
| Multi-phase lifecycle span | pass | solutions/zuvo/features.json:Workflow composition | medium | 2026-08-14 | act-on-critique-artifacts |
| Plugin / skill / hook packaging | pass | https://zuvo.dev/ + solutions/zuvo/features.json:IDE-native / hooks | medium | 2026-08-14 | act-on-critique-artifacts |
| Deterministic quality gates | pass | solutions/zuvo/features.json:Hook-enforced gates | medium | 2026-08-14 | act-on-critique-artifacts |
| Cross-session state | unknown | solutions/zuvo/features.json/scr.md (insufficient evidence) | low | 2026-08-14 | act-on-critique-artifacts |
| Specialist agent orchestration | pass | solutions/zuvo/features.json:Parent/child agent delegation | medium | 2026-08-14 | act-on-critique-artifacts |
| Quality / release enforcement claim | unknown | solutions/zuvo/scr.md (insufficient evidence) | low | 2026-08-14 | act-on-critique-artifacts |
| Process layer above host runtime | pass | https://zuvo.dev/ → sdlc-plugins core, not APO | medium | 2026-08-14 | act-on-critique-artifacts |
