"""Contract tests for multi-ai-task-v2 primitive."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
REGISTRY = SKILL_ROOT / "reference" / "model-family-registry-v1.json"
sys.path.insert(0, str(SCRIPTS))


class MultiAiContractTests(unittest.TestCase):
    def test_registry_has_eleven_slot_mappings(self) -> None:
        data = json.loads(REGISTRY.read_text(encoding="utf-8"))
        cursor = data["cursor_default_pool"]
        lite = data["ocg_lite_pool"]
        self.assertEqual(len(cursor), 6)
        self.assertGreaterEqual(len(lite), 1)
        env = {**dict(__import__("os").environ), "SB_HOST": "cursor"}
        dry = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "multi_ai_cli.py"),
                "--output-root",
                "/tmp/sb-multi-ai-dry-run-test",
                "--dry-run",
            ],
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )
        self.assertEqual(dry.returncode, 0, dry.stderr)
        report = json.loads(dry.stdout)
        self.assertTrue(report["ok"])
        self.assertEqual(report["spine"], "multi-ai-task-v2")
        self.assertEqual(report["resolved_count"], 11)

    def test_spine_constant_in_manifest_schema(self) -> None:
        schema = json.loads((SKILL_ROOT / "schemas" / "multi-ai-work-item-manifest-v1.schema.json").read_text())
        self.assertEqual(schema["properties"]["spine"]["const"], "multi-ai-task-v2")

    def test_empty_pool_selection_is_rejected(self) -> None:
        # The lite/regular mutex needs no check: --ocg-pool takes a single choice.
        from multi_ai_core import PoolSelection, resolve_pool

        with self.assertRaises(ValueError):
            resolve_pool(PoolSelection(ocg_pool="none", cursor_pool="none"))

    def test_skill_md_cli_block_runs_as_documented(self) -> None:
        """R11-15: the documented command must work exactly as written (with placeholders filled)."""
        import os
        import re
        import shlex
        import tempfile

        text = (SKILL_ROOT / "SKILL.md").read_text(encoding="utf-8")
        section = text.split("## CLI contract", 1)[1]
        block = re.search(r"```bash\n(.*?)```", section, re.DOTALL).group(1)
        with tempfile.TemporaryDirectory() as tmp:
            command = block.replace("\\\n", " ").replace("<run-id>", "probe").replace("<task brief>", "probe task")
            argv = shlex.split(command)
            self.assertEqual(argv[:2], ["python3", "skills/silver-multi-ai-task/scripts/multi_ai_cli.py"])
            repo = SKILL_ROOT.parents[1]
            proc = subprocess.run(
                [sys.executable, str(repo / argv[1]), *argv[2:]],
                capture_output=True, text=True, check=False, cwd=tmp,
                env={**os.environ, "SB_HOST": "cursor"},
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertTrue(json.loads(proc.stdout)["ok"])
            self.assertEqual(os.listdir(tmp), [], "a dry run must not write anything")
        # Every flag in the documented flag table is accepted by the CLI.
        documented = set(re.findall(r"^\| `(--[a-z-]+)", section, re.MULTILINE))
        help_text = subprocess.run(
            [sys.executable, str(SCRIPTS / "multi_ai_cli.py"), "--help"], capture_output=True, text=True, check=True
        ).stdout
        self.assertGreaterEqual(len(documented), 10)
        for flag in documented:
            self.assertIn(flag, help_text)
        # Referenced schema files exist.
        for ref in re.findall(r"`(multi-ai-[a-z-]+-v1)`", text):
            self.assertTrue((SKILL_ROOT / "schemas" / f"{ref}.schema.json").is_file(), ref)

    def test_glm_alias_normalization(self) -> None:
        from multi_ai_core import normalize_logical_id

        self.assertEqual(normalize_logical_id("sb-dr-glm-5.2"), "glm-5.2")
        self.assertEqual(normalize_logical_id("ocg-glm-5.2"), "glm-5.2")

    def test_host_gate_rejects_claude_with_cursor_sb_host(self) -> None:
        import os
        from unittest import mock

        from multi_ai_core import host_gate

        with mock.patch.dict(
            os.environ,
            {"SB_HOST": "cursor", "CLAUDECODE": "1"},
            clear=False,
        ):
            gate = host_gate()
        self.assertFalse(gate["ok"])
        self.assertEqual(gate["host"], "claude-code")

    def test_dry_run_report_skips_host_gate_enforcement(self) -> None:
        import os
        from unittest import mock

        from multi_ai_core import PoolSelection, dry_run_report

        with mock.patch.dict(
            os.environ,
            {"SB_HOST": "cursor", "CLAUDECODE": "1"},
            clear=False,
        ):
            report = dry_run_report(PoolSelection())
        self.assertTrue(report["ok"])
        self.assertFalse(report["host_gate_enforced"])
        self.assertNotIn("host_gate", report)

    def test_regular_and_default_pool_no_glm_duplicate(self) -> None:
        from multi_ai_core import PoolSelection, resolve_pool

        resolved = resolve_pool(PoolSelection(ocg_pool="regular", cursor_pool="default"), subscription="auto")
        glm_ids = [x["logical_model_id"] for x in resolved if x["logical_model_id"] == "glm-5.2"]
        self.assertEqual(len(glm_ids), 1)


if __name__ == "__main__":
    unittest.main()
