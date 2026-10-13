#!/usr/bin/env python3
"""
Deep Research Engine — STATE SCAFFOLD (not a runtime orchestrator)

Loads phases.yaml/json SSoT, exposes phase instructions, and manages
phase_manifest.json. Claude/host is the orchestrator.

See reference/methodology.md and phases.yaml.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional


SKILL_ROOT = Path(__file__).resolve().parent.parent


class ResearchPhase(Enum):
    """Nine DR phases aligned with SKILL.md DR-* steps."""
    SCOPE = "scope"
    PLAN = "plan"
    RETRIEVE = "retrieve"
    TRIANGULATE = "triangulate"
    OUTLINE = "outline"
    SYNTHESIZE = "synthesize"
    CRITIQUE = "critique"
    REFINE = "refine"
    PACKAGE = "package"


class ResearchMode(Enum):
    QUICK = "quick"
    STANDARD = "standard"
    DEEP = "deep"
    ULTRADEEP = "ultradeep"


PHASE_ID_MAP = {
    ResearchPhase.SCOPE: "DR-SCOPE",
    ResearchPhase.PLAN: "DR-PLAN",
    ResearchPhase.RETRIEVE: "DR-RETRIEVE",
    ResearchPhase.TRIANGULATE: "DR-TRIANGULATE",
    ResearchPhase.OUTLINE: "DR-OUTLINE",
    ResearchPhase.SYNTHESIZE: "DR-SYNTHESIZE",
    ResearchPhase.CRITIQUE: "DR-CRITIQUE",
    ResearchPhase.REFINE: "DR-REFINE",
    ResearchPhase.PACKAGE: "DR-PACKAGE",
}


def load_phases_config() -> dict[str, Any]:
    json_path = SKILL_ROOT / "phases.json"
    if json_path.exists():
        with open(json_path, encoding="utf-8") as f:
            return json.load(f)
    yaml_path = SKILL_ROOT / "phases.yaml"
    if yaml_path.exists():
        try:
            import yaml  # type: ignore
        except ImportError as exc:
            raise RuntimeError("phases.json missing and PyYAML not installed") from exc
        with open(yaml_path, encoding="utf-8") as f:
            return yaml.safe_load(f)
    raise FileNotFoundError("phases.json or phases.yaml required")


@dataclass
class Source:
    url: str
    title: str
    snippet: str
    retrieved_at: str
    credibility_score: float = 0.0
    source_type: str = "web"
    verification_status: str = "unverified"

    def to_citation(self, index: int) -> str:
        return f"[{index}] {self.title} - {self.url} (Retrieved: {self.retrieved_at})"


@dataclass
class ResearchState:
    query: str
    mode: ResearchMode
    phase: ResearchPhase
    scope: Dict[str, Any]
    plan: Dict[str, Any]
    sources: List[Source]
    findings: List[Dict[str, Any]]
    synthesis: Dict[str, Any]
    critique: Dict[str, Any]
    report: str
    metadata: Dict[str, Any]

    def save(self, filepath: Path) -> None:
        max_retries = 3
        for attempt in range(max_retries):
            try:
                with open(filepath, 'w', encoding='utf-8') as f:
                    json.dump(self._serialize(), f, indent=2)
                return
            except (IOError, OSError) as e:
                if attempt == max_retries - 1:
                    raise IOError(f"Failed to save state after {max_retries} attempts: {e}") from e
                time.sleep((attempt + 1) * 0.5)

    def _serialize(self) -> dict:
        return {
            'query': self.query,
            'mode': self.mode.value,
            'phase': self.phase.value,
            'scope': self.scope,
            'plan': self.plan,
            'sources': [asdict(s) for s in self.sources],
            'findings': self.findings,
            'synthesis': self.synthesis,
            'critique': self.critique,
            'report': self.report,
            'metadata': self.metadata,
        }

    @classmethod
    def load(cls, filepath: Path) -> 'ResearchState':
        with open(filepath, encoding='utf-8') as f:
            data = json.load(f)
        return cls(
            query=data['query'],
            mode=ResearchMode(data['mode']),
            phase=ResearchPhase(data['phase']),
            scope=data['scope'],
            plan=data['plan'],
            sources=[Source(**s) for s in data['sources']],
            findings=data['findings'],
            synthesis=data['synthesis'],
            critique=data['critique'],
            report=data['report'],
            metadata=data['metadata'],
        )


class ResearchEngine:
    """Phase instruction scaffold — not a runtime orchestrator."""

    def __init__(self, mode: ResearchMode = ResearchMode.STANDARD):
        self.mode = mode
        self.config = load_phases_config()
        self.state: Optional[ResearchState] = None

    def phases_for_mode(self, mode: Optional[ResearchMode] = None) -> List[ResearchPhase]:
        mode = mode or self.mode
        keys = self.config.get("modes", {}).get(mode.value, {}).get("phases", [])
        return [ResearchPhase(k) for k in keys]

    def phase_metadata(self, phase: ResearchPhase) -> dict[str, Any]:
        return self.config.get("phases", {}).get(phase.value, {})

    def get_phase_instructions(self, phase: ResearchPhase) -> str:
        meta = self.phase_metadata(phase)
        phase_id = meta.get("id", PHASE_ID_MAP.get(phase, phase.value))
        artifacts = ", ".join(meta.get("required_artifacts", []))
        checks = "\n".join(f"- {c}" for c in meta.get("vloop_checks", []))
        return f"""# {phase_id}: {meta.get('name', phase.value.upper())}

