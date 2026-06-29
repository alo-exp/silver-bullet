#!/usr/bin/env python3
"""TUI friction monitor — Round 4 full matrix (rows 1-22).

Poll 60-90s, status every 10min, max 6h. Exits when all matrix rows complete or batch dead.
Interventions: ensure watch/monitor, TERM hung expect (>45min stale log). Never login/logout.
"""
import glob
import json
import os
import random
import re
import subprocess
import sys
import time
from datetime import datetime, timezone

SB = os.environ.get("SB_ROOT", "/Users/shafqat/projects/silver-bullet/repo")
os.chdir(SB)

RETRY_ROWS = set(range(1, 23))  # full Round 4 matrix rows 1-22
FINDINGS = ".e2e-tui-watch-findings.jsonl"
OFFSET_FILE = ".planning/enterprise-e2e/.tui-monitor-agent-offset.json"
LEDGER = os.environ.get(
    "SB_E2E_LEDGER_FILE", ".planning/enterprise-e2e/ROUND-4-LEDGER.md"
)
STATUS = ".planning/enterprise-e2e/.tui-monitor-agent-status.jsonl"
ISSUES_APPEND = os.path.join(SB, "scripts", "lib", "enterprise-e2e-issues-append.py")
MATRIX_LOG = os.environ.get("SB_E2E_MATRIX_LOG", ".e2e-matrix-live.log")
REPORT = ".planning/enterprise-e2e/.tui-monitor-batch-final-report.md"
LOG = ".planning/enterprise-e2e/.tui-monitor-agent-run.log"

