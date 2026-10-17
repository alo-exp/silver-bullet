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
import shlex
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
    # Literal word list ("echo true") when every word is a plain ASCII literal, so
    # `cond && echo true || echo false` arms can be told apart by trace text.
    sig: str | None = None
    fn: str = ""  # innermost enclosing function ("" at top level)
    argc: int | None = None  # number of arguments when it cannot vary at run time
    procsub: tuple | None = None  # (function, node id, container start, container end) inside <(...)


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


_SIG_UNSAFE = set("\\$`*?[]{}~\n")


def _literal_arg(node, src: bytes) -> str | None:
    """The value of a plain literal argument (word, '...', "...", number), else None."""
    text = _text(node, src)
    if not text.isascii():
        return None  # xtrace prints non-ASCII words as $'\ooo' escapes
    if node.type in ("word", "number"):
        return None if _SIG_UNSAFE & set(text) else text
    if node.type == "raw_string":
        return None if "\n" in text else text[1:-1]
    if node.type == "string":
        if any(c.type not in ('"', "string_content") for c in node.children):
            return None
        inner = text[1:-1]
        return None if _SIG_UNSAFE & set(inner) else inner
    return None


def _fixed_arg(node, src: bytes) -> bool:
    """True when an argument always expands to exactly one word."""
    t = node.type
    if t in ("raw_string", "number"):
        return True
    text = _text(node, src)
    if t == "string":
        return "[@]" not in text and "$@" not in text
    if t == "word":
        return not (set("*?[{~") & set(text))
    if t == "concatenation":
        return all(_fixed_arg(c, src) for c in node.children if c.is_named)
    return False


