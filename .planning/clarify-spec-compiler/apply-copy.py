#!/usr/bin/env python3
"""Apply remaining copy patches for clarify-spec-compiler. Idempotent."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(rel: str, old: str, new: str) -> None:
    path = ROOT / rel
    text = path.read_text()
    if new in text and old not in text:
        print(f"SKIP already applied: {rel}")
        return
    if old not in text:
        raise SystemExit(f"MISSING in {rel}: {old[:90]!r}")
    path.write_text(text.replace(old, new, 1))
    print(f"OK {rel}")


def main() -> None:
    create_old = (
        "**Create:** `/silver:spec` (Socratic elicitation) or `/silver:ingest` "
        "(external artifact ingestion from JIRA/Figma/Google Docs)"
    )
    create_new = (
        "**Create:** `/silver:clarify --spec` (interview) then `/silver:spec` "
        "(compile canonical artifacts), or `/silver:ingest` "
        "(external artifact ingestion from JIRA/Figma/Google Docs) then clarify `next=spec` then spec"
    )
    table_old = (
        "| Spec elicitation | SPEC.md | /artifact-reviewer --reviewer review-spec | YES | /silver:spec Step 7 |"
    )
    table_new = (
        "| Spec compile | SPEC.md | /artifact-reviewer --reviewer review-spec | YES | /silver:spec Step 7 |"
    )
    for rel in ("silver-bullet.md", "templates/silver-bullet.md.base"):
        replace_once(rel, create_old, create_new)
        replace_once(rel, table_old, table_new)

    spec = "site/help/workflows/silver-spec.html"
    replace_once(
        spec,
        "<title>/silver:spec &mdash; Spec Elicitation Workflow &mdash; Silver Bullet Help</title>",
        "<title>/silver:spec &mdash; Spec Compiler &mdash; Silver Bullet Help</title>",
    )
    replace_once(
        spec,
        '<meta name="description" content="Silver Bullet spec elicitation workflow: Socratic discovery, assumptions, SPEC.md, REQUIREMENTS.md, optional DESIGN.md, and artifact review before SB planning.">',
        '<meta name="description" content="Silver Bullet spec compiler: reads the newest clarify brief and any ingest draft, writes SPEC.md and REQUIREMENTS.md from SPEC acceptance criteria, optional DESIGN.md, and artifact review before SB planning.">',
    )
    replace_once(
        spec,
        "<p>Socratic spec elicitation workflow that produces canonical <code>.planning/SPEC.md</code> and <code>.planning/REQUIREMENTS.md</code> before implementation begins.</p>",
        "<p>Spec compiler that produces canonical <code>.planning/SPEC.md</code> and <code>.planning/REQUIREMENTS.md</code> from the newest clarify brief (and any ingest draft) before implementation begins.</p>",
    )
    replace_once(
        spec,
        "<p><code>/silver:spec</code> implements catalog atomic flow <code>AF-SPECIFY</code>. It guides a product-style elicitation session, records assumptions, writes the canonical spec artifacts, and runs artifact review before downstream planning consumes the result.</p>",
        "<p><code>/silver:spec</code> implements catalog atomic flow <code>AF-SPECIFY</code>. It is a compiler: it reads the newest <code>*-CLARIFY-*.md</code> brief plus any ingest SPEC draft, writes the canonical spec artifacts, and runs artifact review before downstream planning consumes the result. Interviewing lives in <code>/silver:clarify --spec</code>.</p>",
    )
    replace_once(
        spec,
        "<p>It does not implement code. Its job is to turn a fuzzy or formal product request into traceable planning inputs.</p>",
        "<p>It does not implement code and does not run the 9-turn interview. Its job is to compile a decision-ready brief into traceable planning inputs.</p>",
    )
    replace_once(
        spec,
        """  <li><strong>Mode detection:</strong> detect greenfield vs augment mode by checking whether <code>.planning/SPEC.md</code> already exists.</li>
  <li><strong>Context gathering:</strong> collect feature name, description, and optional JIRA, Figma, Google Doc, or presentation links.</li>
  <li><strong>Spec scaffold:</strong> use the SB spec scaffold to establish a formal product spec structure.</li>
  <li><strong>Socratic elicitation:</strong> ask structured questions across problem, user goal, scope boundary, user stories, acceptance criteria, edge cases, error states, data model, and open questions.</li>
  <li><strong>Assumption consolidation:</strong> resolve, accept, or tag every assumption before writing the spec.</li>
  <li><strong>Artifact injection:</strong> incorporate available source artifacts and record inaccessible sources explicitly.</li>
  <li><strong>Write and review artifacts:</strong> write SPEC.md, derive REQUIREMENTS.md, optionally write DESIGN.md, then run artifact review to two consecutive clean passes.</li>""",
        """  <li><strong>Mode detection:</strong> detect greenfield vs augment mode by checking whether <code>.planning/SPEC.md</code> already exists, and load the newest <code>*-CLARIFY-*.md</code> brief plus any ingest draft.</li>
  <li><strong>Compile inputs:</strong> map the clarify capture schema (and ingest SPEC dump, if any) onto the SB spec scaffold. Do not re-run the 9-turn interview.</li>
  <li><strong>Domain completeness:</strong> treat problem, scope, stories, and AC in the brief as covered. Gap-fill questions only for required SPEC sections that are still empty.</li>
  <li><strong>Assumption consolidation:</strong> honor statuses from the brief; resolve, accept, or tag remaining assumptions before writing the spec.</li>
  <li><strong>Artifact injection:</strong> incorporate available source artifacts and record inaccessible sources explicitly.</li>
  <li><strong>Write and review artifacts:</strong> write SPEC.md, derive REQUIREMENTS.md from SPEC acceptance criteria, optionally write DESIGN.md, then run artifact review to two consecutive clean passes.</li>""",
    )
    replace_once(
        spec,
        "  <li>Socratic elicitation minimum coverage</li>",
        "  <li>Consume newest clarify brief when present (brief-domain completeness, not a live turn-counter)</li>",
    )

    replace_once(
        "site/help/workflows/silver-ingest.html",
        "<p>After ingestion, run <code>/silver:spec</code> if the imported material needs additional elicitation, or <code>/silver:validate</code> if plans already exist and need coverage analysis.</p>",
        "<p>After ingestion, run <code>/silver:clarify --spec</code> (or <code>--next spec</code>) to interview, then <code>/silver:spec</code> to compile, or <code>/silver:validate</code> if plans already exist and need coverage analysis.</p>",
    )
    replace_once(
        "site/help/workflows/silver-ingest.html",
        """<div class="code-block">/silver:ingest PROJ-123
