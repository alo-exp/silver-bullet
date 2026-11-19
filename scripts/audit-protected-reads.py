#!/usr/bin/env python3
"""Audit of every place that reads a protected value live (docs/ENFORCEMENT.md, "Protected-read audit").

Protected values: the state file, the trivial marker (and any config-given trivial path), .silver-bullet.json (every key),
silver-bullet.md, the unlock. A gate must read them only through the verified record (hooks/lib/integrity.sh:
sb_integrity_gate + sb_iv_jq / SB_IV_* / sb_integrity_state_contents / sb_integrity_trivial_ok).

  audit-protected-reads.py [--rev REV] [--json] [--markdown] [--check FIXTURE]

Every line outside the allowlist that reads a protected value directly is a row. A row is Y (reads the verified record),
A (the integrity machinery itself, allowlisted), X (not an enforcement decision, with the reason) or N (a bug). The test
tests/hooks/test-integrity-audit.sh fails on any N row and on any row the fixture does not know.
"""
import glob, json, os, re, subprocess, sys

ROOT = os.environ.get("SB_AUDIT_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CFGVAR = r'(?:config_file|cfg|sb_cfg|config|conf|_cfg|cfg_file|config_path|scope_config|[A-Za-z_]*_config|[A-Za-z_]*_cfg|[A-Za-z_]*config_file)'
READ_PATTERNS = [
    ("config", re.compile(r'\bjq\b[^\n]*"\$\{?' + CFGVAR + r'\b')),
    ("config", re.compile(r'\.silver-bullet\.json["\']?[^\n]*\|\s*jq|\bjq\b[^\n]*\.silver-bullet\.json|<\s*"?[^\s"]*\.silver-bullet\.json')),
    ("config", re.compile(r'-[fer]\s+"?\$\{?[A-Za-z_]*\}?/\.silver-bullet\.json|-[fer]\s+"[^"]*\.silver-bullet\.json')),
    ("config", re.compile(r'\$[a-z_]*dir/\.silver-bullet\.json')),
    ("config", re.compile(r'open\([^)]*silver-bullet\.json|json\.loads?\([^)]*(?:config|silver-bullet)|\b(?:cat|grep|head|sed|awk)\b[^\n]*\.silver-bullet\.json')),
    ("md", re.compile(r'-[fer]\s+"?[^\s"]*silver-bullet\.md|\b(?:cat|grep|head|sed|awk)\b[^\n]*silver-bullet\.md|<\s*"?[^\s"]*silver-bullet\.md')),
    ("roadmap", re.compile(r'\b(?:cat|grep|head|sed|awk|wc)\b[^\n]*ROADMAP\.md|-[fer]\s+"[^"]*ROADMAP\.md|<\s*"?[^\s"]*ROADMAP\.md')),
    ("instruction", re.compile(r'\b(?:cat|grep|head|sed|awk)\b[^\n]*(?:CLAUDE|AGENTS)\.md|-[fer]\s+"[^"]*(?:CLAUDE|AGENTS)\.md')),
    ("state", re.compile(r'\b(?:cat|head|tail|wc -l\s*<|grep[^|]*)\s+"?\$\{?(?:state_file|STATE_FILE)\b|<\s*"?\$\{?(?:state_file|STATE_FILE)\b')),
    ("state", re.compile(r'\b(?:cat|head|tail|grep|sed|awk)\b[^\n]*"?\$\{?(?:SB_RUNTIME_STATE_DIR|SB_STATE_DIR|_sb_state_dir)\}?/state["\s]')),
    ("trivial", re.compile(r'-[fe]\s+"?\$\{?(?:trivial_file|_trivial_file|TRIVIAL_FILE|_bypass_trivial)\b|-[fe]\s+"\$\{?SB_[A-Z_]*\}?/trivial')),
    ("unlock", re.compile(r'contract-unlock["\']?\s*(?:\]|\))|>\s*"?[^\s"]*contract-unlock')),
]
# a line that also names a live path is never class Y
LIVE_PATH = re.compile(r'\.silver-bullet\.json|silver-bullet\.md|\$\{?(?:config_file|cfg|state_file|STATE_FILE|trivial_file)\b|ROADMAP\.md|CLAUDE\.md|AGENTS\.md|SB_RUNTIME_STATE_DIR\}?/(?:state|trivial)')

# (path glob or exact path) -> (disposition, reason). First match wins.
RULES = [
    ("hooks/lib/integrity.sh", "A", "the integrity machinery: reads the live files to verify and to record them"),
    ("hooks/lib/integrity-anchor.sh", "A", "the integrity machinery: where the project is (record, contract files, git tracking)"),
    ("hooks/lib/state-seal.sh", "A", "the integrity machinery: the state seal"),
    ("hooks/lib/sb-project-gate.sh", "A", "activation helper: record-aware project lookup (root with a record wins)"),
    ("hooks/lib/project-active.sh", "A", "activation helper: record-aware"),
    ("hooks/lib/trivial-bypass.sh", "A", "reads the marker only after sb_integrity_verify blesses it"),
    ("hooks/lib/contract-unlock.sh", "A", "declares the contract skills; the unlock itself lives in the record"),
    ("hooks/session-start", "A", "the trust anchor: baselines the record at the end of session start"),
    ("hooks/record-skill.sh", "A", "sanctioned writer: keeps the record in step"),
    ("hooks/flow-advance.sh", "A", "sanctioned writer: re-baselines the config it edits"),
    ("hooks/lib/enforcement-tier-gate.sh", "X", "the tier is min(configured, probed): a live value can only lower it; excluded from the record (hooks keep it)"),
        ("hooks/lib/completion-audit/*", "X", "reads $config_file, which completion-audit.sh sets to the verified snapshot"),
        ("hooks/lib/agentmemory-gate.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/graphify-gate.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/rtk-gate.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/rtk-compat.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/context-mode-*.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/leanctx-gate.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/alumnium-gate.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/token-compression-tools-gate.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/stack-*.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/recommended-tools*.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
                        ("hooks/lib/planning-floor.sh", "X", "reads the verified record (sb_integrity_verify + sb_iv_jq)"),
    ("hooks/graphify-gate.sh", "X", "tool consent gate (.recommended_tools)"),
    ("hooks/agentmemory-gate.sh", "X", "tool consent gate (.recommended_tools)"),
    ("hooks/rtk-gate.sh", "X", "tool consent gate (.recommended_tools)"),
    ("hooks/leanctx-gate.sh", "X", "tool consent gate (.recommended_tools)"),
    ("hooks/context-mode-*.sh", "X", "tool consent gate (.recommended_tools)"),
    ("hooks/token-compression-tools-gate.sh", "X", "tool consent gate (.recommended_tools)"),
    ("hooks/stack-compression-coordinator.sh", "X", "tool consent gate (.recommended_tools)"),
    ("hooks/alumnium-gate.sh", "X", "tool consent gate (.recommended_tools)"),
    ("hooks/record-*-usage.sh", "X", "records tool usage into the consent block"),
    ("hooks/record-graphify-query.sh", "X", "records tool usage into the consent block"),
    ("hooks/record-recommended-mcp.sh", "X", "records tool usage into the consent block"),
    ("hooks/industry-tooling-hint.sh", "X", "advisory hint, no gate decision"),
    ("hooks/compliance-status.sh", "X", "informational progress line, no gate decision"),
    ("hooks/session-log-init.sh", "X", "session log bookkeeping, no gate decision"),
    ("hooks/semantic-compress.sh", "X", "advisory, no gate decision"),
    ("skills/*", "X", "agent-run skill instruction (not a hook gate): it reads tracker, consent or verify keys, and every write goes through the contract guard"),
    ("scripts/*", "X", "user-run or skill-run script, not a hook gate"),
]
# lines matched anywhere that are fine because the value was already verified
VERIFIED_LINE = re.compile(r'sb_iv_jq|SB_IV_|sb_integrity_|\$SB_IV_CONFIG_FILE|verified_config_file')


# per-line exceptions: (file, regex on the line) -> reason. Each is a presence test that makes no trust decision.
LINE_RULES = [
    ("hooks/lib/opt-in-gate.sh", re.compile(r'trivial_file'), "the config trivial path is handed to sb_trivial_bypass, which ignores it once the project has a record (only an install without a record honours it)"),
    ("hooks/dev-cycle-check.sh", re.compile(r'post_work=true'), "wake-up test: the presence of the marker only makes PostToolUse run the verification; it never trusts the marker"),
    ("hooks/flow-advance.sh", re.compile(r'\.silver-bullet\.json'), "writes the one key (.project.active_workflow) in the live file after the RECORDED config said devops-cycle; the record changes by that key only"),
    ("hooks/lib/context-mode-read-deny.sh", re.compile(r'state_file|trivial_file'), "token-saving read gate: exempts the named runtime files from the read-size deny; it decides no planning or delivery gate"),
    ("hooks/lib/context-mode-read-deny.sh", re.compile(r'recommended_tools'), "tool consent key (.recommended_tools): kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/orchestrator-parent.sh", re.compile(r'orchestrator_mode'), "orchestrator parent mode: an extra directive layer; the planning floor and the delivery gates do not depend on it"),
    ("hooks/lib/enterprise-policy.sh", re.compile(r'active_profile|evidence_schema'), "handed the root's config path by the delivery tier only after the drift check proved it equals the record; session and prompt callers print advisory text with it"),
    ("hooks/lib/prerequisite-probe.sh", re.compile(r'silver-bullet'), "installer prerequisite probe: reports a missing contract file, decides no gate"),
    ("hooks/lib/required-skills.sh", re.compile(r'\$\{cfg\}'), "reads the TEMPLATE's default lists (templates/silver-bullet.config.json.default), not a project file"),
    ("hooks/lib/required-skills.sh", re.compile(r'"\$config_file"'), "only when no project was verified (a standalone caller); a verified gate reads the record"),
    ("hooks/lib/session-ledger.sh", re.compile(r'search_dir'), "session log bookkeeping: finds the project directory for the ledger file, decides no gate"),
    ("hooks/lib/site-session.sh", re.compile(r'search_dir'), "site-session bookkeeping: finds the project directory, decides no gate"),
]


def classify(path, line):
    for pat, rx, why in [(f, r, w) for f, r, w in LINE_RULES]:
        if path == pat and rx.search(line):
            return "X", why
    for pat, disp, why in RULES:
        if glob.fnmatch.fnmatch(path, pat):
            return disp, why
    if VERIFIED_LINE.search(line) and not LIVE_PATH.search(line):
        return "Y", "reads the verified record"
    return "N", "reads a protected value live"


def read(path, rev):
    if rev:
        return subprocess.run(["git", "-C", ROOT, "show", f"{rev}:{path}"], capture_output=True, text=True).stdout
    return open(os.path.join(ROOT, path), errors="replace").read()


def files(rev):
    if rev:
        out = subprocess.run(["git", "-C", ROOT, "ls-tree", "-r", "--name-only", rev, "hooks", "scripts", "skills"], capture_output=True, text=True).stdout.split()
        cands = [f for f in out if f.endswith((".sh", ".py")) or f == "hooks/session-start" or (f.startswith("skills/") and f.endswith("/SKILL.md"))]
    else:
        cands = sorted(set(glob.glob("hooks/**/*.sh", root_dir=ROOT, recursive=True) + glob.glob("hooks/**/*.py", root_dir=ROOT, recursive=True)
                           + glob.glob("scripts/*.sh", root_dir=ROOT) + glob.glob("skills/*/SKILL.md", root_dir=ROOT) + ["hooks/session-start"]))
        cands = [f for f in cands if os.path.isfile(os.path.join(ROOT, f))]
    return sorted(cands)


def scan(rev=None):
    rows = []
    for f in files(rev):
        text = read(f, rev)
        for i, l in enumerate(text.splitlines(), 1):
            s = l.strip()
            if not s or s.startswith("#"):
                continue
            for kind, pat in READ_PATTERNS:
                if pat.search(l):
                    disp, why = classify(f, l)
                    rows.append({"file": f, "line": i, "kind": kind, "snippet": s[:160], "record": disp, "reason": why})
                    break
    return rows


def main():
    rev = None
    args = sys.argv[1:]
    if "--rev" in args:
        rev = args[args.index("--rev") + 1]
    rows = scan(rev)
    if "--check" in args:
        fx = json.load(open(args[args.index("--check") + 1]))
        known = {(r["file"], r["snippet"]) for r in fx["rows"]}
        bad = [r for r in rows if r["record"] == "N"]
        unknown = [r for r in rows if (r["file"], r["snippet"]) not in known]
        stale = [r for r in fx["rows"] if (r["file"], r["snippet"]) not in {(x["file"], x["snippet"]) for x in rows}]
        for r in bad: print("N  %s:%s %s" % (r["file"], r["line"], r["snippet"]))
        for r in unknown: print("NEW %s:%s %s" % (r["file"], r["line"], r["snippet"]))
        for r in stale: print("STALE %s %s" % (r["file"], r["snippet"]))
        sys.exit(1 if (bad or unknown or stale) else 0)
    if "--markdown" in args:
        print("| file:line | value read | how it is used | verified record | disposition |\n|---|---|---|---|---|")
        for r in rows:
            print("| %s:%s | %s | `%s` | %s | %s |" % (r["file"], r["line"], r["kind"], r["snippet"].replace("|", "\\|")[:90], r["record"], r["reason"]))
        return
    from collections import Counter
    c = Counter(r["record"] for r in rows)
    n_rows = ["N  %s:%s [%s] %s" % (x["file"], x["line"], x["kind"], x["snippet"]) for x in rows if x["record"] == "N"]
    report = "\n".join(["%s %s" % (dict(c), len(rows))] + n_rows)
    print(json.dumps({"counts": c, "rows": rows}, indent=1) if "--json" in args else report)


if __name__ == "__main__":
    main()