def _sig(words) -> str | None:
    """Join words into a signature; None when too long to survive trace truncation."""
    joined = "\x1f".join(words)
    return joined if len(joined) <= 150 else None


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
    elif word == "{" and words_after_name:
        # tree-sitter-bash parses `! { cmd ...; }` as a command named "{"; bash
        # traces the command inside the group.
        word = _literal_word(words_after_name[0], src)
    if not seen_name:
        word = None
    sig = None
    if word is not None and not names and word not in WRAPPER_WORDS and words_after_name:
        parts = [word]
        for child in words_after_name:
            lit = _literal_arg(child, src)
            if lit is None:
                parts = None
                break
            parts.append(lit)
        if parts is not None:
            sig = _sig(parts)
    argc = None
    if word is not None and not names and word not in WRAPPER_WORDS and all(_fixed_arg(c, src) for c in words_after_name):
        argc = len(words_after_name)
    return Statement(
        node.start_point[0] + 1, node.end_point[0] + 1, "command", word, frozenset(names), sig=sig, argc=argc
    )


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

    window: list[tuple[int, int] | None] = [None]  # active attribution window
    procsub_stack: list[tuple] = []
    container_stack: list[tuple[int, int]] = []  # spans of enclosing redirected statements

    def widen(lo: int, hi: int) -> tuple[int, int]:
        cur = window[-1]
        return (lo, hi) if cur is None else (min(cur[0], lo), max(cur[1], hi))

    def add(stmt: Statement):
        stmt.fn = fn_stack[-1].name if fn_stack else ""
        stmt.procsub = procsub_stack[-1] if procsub_stack else None
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
            # bash reports these commands at the enclosing statement's first line
            # (backslash continuations) or last line (assignments), and shifts
            # multi-line substitutions further; the window covers all of that.
            extra = node.end_point[0] - node.start_point[0]
            lo, hi = widen(outer_start, outer_end)
            if node.type == "process_substitution" and fn_stack:
                # Inside a function bash reports a process substitution's commands
                # at the line where the function definition starts.
                lo = min(lo, fn_stack[-1].start)
            window.append((lo, hi + extra))
            is_procsub = node.type == "process_substitution"
            if is_procsub:
                cont = container_stack[-1] if container_stack else (outer_start, outer_end)
                procsub_stack.append((fn_stack[-1].name if fn_stack else "", node.start_byte, cont[0], cont[1]))
            for inner in node.children:
                if inner.is_named:
                    visit(inner)
            if is_procsub:
                procsub_stack.pop()
            window.pop()
            return
        for child in node.children:
            visit_substitutions(child, outer_start, outer_end)

    def visit(node):
        t = node.type
        if t == "ERROR" or node.is_missing:
            errors.append(node.start_point[0] + 1)
        if t in SKIP_CHILD_TYPES:
            if t == "comment":
                return
            lo, hi = node.start_point[0] + 1, node.end_point[0] + 1
            for child in node.children:
                if child.type in SKIP_CHILD_TYPES or not child.is_named or child.type in (
                    "command_substitution",
                    "process_substitution",
                ):
                    # Expansions in redirect targets (e.g. `done < <(cmd)`) and here-documents.
                    visit_substitutions(child, lo, hi)
                else:
                    # tree-sitter nests `cmd <<EOF || fallback` inside the here-document
                    # redirect; bash reports the fallback at the end of the document.
                    window.append(widen(lo, hi))
                    visit(child)
                    window.pop()
            return
        if t in ("list", "pipeline"):
            # Simple commands chained after a here-document or a continuation line
            # are reported anywhere in the chain's span.
            lo, hi = widen(node.start_point[0] + 1, node.end_point[0] + 1)
            for child in node.children:
                if not child.is_named:
                    continue
                if child.type in LEAF_TYPES or child.type in ("redirected_statement", "negated_command"):
                    window.append((lo, hi))
                    visit(child)
                    window.pop()
                else:
                    visit(child)
            return
        if t in LEAF_TYPES:
            stmt = _leaf_statement(node, src)
            if stmt.kind == "command" and stmt.word == "}" and node.named_child_count == 1:
                return  # the closing brace of a misparsed `! { ...; }` group
            add(stmt)
            visit_substitutions(node, stmt.start, stmt.end)
            return
        if t == "redirected_statement":
            container_stack.append((node.start_point[0] + 1, node.end_point[0] + 1))
            for child in node.children:
                if child.is_named:
                    visit(child)
            container_stack.pop()
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
                if child != body and child.is_named:
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
    for lang in ("bash", "python", "javascript"):
        if lang not in scope:
            result[lang] = []
            continue
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
            if lang == "javascript" and not rel.endswith((".js", ".mjs", ".cjs", ".ts")):
                continue
            chosen.append(rel)
        result[lang] = chosen
    return scope, result


# --------------------------------------------------------------------------
# Trace collection
# --------------------------------------------------------------------------

# "+" repeats once per subshell/substitution level; pid and function depth are
# absent in traces written before they were added to PS4.
HIT_RE = re.compile(
    rb"^(\++)\x1f([^\x1f\n]*)\x1f(\d+)\x1f(?:(\d+)\x1f(\d*)\x1f(?:([^\x1f\n]*)\x1f)?)?([^\n]{0,200})", re.M
)
FN_KEY = "\x04"  # FN_KEY + function + "\x1f" + word or signature: per-function multiplicity
RUN_KEY = "\x03"  # RUN_KEY + function + "\x1e" + words: one process's run of records for a line
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


RECENT_RECORDS = 64  # how far back a substitution's run can join its parent's


def _trace_token(cmd: bytes, word: str) -> str:
    """Run token: the first word, plus '#<argc>' when the record parses into words."""
    if len(cmd) >= 200:
        return word
    try:
        words = shlex.split(cmd.decode("utf-8", "replace"), posix=True)
    except ValueError:
        return word
    return f"{word}#{len(words) - 1}" if words else word


def _trace_sig(cmd: bytes) -> str | None:
    """Signature of a traced command whose text is plain words, else None."""
    if len(cmd) >= 200 or not cmd.isascii():
        return None
    try:
        words = shlex.split(cmd.decode("ascii"), posix=True)
    except ValueError:
        return None
    if not words:
        return None
    joined = _sig(words)
    return None if joined is None else "\x01" + joined


