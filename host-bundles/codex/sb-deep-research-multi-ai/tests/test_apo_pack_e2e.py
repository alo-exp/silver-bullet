"""End to end on an APO category-pack run through the public entry points only.

No test fixture, no patching: a need profile that selects the pack, worker envelopes (real claims
from the repo's own research run plus the phrasings the pack's prose parsers read), and
``package_solution_outputs``. This is the production configuration of every code path the
pack vocabulary activates (R12-21).
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from package_solution_outputs import package_solution_outputs  # noqa: E402

PACK_ID = "agentic-sdlc-process-orchestrator"

REAL_CLAIMS = [
    "Startup-weighted comparison matrix should weight cross-host coverage (SB), lifecycle span depth (SB, Devin, Factory), "
    "deterministic gate enforcement (SB, cc10x, Devin), and plugin-ecosystem size (SB, Oh My plugins) as the top "
    "differentiators — with SB leading on 3 of 4 and Devin leading on lifecycle span.",
    "Each APO candidate's compatibility with host runtimes (Claude Code, Codex, Cursor, Copilot) is not systematically mapped. "
    "Integration breadth is a key differentiator for APO. Silver Bullet's multi-host support is a strength that needs competitive context.",
    "Silver Bullet is the deepest APO by process-lattice span: 85+ canonical skills, deterministic hooks, cross-session agentmemory, "
    "specialist subagent routing, and plugin/skill/hook packaging across Claude Code, Codex, and Cursor — covering all 7 inclusion "
    "criteria versus 4-5 for nearest peers.",
    "Zuvo is OSS-licensed (per query override: license is OSS, not commercial). It is a host-integrated skill/orchestration layer; "
    "satisfies plugin/skill/hook packaging + process layer above host runtime. Map to sdlc-plugins market despite category overlap.",
    "Adjacent-only band (LangGraph, CrewAI, MetaGPT, LangChain, AxonFlow, Cavekit v4) is excluded from Top-N/MQ/Wave/matrix per pack: "
    "they are generic agent frameworks without a shipped, enforced SDLC process product.",
    "Director is a primary-market APO candidate: agent orchestration, workflow composition.",
    "Factory provides SSO and audit logs while Devin offers managed hosting.",
]
# the phrasings the pack's prose parsers read (core set, matrix leaders, host runtime, checkmarks, rows)
PARSER_CLAIMS = [
    "Confirmed in-scope core set: devin, aider",
    "APO matrix leaders are devin and aider",
    "Host runtime: Cursor IDE and Claude Code",
    "Matrix — CI integration: cline",
    "Hook-enforced gates ✔ for openhands",
    "Matrix entry — Workflow composition: crewai, autogen but sweep does not",
    "matrix row 'Managed hosting': tembo",
    "Aider lacks audit logs entirely",
    "Devin is the pick satisfying all three matrix must-haves for the startup.",
]
ROWS = [
    {"vendor": "Silver Bullet", "feature": "Workflow composition", "supported": True},
    {"vendor": "Devin", "feature": "Workflow composition", "supported": True},
    {"vendor": "Devin", "feature": "Managed hosting", "supported": True},
    {"vendor": "Director", "feature": "Hook-enforced gates", "supported": True},
    {"vendor": "MetaGPT", "feature": "Workflow composition", "supported": False},
]


def envelope(model, phase, payload):
    return {"schema_id": "dr-phase-contribution-envelope-v1", "logical_model_id": model, "phase_id": phase,
            "work_item_id": f"w-{model}-{phase}", "model_family_id": f"fam-{model}", "payload": payload}


class ApoPackRunTests(unittest.TestCase):
    def package(self, need, claims=REAL_CLAIMS + PARSER_CLAIMS):
        env = {"SB_SKIP_VENDOR_URL_HEALTH": "1", "SB_SKIP_LANDSCAPE_PDF": "1", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1"}
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, env):
            out = Path(tmp) / "run"
            (out / "contributions").mkdir(parents=True)
            (out / "need_profile.json").write_text(json.dumps(need), encoding="utf-8")
            (out / "scope.md").write_text("# Research scope\n\nResearch topic: APO landscape\n", encoding="utf-8")
            (out / "run_manifest.json").write_text(json.dumps({"query": "APO landscape", "research_type": "solution-landscape", "run_id": "r"}), encoding="utf-8")
            envelopes = [
                envelope("m1", "DR-RETRIEVE", {"evidence": [{"claim": c} for c in claims]}),
                envelope("m2", "DR-TRIANGULATE", {"claim_candidates": [{"text": c} for c in claims], "matrix_entries": ROWS}),
                envelope("m3", "DR-CRITIQUE", {"critiques": [{"finding": c} for c in claims[:3]], "matrix_entries": ROWS}),
            ]
            (out / "contributions" / "all-envelopes.json").write_text(json.dumps(envelopes), encoding="utf-8")
            try:
                result = package_solution_outputs(out, skip_xlsx=True)
            except ValueError as exc:  # the content gate: a thin evidence base does not cover every seed
                result = {"status": "gate-failed", "error": str(exc)}
            read = lambda rel: json.loads((out / rel).read_text(encoding="utf-8"))  # noqa: E731
            return result, {
                "comparison": read("comparison/comparison.json"),
                "audit": read("landscape/catalog_audit.json"),
                "report": (out / "landscape" / "landscape-report.md").read_text(encoding="utf-8"),
                "need": read("need_profile.json"),
            }

    def test_pack_run_packages_with_real_claims_and_keeps_the_primary_market_seeds(self) -> None:
        result, got = self.package({"category_pack_id": PACK_ID, "must_haves": ["workflow composition"]})
        # a thin evidence base legitimately leaves other seeds as gaps; the ones the claims name are not among them
        self.assertEqual(result["status"], "gate-failed", result)
        self.assertIn("must_research gaps", result["error"])
        for named in ("director", "cursor"):
            self.assertNotIn(f"'{named}'", result["error"])
        self.assertEqual(got["need"], {"category_pack_id": PACK_ID, "must_haves": ["workflow composition"]})  # never rewritten
        by_slug = got["audit"]["by_slug"]
        # "Director is ..." and the structured row name the Director seed: it stays core, Cursor is evidenced
        self.assertEqual(by_slug["director"]["classification"], "core")
        self.assertNotEqual(by_slug["cursor"]["reason"], "core_seed without envelope evidence (gap)")
        # an "SDLC" mention is a category word, not the Zuvo vendor
        self.assertNotIn("sdlc", {r["solution"] for r in got["comparison"]["rankings"]})
        rows = [r for r in got["comparison"]["rows"] if r.get("type") == "feature" and "composition" in r["name"].lower()]
        self.assertEqual(len(rows), 1)  # one folded row, ranked as the user's Critical must-have
        self.assertEqual(rows[0]["priority"], "Critical")
        self.assertIn("priority-weighted", got["report"])
        self.assertNotIn("startup-weighted score", got["report"])


if __name__ == "__main__":
    unittest.main()