/silver:spec Augment the checkout recovery spec from ingested artifacts
/silver:validate</div>""",
        """<div class="code-block">/silver:ingest PROJ-123
/silver:clarify --spec Interview remaining spec domains from ingested artifacts
/silver:spec Compile SPEC.md and REQUIREMENTS.md
/silver:validate</div>""",
    )

    replace_once(
        "site/help/workflows/index.html",
        '<a href="silver-clarify.html" class="workflow-card"><h4>/silver:clarify</h4><p>Fuzzy-intent intake and decision-ready brief (<code>CLARIFY</code>)</p></a>',
        '<a href="silver-clarify.html" class="workflow-card"><h4>/silver:clarify</h4><p>Light FLOW 3 brief, or <code>next=spec</code> interview before compile (<code>CLARIFY</code>)</p></a>',
    )
    replace_once(
        "site/help/workflows/index.html",
        '<a href="silver-spec.html" class="workflow-card"><h4>/silver:spec</h4><p>SPEC.md and REQUIREMENTS.md (<code>SPECIFY</code>)</p></a>',
        '<a href="silver-spec.html" class="workflow-card"><h4>/silver:spec</h4><p>Compile canonical SPEC.md and REQUIREMENTS.md (<code>SPECIFY</code>)</p></a>',
    )

    replace_once(
        "site/help/search.js",
        '"text": "Spec workflow creates a canonical SPEC.md with requirements, acceptance criteria, assumptions, source links, and artifact review before SB planning."',
        '"text": "Spec compiler reads the newest clarify brief and writes canonical SPEC.md and REQUIREMENTS.md from SPEC acceptance criteria, with artifact review before SB planning."',
    )

    # clarify help
    cl = ROOT / "site/help/workflows/silver-clarify.html"
    t = cl.read_text()
    if 'id="next-spec"' in t:
        print("SKIP already applied: silver-clarify.html")
        return
    old_overview = """      <p><code>/silver:clarify</code> implements catalog atomic flow <code>AF-CLARIFY</code>. It merges product framing, option generation, and convergence into a single workflow — the front end of planning before <code>AF-ORIENT</code>, <code>AF-PLAN</code>, or composed workflows like <code>/silver:feature</code> continue.</p>
      <p>It does not implement work or write phase plans. It helps compare options, pressure-test assumptions, and lock a recommendation. If the topic is visual or diagram-heavy, it can offer the browser-based visual companion before the deeper questions begin.</p>"""
    new_overview = """      <p><code>/silver:clarify</code> implements catalog atomic flow <code>AF-CLARIFY</code>. Default mode is light FLOW 3: product framing, option generation, and a decision-ready brief before <code>AF-ORIENT</code>, <code>AF-PLAN</code>, or composed workflows continue.</p>
      <p>When composition is heading to <code>AF-SPECIFY</code>, ingest just ran, or the user asked for a spec, <code>--spec</code> / <code>--next spec</code> owns the full spec interview (context + Turns 1–9 + assumption protocol) and writes only a timestamped clarify brief. It does not write <code>SPEC.md</code> or <code>REQUIREMENTS.md</code> — <code>/silver:spec</code> compiles those.</p>"""
    if old_overview not in t:
        raise SystemExit("clarify overview missing")
    t = t.replace(old_overview, new_overview)
    old_side = """        <li><a href="#modes">Modes</a></li>
        <li><a href="#output">Output</a></li>"""
    new_side = """        <li><a href="#modes">Modes</a></li>
        <li><a href="#next-spec">next=spec</a></li>
        <li><a href="#output">Output</a></li>"""
    t = t.replace(old_side, new_side)
    old_modes = """        <li><strong>Chain</strong> - continues directly into <code>/silver:context</code> and <code>/silver:plan</code> when the handoff is ready.</li>
      </ul>"""
    new_modes = """        <li><strong>Chain</strong> - continues directly into <code>/silver:context</code> and <code>/silver:plan</code> when the handoff is ready. In <code>next=spec</code> mode, chain continues into <code>/silver:spec</code>.</li>
        <li><strong>Spec (<code>--spec</code> / <code>--next spec</code>)</strong> - full document-authoring interview. Auto-detected when <code>.planning/INGESTION_MANIFEST.md</code> exists or composition is heading to AF-SPECIFY.</li>
      </ul>"""
    t = t.replace(old_modes, new_modes)
    insert = """
      <div class="divider"></div>

      <h2 id="next-spec">next=spec</h2>
      <p>Clarify owns all spec interviewing. The brief must include Overview (who + problem), at least one <code>As a…</code> user story, at least one testable acceptance criterion, assumptions with <code>Status:</code>, out of scope, edges, errors, data, and open questions. Light FLOW 3 (research, content, new-workflow, decide/compare) does <strong>not</strong> attach the 9 spec turns. Need-profile interview stays on AF-DECIDE paths only.</p>
      <div class="code-block">/silver:clarify --spec Add scheduled report exports for admins
/silver:clarify --next spec</div>
"""
    t = t.replace('      <h2 id="output">Output</h2>', insert + '      <h2 id="output">Output</h2>', 1)
    old_out = """      <p>The main artifact is a plan-scoped clarify brief: <code>.planning/{plan-basename}-CLARIFY-{YYMMDD}-{timestamp}.md</code>. It should contain the problem framing, options considered, recommendation, and any follow-up questions that still need SB planning.</p>"""
    new_out = """      <p>The main artifact is a plan-scoped clarify brief: <code>.planning/{plan-basename}-CLARIFY-{YYMMDD}-{timestamp}.md</code>. Light mode: problem framing, options, recommendation, follow-ups. <code>next=spec</code> mode: capture schema that <code>/silver:spec</code> can compile into review-spec-passing SPEC.md. This skill never writes SPEC.md or REQUIREMENTS.md.</p>"""
    if old_out not in t:
        raise SystemExit("clarify output missing")
    t = t.replace(old_out, new_out)
    cl.write_text(t)
    print("OK site/help/workflows/silver-clarify.html")


if __name__ == "__main__":
    main()