def collect(cov_dir: Path) -> int:
    """Fold raw trace files into bash-hits.json and delete them.

    bash-hits.json maps traced path -> line -> word -> multiplicity, where the
    multiplicity is the largest number of times the word was traced in one run
    of records for that line by one process. It lets attribution tell apart two
    same-word statements on one line, e.g. ``x=$(cmd) || x=""``. A run continues
    across deeper records (a called function, a command substitution) and records
    of other processes (a process substitution running concurrently), and ends
    at the next record of the same process at the same or a shallower depth.
    Records for one line traced back to back by different processes (a command
    substitution and its parent statement) also form a run; flush keeps the
    larger count, since neither kind of run overcounts. A run another process
    traced shortly before at the same or a deeper level (a command substitution,
    or pipeline stages, whose parent statement shares the line) is added to the
    parent's run for that line, and so is a deeper run another process opens
    for that line while the parent's run is open (a second substitution in the
    same statement).

    Besides first words, each run counts signatures ("\x01" + words joined by
    \x1f) of records whose text parses into plain words, so statements with
    literal arguments (``echo true`` / ``echo false``) can be told apart.
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

    def flush_run(run):
        key, _depth, own, fn, words, children, anchor, after = run
        counts = dict(own)
        for child in children:  # substitutions that ran after this run opened
            for k, n in child.items():
                counts[k] = counts.get(k, 0) + n
        flush(key, counts)
        fn_counts = {f"{FN_KEY}{fn}\x1f{k}": n for k, n in counts.items()}
        if 0 < len(words) <= 12:
            tag = f"\x1d{anchor}\x1c{after[0] if after else ''}"
            fn_counts[RUN_KEY + fn + "\x1e" + "\x1e".join(sorted(words)) + tag] = 1
        flush(key, fn_counts)

    def bump(counts, w, sig):
        counts[w] = counts.get(w, 0) + 1
        if sig is not None:
            counts[sig] = counts.get(sig, 0) + 1

    for trace in sorted(raw.glob("*.trace")):
        data = trace.read_bytes()
        m = PWD_RE.search(data)
        start_pwd = m.group(1).decode("utf-8", "replace") if m else ""
        # Per process: a stack of open runs [key, depth, counts], deepest last.
        stacks: dict[bytes, list] = {}
        # Across processes: consecutive records for one line, e.g. a command
        # substitution's child traced just before its parent statement.
        flat_key = None
        flat_counts: dict[str, int] = {}
        # Runs recently opened per line: [pid, depth, counts, record index].
        recent: dict[tuple, list] = {}
        # Recent records (pid, depth, src, line): a child process's run is anchored at
        # the parent's last record before it, e.g. the `while read` of `done < <(...)`.
        history: list[tuple] = []
        awaiting: list[list] = []  # child runs waiting for the parent's next record
        for index, (plus, src_b, line_b, pid, fdepth, fn_b, cmd) in enumerate(HIT_RE.findall(data)):
            src = src_b.decode("utf-8", "replace")
            if not src:
                continue
            if not src.startswith("/") and start_pwd:
                src = os.path.normpath(os.path.join(start_pwd, src))
            key = (src, line_b.decode())
            depth = len(plus) + int(fdepth or 0)
            stack = stacks.setdefault(pid, [])
            while stack and (stack[-1][1] > depth or (stack[-1][1] == depth and stack[-1][0] != key)):
                flush_run(stack.pop())
            if not stack or stack[-1][1] < depth:
                counts = {}
                kept = []
                for other in recent.get(key, []):
                    if index - other[3] > RECENT_RECORDS:
                        continue  # too old to belong to this statement
                    if other[0] != pid and other[1] >= depth:
                        for k, n in other[2].items():
                            counts[k] = counts.get(k, 0) + n
                    else:
                        if other[0] != pid and other[1] < depth:
                            other[4][5].append(counts)  # a substitution of that open run
                        kept.append(other)
                anchor = ""
                for hpid, hdepth, hsrc, hline in reversed(history):
                    if hpid != pid and hdepth < depth:
                        anchor = hline if hsrc == src else ""
                        break
                run = [key, depth, counts, fn_b.decode("utf-8", "replace"), [], [], anchor, []]
                awaiting.append(run + [pid, src, index])
                kept.append([pid, depth, counts, index, run])
                recent[key] = kept
                stack.append(run)
            w = _first_word(cmd)
            sig = _trace_sig(cmd)
            bump(stack[-1][2], w, sig)
            stack[-1][4].append(_trace_token(cmd, w))
            still = []
            for waiting in awaiting:
                wpid, wsrc, windex = waiting[8], waiting[9], waiting[10]
                if index - windex > RECENT_RECORDS:
                    continue
                if wpid != pid and depth < waiting[1]:
                    if wsrc == src:
                        waiting[7].append(key[1])  # shares the run's anchor list
                    continue
                still.append(waiting)
            awaiting = still
            history.append((pid, depth, src, key[1]))
            if len(history) > RECENT_RECORDS:
                del history[0]
            if key != flat_key:
                flush(flat_key, flat_counts)
                flat_key, flat_counts = key, {}
            bump(flat_counts, w, sig)
            count += 1
        flush(flat_key, flat_counts)
        for stack in stacks.values():
            for run in stack:
                flush_run(run)
        if os.environ.get("SB_COV_KEEP_RAW"):
            trace.rename(trace.with_suffix(".kept"))
        else:
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
    """Credit statements from {line: {key: multiplicity}} and return coverage details.

    Keys are first words, signatures ("\x01" + literal words), per-function
    variants of both (FN_KEY + function + "\x1f" + key) and process runs
    (RUN_KEY + function + "\x1e" + words); see collect().

    A hit (line, word) credits statements whose own span contains the line and
    whose word matches; with multiplicity n it credits up to n such statements in
    source order. Only when nothing matches by span are attribution windows of
    commands inside multi-line substitutions consulted. Assignment hits ("=name")
    match statements that assign that name. Hits that still match nothing go to
    dynamic statements (unknown command word) on that line, else they are orphans.
    Per-function hits only credit statements in that function, so a record bash
    reports at another function's line (multi-line substitutions) cannot credit
    the wrong statement. Signature hits are applied first and credit only
    statements with that signature; the word pass then leaves statements whose
    signature could have been seen to the signature pass. Finally a process's run
    of records that no statement on its line explains is matched to the one
    process substitution in that function whose words contain the run's words:
    bash reports such commands at the line of the last function it parsed.
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

    def fn_ok(i: int, fn: str | None) -> bool:
        if fn is None:
            return True
        own = stmts[i].fn
        return own == fn or (own == "" and fn in ("", "source", "main"))

    def matches(i: int, w: str) -> bool:
        st = stmts[i]
        if w.startswith("="):
            return w[1:] in st.names or (st.kind == "assignment" and not st.names)
        return st.word is not None and st.word == w

    entries = []  # (line, function or None, key, multiplicity)
    runs = []  # (line, function, words)
    sig_words: dict[int, set] = {}
    plain_keys = 0
    for ln, words in line_words.items():
        if isinstance(words, list):  # tolerate the pre-multiplicity format
            words = {w: 1 for w in words}
        ln = int(ln)
        best: dict[str, int] = {}
        for k, n in words.items():
            if k.startswith(RUN_KEY):
                fn, _, rest = k[1:].partition("\x1e")
                rest, _, anchors = rest.partition("\x1d")
                before, _, after = anchors.partition("\x1c")
                runs.append((ln, fn, rest.split("\x1e"), [int(a) for a in (before, after) if a]))
            elif k.startswith(FN_KEY):
                fn, _, w = k[1:].partition("\x1f")
                entries.append((ln, fn, w, n))
                best[w] = max(best.get(w, 0), n)
        for k, n in words.items():
            if k.startswith((RUN_KEY, FN_KEY)):
                continue
            plain_keys += 1
            if k.startswith("\x01"):
                sig_words.setdefault(ln, set()).add(k[1:].split("\x1f", 1)[0])
            if n > best.get(k, 0):
                entries.append((ln, None, k, n))

    # Signatures first.
    for ln, fn, w, n in entries:
        if not w.startswith("\x01"):
            continue
        cands = [i for i in by_line.get(ln, []) + by_window.get(ln, []) if stmts[i].sig == w[1:] and fn_ok(i, fn)]
        for i in cands[: max(1, n)]:
            covered[i] = True

    orphans = set()
    for ln, fn, w, n in entries:
        if w.startswith("\x01"):
            continue
        own = [i for i in by_line.get(ln, []) if matches(i, w) and fn_ok(i, fn)]
        # Process substitutions inside functions are matched by their runs below.
        cands = own + [
            i
            for i in by_window.get(ln, [])
            if matches(i, w) and fn_ok(i, fn) and not (stmts[i].procsub and stmts[i].procsub[0])
        ]
        # A statement with a signature was credited by the signature pass if it ran.
        cands = [i for i in cands if not (stmts[i].sig and stmts[i].word in sig_words.get(ln, ()))] or cands
        if not cands:
            cands = [i for i in by_line.get(ln, []) if stmts[i].word is None and not w.startswith("=") and fn_ok(i, fn)]
        if not cands:
            orphans.add((ln, w))
            continue
        own_set = set(own)
        cands.sort(key=lambda i: (i not in own_set, not (covered[i] and stmts[i].sig is not None)))
        for i in cands[: max(1, n)]:
            covered[i] = True

    # Process substitutions reported at the wrong line.
    nodes: dict[tuple, list[int]] = {}
    for i, st in enumerate(stmts):
        if st.procsub is not None:
            nodes.setdefault(st.procsub[:2], []).append(i)
    def fit(idx: list[int], tokens: list[str]):
        """Statements of one substitution matching the run's tokens, or None."""
        free = list(idx)
        chosen = []
        for tok in tokens:
            w, _, argc = tok.partition("#")
            pick = next(
                (i for i in free if stmts[i].word == w and (not argc or stmts[i].argc in (None, int(argc)))),
                None,
            )
            if pick is None:
                return None
            free.remove(pick)
            chosen.append(pick)
        return chosen

    for ln, fn, tokens, anchors in runs:
        words = [t.partition("#")[0] for t in tokens]
        if all(any(matches(i, w) and fn_ok(i, fn) for i in by_line.get(ln, [])) for w in words):
            continue  # statements on this line explain the run
        fits = []
        for key, idx in nodes.items():
            if not (key[0] == fn or (key[0] == "" and fn in ("", "source", "main"))):
                continue
            chosen = fit(idx, tokens)
            if chosen is not None:
                fits.append((idx, chosen))
        if len(fits) > 1 and anchors:
            # The parent's records around the substitution belong to its enclosing
            # statement (the `while read` of `done < <(...)`), or come just before it.
            def span(f):
                ps = stmts[f[0][0]].procsub
                return ps[2], ps[3]

            near = [f for f in fits if any(span(f)[0] <= a <= span(f)[1] for a in anchors)]
            if not near:
                later = [f for f in fits if span(f)[0] > anchors[0]]
                first = min((span(f)[0] for f in later), default=None)
                near = [f for f in later if span(f)[0] == first]
            fits = near or fits
        if len(fits) != 1:
            continue  # ambiguous or unknown: leave it to the orphan list
        for i in fits[0][1]:
            covered[i] = True
        for w in words:
            orphans.discard((ln, w))
    orphans = [list(o) for o in sorted(orphans)]
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
        "orphan_hits": orphans,
        "hit_keys": plain_keys,
        "parse_errors": analysis.parse_errors,
    }


