"""Test-only vendor catalogues.

The product ships no built-in vendor lists (R12-02). Tests that exercise the code paths
taking a catalogue (vendor buckets, link pairs, value-curve series) patch these lists in.
"""

from __future__ import annotations

import functools
from unittest import mock

COMMERCIAL_CATALOG: list[dict[str, str]] = [
    {"slug": "factory-ai", "name": "Factory.ai", "url": "https://www.factory.ai/"},
    {"slug": "devin", "name": "Devin (Cognition)", "url": "https://devin.ai/"},
    {"slug": "github-copilot-workspace", "name": "GitHub Copilot Workspace", "url": "https://githubnext.com/projects/copilot-workspace"},
    {"slug": "cursor-agents", "name": "Cursor Background Agents", "url": "https://cursor.com/docs/background-agent"},
    {"slug": "sweep-ai", "name": "Sweep", "url": "https://sweep.dev/"},
    {"slug": "tembo", "name": "Tembo", "url": "https://tembo.io/"},
    {"slug": "replit-agent", "name": "Replit Agent", "url": "https://replit.com/"},
    {"slug": "windsurf", "name": "Windsurf (Codeium)", "url": "https://codeium.com/windsurf"},
    {"slug": "tabnine-enterprise", "name": "Tabnine Enterprise", "url": "https://www.tabnine.com/"},
    {"slug": "amazon-q-developer", "name": "Amazon Q Developer", "url": "https://aws.amazon.com/q/developer/"},
    {"slug": "sourcegraph-cody", "name": "Sourcegraph Cody", "url": "https://sourcegraph.com/cody"},
    {"slug": "augment-code", "name": "Augment Code", "url": "https://www.augmentcode.com/"},
    {"slug": "poolside", "name": "Poolside", "url": "https://poolside.ai/"},
    {"slug": "coderabbit", "name": "CodeRabbit", "url": "https://coderabbit.ai/"},
    {"slug": "jetbrains-ai", "name": "JetBrains AI Assistant", "url": "https://www.jetbrains.com/ai/"},
    {"slug": "github-copilot-enterprise", "name": "GitHub Copilot Enterprise", "url": "https://github.com/features/copilot"},
    {"slug": "cognition-scout", "name": "Cognition Scout", "url": "https://cognition.ai/"},
    {"slug": "linear-agent", "name": "Linear Agent Integrations", "url": "https://linear.app/"},
]

OSS_CATALOG: list[dict[str, str]] = [
    {"slug": "openhands", "name": "OpenHands", "license": "MIT", "url": "https://github.com/All-Hands-AI/OpenHands"},
    {"slug": "langgraph-platform", "name": "LangGraph Platform", "license": "Open Core", "url": "https://www.langchain.com/langgraph"},
    {"slug": "crewai", "name": "CrewAI", "license": "MIT", "url": "https://github.com/crewAIInc/crewAI"},
    {"slug": "metagpt", "name": "MetaGPT", "license": "MIT", "url": "https://github.com/FoundationAgents/MetaGPT"},
    {"slug": "spec-kit", "name": "GitHub spec-kit", "license": "MIT", "url": "https://github.com/github/spec-kit"},
    {"slug": "cline", "name": "Cline", "license": "Apache 2.0", "url": "https://github.com/cline/cline"},
    {"slug": "continue", "name": "Continue", "license": "Apache 2.0", "url": "https://github.com/continuedev/continue"},
    {"slug": "autogen", "name": "Microsoft AutoGen", "license": "MIT", "url": "https://github.com/microsoft/autogen"},
    {"slug": "gsd", "name": "GSD (Get Shit Done)", "license": "MIT", "url": "https://github.com/gsd-build/get-shit-done"},
    {"slug": "bmad-method", "name": "BMAD-METHOD", "license": "MIT", "url": "https://github.com/bmad-code-org/BMAD-METHOD"},
    {"slug": "aider", "name": "Aider", "license": "Apache 2.0", "url": "https://github.com/paul-gauthier/aider"},
    {"slug": "swe-agent", "name": "SWE-agent", "license": "MIT", "url": "https://github.com/SWE-agent/SWE-agent"},
    {"slug": "semantic-kernel", "name": "Semantic Kernel", "license": "MIT", "url": "https://github.com/microsoft/semantic-kernel"},
    {"slug": "gpt-engineer", "name": "GPT-Engineer", "license": "MIT", "url": "https://github.com/gpt-engineer-org/gpt-engineer"},
    {"slug": "praisonai", "name": "PraisonAI", "license": "MIT", "url": "https://github.com/MervinPraison/PraisonAI"},
    {"slug": "superagent", "name": "Superagent", "license": "MIT", "url": "https://github.com/homanp/superagent"},
    {"slug": "agentgpt", "name": "AgentGPT", "license": "GPL-3.0", "url": "https://github.com/reworkd/AgentGPT"},
    {"slug": "langchain", "name": "LangChain", "license": "MIT", "url": "https://github.com/langchain-ai/langchain"},
    {"slug": "open-interpreter", "name": "Open Interpreter", "license": "AGPL-3.0", "url": "https://github.com/OpenInterpreter/open-interpreter"},
    {"slug": "devika", "name": "Devika", "license": "MIT", "url": "https://github.com/stitionai/devika"},
]


def with_legacy_catalogs(cls):
    """Class decorator: run every test with the fixture catalogues installed in synthesize_landscape."""
    import synthesize_landscape as sl
    from category_pack import load_pack_overlay

    # chart geometry these tests were written against: the APO pack's default axis profile
    apo = {k: tuple(v) if isinstance(v, list) else v
           for k, v in load_pack_overlay("agentic-sdlc-process-orchestrator")["market_chart_profiles"]["apo"].items()}
    import materialize_solution_artifacts as mat

    overlay = load_pack_overlay("agentic-sdlc-process-orchestrator")
    vendor_data = {
        "KNOWN_SOLUTIONS": dict(overlay["known_solutions"]),
        "OVERVIEW_SEEDS": dict(overlay["overview_seeds"]),
        "SLUG_ALIASES": dict(overlay["slug_aliases"]),
        "_HEAD_SLUG_ALIASES": dict(overlay["head_slug_aliases"]),
    }
    mat_patch = mock.patch.multiple(mat, **vendor_data)
    sl_patch = mock.patch.multiple(sl, KNOWN_SOLUTIONS=vendor_data["KNOWN_SOLUTIONS"], OVERVIEW_SEEDS=vendor_data["OVERVIEW_SEEDS"])
    patcher = mock.patch.multiple(
        sl,
        _NEUTRAL_CHART_PROFILE=apo,
        COMMERCIAL_CATALOG=COMMERCIAL_CATALOG,
        OSS_CATALOG=OSS_CATALOG,
        COMMERCIAL_SLUGS=frozenset(e["slug"] for e in COMMERCIAL_CATALOG),
        OSS_SLUGS=frozenset(e["slug"] for e in OSS_CATALOG),
        NON_COMMERCIAL_SLUGS=frozenset(e["slug"] for e in OSS_CATALOG),
    )
    import pack_vocabulary

    values = pack_vocabulary.converted(overlay["vocabulary"])

    def with_vocabulary(test):
        @functools.wraps(test)
        def run(*args, **kwargs):
            with pack_vocabulary.apply_values(values):
                return test(*args, **kwargs)

        return run

    for name, value in list(vars(cls).items()):
        if name.startswith("test") and callable(value):
            setattr(cls, name, mat_patch(sl_patch(patcher(with_vocabulary(value)))))
    return cls
