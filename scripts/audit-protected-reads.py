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

READ_PATTERNS = [
    ("config", re.compile(r'\bjq\b[^\n]*"\$\{?(?:config_file|cfg|sb_cfg|config|_cfg|cfg_file|config_path|scope_config)\b')),
    ("config", re.compile(r'\.silver-bullet\.json["\']?[^\n]*\|\s*jq|\bjq\b[^\n]*\.silver-bullet\.json|<\s*"?[^\s"]*\.silver-bullet\.json')),
    ("config", re.compile(r'-[fer]\s+"?\$\{?[A-Za-z_]*\}?/\.silver-bullet\.json|-[fer]\s+"[^"]*\.silver-bullet\.json')),
    ("config", re.compile(r'\$search_dir/\.silver-bullet\.json')),
    ("md", re.compile(r'-[fer]\s+"?[^\s"]*silver-bullet\.md')),
    ("state", re.compile(r'\b(?:cat|head|tail|wc -l\s*<|grep[^|]*)\s+"?\$\{?(?:state_file|STATE_FILE)\b|<\s*"?\$\{?(?:state_file|STATE_FILE)\b')),
    ("trivial", re.compile(r'-[fe]\s+"?\$\{?(?:trivial_file|_trivial_file|TRIVIAL_FILE|_bypass_trivial)\b|-[fe]\s+"\$\{?SB_[A-Z_]*\}?/trivial')),
    ("unlock", re.compile(r'contract-unlock["\']?\s*(?:\]|\))|>\s*"?[^\s"]*contract-unlock')),
]

# (path glob or exact path) -> (disposition, reason). First match wins.
RULES = [
    ("hooks/lib/integrity.sh", "A", "the integrity machinery: reads the live files to verify and to record them"),
    ("hooks/lib/state-seal.sh", "A", "the integrity machinery: the state seal"),
    ("hooks/lib/sb-project-gate.sh", "A", "activation helper: record-aware project lookup (root with a record wins)"),
    ("hooks/lib/project-active.sh", "A", "activation helper: record-aware"),
    ("hooks/lib/trivial-bypass.sh", "A", "reads the marker only after sb_integrity_verify blesses it"),
    ("hooks/lib/contract-unlock.sh", "A", "declares the contract skills; the unlock itself lives in the record"),
    ("hooks/session-start", "A", "the trust anchor: baselines the record at the end of session start"),
    ("hooks/record-skill.sh", "A", "sanctioned writer: keeps the record in step"),
    ("hooks/flow-advance.sh", "A", "sanctioned writer: re-baselines the config it edits"),
    ("hooks/lib/enforcement-tier-gate.sh", "X", "the tier is min(configured, probed): a live value can only lower it; excluded from the record (hooks keep it)"),
    ("hooks/lib/enterprise-policy.sh", "X", "receives the verified snapshot from the delivery gates (completion-audit); other callers print advisory text"),
    ("hooks/lib/completion-audit/*", "X", "reads $config_file, which completion-audit.sh sets to the verified snapshot"),
    ("hooks/lib/orchestrator-*.sh", "X", "orchestrator directives: an extra layer; absence of a directive never relaxes the planning floor"),
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
    ("hooks/lib/opt-in-gate.sh", "X", "tool consent (.recommended_tools), kept by the hooks themselves and excluded from the record"),
    ("hooks/lib/prerequisite-probe.sh", "X", "installer probe, no gate decision"),
    ("hooks/lib/session-ledger.sh", "X", "session log bookkeeping, no gate decision"),
    ("hooks/lib/site-session.sh", "X", "site-session bookkeeping; activation through the record-aware helper in the hook"),
    ("hooks/lib/required-skills.sh", "X", "reads the template's default lists; reads the project's version through the verified record when one was verified"),
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
    ("scripts/*", "X", "user-run or skill-run script, not a hook gate"),
]
# lines matched anywhere that are fine because the value was already verified
VERIFIED_LINE = re.compile(r'sb_iv_jq|SB_IV_|sb_integrity_|\$SB_IV_CONFIG_FILE|verified_config_file')


# per-line exceptions: (file, regex on the line) -> reason. Each is a presence test that makes no trust decision.
LINE_RULES = [
    ("hooks/dev-cycle-check.sh", re.compile(r'post_work=true'), "wake-up test: the presence of the marker only makes PostToolUse run the verification; it never trusts the marker"),
]


def classify(path, line):
    for pat, rx, why in [(f, r, w) for f, r, w in LINE_RULES]:
        if path == pat and rx.search(line):
            return "X", why
    for pat, disp, why in RULES:
        if glob.fnmatch.fnmatch(path, pat):
            return disp, why
    if VERIFIED_LINE.search(line):
        return "Y", "reads the verified record"
    return "N", "reads a protected value live"


def read(path, rev):
    if rev:
        return subprocess.run(["git", "-C", ROOT, "show", f"{rev}:{path}"], capture_output=True, text=True).stdout
    return open(os.path.join(ROOT, path), errors="replace").read()


def files(rev):
    if rev:
        out = subprocess.run(["git", "-C", ROOT, "ls-tree", "-r", "--name-only", rev, "hooks", "scripts"], capture_output=True, text=True).stdout.split()
        cands = [f for f in out if f.endswith(".sh") or f == "hooks/session-start"]
    else:
        cands = sorted(set(glob.glob("hooks/**/*.sh", root_dir=ROOT, recursive=True) + glob.glob("scripts/*.sh", root_dir=ROOT) + ["hooks/session-start"]))
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
    if "--json" in args:
        json.dump({"counts": c, "rows": rows}, sys.stdout, indent=1)
    else:
        print(dict(c), len(rows))
        for r in rows:
            if r["record"] == "N": print("N  %s:%s [%s] %s" % (r["file"], r["line"], r["kind"], r["snippet"]))


if __name__ == "__main__":
    main()