def _copy_matches_source(analysis: BashAnalysis, line_words: dict) -> bool:
    """True when a copy's hits line up with the source (rejects edited copies).

    Tests sometimes run a staged copy that was modified (lines inserted or
    removed). Its hits would land on the wrong statements, so a copy is only
    credited when at most 10% of its distinct (line, word) hits fail to match.
    """
    res = bash_file_coverage(analysis, line_words)
    total = res["hit_keys"]
    return total == 0 or len(res["orphan_hits"]) <= max(1, total // 10)


REJECTED_COPIES: list[str] = []


def bash_coverage(cov_dir: Path, scoped: list[str]) -> dict:
    hits_path = cov_dir / "bash-hits.json"
    hits = json.loads(hits_path.read_text()) if hits_path.exists() else {}
    mapping = _map_paths(hits.keys(), scoped)
    root = str(REPO_ROOT) + os.sep
    analyses: dict[str, BashAnalysis] = {}
    merged: dict[str, dict[int, dict]] = {}
    for traced, rel in mapping.items():
        real = os.path.realpath(traced) if os.path.exists(traced) else traced
        if not real.startswith(root):
            analysis = analyses.setdefault(rel, analyze_bash(REPO_ROOT / rel))
            line_words = {int(k): v for k, v in hits[traced].items()}
            if not _copy_matches_source(analysis, line_words):
                REJECTED_COPIES.append(f"{traced} -> {rel}")
                continue
        dest = merged.setdefault(rel, {})
        for ln, words in hits[traced].items():
            slot = dest.setdefault(int(ln), {})
            for w, n in (words.items() if isinstance(words, dict) else ((w, 1) for w in words)):
                slot[w] = max(slot.get(w, 0), n)
    results = {}
    for rel in scoped:
        analysis = analyses.get(rel) or analyze_bash(REPO_ROOT / rel)
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


def js_coverage(cov_dir: Path, scoped: list[str]) -> dict:
    """Merge Node LCOV files (tests/scripts/test-js-unit.sh) for scoped JS/TS files."""
    lines: dict[str, dict[int, int]] = {}
    funcs: dict[str, dict[tuple, int]] = {}
    branches: dict[str, dict[tuple, int]] = {}
    for info in sorted((cov_dir / "js").glob("*.info")) if (cov_dir / "js").exists() else []:
        current = None
        for raw in info.read_text(errors="replace").splitlines():
            if raw.startswith("SF:"):
                sf = raw[3:]
                path = os.path.normpath(sf if sf.startswith("/") else os.path.join(REPO_ROOT, sf))
                rel = os.path.relpath(path, REPO_ROOT)
                current = rel
                lines.setdefault(rel, {})
                funcs.setdefault(rel, {})
                branches.setdefault(rel, {})
            elif current is None:
                continue
            elif raw.startswith("DA:"):
                ln, cnt = raw[3:].split(",")[:2]
                lines[current][int(ln)] = max(lines[current].get(int(ln), 0), int(cnt))
            elif raw.startswith("FN:"):
                ln, name = raw[3:].split(",", 1)
                funcs[current].setdefault((name,), 0)
            elif raw.startswith("FNDA:"):
                cnt, name = raw[5:].split(",", 1)
                funcs[current][(name,)] = max(funcs[current].get((name,), 0), int(cnt))
            elif raw.startswith("BRDA:"):
                ln, block, br, taken = raw[5:].split(",")
                key = (int(ln), block, br)
                hit = 0 if taken == "-" else int(taken)
                branches[current][key] = max(branches[current].get(key, 0), hit)
            elif raw == "end_of_record":
                current = None
    results = {}
    for rel in scoped:
        if rel in lines:
            ln, fn, br = lines[rel], funcs[rel], branches[rel]
            results[rel] = {
                "lines": len(ln),
                "lines_covered": sum(1 for c in ln.values() if c),
                "functions": len(fn),
                "functions_covered": sum(1 for c in fn.values() if c),
                "branches": len(br),
                "branches_covered": sum(1 for c in br.values() if c),
                "missing_lines": sorted(k for k, c in ln.items() if not c),
                "measured": True,
            }
        else:
            text = (REPO_ROOT / rel).read_text(errors="replace").splitlines()
            approx = sum(1 for t in text if t.strip() and not t.strip().startswith(("//", "*", "/*")))
            results[rel] = {
                "lines": approx,
                "lines_covered": 0,
                "functions": 0,
                "functions_covered": 0,
                "branches": 0,
                "branches_covered": 0,
                "missing_lines": [],
                "measured": False,
            }
    return results


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
    bash_scoped, py_scoped, js_scoped = scoped["bash"], scoped["python"], scoped["javascript"]
    if only:
        bash_scoped = [f for f in bash_scoped if _matches(f, only)]
        py_scoped = [f for f in py_scoped if _matches(f, only)]
        js_scoped = [f for f in js_scoped if _matches(f, only)]
    bash = bash_coverage(cov_dir, bash_scoped)
    py = python_coverage(cov_dir, py_scoped)
    js = js_coverage(cov_dir, js_scoped)
    bt = _totals(bash, ["statements", "lines", "functions"])
    pt = _totals(py, ["statements", "branches"])
    jt = _totals(js, ["lines", "functions", "branches"])
    exclusions = []
    for lang in ("bash", "python", "javascript"):
        for e in scope.get(lang, {}).get("exclude", []):
            exclusions.append({"language": lang, **e})
    summary = {
        "bash": {**bt, "files": len(bash)},
        "python": {**pt, "files": len(py)},
        "javascript": {**jt, "files": len(js), "unmeasured_files": sorted(k for k, v in js.items() if not v["measured"])},
        "exclusions": exclusions,
    }
    (cov_dir / "coverage-summary.json").write_text(
        json.dumps({"summary": summary, "bash": bash, "python": py, "javascript": js}, indent=1, sort_keys=True)
    )

    # (file, primary covered, primary total, funcs covered, funcs total, branches covered, branches total)
    rows = []
    for rel, r in sorted(bash.items()):
        rows.append((rel, r["statements_covered"], r["statements"], r["functions_covered"], r["functions"], None, None))
    for rel, r in sorted(py.items()):
        rows.append((rel, r["statements_covered"], r["statements"], None, None, r["branches_covered"], r["branches"]))
    for rel, r in sorted(js.items()):
        rows.append((rel, r["lines_covered"], r["lines"], r["functions_covered"], r["functions"], r["branches_covered"], r["branches"]))
    width = max([len(r[0]) for r in rows] + [10])
    print(f"{'File':<{width}}  {'Stmts/Lines':>11}  {'Funcs':>9}  {'Branches':>11}  Cover")
    for rel, sc, s, fc, f, bc, b in rows:
        if sc == s and fc == f and bc == b and not show_missing:
            continue
        if js.get(rel) and not js[rel]["measured"]:
            print(f"{rel:<{width}}  {'-':>5}/~{s:<4}  {'-':>9}  {'-':>11}  not loaded by any JS test")
            continue
        funcs = f"{fc}/{f}" if f is not None else "-"
        br = f"{bc}/{b}" if b is not None else "-"
        print(f"{rel:<{width}}  {sc:>5}/{s:<5}  {funcs:>9}  {br:>11}  {_pct(sc, s):6.2f}%")
        if not show_missing:
            continue
        if rel in bash:
            r = bash[rel]
            if r["missing_statements"]:
                print("    missing: " + ", ".join(f"{m['line']}({m['word']})" for m in r["missing_statements"][:60]))
            if r["missing_functions"]:
                print("    uncalled functions: " + ", ".join(f["name"] for f in r["missing_functions"]))
        elif rel in py:
            r = py[rel]
            if r["missing_lines"]:
                print("    missing lines: " + _ranges(r["missing_lines"]))
            if r["missing_branches"]:
                print("    missing branches: " + ", ".join(f"{k}->{v}" for k, v in list(r["missing_branches"].items())[:40]))
        elif js[rel]["missing_lines"]:
            print("    missing lines: " + _ranges(js[rel]["missing_lines"]))
    print()
    totals = [
        f"Bash       files {len(bash)}: statements {bt['statements_covered']}/{bt['statements']} ({_pct(bt['statements_covered'], bt['statements']):.2f}%), "
        f"lines {bt['lines_covered']}/{bt['lines']} ({_pct(bt['lines_covered'], bt['lines']):.2f}%), "
        f"functions {bt['functions_covered']}/{bt['functions']} ({_pct(bt['functions_covered'], bt['functions']):.2f}%)",
        f"Python     files {len(py)}: statements {pt['statements_covered']}/{pt['statements']} ({_pct(pt['statements_covered'], pt['statements']):.2f}%), "
        f"branches {pt['branches_covered']}/{pt['branches']} ({_pct(pt['branches_covered'], pt['branches']):.2f}%)",
        f"JS/TS      files {len(js)}: lines {jt['lines_covered']}/{jt['lines']} ({_pct(jt['lines_covered'], jt['lines']):.2f}%), "
        f"functions {jt['functions_covered']}/{jt['functions']} ({_pct(jt['functions_covered'], jt['functions']):.2f}%), "
        f"branches {jt['branches_covered']}/{jt['branches']} ({_pct(jt['branches_covered'], jt['branches']):.2f}%)",
    ]
    for line in totals:
        print(line)
    unmeasured = summary["javascript"]["unmeasured_files"]
    if unmeasured:
        print(f"JS/TS files not loaded by any test (approximate line counts): {', '.join(unmeasured)}")
    if REJECTED_COPIES:
        print(f"Ignored {len(REJECTED_COPIES)} modified staged copies whose traces do not match the source (see coverage-summary.json)")
        summary["rejected_copies"] = REJECTED_COPIES
        (cov_dir / "coverage-summary.json").write_text(
            json.dumps({"summary": summary, "bash": bash, "python": py, "javascript": js}, indent=1, sort_keys=True)
        )
    orphan_total = sum(len(r["orphan_hits"]) for r in bash.values())
    if orphan_total:
        print(f"Unattributed bash trace hits: {orphan_total} (eval/trap bodies or analyzer gaps; per-file list in coverage-summary.json)")
    errors = {rel: r["parse_errors"] for rel, r in bash.items() if r["parse_errors"]}
    if errors:
        print("Bash parse errors (statements near these lines may be miscounted):")
        for rel, lines in errors.items():
            print(f"  {rel}: lines {lines[:10]}")
    (cov_dir / "coverage-summary.md").write_text(
        "# Coverage summary\n\n" + "\n".join(f"- {t}" for t in totals) + "\n"
    )
    if fail_under is not None:
        metrics = [
            _pct(bt["statements_covered"], bt["statements"]),
            _pct(bt["lines_covered"], bt["lines"]),
            _pct(bt["functions_covered"], bt["functions"]),
            _pct(pt["statements_covered"], pt["statements"]),
            _pct(pt["branches_covered"], pt["branches"]),
            _pct(jt["lines_covered"], jt["lines"]),
            _pct(jt["functions_covered"], jt["functions"]),
            _pct(jt["branches_covered"], jt["branches"]),
        ]
        if min(metrics) + 1e-9 < fail_under or (fail_under >= 100 and unmeasured):
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
    res = bash_coverage(cov_dir, [rel])[rel]
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