Required artifacts: {artifacts or 'none'}

V-loop checks:
{checks or '- (see phases.yaml)'}

Load reference/methodology.md for full activities.
Output directory: $SB_RESEARCH_OUT_DIR (research/<date>-<slug>/)
"""

    def write_phase_manifest(self, out_dir: Path, mode: Optional[ResearchMode] = None) -> Path:
        mode = mode or self.mode
        manifest_path = out_dir / "phase_manifest.json"
        phases = []
        for phase in self.phases_for_mode(mode):
            meta = self.phase_metadata(phase)
            phases.append({
                "key": phase.value,
                "id": meta.get("id"),
                "name": meta.get("name"),
                "required_artifacts": meta.get("required_artifacts", []),
                "status": "pending",
            })
        payload = {
            "version": self.config.get("version", "1.0.0"),
            "mode": mode.value,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "phases": phases,
        }
        out_dir.mkdir(parents=True, exist_ok=True)
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)
        return manifest_path

    def read_phase_manifest(self, out_dir: Path) -> dict[str, Any]:
        path = out_dir / "phase_manifest.json"
        if not path.exists():
            raise FileNotFoundError(f"phase_manifest.json not found in {out_dir}")
        with open(path, encoding="utf-8") as f:
            return json.load(f)

    def initialize_research(self, query: str) -> ResearchState:
        self.state = ResearchState(
            query=query,
            mode=self.mode,
            phase=ResearchPhase.SCOPE,
            scope={},
            plan={},
            sources=[],
            findings=[],
            synthesis={},
            critique={},
            report="",
            metadata={
                'started_at': datetime.now(timezone.utc).isoformat(),
                'version': self.config.get('version', '1.0.0'),
            },
        )
        return self.state

    def execute_phase(self, phase: ResearchPhase) -> Dict[str, Any]:
        instructions = self.get_phase_instructions(phase)
        print(instructions)
        return {
            'phase': phase.value,
            'phase_id': PHASE_ID_MAP.get(phase),
            'status': 'instructions_displayed',
            'timestamp': datetime.now(timezone.utc).isoformat(),
        }

    def run_pipeline(self, query: str, out_dir: Optional[Path] = None) -> str:
        self.initialize_research(query)
        out_dir = out_dir or Path(".planning/research/offline-run")
        self.write_phase_manifest(out_dir)
        for phase in self.phases_for_mode():
            self.state.phase = phase  # type: ignore[union-attr]
            self.execute_phase(phase)
        return str(out_dir / "research_report.md")


def main() -> None:
    parser = argparse.ArgumentParser(description="Deep Research Engine scaffold")
    parser.add_argument('--query', '-q', type=str, help='Research question')
    parser.add_argument('--mode', '-m', choices=['quick', 'standard', 'deep', 'ultradeep'], default='standard')
    parser.add_argument('--out-dir', type=str, help='Research output directory')
    parser.add_argument('--manifest-only', action='store_true', help='Write phase_manifest.json only')
    parser.add_argument('--phase', type=str, help='Print instructions for one phase')
    parser.add_argument('--list-phases', action='store_true', help='List phases for mode')
    args = parser.parse_args()

    mode = ResearchMode(args.mode)
    engine = ResearchEngine(mode=mode)

    if args.list_phases:
        for p in engine.phases_for_mode():
            meta = engine.phase_metadata(p)
            print(f"{meta.get('id', p.value)}: {p.value}")
        return

    if args.phase:
        phase = ResearchPhase(args.phase)
        print(engine.get_phase_instructions(phase))
        return

    if args.manifest_only:
        if not args.out_dir:
            print("Error: --out-dir required with --manifest-only", file=sys.stderr)
            sys.exit(1)
        path = engine.write_phase_manifest(Path(args.out_dir), mode)
        print(f"Wrote {path}")
        return

    if not args.query:
        parser.error('--query required unless --manifest-only, --list-phases, or --phase')

    out = Path(args.out_dir) if args.out_dir else None
    report = engine.run_pipeline(args.query, out)
    print(f"Pipeline scaffold complete. Target report: {report}")


if __name__ == '__main__':
    main()
