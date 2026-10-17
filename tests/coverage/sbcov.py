#!/usr/bin/env python3
"""Silver Bullet coverage engine for Bash (statements, lines, functions) and Python.

Bash has no native coverage support, so this tool combines two pieces:

* ``bash-env.sh`` turns on xtrace in every bash process started during a coverage
  run and writes ``+<US>BASH_SOURCE<US>LINENO<US>command`` lines to per-process
  trace files (US = ASCII 0x1f).
* A static analysis built on tree-sitter-bash that lists every executable
  statement in a script with its line span and the command word bash will print
  when it runs the statement.

A trace hit credits the statements whose span contains the reported line and
whose command word matches the traced command. Matching on the word as well as
the line keeps one-liners honest: in ``check || exit 1`` the ``exit`` statement
is only covered by a run that actually took the error path.

Why spans and not exact lines: bash reports some multi-line commands at their
first line (backslash continuations) and others at their last line
(assignments with multi-line values, commands with multi-line string arguments).

Python files are measured with coverage.py (statements and branches); this tool
only merges those results into the shared report.

Subcommands:
  analyze FILE...            list statements and functions found in bash files
  collect --cov-dir DIR      fold raw trace files into DIR/bash-hits.json
  report  --cov-dir DIR      print the combined report (and write JSON/Markdown)
  annotate --cov-dir DIR FILE  show FILE with per-statement coverage markers
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCOPE_FILE = Path(__file__).resolve().parent / "scope.json"

# --------------------------------------------------------------------------
# Static analysis of bash sources
# --------------------------------------------------------------------------

ASSIGN_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)(\[[^\]]*\])?\+?=")
DECLARATION_WORDS = {"declare", "typeset", "local", "export", "readonly"}
WRAPPER_WORDS = {"time", "nohup", "coproc"}
# Node types that are statements bash traces itself.
LEAF_TYPES = {
    "command",
    "declaration_command",
    "unset_command",
    "test_command",
    "variable_assignment",
    "variable_assignments",
}
# Containers whose children are statements in sequence.
BLOCK_TYPES = {
    "program",
    "compound_statement",
    "do_group",
    "subshell",
    "else_clause",
    "elif_clause",
    "list",
    "pipeline",
    "negated_command",
    "redirected_statement",
    "case_item",
    "function_definition",
}
SKIP_CHILD_TYPES = {
    "comment",
    "heredoc_body",
    "heredoc_redirect",
    "file_redirect",
    "herestring_redirect",
    "heredoc_start",
    "heredoc_end",
}


@dataclass
class Statement:
    start: int  # 1-based, inclusive
    end: int
    kind: str
    word: str | None  # expected first traced word; None = dynamic (wildcard)
    names: frozenset = frozenset()  # assignment names carried by the statement
    # Attribution window used when no statement matches a hit by its own span.
    # Commands inside multi-line $(...) are traced at shifted line numbers
    # (bash reparses the substitution text), so they get a wider window.
    win_start: int = 0
    win_end: int = 0


@dataclass
class Function:
    name: str
    start: int
    end: int
    statements: list = field(default_factory=list)  # indexes into statements


@dataclass
class BashAnalysis:
    path: str
    statements: list
    functions: list
    parse_errors: list


_PARSER = None


def _parser():
    global _PARSER
    if _PARSER is None:
        import tree_sitter_bash
        from tree_sitter import Language, Parser

        _PARSER = Parser(Language(tree_sitter_bash.language()))
    return _PARSER


def _text(node, src: bytes) -> str:
    return src[node.start_byte : node.end_byte].decode("utf-8", "replace")


def _literal_word(node, src: bytes) -> str | None:
    """Return the literal command word for a command_name node, or None if dynamic."""
    raw = _text(node, src).strip()
    if not raw:
        return None
    if any(ch in raw for ch in "$`*?["):
        # '[' alone is the test builtin, not a glob
        if raw not in ("[", "'['", '"["'):
            return None
    word = raw
    if len(word) >= 2 and word[0] == word[-1] and word[0] in "'\"":
        word = word[1:-1]
    word = word.replace("\\", "")
    return word or None


def _assignment_name(node, src: bytes) -> str | None:
    m = ASSIGN_RE.match(_text(node, src))
    return m.group(1) if m else None


def _command_statement(node, src: bytes) -> Statement:
    word = None
    names = set()
    words_after_name = []
    seen_name = False
    for child in node.children:
        if child.type == "variable_assignment":
            n = _assignment_name(child, src)
            if n:
                names.add(n)
        elif child.type == "command_name" and not seen_name:
            seen_name = True
            word = _literal_word(child, src)
        elif seen_name and child.type not in SKIP_CHILD_TYPES:
            words_after_name.append(child)
    if word in WRAPPER_WORDS and words_after_name:
        word = _literal_word(words_after_name[0], src)
    if not seen_name:
        word = None
    return Statement(node.start_point[0] + 1, node.end_point[0] + 1, "command", word, frozenset(names))


def _leaf_statement(node, src: bytes) -> Statement:
    s, e = node.start_point[0] + 1, node.end_point[0] + 1
    t = node.type
    if t == "command":
        return _command_statement(node, src)
    if t == "declaration_command":
        names = set()
        for child in node.children:
            if child.type == "variable_assignment":
                n = _assignment_name(child, src)
                if n:
                    names.add(n)
            elif child.type == "variable_name":
                names.add(_text(child, src))
        word = node.children[0].type if node.children else None
        return Statement(s, e, "declaration", word, frozenset(names))
    if t == "unset_command":
        return Statement(s, e, "unset", node.children[0].type if node.children else "unset")
    if t == "test_command":
        first = _text(node, src)[:2]
        if first.startswith("[["):
            return Statement(s, e, "test", "[[")
        if first.startswith("(("):
            return Statement(s, e, "arith", "((")
        return Statement(s, e, "test", "[")
    if t == "variable_assignment":
        n = _assignment_name(node, src)
        return Statement(s, e, "assignment", "=", frozenset({n} if n else set()))
    if t == "variable_assignments":
        names = {_assignment_name(c, src) for c in node.children if c.type == "variable_assignment"}
        return Statement(s, e, "assignment", "=", frozenset(n for n in names if n))
    raise ValueError(t)


def analyze_bash(path: Path) -> BashAnalysis:
    src = path.read_bytes()
    tree = _parser().parse(src)
    statements: list[Statement] = []
    functions: list[Function] = []
    errors: list[int] = []
    fn_stack: list[Function] = []

    window: list[tuple[int, int] | None] = [None]  # active $(...) attribution window

    def add(stmt: Statement):
        win = window[-1]
        if win is None:
            stmt.win_start, stmt.win_end = stmt.start, stmt.end
        else:
            stmt.win_start, stmt.win_end = min(win[0], stmt.start), max(win[1], stmt.end)
        statements.append(stmt)
        for fn in fn_stack:
            fn.statements.append(len(statements) - 1)

    def visit_substitutions(node, outer_start: int, outer_end: int):
        """Add statements for commands inside $(...), <(...) and `...` at or below node."""
        if node.type in ("command_substitution", "process_substitution"):
            extra = node.end_point[0] - node.start_point[0]
            parent = window[-1]
            lo = outer_start if parent is None else min(parent[0], outer_start)
            hi = outer_end + extra if parent is None else max(parent[1], outer_end) + extra
            window.append((lo, hi) if extra else parent)
            for inner in node.children:
                if inner.is_named:
                    visit(inner)
            window.pop()
            return
        for child in node.children:
            visit_substitutions(child, outer_start, outer_end)

    def visit(node):
        t = node.type
        if t == "ERROR" or node.is_missing:
            errors.append(node.start_point[0] + 1)
        if t in SKIP_CHILD_TYPES:
            return
        if t in LEAF_TYPES:
            stmt = _leaf_statement(node, src)
            add(stmt)
            visit_substitutions(node, stmt.start, stmt.end)
            return
        if t == "redirected_statement":
            for child in node.children:
                if child.type in SKIP_CHILD_TYPES:
                    # Expansions in redirect targets and here-documents run with the command.
                    visit_substitutions(child, node.start_point[0] + 1, node.end_point[0] + 1)
                elif child.is_named:
                    visit(child)
            return
        if t == "compound_statement" and node.children and node.children[0].type == "((":
            stmt = Statement(node.start_point[0] + 1, node.end_point[0] + 1, "arith", "((")
            add(stmt)
            visit_substitutions(node, stmt.start, stmt.end)
            return
        if t == "function_definition":
            name_node = node.child_by_field_name("name")
            fn = Function(_text(name_node, src) if name_node else "?", node.start_point[0] + 1, node.end_point[0] + 1)
            functions.append(fn)
            fn_stack.append(fn)
            body = node.child_by_field_name("body")
            if body is not None:
                visit(body)
            fn_stack.pop()
            return
        if t == "for_statement":
            # Header "for x in words" is traced as one statement.
            body = node.child_by_field_name("body")
            header_end = (body.start_point[0] + 1) if body is not None else node.end_point[0] + 1
            add(Statement(node.start_point[0] + 1, header_end, "for", "select" if node.children[0].type == "select" else "for"))
            for child in node.children:
                if child is not body and child.is_named:
                    visit_substitutions(child, node.start_point[0] + 1, header_end)
            if body is not None:
                visit(body)
            return
        if t == "c_style_for_statement":
            body = node.child_by_field_name("body")
            header_end = (body.start_point[0] + 1) if body is not None else node.end_point[0] + 1
            add(Statement(node.start_point[0] + 1, header_end, "arith", "(("))
            if body is not None:
                visit(body)
            return
        if t == "case_statement":
            add(Statement(node.start_point[0] + 1, node.start_point[0] + 1, "case", "case"))
            for child in node.children:
                if child.type == "case_item":
                    visit(child)
                elif child.is_named:
                    visit_substitutions(child, node.start_point[0] + 1, node.start_point[0] + 1)
            return
        if t in ("if_statement", "while_statement", "until_statement"):
            for child in node.children:
                if child.type not in ("if", "then", "fi", "while", "until", ";", "\n", "&"):
                    visit(child)
            return
        # Generic container: visit named children in order.
        for child in node.children:
            if child.is_named:
                visit(child)

    visit(tree.root_node)
    return BashAnalysis(str(path), statements, functions, errors)


# --------------------------------------------------------------------------
# Scope
# --------------------------------------------------------------------------


def _git_files() -> list[str]:
    out = subprocess.run(["git", "-C", str(REPO_ROOT), "ls-files", "-z"], check=True, capture_output=True).stdout
    files = [f for f in out.decode().split("\0") if f]
    # Files added in the working tree but not committed yet are in scope too.
    extra = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "ls-files", "-z", "--others", "--exclude-standard"],
        check=True,
        capture_output=True,
    ).stdout
    files += [f for f in extra.decode().split("\0") if f]
    return sorted(set(f for f in files if (REPO_ROOT / f).is_file() and not (REPO_ROOT / f).is_symlink()))


def _is_bash(rel: str) -> bool:
    if rel.endswith(".sh"):
        return True
    p = REPO_ROOT / rel
    if p.suffix:
        return False
    try:
        with p.open("rb") as fh:
            first = fh.readline(200)
    except OSError:
        return False
    return first.startswith(b"#!") and b"bash" in first


def _matches(rel: str, patterns) -> bool:
    return any(fnmatch.fnmatchcase(rel, pat) for pat in patterns)


def load_scope():
    scope = json.loads(SCOPE_FILE.read_text())
    files = _git_files()
    result = {}
    for lang in ("bash", "python"):
        spec = scope[lang]
        include = spec["include"]
        exclude = [e["glob"] for e in spec.get("exclude", [])]
        chosen = []
        for rel in files:
            if not _matches(rel, include) or _matches(rel, exclude):
                continue
            if lang == "bash" and not _is_bash(rel):
                continue
            if lang == "python" and not rel.endswith(".py"):
                continue
            chosen.append(rel)
        result[lang] = chosen
    return scope, result


# --------------------------------------------------------------------------
# Trace collection
# --------------------------------------------------------------------------

HIT_RE = re.compile(rb"^\++\x1f([^\x1f\n]*)\x1f(\d+)\x1f([^\n]{0,200})", re.M)
PWD_RE = re.compile(rb"^#PWD\x1f([^\n]*)$", re.M)


def _first_word(cmd: bytes) -> str:
    text = cmd.decode("utf-8", "replace").lstrip()
    if not text:
        return ""
    if text.startswith("[["):
        return "[["
    if text.startswith("(("):
        return "(("
    m = ASSIGN_RE.match(text)
    if m:
        return "=" + m.group(1)
    word = text.split(None, 1)[0]
    if len(word) >= 2 and word[0] == word[-1] == "'":
        word = word[1:-1]
    return word


def collect(cov_dir: Path) -> int:
    """Fold raw trace files into bash-hits.json and delete them.

    bash-hits.json maps traced path -> line -> word -> multiplicity, where the
    multiplicity is the largest number of times the word was traced in one
    uninterrupted run of records for that line. It lets attribution tell apart
    two same-word statements on one line, e.g. ``x=$(cmd) || x=""``.
    """
    raw = cov_dir / "raw"
    hits_path = cov_dir / "bash-hits.json"
    hits: dict = json.loads(hits_path.read_text()) if hits_path.exists() else {}
    count = 0

    def flush(key, counts):
        if key is None:
            return
        src, line = key
        per_line = hits.setdefault(src, {}).setdefault(line, {})
        for w, n in counts.items():
            if per_line.get(w, 0) < n:
                per_line[w] = n

    for trace in sorted(raw.glob("*.trace")):
        data = trace.read_bytes()
        m = PWD_RE.search(data)
        start_pwd = m.group(1).decode("utf-8", "replace") if m else ""
        run_key = None
        run_counts: dict[str, int] = {}
        for src_b, line_b, cmd in HIT_RE.findall(data):
            src = src_b.decode("utf-8", "replace")
            if not src:
                continue
            if not src.startswith("/") and start_pwd:
                src = os.path.normpath(os.path.join(start_pwd, src))
            key = (src, line_b.decode())
            if key != run_key:
                flush(run_key, run_counts)
                run_key, run_counts = key, {}
            w = _first_word(cmd)
            run_counts[w] = run_counts.get(w, 0) + 1
            count += 1
        flush(run_key, run_counts)
        trace.unlink()
    hits_path.write_text(json.dumps(hits))
    return count


def merge(cov_dir: Path, sources: list[Path]) -> int:
    """Merge other bash-hits.json files into cov_dir/bash-hits.json (max multiplicity)."""
    hits_path = cov_dir / "bash-hits.json"
    hits: dict = json.loads(hits_path.read_text()) if hits_path.exists() else {}
    merged = 0
    for src in sources:
        if not src.exists():
            continue
        for path, lines in json.loads(src.read_text()).items():
            dest = hits.setdefault(path, {})
            for ln, words in lines.items():
                slot = dest.setdefault(ln, {})
                for w, n in words.items():
                    if slot.get(w, 0) < n:
                        slot[w] = n
        merged += 1
    cov_dir.mkdir(parents=True, exist_ok=True)
    hits_path.write_text(json.dumps(hits))
    return merged


# --------------------------------------------------------------------------
# Mapping traced paths back to repository files
# --------------------------------------------------------------------------


def _map_paths(traced_paths, scoped: list[str]) -> dict:
    """Map traced absolute paths to repo-relative scoped files.

    Paths inside the repository (including through symlinked package roots) are
    resolved with realpath. Copies outside the repository (tests that stage a
    plugin into a temp dir) are matched by the longest unique path suffix of at
    least two components, e.g. ``/tmp/x/hooks/lib/foo.sh`` -> ``hooks/lib/foo.sh``.
    """
    root = str(REPO_ROOT) + os.sep
    scoped_set = set(scoped)
    by_suffix: dict[str, list[str]] = {}
    for rel in scoped:
        parts = rel.split("/")
        for i in range(len(parts) - 1):
            by_suffix.setdefault("/".join(parts[i:]), []).append(rel)
    mapping = {}
    for p in traced_paths:
        real = os.path.realpath(p) if os.path.exists(p) else p
        if real.startswith(root) and real[len(root) :] in scoped_set:
            mapping[p] = real[len(root) :]
            continue
        parts = p.split("/")
        for i in range(1, len(parts) - 1):
            cand = by_suffix.get("/".join(parts[i:]))
            if cand and len(cand) == 1:
                mapping[p] = cand[0]
                break
    return mapping


# --------------------------------------------------------------------------
# Coverage computation
# --------------------------------------------------------------------------


def bash_file_coverage(analysis: BashAnalysis, line_words: dict) -> dict:
    """Credit statements from {line: {word: multiplicity}} and return coverage details.

    A hit (line, word) credits statements whose own span contains the line and
    whose word matches; with multiplicity n it credits up to n such statements in
    source order. Only when nothing matches by span are attribution windows of
    commands inside multi-line substitutions consulted. Assignment hits ("=name")
    match statements that assign that name. Hits that still match nothing go to
    dynamic statements (unknown command word) on that line, else they are orphans.
    """
    stmts = analysis.statements
    covered = [False] * len(stmts)
    by_line: dict[int, list[int]] = {}
    by_window: dict[int, list[int]] = {}
    for i, st in enumerate(stmts):
        for ln in range(st.start, st.end + 1):
            by_line.setdefault(ln, []).append(i)
        for ln in range(st.win_start or st.start, (st.win_end or st.end) + 1):
            if not st.start <= ln <= st.end:
                by_window.setdefault(ln, []).append(i)

    def matches(i: int, w: str) -> bool:
        st = stmts[i]
        if w.startswith("="):
            return w[1:] in st.names or (st.kind == "assignment" and not st.names)
        return st.word is not None and st.word == w

    orphans = []
    for ln, words in line_words.items():
        if isinstance(words, list):  # tolerate the pre-multiplicity format
            words = {w: 1 for w in words}
        for w, n in words.items():
            cands = [i for i in by_line.get(ln, []) if matches(i, w)]
            if not cands:
                cands = [i for i in by_window.get(ln, []) if matches(i, w)]
            if not cands:
                cands = [i for i in by_line.get(ln, []) if stmts[i].word is None and not w.startswith("=")]
            if not cands:
                orphans.append([ln, w])
                continue
            for i in cands[: max(1, n)]:
                covered[i] = True
    lines_exec = {}
    for i, st in enumerate(stmts):
        lines_exec[st.start] = lines_exec.get(st.start, False) or covered[i]
    funcs = []
    for fn in analysis.functions:
        hit = any(covered[i] for i in fn.statements)
        funcs.append({"name": fn.name, "line": fn.start, "covered": hit})
    return {
        "statements": len(stmts),
        "statements_covered": sum(covered),
        "lines": len(lines_exec),
        "lines_covered": sum(1 for v in lines_exec.values() if v),
        "functions": len(funcs),
        "functions_covered": sum(1 for f in funcs if f["covered"]),
        "missing_statements": [
            {"line": st.start, "end": st.end, "word": st.word or "*"} for i, st in enumerate(stmts) if not covered[i]
        ],
        "missing_functions": [f for f in funcs if not f["covered"]],
        "orphan_hits": sorted(orphans),
        "parse_errors": analysis.parse_errors,
    }


def bash_coverage(cov_dir: Path, scoped: list[str]) -> dict:
    hits_path = cov_dir / "bash-hits.json"
    hits = json.loads(hits_path.read_text()) if hits_path.exists() else {}
    mapping = _map_paths(hits.keys(), scoped)
    merged: dict[str, dict[int, dict]] = {}
    for traced, rel in mapping.items():
        dest = merged.setdefault(rel, {})
        for ln, words in hits[traced].items():
            slot = dest.setdefault(int(ln), {})
            for w, n in (words.items() if isinstance(words, dict) else ((w, 1) for w in words)):
                slot[w] = max(slot.get(w, 0), n)
    results = {}
    for rel in scoped:
        analysis = analyze_bash(REPO_ROOT / rel)
        results[rel] = bash_file_coverage(analysis, merged.get(rel, {}))
    return results


def python_coverage(cov_dir: Path, scoped: list[str]) -> dict:
    data_files = list((cov_dir / "py").glob(".coverage*")) if (cov_dir / "py").exists() else []
    results = {}
    try:
        import coverage
    except ImportError:
        coverage = None
    cov = None
    if coverage is not None and data_files:
        cov = coverage.Coverage(data_file=str(cov_dir / "py-combined.coverage"), config_file=str(cov_dir / "coveragerc"))
        cov.combine([str(p) for p in data_files], keep=True)
        cov.save()
        cov.load()
    for rel in scoped:
        path = str(REPO_ROOT / rel)
        if cov is not None:
            try:
                analysis = cov._analyze(path)  # noqa: SLF001 - stable enough across 7.x
                nums = analysis.numbers
                missing_branches = analysis.missing_branch_arcs()
                results[rel] = {
                    "statements": nums.n_statements,
                    "statements_covered": nums.n_statements - nums.n_missing,
                    "branches": nums.n_branches,
                    "branches_covered": nums.n_branches - nums.n_missing_branches,
                    "missing_lines": sorted(analysis.missing),
                    "missing_branches": {str(k): sorted(v) for k, v in sorted(missing_branches.items())},
                }
                continue
            except Exception:  # file never imported/executed
                pass
        stmts = _python_statement_count(path)
        results[rel] = {
            "statements": stmts["statements"],
            "statements_covered": 0,
            "branches": stmts["branches"],
            "branches_covered": 0,
            "missing_lines": stmts["lines"],
            "missing_branches": {},
        }
    return results


def _python_statement_count(path: str) -> dict:
    try:
        from coverage.python import PythonParser

        parser = PythonParser(filename=path)
        parser.parse_source()
        arcs = parser.arcs()
        exits = {}
        for a, b in arcs:
            if a > 0:
                exits.setdefault(a, set()).add(b)
        branches = sum(len(v) for v in exits.values() if len(v) > 1)
        return {"statements": len(parser.statements), "branches": branches, "lines": sorted(parser.statements)}
    except Exception:
        return {"statements": 0, "branches": 0, "lines": []}


# --------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------


def _pct(a: int, b: int) -> float:
    return 100.0 if b == 0 else 100.0 * a / b


def _totals(results: dict, keys) -> dict:
    out = {}
    for k in keys:
        out[k] = sum(r[k] for r in results.values())
        out[k + "_covered"] = sum(r[k + "_covered"] for r in results.values())
    return out


def report(cov_dir: Path, fail_under: float | None, show_missing: bool, only: list[str] | None) -> int:
    scope, scoped = load_scope()
    bash_scoped = scoped["bash"]
    py_scoped = scoped["python"]
    if only:
        bash_scoped = [f for f in bash_scoped if _matches(f, only)]
        py_scoped = [f for f in py_scoped if _matches(f, only)]
    bash = bash_coverage(cov_dir, bash_scoped)
    py = python_coverage(cov_dir, py_scoped)
    bt = _totals(bash, ["statements", "lines", "functions"])
    pt = _totals(py, ["statements", "branches"])
    summary = {
        "bash": {**bt, "files": len(bash)},
        "python": {**pt, "files": len(py)},
        "exclusions": scope["bash"].get("exclude", []) + scope["python"].get("exclude", []),
    }
    (cov_dir / "coverage-summary.json").write_text(
        json.dumps({"summary": summary, "bash": bash, "python": py}, indent=1, sort_keys=True)
    )

    rows = []
    for rel, r in sorted(bash.items()):
        rows.append((rel, r["statements_covered"], r["statements"], r["functions_covered"], r["functions"], None, None))
    for rel, r in sorted(py.items()):
        rows.append((rel, r["statements_covered"], r["statements"], None, None, r["branches_covered"], r["branches"]))
    width = max([len(r[0]) for r in rows] + [10])
    print(f"{'File':<{width}}  {'Stmts':>11}  {'Funcs':>9}  {'Branches':>11}  Cover")
    for rel, sc, s, fc, f, bc, b in rows:
        if sc == s and (fc == f) and (bc == b) and not show_missing:
            continue
        funcs = f"{fc}/{f}" if f is not None else "-"
        br = f"{bc}/{b}" if b is not None else "-"
        print(f"{rel:<{width}}  {sc:>5}/{s:<5}  {funcs:>9}  {br:>11}  {_pct(sc, s):6.2f}%")
        if show_missing:
            r = bash.get(rel) or py.get(rel)
            if rel in bash:
                miss = r["missing_statements"]
                if miss:
                    print("    missing: " + ", ".join(f"{m['line']}({m['word']})" for m in miss[:60]))
                if r["missing_functions"]:
                    print("    uncalled functions: " + ", ".join(f["name"] for f in r["missing_functions"]))
            else:
                if r["missing_lines"]:
                    print("    missing lines: " + _ranges(r["missing_lines"]))
                if r["missing_branches"]:
                    print("    missing branches: " + ", ".join(f"{k}->{v}" for k, v in list(r["missing_branches"].items())[:40]))
    print()
    print(
        "Bash   files {f}: statements {sc}/{s} ({sp:.2f}%), lines {lc}/{l} ({lp:.2f}%), functions {fc}/{fn} ({fp:.2f}%)".format(
            f=len(bash),
            sc=bt["statements_covered"],
            s=bt["statements"],
            sp=_pct(bt["statements_covered"], bt["statements"]),
            lc=bt["lines_covered"],
            l=bt["lines"],
            lp=_pct(bt["lines_covered"], bt["lines"]),
            fc=bt["functions_covered"],
            fn=bt["functions"],
            fp=_pct(bt["functions_covered"], bt["functions"]),
        )
    )
    print(
        "Python files {f}: statements {sc}/{s} ({sp:.2f}%), branches {bc}/{b} ({bp:.2f}%)".format(
            f=len(py),
            sc=pt["statements_covered"],
            s=pt["statements"],
            sp=_pct(pt["statements_covered"], pt["statements"]),
            bc=pt["branches_covered"],
            b=pt["branches"],
            bp=_pct(pt["branches_covered"], pt["branches"]),
        )
    )
    orphan_total = sum(len(r["orphan_hits"]) for r in bash.values())
    if orphan_total:
        print(f"Unattributed bash trace hits: {orphan_total} (eval/trap bodies or analyzer gaps; per-file list in coverage-summary.json)")
    errors = {rel: r["parse_errors"] for rel, r in bash.items() if r["parse_errors"]}
    if errors:
        print("Bash parse errors (statements near these lines may be miscounted):")
        for rel, lines in errors.items():
            print(f"  {rel}: lines {lines[:10]}")
    if fail_under is not None:
        metrics = [
            _pct(bt["statements_covered"], bt["statements"]),
            _pct(bt["lines_covered"], bt["lines"]),
            _pct(bt["functions_covered"], bt["functions"]),
            _pct(pt["statements_covered"], pt["statements"]),
            _pct(pt["branches_covered"], pt["branches"]),
        ]
        if min(metrics) + 1e-9 < fail_under:
            print(f"FAIL: coverage below {fail_under}%")
            return 2
    return 0


def _ranges(nums) -> str:
    out = []
    start = prev = None
    for n in nums:
        if start is None:
            start = prev = n
        elif n == prev + 1:
            prev = n
        else:
            out.append(f"{start}-{prev}" if start != prev else str(start))
            start = prev = n
    if start is not None:
        out.append(f"{start}-{prev}" if start != prev else str(start))
    return ", ".join(out)


def annotate(cov_dir: Path, rel: str, as_json: bool = False) -> int:
    path = REPO_ROOT / rel
    analysis = analyze_bash(path)
    hits_path = cov_dir / "bash-hits.json"
    hits = json.loads(hits_path.read_text()) if hits_path.exists() else {}
    mapping = _map_paths(hits.keys(), [rel])
    line_words: dict[int, dict] = {}
    for traced, mapped in mapping.items():
        for ln, words in hits[traced].items():
            slot = line_words.setdefault(int(ln), {})
            for w, n in words.items():
                slot[w] = max(slot.get(w, 0), n)
    res = bash_file_coverage(analysis, line_words)
    if as_json:
        print(json.dumps(res, indent=1, sort_keys=True))
        return 0
    missing = {}
    for m in res["missing_statements"]:
        missing.setdefault(m["line"], []).append(m["word"])
    starts = {st.start for st in analysis.statements}
    for i, line in enumerate(path.read_text(errors="replace").splitlines(), start=1):
        mark = "  "
        if i in missing:
            mark = "!!" if len(missing[i]) == sum(1 for st in analysis.statements if st.start == i) else "! "
        elif i in starts:
            mark = "ok"
        print(f"{mark} {i:5} {line}")
    print(f"\n{rel}: statements {res['statements_covered']}/{res['statements']}, functions {res['functions_covered']}/{res['functions']}")
    print("Legend: ok = all statements on the line ran, !! = none ran, ! = some ran (see missing words)")
    for ln, words in sorted(missing.items()):
        print(f"  line {ln}: not run: {', '.join(words)}")
    return 0


SITECUSTOMIZE = '''\
# Generated by tests/coverage/sbcov.py: start coverage.py in every Python process.
import os

if os.environ.get("COVERAGE_PROCESS_START"):
    try:
        import coverage

        coverage.process_startup()
    except Exception:  # never break the code under test
        pass
'''


def _skill_aliases(name: str) -> list[str]:
    short = name[len("silver-") :] if name.startswith("silver-") else name
    if name.startswith("silver-"):
        return [f"agents/claude/sb:{short}", f"host-bundles/codex/sb-{short}", f"plugins/silver-bullet/skill-source/sb-{short}"]
    return [f"agents/claude/{name}", f"host-bundles/codex/{name}", f"plugins/silver-bullet/skill-source/{name}"]


def write_config(cov_dir: Path) -> None:
    """Write the coverage.py config and sitecustomize bootstrap for a run."""
    root = str(REPO_ROOT)
    lines = [
        "[run]",
        "branch = True",
        "parallel = True",
        f"data_file = {cov_dir}/py/.coverage",
        "source =",
        f"    {root}/hooks",
        f"    {root}/scripts",
        f"    {root}/skills",
        f"    {root}/site",
        "omit =",
        "    */tests/*",
        "",
        "[paths]",
    ]
    # Generated skill bundles run the same scripts from another path; fold them back.
    for skill in sorted(p.name for p in (REPO_ROOT / "skills").iterdir() if p.is_dir()):
        if not any((REPO_ROOT / "skills" / skill).rglob("*.py")):
            continue
        key = re.sub(r"[^A-Za-z0-9_]", "_", skill)
        lines.append(f"{key} =")
        lines.append(f"    {root}/skills/{skill}/")
        for alias in _skill_aliases(skill):
            lines.append(f"    {root}/{alias}/")
    lines += ["", "[report]", "precision = 2", ""]
    (cov_dir / "coveragerc").write_text("\n".join(lines))
    boot = cov_dir / "pyboot"
    boot.mkdir(parents=True, exist_ok=True)
    (boot / "sitecustomize.py").write_text(SITECUSTOMIZE)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("analyze")
    a.add_argument("files", nargs="+")
    c = sub.add_parser("collect")
    c.add_argument("--cov-dir", required=True, type=Path)
    r = sub.add_parser("report")
    r.add_argument("--cov-dir", required=True, type=Path)
    r.add_argument("--fail-under", type=float)
    r.add_argument("--show-missing", action="store_true")
    r.add_argument("--only", action="append", help="glob of repo-relative files to report")
    n = sub.add_parser("annotate")
    n.add_argument("--cov-dir", required=True, type=Path)
    n.add_argument("file")
    n.add_argument("--json", action="store_true", help="print the coverage record instead of the source")
    s = sub.add_parser("scope")
    s.add_argument("--lang", choices=["bash", "python"], required=True)
    mg = sub.add_parser("merge")
    mg.add_argument("--cov-dir", required=True, type=Path)
    mg.add_argument("sources", nargs="+", type=Path)
    w = sub.add_parser("write-config")
    w.add_argument("--cov-dir", required=True, type=Path)
    args = ap.parse_args(argv)

    if args.cmd == "merge":
        print(f"merged {merge(args.cov_dir, args.sources)} hit files")
        return 0
    if args.cmd == "write-config":
        write_config(args.cov_dir)
        return 0
    if args.cmd == "analyze":
        for f in args.files:
            res = analyze_bash(Path(f))
            print(f"# {f}: {len(res.statements)} statements, {len(res.functions)} functions, parse errors at {res.parse_errors}")
            for st in res.statements:
                print(f"{st.start}-{st.end}\t{st.kind}\t{st.word or '*'}\t{','.join(sorted(st.names))}")
            for fn in res.functions:
                print(f"function {fn.name} {fn.start}-{fn.end} ({len(fn.statements)} statements)")
        return 0
    if args.cmd == "collect":
        n_hits = collect(args.cov_dir)
        print(f"collected {n_hits} trace hits")
        return 0
    if args.cmd == "report":
        return report(args.cov_dir, args.fail_under, args.show_missing, args.only)
    if args.cmd == "annotate":
        return annotate(args.cov_dir, args.file, args.json)
    if args.cmd == "scope":
        _, scoped = load_scope()
        print("\n".join(scoped[args.lang]))
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