POLL_MIN, POLL_MAX = 60, 90
STATUS_INTERVAL = 600
MAX_RUNTIME = 21600
HUNG_SEC = 2700
FIX_SHAS = ("fa48f52f",)
BATCH_START_TS = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def reset_monitor_offsets():
    """Seek row-log + findings offsets to EOF so historical attempt logs are not replayed."""
    offsets = {}
    for path in sorted(glob.glob(".e2e-row*-attempt.log")):
        key = os.path.basename(path)
        offsets[key] = os.path.getsize(path) if os.path.isfile(path) else 0
    with open(os.path.join(SB, ".e2e-tui-watch-offsets.json"), "w", encoding="utf-8") as f:
        json.dump(offsets, f, indent=2)
    findings_lines = 0
    if os.path.isfile(FINDINGS):
        with open(FINDINGS, encoding="utf-8") as f:
            findings_lines = sum(1 for _ in f)
    with open(OFFSET_FILE, "w", encoding="utf-8") as f:
        json.dump(
            {"findings_line": findings_lines, "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "reset_reason": "round_start"},
            f,
        )
    print(f"reset monitor offsets: {len(offsets)} row logs, findings_line={findings_lines}", flush=True)
    return offsets, findings_lines


ROW_SLUGS = {
    1: "silver-router", 2: "silver-research", 3: "silver-feature", 4: "silver-bugfix",
    5: "silver-ui", 6: "silver-fast", 7: "silver-test", 8: "silver-refactor",
    9: "silver-benchmark", 10: "silver-content", 11: "silver-devops", 12: "silver-deploy",
    13: "silver-canary", 14: "silver-release", 15: "review-triad", 16: "ship-readiness",
    17: "silver-incident", 18: "silver-retro", 19: "silver-forensics", 20: "process-maintenance",
    21: "post-exec-gates", 22: "validate-substep",
}
ledger_synced = set()

start_epoch = time.time()
last_status_epoch = start_epoch
cycle = 0
seen_friction = set()
friction_entries = []
row_results = {}  # row -> pass|fail
exit_reason = None

initial_log_size = os.path.getsize(MATRIX_LOG) if os.path.isfile(MATRIX_LOG) else 0
row_log_baselines = {}
reset_monitor_offsets()
for r in RETRY_ROWS:
    p = f".e2e-row{r}-attempt.log"
    row_log_baselines[r] = os.path.getsize(p) if os.path.isfile(p) else 0


def log(msg):
    line = f"{utc_now()} {msg}\n"
    with open(LOG, "a") as f:
        f.write(line)
    print(msg, flush=True)


def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def alive(pid):
    if not pid:
        return False
    try:
        os.kill(int(pid), 0)
        return True
    except (OSError, ValueError):
        return False


def read_pid(path):
    if not os.path.isfile(path):
        return ""
    return open(path).read().strip()


def ensure_watch():
    pid = read_pid(".e2e-tui-watch.pid")
    if alive(pid):
        return
    out = subprocess.run(["pgrep", "-f", "watch-enterprise-e2e-tui.sh"], capture_output=True, text=True)
    if not out.stdout.strip():
        env = os.environ.copy()
        env["SB_E2E_LEDGER_NO_UX_APPEND"] = "1"
        subprocess.Popen(
            ["bash", "scripts/watch-enterprise-e2e-tui.sh"],
            stdin=subprocess.DEVNULL,
            stdout=open(".e2e-tui-watch-restart.log", "a"),
            stderr=subprocess.STDOUT,
            start_new_session=True,
            env=env,
        )
        time.sleep(2)
        out = subprocess.run(["pgrep", "-f", "watch-enterprise-e2e-tui.sh"], capture_output=True, text=True)
    if out.stdout.strip():
        open(".e2e-tui-watch.pid", "w").write(out.stdout.strip().split()[0])
        log(f"INTERVENTION restarted watch pid={out.stdout.strip().split()[0]}")


def ensure_pending_driver():
    """Respawn round4 pending-rows driver when batch dies mid-matrix."""
    driver = ".planning/enterprise-e2e/round4-pending-rows-driver.sh"
    if not os.path.isfile(driver):
        return False
    env = os.environ.copy()
    env.setdefault("SB_E2E_LEDGER_NO_UX_APPEND", "1")
    env.setdefault("SB_E2E_MATRIX_FORCE", "1")
    env.setdefault("SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT", "0")
    env.setdefault("CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY", "arrow")
    env.setdefault("RTK_DISABLED", "1")
    env.setdefault("SB_E2E_SESSION0_SKIP", "1")
    env.setdefault(
        "SB_E2E_LEDGER_FILE",
        os.path.join(SB, ".planning/enterprise-e2e/ROUND-4-LEDGER.md"),
    )
    env.setdefault(
        "SB_TEST_ENTERPRISE_APP_ROOT",
        "/Users/shafqat/projects/enterprise-grade-test-app",
    )
    env.setdefault("SB_E2E_MATRIX_LOG", MATRIX_LOG)
    subprocess.Popen(
        ["bash", driver],
        stdin=subprocess.DEVNULL,
        stdout=open(".e2e-round4-driver-respawn.log", "a"),
        stderr=subprocess.STDOUT,
        start_new_session=True,
        env=env,
        cwd=SB,
    )
    time.sleep(5)
    out = subprocess.run(["pgrep", "-f", "run-enterprise-e2e-matrix.sh"], capture_output=True, text=True)
    pids = [p for p in out.stdout.strip().split() if p]
    if pids:
        open(".e2e-matrix-batch.pid", "w").write(pids[0])
        log(f"INTERVENTION restarted pending-rows driver pid={pids[0]}")
        return True
    return False


def ensure_monitor():
    batch_pid = read_pid(".e2e-matrix-batch.pid")
    if not alive(batch_pid):
        out = subprocess.run(["pgrep", "-f", "run-enterprise-e2e-matrix.sh"], capture_output=True, text=True)
        pids = [p for p in out.stdout.strip().split() if p]
        if pids:
            open(".e2e-matrix-batch.pid", "w").write(pids[-1])
            batch_pid = pids[-1]
    mon_pid = read_pid(".e2e-matrix-monitor.pid")
    if alive(batch_pid) and not alive(mon_pid):
        out = subprocess.run(["pgrep", "-f", "monitor-enterprise-e2e-matrix.sh"], capture_output=True, text=True)
        if not out.stdout.strip():
            subprocess.Popen(
                ["bash", "scripts/monitor-enterprise-e2e-matrix.sh"],
                stdin=subprocess.DEVNULL,
                stdout=open(".e2e-matrix-monitor-restart.log", "a"),
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            time.sleep(1)
            out2 = subprocess.run(["pgrep", "-f", "monitor-enterprise-e2e-matrix.sh"], capture_output=True, text=True)
            if out2.stdout.strip():
                open(".e2e-matrix-monitor.pid", "w").write(out2.stdout.strip().split()[0])
                log(f"INTERVENTION restarted monitor pid={out2.stdout.strip().split()[0]}")


def batch_alive():
    bp = read_pid(".e2e-matrix-batch.pid")
    if alive(bp):
        return True
    out = subprocess.run(["pgrep", "-f", "run-enterprise-e2e-matrix.sh"], capture_output=True, text=True)
    pids = [p for p in out.stdout.strip().split() if p]
    if pids:
        open(".e2e-matrix-batch.pid", "w").write(pids[-1])
        return True
    return False


def count_passes():
    if not os.path.isfile(LEDGER):
        return 0
    with open(LEDGER) as f:
        return sum(1 for line in f if "**Pass**" in line and re.match(r"^\| \d+ \|", line))


def sync_ledger_row(row, evidence=""):
    """Update human ledger when matrix log reports PASS."""
    if row in ledger_synced or row not in ROW_SLUGS:
        return False
    slug = ROW_SLUGS[row]
    if not os.path.isfile(LEDGER):
        return False
    text = open(LEDGER).read()
    if re.search(rf"\| {row} \| `{re.escape(slug)}` \|[^\n]*\*\*Pass\*\*", text):
        ledger_synced.add(row)
        return False
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    note = evidence or f"live FORCE @ {FIX_SHAS[0]}"
    pat = (
        rf"(\| {row} \| `{re.escape(slug)}` \|)[^|]*(\| haiku \|)[^|]*(\|)[^|]*(\|)[^|]*(\|)[^|]*"
        rf"(\| `graphify query \"{re.escape(slug)} routes hooks skills orchestrator\"` \| \|)"
    )
    repl = rf"\1 {date} \2 **Pass** \3 {note} \4 \5 \6"
    new_text, n = re.subn(pat, repl, text, count=1)
    if not n:
        return False
    passes = sum(1 for line in new_text.splitlines() if "**Pass**" in line and re.match(r"^\| \d+ \|", line))
    new_text = re.sub(
        r"^\*\*Pass count:\*\*.*$",
        f"**Pass count:** {passes} / 22 — **IN PROGRESS** (live FORCE matrix @ {FIX_SHAS[0]})",
        new_text,
        count=1,
        flags=re.M,
    )
    open(LEDGER, "w").write(new_text)
    ledger_synced.add(row)
    log(f"LEDGER_SYNC row={row} slug={slug} evidence={evidence[:60]}")
    return True


def count_matrix_log_passes():
    if not os.path.isfile(MATRIX_LOG):
        return 0
    with open(MATRIX_LOG) as f:
        return sum(1 for line in f if re.search(r"^\s*PASS:", line))


def active_row():
    logs = glob.glob(".e2e-row*-attempt.log")
    if not logs:
        return 0
    best = max(logs, key=lambda p: (os.path.getmtime(p), os.path.getsize(p)))
    m = re.search(r"row(\d+)", os.path.basename(best))
    return int(m.group(1)) if m else 0


def strip_ansi(raw):
    text = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", raw.decode("utf-8", errors="replace"))
    return re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", " ", text)


def classify_row_log(row):
    log_path = f".e2e-row{row}-attempt.log"
    if not os.path.isfile(log_path):
        return []
    full_raw = open(log_path, "rb").read()
    full_text = strip_ansi(full_raw)
    all_tokens = [int(x) for x in re.findall(r"(\d+)\s*tokens", full_text)]
    max_tok = max(all_tokens) if all_tokens else 0
    baseline = row_log_baselines.get(row, len(full_raw))
    # Only scan bytes written since round/monitor start — never replay historical logs.
    if baseline >= len(full_raw):
        return []
    raw = full_raw[baseline:]
    text = strip_ansi(raw)
    findings = []
    ts = utc_now()

    def emit(sev, comp, quote):
        findings.append({"row": row, "severity": sev, "component": comp, "quote": quote[:80], "ts": ts})

    if re.search(r"Unknown command:\s*/silver", text, re.I):
        emit("blocker", "routing", "Unknown command: /silver — slash route rejected")
    if re.search(r"Unknown skill|No such skill|skill is not registered", text, re.I):
        m = re.search(r"Unknown skill[^\\n]{0,60}|No such skill[^\\n]{0,40}", text, re.I)
        emit("blocker", "skill", (m.group(0) if m else "Unknown skill")[:80])
    if re.search(r"missing close-bracket|input_prompt_ready", text, re.I) and max_tok < 500:
        emit("blocker", "harness", "expect Tcl bracket error input_prompt_ready line 484")
    if re.search(r"SessionStart.*No such file|session-start.*No such file", text, re.I):
        emit("annoyance", "hook", "SessionStart hook script missing")
    if re.search(r"node:internal/modules/cjs/loader", text):
        emit("annoyance", "hook", "SessionStart node cjs/loader hook error")
    if re.search(r"hookEventName", text, re.I):
        emit("annoyance", "hook", "hookEventName missing on PostToolUse hook")
    if re.search(r"planning-file-guard", text, re.I):
        emit("blocker", "hook", "planning-file-guard blocked write")
    if re.search(r"API Error:.*429|Weekly usage limit", text, re.I):
        emit("info", "quota", "429 / weekly usage limit")
    tokens = [int(x) for x in re.findall(r"(\d+)\s*tokens", text)]
    seg_max = max(tokens) if tokens else 0
    if max_tok == 0 and seg_max == 0 and re.search(r"0\s*tokens", text):
        emit("blocker", "harness", "0-token stall — no workflow progress")
    elif max_tok >= 1000 and row == active_row():
        emit("info", "harness", f"active progress — {max_tok} tokens")
    if re.search(r"orchestrator.*parent|parent must not implement", text, re.I):
        emit("annoyance", "orchestrator", "dual-orchestrator parent inline deliberation")
    if re.search(r"SILVER BULLET.*ROUTING", text, re.I):
        emit("info", "routing", "SILVER BULLET routing banner seen")
    if re.search(r"/silver:bugfix|silver-bugfix", text, re.I) and row == 4:
        emit("info", "routing", "/silver:bugfix routing OK — workflow engaged")
    # product evidence
    for pat, ev in [
        (r"bugfix-health\.md", "docs/bugfix-health.md"),
        (r"refactor-order-validation\.md", ".planning/refactor-order-validation.md"),
        (r"CHANGELOG\.md", "CHANGELOG.md"),
        (r"triad-currency\.md", ".planning/reviews/triad-currency.md"),
        (r"ship-readiness/checklist\.md", ".planning/ship-readiness/checklist.md"),
    ]:
        if re.search(pat, text) and "Write" in text or "wrote" in text.lower():
            emit("info", "product", f"evidence touch: {ev}")
    return findings


def process_findings():
    offset = 0
    if os.path.isfile(OFFSET_FILE):
        offset = json.load(open(OFFSET_FILE)).get("findings_line", 0)
    entries = []
    if not os.path.isfile(FINDINGS):
        return entries
    lines = open(FINDINGS).readlines()
    for i, line in enumerate(lines, 1):
        if i <= offset:
            continue
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") in ("status", "final"):
            continue
        fts = obj.get("ts", "")
        if fts and fts < BATCH_START_TS:
            continue
        cat = obj.get("category", obj.get("component", "?"))
        row = obj.get("row", "?")
        sev = obj.get("severity", "info")
        quote = (obj.get("excerpt") or obj.get("message", ""))[:80].replace("|", "/").replace("\n", " ")
        entries.append({"row": row, "severity": sev, "component": cat, "quote": quote, "ts": obj.get("ts", utc_now())})
    json.dump({"findings_line": len(lines), "ts": utc_now()}, open(OFFSET_FILE, "w"))
    return entries


def append_issues_doc(row, severity, component, quote):
    if severity == "info" or not os.path.isfile(ISSUES_APPEND):
        return
    try:
        subprocess.run(
            [sys.executable, ISSUES_APPEND, severity, component, quote, str(row)],
            cwd=SB,
            capture_output=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def append_ledger(entries):
    # Round 4+: friction goes to status jsonl only — do not append to human ledger.
    return 0


def append_status(row, action, findings_new, blockers, note=""):
    pids = {}
    for name, path in [
        ("watch", ".e2e-tui-watch.pid"),
        ("monitor", ".e2e-matrix-monitor.pid"),
        ("batch", ".e2e-matrix-batch.pid"),
        ("lock", ".e2e-live-test.lock"),
    ]:
        if os.path.isfile(path):
            pids[name] = read_pid(path)
    exp = subprocess.run(["pgrep", "-f", "claude-interactive-invoke.expect"], capture_output=True, text=True)
    if exp.stdout.strip():
        pids["expect"] = exp.stdout.strip().split()[0]
    obj = {
        "ts": utc_now(),
        "row": row,
        "pids": pids,
        "findings_new": findings_new,
        "blockers": blockers[:10],
        "ledger": f"{count_passes()}/22",
        "action": action,
        "cycle": cycle,
        "fix_shas": list(FIX_SHAS),
        "retry_rows_done": len(row_results),
        "retry_rows_total": len(RETRY_ROWS),
    }
    if note:
        obj["note"] = note
    with open(STATUS, "a") as f:
        f.write(json.dumps(obj) + "\n")
    return obj


def check_hung_expect(row):
    log_path = f".e2e-row{row}-attempt.log"
    if not os.path.isfile(log_path):
        return
    mtime = os.path.getmtime(log_path)
    if time.time() - mtime < HUNG_SEC:
        return
    out = subprocess.run(["pgrep", "-f", "claude-interactive-invoke.expect"], capture_output=True, text=True)
    for pid in out.stdout.strip().split():
        subprocess.call(["kill", "-TERM", pid])
        log(f"INTERVENTION TERM expect {pid} row={row} hung>{HUNG_SEC}s")


def parse_new_matrix_results():
    """Parse PASS/FAIL for retry rows written since monitor start."""
    if not os.path.isfile(MATRIX_LOG):
        return
    size = os.path.getsize(MATRIX_LOG)
    if size <= initial_log_size:
        return
    with open(MATRIX_LOG) as f:
        f.seek(initial_log_size)
        new_content = f.read()
    current = None
    for line in new_content.splitlines():
        m = re.match(r"=== Row (\d+):", line)
        if m:
            current = int(m.group(1))
        elif current in RETRY_ROWS:
            if re.search(r"^\s*PASS:", line):
                row_results[current] = "pass"
                ev = re.sub(r"^\s*PASS:\s*", "", line.strip())
                sync_ledger_row(current, ev)
            elif line.strip().startswith("FAIL:"):
                row_results[current] = "fail"


def all_retry_rows_done():
    return RETRY_ROWS <= set(row_results.keys())


def collect_friction():
    entries = []
    for e in process_findings():
        key = (e["row"], e["component"], e["quote"][:40])
        if key not in seen_friction:
            seen_friction.add(key)
            entries.append(e)
            friction_entries.append(e)
    for r in RETRY_ROWS:
        for e in classify_row_log(r):
            key = (e["row"], e["component"], e["quote"][:40])
            if key not in seen_friction:
                seen_friction.add(key)
                entries.append(e)
                friction_entries.append(e)
    return entries


def filter_blockers(entries):
    blockers = [f"{e['component']}: {e['quote'][:50]}" for e in entries if e.get("severity") == "blocker"]
    progress_rows = {e["row"] for e in entries if e.get("component") == "harness" and "active progress" in e.get("quote", "")}
    if not progress_rows:
        return blockers
    filtered = []
    for b in blockers:
        skip = False
        for r in progress_rows:
            if b.startswith("harness:") and any(x in b for x in ("Tcl", "0-token", "stall")):
                # active row with progress — stale harness noise
                if r == active_row():
                    skip = True
                    break
        if not skip:
            filtered.append(b)
    return filtered


def write_final_report():
    pids = {
        "batch": read_pid(".e2e-matrix-batch.pid"),
        "watch": read_pid(".e2e-tui-watch.pid"),
        "monitor": read_pid(".e2e-matrix-monitor.pid"),
    }
    exp = subprocess.run(["pgrep", "-f", "claude-interactive-invoke.expect"], capture_output=True, text=True)
    if exp.stdout.strip():
        pids["expect"] = exp.stdout.strip().split()[0]

    lines = [
        f"# TUI Friction Monitor — Batch Final Report",
        "",
        f"**Generated:** {utc_now()}",
        f"**Exit reason:** {exit_reason}",
        f"**Cycles:** {cycle}",
        f"**Elapsed:** {int(time.time() - start_epoch)}s",
        f"**Fix SHAs:** {', '.join(FIX_SHAS)}",
        "",
        "## Process health",
        "",
        "| Component | PID | Alive |",
        "|-----------|-----|-------|",
    ]
    for name, pid in pids.items():
        lines.append(f"| {name} | {pid} | {alive(pid)} |")
    lines += [
        "",
        "## Retry batch row results",
        "",
        "| Row | Result | Friction |",
        "|-----|--------|----------|",
    ]
    for r in sorted(RETRY_ROWS):
        res = row_results.get(r, "pending")
        frictions = [f"{e['component']}: {e['quote'][:40]}" for e in friction_entries if e.get("row") == r and e.get("severity") == "blocker"]
        lines.append(f"| {r} | {res} | {'; '.join(frictions[:3]) or '—'} |")
    lines += [
        "",
        f"## Ledger pass count: {count_passes()}/22",
        f"## Friction entries tracked: {len(seen_friction)}",
        "",
        "No login/logout interventions.",
    ]
    open(REPORT, "w").write("\n".join(lines) + "\n")


log(f"MONITOR_START baseline_log_size={initial_log_size} passes={count_passes()} active_row={active_row()}")

# Initial status on start
init_entries = collect_friction()
for e in init_entries:
    if e.get("severity") != "info":
        append_issues_doc(
            e.get("row", "?"),
            e.get("severity", "friction"),
            e.get("component", "?"),
            e.get("quote", ""),
        )
init_added = append_ledger(init_entries)
init_blockers = filter_blockers(init_entries)
append_status(active_row(), "watch", init_added, init_blockers, note="continuation monitor start post Tcl fix")

while True:
    cycle += 1
    now = time.time()
    elapsed = now - start_epoch

    if elapsed > MAX_RUNTIME:
        exit_reason = "max_runtime_6h"
        break

    ensure_watch()
    ensure_monitor()

    if not batch_alive() and elapsed > 600:
        parse_new_matrix_results()
        if all_retry_rows_done() or "Matrix summary" in open(MATRIX_LOG).read()[initial_log_size:]:
            exit_reason = "batch_complete"
            break
        if ensure_pending_driver() and batch_alive():
            append_status(active_row(), "intervene", 0, [], note="restarted pending-rows driver")
            continue
        exit_reason = "batch_dead"
        append_status(active_row(), "escalate", 0, ["batch dead before all rows done"])
        break

    row = active_row()
    check_hung_expect(row)
    parse_new_matrix_results()

    entries = collect_friction()
    for e in entries:
        if e.get("severity") != "info":
            append_issues_doc(
                e.get("row", "?"),
                e.get("severity", "friction"),
                e.get("component", "?"),
                e.get("quote", ""),
            )
    ledger_added = append_ledger(entries)
    blockers = filter_blockers(entries)

    if all_retry_rows_done():
        exit_reason = "all_retry_rows_complete"
        append_status(row, "batch_complete", ledger_added, blockers)
        break

    if now - last_status_epoch >= STATUS_INTERVAL:
        append_status(row, "watch", ledger_added, blockers)
        last_status_epoch = now

    log(f"CYCLE={cycle} row={row} elapsed={int(elapsed)}s done={len(row_results)}/22 ledger_added={ledger_added}")
    time.sleep(POLL_MIN + random.randint(0, POLL_MAX - POLL_MIN))

write_final_report()
append_status(active_row(), "final", 0, [], note=exit_reason or "unknown")
log(f"DONE reason={exit_reason} rows={row_results}")
