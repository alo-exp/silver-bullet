"""Static analysis of shell commands and hook payloads for Silver Bullet hooks.

One parser and one analyzer serve every gate, so they all agree on what a command
does. The command is never executed; repository code is never run.

Command-line use, through analyze.py (input always on stdin, so payload size is never
limited by argv; importing this module lets Python reuse its cached bytecode):

    python3 analyze.py payload      [--base-dir DIR]  < hook-payload.json
    python3 analyze.py command      [--base-dir DIR]  < command.txt
    python3 analyze.py load-payload [--base-dir DIR]  < hook-payload.json
    python3 analyze.py load-command [--base-dir DIR]  < command.txt

``payload``/``command`` print the analysis as one JSON object. The ``load-*`` modes
print NUL-terminated ``key``/``value`` pairs for hooks/lib/shell-analysis.sh, ending
with the key ``__end__``. A missing ``__end__`` means the helper failed.

Bounded work: input over MAX_INPUT_CHARS is not parsed; the parser stops after MAX_PARSE_SECONDS and the
walker after MAX_STEPS commands or MAX_SECONDS (the deadline is checked at every step); a stored value over
MAX_VALUE_CHARS and an array over MAX_SEQUENCE items becomes unknown, brace sequences and GIT_CONFIG_COUNT are
capped, regular expressions over command text are linear, and an unexpected exception (the parser's included)
becomes status "parse_failed". Each of these reports ``unseen`` (strictest tier). Together they keep one analysis
under 2 s, so the three analyses a hook can make fit its 15 s limit.

Analysis schema (version 1):

  schema            1
  base_dir          the directory relative paths were resolved against
  status            "ok" | "empty" (no input) | "parse_failed" (invalid JSON payload,
                    shell syntax the parser rejects, or an analyzer fault; complete
                    commands before the error are still analyzed, and the rest counts
                    as unseen code, see ``unseen`` below)
  error             reason when status != "ok", else ""
  tool              payload mode: {"name", "kind": shell|mcp|patch|edit|other,
                    "mcp_server", "mcp_tool"}
  command           payload mode: the shell command (string, or a list joined with
                    shell quoting)
  file_path         payload mode: tool_input.file_path // tool_response.filePath //
                    first patch path
  patch_paths       payload mode: paths named by apply_patch markers
  actions           sorted delivery actions the command performs: commit, push,
                    pr_create, pr_merge, release_create, deploy, remote_write
  tier              highest tier of ``actions``: none | intermediate | completion
                    (commit/push are intermediate; everything else is completion)
  possible_actions  actions inferred for opaque parts from their visible arguments,
                    e.g. ``$X commit -m m`` -> commit; ``$PYTHON -m pytest`` -> none.
                    The pseudo action ``unseen`` (tier completion, canonical "deploy
                    [unseen: why]") stands for code that runs but cannot be read:
                    eval of computed text, a shell or interpreter fed by a pipe or an
                    open descriptor, bash -s, <(...), a program word computed in the
                    command (assigned from $(...), read, mapfile, cut by an operator,
                    xargs input), awk system(var), sed e, inline interpreter code that
                    runs a command that is not written out, arithmetic or subscripts
                    that evaluate a variable holding $(...), an IFS nobody knows, parse
                    errors, a script this command wrote from text it cannot read and then
                    runs, and any exceeded budget. Script files are opaque, not unseen.
                    It makes possible_tier "completion" and could_be_delivery true.
  possible_tier     highest tier of ``possible_actions``
  could_be_delivery true when ``possible_actions`` is not empty
  opaque            true when some part cannot be resolved statically (including every
                    script file, sourced file and interpreter program that is run)
  opaque_reasons    why: dynamic command words, non-literal eval/sh -c, parse errors...
  unseen_reasons    why code "cannot be inspected" (the reasons behind ``unseen``)
  read_only         strict allowlist verdict: every command is a known read-only
                    program with read-only arguments and nothing is written
  read_only_legacy  ``read_only`` or only plain test runners in addition
                    (the command_looks_read_only.py contract)
  test_runner       a test runner (npm test, node --test, jest...) is present
  writes            [{"path", "raw", "dynamic", "via", "scope": path|tree}]; dynamic
                    paths keep their unresolved text; "tree" means a whole work tree
  write_paths       legacy candidate_write_paths.py view: literal paths plus dynamic
                    paths that keep a static directory part
  opaque_writers    [{"program", "reason"}] code whose writes cannot be listed
                    (interpreter one-liners and scripts, awk system(), sed e...)
  delivery          [{"action", "tier", "canonical", "possible"}] one per delivery
                    command; ``canonical`` restates it with the verb phrase the legacy
                    regex consumers know ("gh pr create ...", "deploy ...")
  legacy_first_line canonical text of the highest-tier delivery commands (the
                    ``cmd_first_line`` value classify.sh exports), else the first line
  push              [{"remote", "refspecs", "dsts", "tags", "all", "mirror",
                    "delete", "force", "default"}] one per git push / send-pack
  commits           [{"all", "amend", "pathspecs", "staged_paths"}] one per commit;
                    ``staged_paths`` are git-add operands earlier in the command
  commands          [{"program", "argv", "cwd"}] every simple command, unwrapped
  skill_adapter     true for a lone literal ``scripts/silver-bullet invoke-skill ...``
  invoked_script    first script file the command runs that exists, else ""
  rtk_unwrapped     the command with a leading ``env``/assignments/``rtk`` prefix
                    removed (verbatim text), or "" when nothing was removed
"""

from __future__ import annotations

import json
import os
import re
import shlex
import sys
import time

SCHEMA_VERSION = 1
MAX_DEPTH = 24
MAX_EXPANSIONS = 64
MAX_LOOP_VALUES = 16
# Analysis budget: exceeding any limit ends the walk and reports unseen code (strictest tier),
# so a crafted command can neither stall a hook until its timeout nor crash the analyzer.
MAX_INPUT_CHARS = 512 * 1024
MAX_STEPS = 20000
# One analysis takes at most MAX_PARSE_SECONDS + MAX_SECONDS; dev-cycle-check runs three (write paths,
# invoked script, read-only) and the host stops a hook at 15 s, so all three stay well inside it.
MAX_SECONDS = 1.0
MAX_PARSE_SECONDS = 1.0
MAX_VALUE_CHARS = 64 * 1024   # a variable, array or stdin feed larger than this becomes unknown
MAX_SEQUENCE = 4096
MAX_GIT_CONFIG = 64

ACTION_TIER = {
    "commit": "intermediate",
    "push": "intermediate",
    "pr_create": "completion",
    "pr_merge": "completion",
    "release_create": "completion",
    "deploy": "completion",
    "remote_write": "completion",
    "unseen": "completion",
}
TIER_RANK = {"none": 0, "intermediate": 1, "completion": 2}
# Verb phrase the legacy regex consumers (deploy tier, change class, enterprise policy)
# recognise. A remote API write lands commits on a branch without a local push, so it
# is reported with the PR-merge phrase.
CANONICAL_PREFIX = {
    "commit": "git commit",
    "push": "git push",
    "pr_create": "gh pr create",
    "pr_merge": "gh pr merge",
    "release_create": "gh release create",
    "deploy": "deploy",
    "remote_write": "gh pr merge",
    "unseen": "deploy",
}


# =============================================================================
# Parser: bash syntax -> a small tree (Script / AndOr / Pipeline / Simple / Compound)
# =============================================================================


class ParseError(Exception):
    """The text is not shell syntax the parser accepts."""


class Word:
    """One shell word: atoms plus the scripts its substitutions run.

    atoms: ("lit", text, quoted) | ("var", name, quoted) | ("cmd", Script, quoted, raw)
           | ("dyn", raw, quoted)
    """

    __slots__ = ("atoms", "nested", "text", "start")

    def __init__(self, atoms, nested, text, start=-1):
        self.atoms = atoms
        self.nested = nested
        self.text = text
        self.start = start

    def literal(self):
        """The value when the word is plain text (quotes removed), else None."""
        if any(atom[0] != "lit" for atom in self.atoms):
            return None
        return "".join(atom[1] for atom in self.atoms)

    def unquoted_literal(self):
        """The value when the word is unquoted plain text, else None."""
        if all(atom[0] == "lit" and not atom[2] for atom in self.atoms):
            return "".join(atom[1] for atom in self.atoms)
        return None


class Redir:
    __slots__ = ("op", "fd", "target", "quoted", "body", "body_word")

    def __init__(self, op, fd, target):
        self.op = op
        self.fd = fd
        self.target = target
        self.quoted = False
        self.body = None
        self.body_word = None


class Assign:
    __slots__ = ("name", "value", "append", "array")

    def __init__(self, name, value, append, array):
        self.name = name
        self.value = value
        self.append = append
        self.array = array


class Simple:
    __slots__ = ("assigns", "words", "redirs")

    def __init__(self, assigns, words, redirs):
        self.assigns = assigns
        self.words = words
        self.redirs = redirs


class Compound:
    __slots__ = ("kind", "parts", "redirs", "extra")

    def __init__(self, kind, parts, extra=None):
        self.kind = kind
        self.parts = parts
        self.redirs = []
        self.extra = extra


class Script:
    __slots__ = ("items", "error")

    def __init__(self, items, error=""):
        self.items = items
        self.error = error


_META = " \t\n;&|<>()"
_WORD_PLAIN = re.compile(r"[^ \t\n;&|<>()'\"\\$`]+")
_DQ_PLAIN = re.compile(r"[^\"\\$`]+")
_HEREDOC_PLAIN = re.compile(r"[^\\$`]+")
_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_ASSIGN = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)(\[[^\]\n]*\])?(\+?)=")
_REDIR = re.compile(r"(\d+|\{[A-Za-z_][A-Za-z0-9_]*\})?(<<<|<<-|<<|<>|<&|>>|>&|>\||<|>|&>>|&>)")
_ANSI_SIMPLE = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "e": "\x1b", "E": "\x1b",
                "f": "\f", "v": "\v", "\\": "\\", "'": "'", '"': '"', "?": "?"}
_DECLARATIONS = {"declare", "typeset", "local", "export", "readonly"}
_KEYWORDS = (("{", "kw_brace"), ("if", "kw_if"), ("while", "kw_while"), ("until", "kw_while"),
             ("for", "kw_for"), ("select", "kw_for"), ("case", "kw_case"),
             ("function", "kw_function"), ("[[", "kw_cond"), ("coproc", "kw_coproc"))


class _Parser:
    def __init__(self, src, deadline=None):
        self.s = src
        self.n = len(src)
        self.i = 0
        self.heredocs = []
        self.ticks = 0
        self.deadline = deadline if deadline is not None else time.monotonic() + MAX_PARSE_SECONDS

    def tick(self):
        self.ticks += 1
        if self.ticks % 16 == 0 and time.monotonic() > self.deadline:
            raise ParseError("analysis time budget exceeded")

    # -- characters ---------------------------------------------------------
    def peek(self, k=0):
        j = self.i + k
        return self.s[j] if j < self.n else ""

    def at(self, text):
        return self.s.startswith(text, self.i)

    def at_word(self, word):
        """True when the next token is exactly the unquoted word ``word``."""
        if not self.s.startswith(word, self.i):
            return False
        j = self.i + len(word)
        return j >= self.n or self.s[j] in _META

    def expect(self, text):
        if not self.at(text):
            raise ParseError("expected '%s'" % text)
        self.i += len(text)

    def expect_word(self, word):
        self.skip_newlines()
        if not self.at_word(word):
            raise ParseError("expected '%s'" % word)
        self.i += len(word)

    def skip_blanks(self):
        """Skip blanks, line continuations and comments (a '#' that starts a word)."""
        while self.i < self.n:
            c = self.s[self.i]
            if c in " \t":
                self.i += 1
            elif c == "\\" and self.peek(1) == "\n":
                self.i += 2
            elif c == "#":
                j = self.s.find("\n", self.i)
                self.i = self.n if j < 0 else j
            else:
                return

    def newline(self):
        """Consume a newline, then read the bodies of here-documents opened on that line."""
        self.i += 1
        pending, self.heredocs = self.heredocs, []
        for redir in pending:
            self.read_heredoc(redir)

    def skip_newlines(self):
        while True:
            self.skip_blanks()
            if self.peek() != "\n":
                return
            self.newline()

    # -- lists --------------------------------------------------------------
    def at_stop(self, stops):
        c = self.peek()
        if c == ")":
            return ")" in stops
        if c == ";":
            return ";;" in stops and self.peek(1) in (";", "&")
        return any(self.at_word(word) for word in stops if word not in (")", ";;"))

    def parse_list(self, stops, top=False):
        items = []
        while True:
            try:  # skip_newlines reads here-documents too, so it can fail like parse_item
                self.skip_newlines()
                if self.i >= self.n or self.at_stop(stops):
                    return Script(items)
                item = self.parse_item()
            except Exception as exc:  # noqa: BLE001 - keep the commands read so far, whatever went wrong
                if not top:
                    raise
                return Script(items, _parse_failure(exc))
            items.append(item)

    def parse_item(self):
        andor = self.parse_andor()
        self.skip_blanks()
        background = False
        c = self.peek()
        if c == ";" and self.peek(1) not in (";", "&"):
            self.i += 1
        elif c == "&":
            self.i += 1
            background = True
        elif c == "\n":
            self.newline()
        return andor, background

    def parse_andor(self):
        pipes = [self.parse_pipeline()]
        while True:
            self.skip_blanks()
            if not (self.at("&&") or self.at("||")):
                return pipes
            self.i += 2
            self.skip_newlines()
            pipes.append(self.parse_pipeline())

    def parse_pipeline(self):
        while True:
            self.skip_blanks()
            if self.at_word("!"):
                self.i += 1
            elif self.at_word("time"):
                self.i += 4
                self.skip_blanks()
                if self.at_word("-p"):
                    self.i += 2
            else:
                break
        cmds = [self.parse_command()]
        while True:
            self.skip_blanks()
            if self.at("||") or self.peek() != "|":
                return cmds
            self.i += 2 if self.at("|&") else 1
            self.skip_newlines()
            cmds.append(self.parse_command())

    # -- commands -----------------------------------------------------------
    def parse_command(self):
        self.tick()
        self.skip_blanks()
        c = self.peek()
        if c == "":
            raise ParseError("unexpected end of input")
        if c == "(":
            if self.at("(("):
                return self.finish(self.parse_arith_command())
            self.i += 1
            body = self.parse_list((")",))
            self.expect(")")
            return self.finish(Compound("subshell", [body]))
        if c in ");&|":
            raise ParseError("unexpected '%s'" % c)
        for keyword, method in _KEYWORDS:
            if self.at_word(keyword):
                self.i += len(keyword)
                return self.finish(getattr(self, method)())
        return self.parse_simple()

    def finish(self, node):
        while True:
            self.skip_blanks()
            redir = self.try_redir()
            if redir is None:
                return node
            node.redirs.append(redir)

    def kw_brace(self):
        body = self.parse_list(("}",))
        self.expect_word("}")
        return Compound("group", [body])

    def kw_if(self):
        parts = []
        while True:
            parts.append(self.parse_list(("then",)))
            self.expect_word("then")
            parts.append(self.parse_list(("elif", "else", "fi")))
            if self.at_word("elif"):
                self.i += 4
                continue
            if self.at_word("else"):
                self.i += 4
                parts.append(self.parse_list(("fi",)))
            self.expect_word("fi")
            return Compound("group", parts)

    def kw_while(self):
        cond = self.parse_list(("do",))
        self.expect_word("do")
        body = self.parse_list(("done",))
        self.expect_word("done")
        return Compound("group", [cond, body])

    def kw_for(self):
        self.skip_blanks()
        if self.at("(("):
            header = self.parse_arith_command()
            name, values = None, None
            nested = [header]
        else:
            name = self.parse_word().literal()
            values = None
            self.skip_newlines()
            if self.at_word("in"):
                self.i += 2
                values = []
                while True:
                    self.skip_blanks()
                    if self.peek() in ("", "\n", ";"):
                        break
                    start = self.i
                    values.append(self.parse_word())
                    if self.i == start:  # a metacharacter such as ")" or "|" ends no word: do not loop on it
                        raise ParseError("unexpected '%s' in the word list of a for loop" % self.peek())
            nested = []
        self.skip_blanks()
        if self.peek() == ";":
            self.i += 1
        self.skip_newlines()
        if self.at_word("{"):
            self.i += 1
            body = self.parse_list(("}",))
            self.expect_word("}")
        else:
            self.expect_word("do")
            body = self.parse_list(("done",))
            self.expect_word("done")
        return Compound("for", [body], (name, values, nested))

    def kw_case(self):
        self.skip_blanks()
        subject = self.parse_word()
        self.expect_word("in")
        patterns, parts = [subject], []
        while True:
            self.skip_newlines()
            if self.at_word("esac"):
                self.i += 4
                return Compound("case", parts, patterns)
            if self.peek() == "(":
                self.i += 1
            while True:
                self.skip_blanks()
                patterns.append(self.parse_word())
                self.skip_blanks()
                if self.peek() != "|":
                    break
                self.i += 1
            self.expect(")")
            parts.append(self.parse_list(("esac", ";;")))
            self.skip_blanks()
            if self.at(";;&"):
                self.i += 3
            elif self.at(";;") or self.at(";&"):
                self.i += 2

    def kw_function(self):
        self.skip_blanks()
        name = self.parse_word().literal()
        self.skip_blanks()
        if self.peek() == "(":
            self.i += 1
            self.skip_blanks()
            self.expect(")")
        return self.function_body(name)

    def function_body(self, name):
        self.skip_newlines()
        body = self.parse_command()
        return Compound("function", [Script([([[body]], False)])], name)

    def kw_cond(self):
        words = []
        while True:
            self.skip_newlines()
            if self.at_word("]]"):
                self.i += 2
                return Compound("words", [], words)
            if self.i >= self.n:
                raise ParseError("unterminated [[")
            if self.peek() in _META:
                self.i += 1
                continue
            words.append(self.parse_word())

    def kw_coproc(self):
        self.skip_blanks()
        m = _NAME.match(self.s, self.i)
        if m is not None:  # coproc NAME { ...; } / coproc NAME ( ... ): NAME is not the program
            j = m.end()
            while j < self.n and self.s[j] in " \t":
                j += 1
            if j < self.n and self.s[j] in "{(":
                self.i = j
        return Compound("group", [Script([([[self.parse_command()]], False)])])

    def parse_arith_command(self):
        start = self.i
        self.i += 2
        word = self.scan_arith()
        return Compound("words", [], [Word(word.atoms, word.nested, self.s[start:self.i])])

    def scan_arith(self):
        """Scan an arithmetic body up to the closing '))'; collect its substitutions."""
        depth, atoms, nested = 0, [], []
        while True:
            self.tick()
            if self.i >= self.n:
                raise ParseError("unterminated arithmetic expression")
            c = self.s[self.i]
            if c == ")" and depth == 0 and self.peek(1) == ")":
                self.i += 2
                return Word(atoms, nested, "")
            if c == "$" and (self.peek(1) in ("(", "{") or self.peek(1) == "["):
                atom = self.parse_dollar(True, nested)
                atoms.append(atom)
                continue
            if c == "`":
                atoms.append(self.parse_backtick(True, nested))
                continue
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            self.i += 1

    def parse_simple(self):
        assigns, words, redirs = [], [], []
        while True:
            self.tick()
            self.skip_blanks()
            c = self.peek()
            if c in ("", "\n", ";", "|", ")") or (c == "&" and not self.at("&>")):
                break
            if c == "(":
                if len(words) == 1 and not assigns and not redirs and self.funcdef_parens():
                    return self.function_body(words[0].literal())
                raise ParseError("unexpected '('")
            redir = self.try_redir()
            if redir is not None:
                redirs.append(redir)
                continue
            if not words:
                assign = self.try_assign()
                if assign is not None:
                    assigns.append(assign)
                    continue
            elif words[0].literal() in _DECLARATIONS and _ASSIGN.match(self.s, self.i):
                start = self.i
                assign = self.try_assign()
                if assign.array:
                    nested = [script for word in assign.value for script in word.nested]
                    words.append(Word([("lit", assign.name + "=", False), ("dyn", "(...)", False)], nested,
                                      self.s[start:self.i], start))
                    continue
                self.i = start
            words.append(self.parse_word())
        if not (assigns or words or redirs):
            raise ParseError("expected a command")
        return Simple(assigns, words, redirs)

    def funcdef_parens(self):
        j = self.i + 1
        while j < self.n and self.s[j] in " \t":
            j += 1
        if j < self.n and self.s[j] == ")":
            self.i = j + 1
            return True
        return False

    def try_assign(self):
        m = _ASSIGN.match(self.s, self.i)
        if m is None:
            return None
        self.i = m.end()
        name = m.group(1)
        array = bool(m.group(2))
        if array:
            name += m.group(2)  # keep the subscript: a[i]=x sets one element, a[$(cmd)]=x runs cmd
        if self.peek() == "(":
            self.i += 1
            elements = []
            while True:
                self.skip_newlines()
                c = self.peek()
                if c == ")":
                    self.i += 1
                    return Assign(name, elements, bool(m.group(3)), True)
                if c == "":
                    raise ParseError("unterminated array assignment")
                word = self.parse_word()
                if word.text:
                    elements.append(word)
                else:
                    self.i += 1
        return Assign(name, [self.parse_word()], bool(m.group(3)), array)

    def try_redir(self):
        m = _REDIR.match(self.s, self.i)
        if m is None:
            return None
        op = m.group(2)
        if op in ("<", ">") and m.group(1) is None and self.s.startswith("(", m.end()):
            return None
        self.i = m.end()
        self.skip_blanks()
        target = self.parse_word()
        if not target.text:
            raise ParseError("missing redirection target")
        redir = Redir(op, m.group(1), target)
        if op in ("<<", "<<-"):
            redir.quoted = any(ch in target.text for ch in "'\"\\")
            self.heredocs.append(redir)
        return redir

    def read_heredoc(self, redir):
        delim = redir.target.literal()
        if delim is None:
            delim = redir.target.text.replace('"', "").replace("'", "")
        lines = []
        while self.i < self.n:
            j = self.s.find("\n", self.i)
            end = self.n if j < 0 else j
            line = self.s[self.i:end]
            self.i = min(end + 1, self.n)
            if redir.op == "<<-":
                line = line.lstrip("\t")
            if line == delim:
                break
            lines.append(line)
        redir.body = "".join(line + "\n" for line in lines)
        if not redir.quoted:
            sub = _Parser(redir.body, self.deadline)
            redir.body_word = sub.scan_text(None)

    # -- words --------------------------------------------------------------
    def parse_word(self):
        start = self.i
        atoms, nested, buf = [], [], []

        def flush():
            if buf:
                atoms.append(("lit", "".join(buf), False))
                del buf[:]

        if self.peek() in ("<", ">") and self.peek(1) == "(":
            self.i += 2
            nested.append(self.parse_list((")",)))
            self.expect(")")
            atoms.append(("dyn", self.s[start:self.i], False))
        while self.i < self.n:
            self.tick()
            m = _WORD_PLAIN.match(self.s, self.i)
            if m is not None:
                buf.append(m.group())
                self.i = m.end()
                if self.peek() == "(" and m.group()[-1] in "?*+@!":
                    buf.append(self.balanced_parens())
                continue
            c = self.s[self.i]
            if c in _META:
                break
            if c == "\\":
                nxt = self.peek(1)
                self.i += 2
                if nxt == "\n":
                    continue
                flush()
                atoms.append(("lit", nxt or "\\", True))
            elif c == "'":
                j = self.s.find("'", self.i + 1)
                if j < 0:
                    raise ParseError("unterminated single quote")
                flush()
                atoms.append(("lit", self.s[self.i + 1:j], True))
                self.i = j + 1
            elif c == '"':
                flush()
                self.i += 1
                inner = self.scan_text('"')
                atoms.extend(inner.atoms)
                nested.extend(inner.nested)
            elif c == "`":
                flush()
                atoms.append(self.parse_backtick(False, nested))
            elif self.peek(1) == "'":
                flush()
                atoms.append(("lit", self.read_ansi_c(), True))
            elif self.peek(1) == '"':
                flush()
                self.i += 2
                inner = self.scan_text('"')
                atoms.extend(inner.atoms)
                nested.extend(inner.nested)
            else:
                atom = self.parse_dollar(False, nested)
                if atom is None:
                    buf.append("$")
                    self.i += 1
                else:
                    flush()
                    atoms.append(atom)
        flush()
        return Word(atoms, nested, self.s[start:self.i], start)

    def balanced_parens(self):
        start, depth = self.i, 0
        while True:
            self.tick()
            c = self.peek()
            if c == "":
                raise ParseError("unterminated pattern")
            self.i += 1
            depth += {"(": 1, ")": -1}.get(c, 0)
            if depth == 0:
                return self.s[start:self.i]

    def scan_text(self, terminator):
        """Double-quoted text (terminator '"') or an unquoted here-document body (None)."""
        atoms, nested, buf = [], [], []

        def flush():
            if buf:
                atoms.append(("lit", "".join(buf), True))
                del buf[:]

        plain = _DQ_PLAIN if terminator else _HEREDOC_PLAIN
        escapable = '$`"\\\n' if terminator else "$`\\\n"
        while True:
            self.tick()
            if self.i >= self.n:
                if terminator:
                    raise ParseError("unterminated double quote")
                break
            c = self.s[self.i]
            if c == terminator:
                self.i += 1
                break
            if c == "\\":
                nxt = self.peek(1)
                if nxt and nxt in escapable:
                    if nxt != "\n":
                        buf.append(nxt)
                    self.i += 2
                else:
                    buf.append("\\")
                    self.i += 1
            elif c == "$":
                atom = self.parse_dollar(True, nested)
                if atom is None:
                    buf.append("$")
                    self.i += 1
                else:
                    flush()
                    atoms.append(atom)
            elif c == "`":
                flush()
                atoms.append(self.parse_backtick(True, nested))
            else:
                m = plain.match(self.s, self.i)
                buf.append(m.group())
                self.i = m.end()
        flush()
        if not atoms:
            atoms.append(("lit", "", True))
        return Word(atoms, nested, "")

    def parse_dollar(self, quoted, nested):
        start = self.i
        nxt = self.peek(1)
        if nxt == "(":
            if self.peek(2) == "(":
                self.i += 3
                inner = self.scan_arith()
                nested.extend(inner.nested)
                return ("dyn", self.s[start:self.i], quoted)
            self.i += 2
            script = self.parse_list((")",))
            self.expect(")")
            nested.append(script)
            return ("cmd", script, quoted, self.s[start:self.i])
        if nxt == "{":
            return self.parse_braced(quoted, nested)
        if nxt == "[":
            j = self.s.find("]", self.i)
            if j < 0:
                raise ParseError("unterminated $[")
            self.i = j + 1
            return ("dyn", self.s[start:self.i], quoted)
        m = _NAME.match(self.s, self.i + 1)
        if m is not None:
            self.i = m.end()
            return ("var", m.group(), quoted)
        if nxt and nxt in "0123456789@*":
            self.i += 2
            return ("var", nxt, quoted)
        if nxt and nxt in "#?$!-":
            self.i += 2
            return ("dyn", self.s[start:self.i], quoted)
        return None

    def parse_braced(self, quoted, nested):
        start = self.i
        self.i += 2
        depth = 1
        while True:
            self.tick()
            c = self.peek()
            if c == "":
                raise ParseError("unterminated ${")
            if c == "}":
                depth -= 1
                self.i += 1
                if depth == 0:
                    break
            elif c == "$" and self.peek(1) in ("(", "{"):
                if self.peek(1) == "{":
                    depth += 1
                    self.i += 2
                else:
                    self.parse_dollar(True, nested)
            elif c == "`":
                self.parse_backtick(True, nested)
            elif c == "\\":
                self.i += 2
            elif c == "'" and not quoted:
                j = self.s.find("'", self.i + 1)
                if j < 0:
                    raise ParseError("unterminated single quote")
                self.i = j + 1
            elif c == '"':
                self.i += 1
                nested.extend(self.scan_text('"').nested)
            else:
                self.i += 1
        raw = self.s[start:self.i]
        inner = raw[2:-1]
        if _NAME.fullmatch(inner) or inner.isdigit():
            return ("var", inner, quoted)
        return ("dyn", raw, quoted)

    def parse_backtick(self, quoted, nested):
        start = self.i
        j = self.i + 1
        out = []
        escapable = '$`\\"' if quoted else "$`\\"
        while True:
            self.tick()
            if j >= self.n:
                raise ParseError("unterminated backquote")
            c = self.s[j]
            if c == "`":
                break
            if c == "\\" and j + 1 < self.n and self.s[j + 1] in escapable:
                out.append(self.s[j + 1])
                j += 2
                continue
            out.append(c)
            j += 1
        self.i = j + 1
        script = _Parser("".join(out), self.deadline).parse_list(())
        nested.append(script)
        return ("cmd", script, quoted, self.s[start:self.i])

    def read_ansi_c(self):
        j = self.i + 2
        out = []
        while True:
            self.tick()
            if j >= self.n:
                raise ParseError("unterminated $'")
            c = self.s[j]
            if c == "'":
                break
            if c != "\\" or j + 1 >= self.n:
                out.append(c)
                j += 1
                continue
            e = self.s[j + 1]
            j += 2
            if e in _ANSI_SIMPLE:
                out.append(_ANSI_SIMPLE[e])
            elif e in "xuU":
                m = re.match(r"[0-9A-Fa-f]{1,%d}" % {"x": 2, "u": 4, "U": 8}[e], self.s[j:])
                if m is None:
                    out.append("\\" + e)
                else:
                    out.append(chr(min(int(m.group(), 16), 0x10FFFF)))
                    j += m.end()
            elif e in "01234567":
                m = re.match(r"[0-7]{0,2}", self.s[j:])
                out.append(chr(int(e + m.group(), 8)))
                j += m.end()
            elif e == "c" and j < self.n:
                out.append(chr(ord(self.s[j]) & 0x1F))
                j += 1
            else:
                out.append("\\" + e)
        self.i = j + 1
        return "".join(out).split("\x00", 1)[0]


def _parse_failure(exc):
    if isinstance(exc, ParseError):
        return str(exc)
    return "nesting too deep" if isinstance(exc, RecursionError) else "parser error: %s" % type(exc).__name__


def parse(text, deadline=None):
    """Parse ``text``; on a syntax error keep the complete commands before it.

    Never raises: an unexpected fault in the parser is a parse error like any other.
    """
    try:
        return _Parser(text, deadline).parse_list((), top=True)
    except Exception as exc:  # noqa: BLE001 - the parser must not crash a hook, whatever the input
        return Script([], _parse_failure(exc))


# =============================================================================
# Expansion: words -> argv items (str, GlobStr, Dyn)
# =============================================================================


class Dyn:
    """An argument whose value is unknown statically.

    ``roots`` lists the paths it stands for when known (find -exec's {}, xargs input
    produced by find). ``tainted`` marks a value computed in the command itself.
    """

    __slots__ = ("text", "roots", "tainted")

    def __init__(self, text, roots=None, tainted=False):
        self.text = text
        self.roots = roots
        # tainted: the value was computed in this very command (read from a file or a substitution, cut
        # by an operator, taken from stdin...), so used as a program it runs code nobody can read. An
        # untainted Dyn is only unknown (an inherited variable such as $PYTHON), and is judged by its arguments.
        self.tainted = tainted


class GlobStr(str):
    """A literal argument with unquoted glob characters; the shell may replace it."""


def _text(item):
    return item.text if isinstance(item, Dyn) else str(item)


def _cap(value):
    """A stored value larger than MAX_VALUE_CHARS is treated as unknown (None), so repeated
    doubling (x=$x$x) cannot make each step cost more than the budget allows."""
    return None if isinstance(value, str) and len(value) > MAX_VALUE_CHARS else value


def _lit(item):
    """The value of a plain literal argv item; None for Dyn and glob items."""
    if isinstance(item, (Dyn, GlobStr)):
        return None
    return item


class Env:
    """What the walker knows about the shell at one point of the command."""

    def __init__(self, cwd, home):
        self.vars = {}
        self.cwd = cwd
        self.cwd_text = cwd
        self.oldpwd = None
        self.home = home
        self.aliases = {}
        self.functions = {}
        self.git_aliases = {}
        self.positional = None
        self.arrays = {}
        self.files = {}         # path -> text a redirect in this command wrote there (None: content unknown)
        self.integers = set()   # names declared with -i: their assignments are arithmetic
        self.arg0 = None        # $0 of a `sh -c` script: text, False (unknown item) or None (the shell's own)

    def copy(self):
        new = Env(self.cwd, self.home)
        new.vars = dict(self.vars)
        new.cwd_text = self.cwd_text
        new.oldpwd = self.oldpwd
        new.aliases = dict(self.aliases)
        new.functions = dict(self.functions)
        new.git_aliases = dict(self.git_aliases)
        new.arrays = dict(self.arrays)
        new.positional = None if self.positional is None else list(self.positional)
        new.integers = set(self.integers)
        new.files = dict(self.files)
        new.arg0 = self.arg0
        return new

    def lookup(self, name):
        """``(value, tainted)``: the value when known, else None; tainted when the command itself
        assigned the name something the analysis cannot know (an inherited variable is not)."""
        if name in self.vars:
            value = self.vars[name]
            return value, value is None
        if name == "IFS":
            return " \t\n", False
        if name == "0":
            return (None, True) if self.arg0 is False else (self.arg0, False)
        if name.isdigit() or name in ("@", "*"):
            if self.positional is None:
                return None, False
            if name in ("@", "*"):
                if all(_lit(item) is not None for item in self.positional):
                    return " ".join(self.positional), False
                return None, any(isinstance(item, Dyn) and item.tainted for item in self.positional)
            index = int(name)
            if index > len(self.positional):
                return "", False
            value = self.positional[index - 1]
            return _lit(value), isinstance(value, Dyn) and value.tainted
        return {"HOME": self.home, "PWD": self.cwd, "OLDPWD": self.oldpwd}.get(name), False

    def get(self, name):
        return self.lookup(name)[0]

    def chdir(self, item):
        """cd to an argv item; an unknown target makes the directory dynamic."""
        self.oldpwd = self.cwd
        target = _lit(item)
        if target is None or (self.cwd is None and not target.startswith(("/", "~"))):
            self.cwd = None
            self.cwd_text = os.path.join(self.cwd_text, _text(item))
            return
        self.cwd = os.path.normpath(os.path.join(self.cwd or "/", os.path.expanduser(target)))
        self.cwd_text = self.cwd


# `eval "$(tool init)"` setup lines: the whole substitution is one well-known environment tool with plain
# arguments (nothing chained, piped, concatenated or quoted), whose output is shell code for the environment
_GENERATOR_TOOLS = (
    # tools that print shell code and take only plain words as arguments (no sub-command is ever run)
    r"(?:direnv\s+(?:export|hook)|(?:pyenv|rbenv|nodenv|plenv|jenv|goenv)\s+init|fnm\s+env|mise\s+(?:activate|env)|"
    r"(?:/opt/homebrew/bin/|/usr/local/bin/|/home/linuxbrew/\.linuxbrew/bin/)?brew\s+shellenv|starship\s+init|"
    r"zoxide\s+init|opam\s+env|luarocks\s+path|dircolors|conda\s+shell\.\w+\s+hook|poetry\s+env\s+activate|"
    r"register-python-argcomplete|keychain\s+--eval|minikube\s+docker-env|docker-machine\s+env|"
    r"aws\s+configure\s+export-credentials|(?:kubectl|gh|helm|npm|pip3?|poetry|docker|kind|minikube|k3d|just|uv|ruff|"
    r"pipx|rustup|cargo|flux|argocd|istioctl|oc|gcloud|aws_completer)\s+completions?)(?:\s+[\w./=:@-]+)*|"
    # agents that run whatever follows their flags: only the flags that print the environment are allowed
    r"(?:/usr/bin/)?ssh-agent(?:\s+-[sc])?|gpg-agent\s+--daemon")
_ENV_GENERATOR = re.compile(r"^(?:\$|<)\(\s*(?:%s)\s*(?:2>/dev/null\s*)?\)$" % _GENERATOR_TOOLS)
# a substitution that prints a path or a program name, not command text (`$(which python) -m pytest`)
_PATH_PRODUCER = re.compile(
    r"^\$\(\s*(?:which|command\s+-v|type\s+-p|whereis|readlink|realpath|dirname|basename|pwd|pyenv\s+which|"
    r"rbenv\s+which|asdf\s+which|mise\s+which|nvm\s+which|npm\s+(?:bin|root)|yarn\s+(?:bin|global\s+dir)|"
    r"git\s+(?:rev-parse|--exec-path)|brew\s+--prefix|xcrun\s+--find|go\s+env|python[0-9.]*\s+-c\s+'import sys; print\(sys\.executable\)')"
    r"(?:\s+[^;&|`()<>]*)?\s*\)$")
_PARAM = re.compile(r"^\$\{([!#]?)([A-Za-z_][A-Za-z0-9_]*|[0-9]+|[@*])(?:\[([^\]]*)\])?(.*)\}$", re.S)


def _glob_regex(pattern, greedy=True):
    """A shell glob pattern as a regular expression; None when it does not translate."""
    out, i = [], 0
    while i < len(pattern):
        c = pattern[i]
        if c == "*":
            out.append(".*" if greedy else ".*?")
        elif c == "?":
            out.append(".")
        elif c == "[" and pattern.find("]", i + 2) > 0:
            j = pattern.find("]", i + 2)
            body = pattern[i + 1:j]
            out.append("[" + ("^" + body[1:] if body[:1] == "!" else body).replace("\\", "\\\\") + "]")
            i = j
        elif c == "\\" and i + 1 < len(pattern):
            i += 1
            out.append(re.escape(pattern[i]))
        else:
            out.append(re.escape(c))
        i += 1
    return "".join(out)


def _param_operator(value, op):
    """The result of a parameter-expansion operator on a known ``value``; None when not modelled."""
    if len(value) > 4096 or "$" in op or "`" in op or "'" in op or '"' in op:
        return None
    try:
        if op[:1] in ("#", "%"):
            greedy = op[1:2] == op[:1]
            pattern = op[2:] if greedy else op[1:]
            regex = re.compile(_glob_regex(pattern), re.S)
            cuts = range(len(value) + 1) if op[0] == "#" else range(len(value), -1, -1)
            spans = [(k, value[:k]) if op[0] == "#" else (k, value[k:]) for k in cuts]
            hits = [k for k, part in spans if regex.fullmatch(part)]
            if not hits:
                return value
            k = (max(hits) if greedy else min(hits)) if op[0] == "#" else (min(hits) if greedy else max(hits))
            return value[k:] if op[0] == "#" else value[:k]
        if op[:1] == "/":
            mode = op[1:2] if op[1:2] in ("/", "#", "%") else ""
            body = op[1 + len(mode):]
            pattern, sep, replacement = body.partition("/")
            if not pattern:
                return value
            regex = _glob_regex(pattern)
            if mode == "#":
                regex = "^" + regex
            elif mode == "%":
                regex = regex + "$"
            return re.sub(regex, lambda _m: replacement, value, count=0 if mode == "/" else 1, flags=re.S)
        if op[:1] == ":" and (op[1:2].isdigit() or op[1:2] in (" ", "-")):
            numbers = [part.strip() for part in op[1:].split(":")]
            offset = int(numbers[0])
            length = int(numbers[1]) if len(numbers) > 1 else None
            if offset < 0:
                offset = max(len(value) + offset, 0)
            end = None if length is None else offset + length if length >= 0 else len(value) + length
            return value[offset:end]
        if op in ("^^", "@U"):
            return value.upper()
        if op in (",,", "@L"):
            return value.lower()
        if op == "^":
            return value[:1].upper() + value[1:]
        if op == ",":
            return value[:1].lower() + value[1:]
    except (re.error, ValueError):
        return None
    return None


_GH_VALUE_OPTS = {"-t", "--title", "-b", "--body", "-F", "--body-file", "-R", "--repo", "-B", "--base", "-H",
                  "--head", "-a", "--assignee", "-l", "--label", "-m", "--milestone", "-p", "--project", "-r",
                  "--reviewer", "-n", "--notes", "--notes-file", "-N", "--notes-start-tag", "--target",
                  "--discussion-category", "-f", "--field", "--raw-field", "-X", "--method", "-q", "--jq",
                  "--template", "--hostname", "--subject", "--author", "--match-head-commit", "--input", "-H"}


def _help_requested(args, value_opts):
    """True when -h/--help is an option of the command, not the value of another option or after --."""
    skip = False
    for item in args:
        token = _lit(item)
        if skip:
            skip = False
            continue
        if token == "--":
            return False
        if token in ("-h", "--help"):
            return True
        if token in value_opts:
            skip = True
    return False


# variables that change which git configuration files (and so which aliases) apply
_GIT_CONFIG_SOURCES = ("GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM", "GIT_CONFIG", "GIT_CONFIG_NOSYSTEM", "HOME",
                       "XDG_CONFIG_HOME", "GIT_DIR")
_GIT_CONFIG_FILE = re.compile(r"(^|/)(\.git/config|\.gitconfig|\.config/git/config|gitconfig)$")
_GITHUB_API_URL = re.compile(r"^(?:https?://)?(?:api|uploads)\.github\.com(?:/|$)|^https?://[^/]+/api/v3/", re.I)
_STDIN_NAME = re.compile(r"^(?:-|/dev/stdin|/(?:dev|proc/self)/fd/\d+)$")
_GH_CONFIG_SOURCES = ("GH_CONFIG_DIR", "XDG_CONFIG_HOME", "HOME")
_GH_CONFIG_FILE = re.compile(r"(^|/)gh/(?:config|hosts)\.yml$")
_GIT_HELPER = re.compile(r"^git-([a-z][a-z-]*)$")
_ARRAY_ALL = re.compile(r"^\$\{([A-Za-z_][A-Za-z0-9_]*)\[[@*]\]\}$")
_ARRAY_OR_ARGS = re.compile(r"^\$(\{[A-Za-z_][A-Za-z0-9_]*\[[@*]\]\}|[@*]|\{[@*]\})$")
# `[` ... `$(` / backquote before the closing `]`; no class contains `[`, so a search is linear in the text
_SUBSCRIPT_EXEC = re.compile(r"\[(?:[^\][$`]|\$(?!\())*(?:\$\(|`)")
_EXEC_TEXT = re.compile(r"\$\(|`")
_ARITH_NAMES = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_GLOB_CHARS = re.compile(r"[*?]")


def _has_glob(text):
    """Unquoted glob characters (`*`, `?`, or `[` ... `]`); linear, unlike a `\\[.*\\]` search."""
    if _GLOB_CHARS.search(text):
        return True
    start = text.find("[")
    return start >= 0 and text.find("]", start + 1) >= 0


_SEQUENCE = re.compile(r"(-?\d+)\.\.(-?\d+)(?:\.\.(-?\d+))?$|([A-Za-z])\.\.([A-Za-z])$")


def _units(atoms):
    units = []
    for atom in atoms:
        if atom[0] == "lit":
            units.extend((ch, atom[2]) for ch in atom[1])
        else:
            units.append((atom,))
    return units


def _atoms(units):
    atoms = []
    for unit in units:
        if len(unit) == 1:
            atoms.append(unit[0])
        elif atoms and atoms[-1][0] == "lit" and atoms[-1][2] == unit[1]:
            atoms[-1] = ("lit", atoms[-1][1] + unit[0], unit[1])
        else:
            atoms.append(("lit", unit[0], unit[1]))
    return atoms


def _brace_alternatives(inner):
    """Alternatives of one brace body, or None when the braces stay literal."""
    depth, parts, current = 0, [], []
    for unit in inner:
        if unit == ("{", False):
            depth += 1
        elif unit == ("}", False):
            depth -= 1
        elif unit == (",", False) and depth == 0:
            parts.append(current)
            current = []
            continue
        current.append(unit)
    if parts:
        return parts + [current]
    if any(len(unit) == 1 or unit[1] for unit in inner):
        return None
    m = _SEQUENCE.match("".join(unit[0] for unit in inner))
    if m is None:
        return None
    if m.group(1) is not None:
        start, end, step = int(m.group(1)), int(m.group(2)), abs(int(m.group(3) or 1)) or 1
        span = range(start, end + (1 if end >= start else -1), step if end >= start else -step)
        # never build more than the expansion limit allows: the caller treats the excess as dynamic
        values = [str(v) for v in span[:MAX_EXPANSIONS + 1]]
    else:
        start, end = ord(m.group(4)), ord(m.group(5))
        values = [chr(v) for v in range(start, end + (1 if end >= start else -1), 1 if end >= start else -1)]
    return [[(ch, False) for ch in value] for value in values]


def _brace_expand(units):
    """Every brace expansion of ``units``; None when there are too many."""
    for i, unit in enumerate(units):
        if unit != ("{", False):
            continue
        depth = 0
        for j in range(i, len(units)):
            if units[j] == ("{", False):
                depth += 1
            elif units[j] == ("}", False):
                depth -= 1
                if depth == 0:
                    break
        else:
            continue
        alternatives = _brace_alternatives(units[i + 1:j])
        if alternatives is None:
            continue
        out = []
        for alternative in alternatives:
            sub = _brace_expand(units[:i] + alternative + units[j + 1:])
            if sub is None or len(out) + len(sub) > MAX_EXPANSIONS:
                return None
            out.extend(sub)
        return out
    return [units]


def _echo_output(args):
    newline, escapes = True, False
    while args and re.fullmatch(r"-[neE]+", args[0]):
        newline = newline and "n" not in args[0]
        escapes = "e" in args[0] or (escapes and "E" not in args[0])
        args = args[1:]
    text = " ".join(args)
    if "\\" in text and not escapes:
        return None  # sh/dash echo interprets backslash escapes that bash prints literally
    if escapes:
        if re.search(r"\\(?!([nrtabefvE\\'\"?]))", text):
            return None  # \xHH, \0NNN, \uHHHH, \c...: the output is not modelled
        text = re.sub(r"\\(.)", lambda m: _ANSI_SIMPLE.get(m.group(1), "\\" + m.group(1)), text)
    return text + ("\n" if newline else "")


_PRINTF_TOKEN = re.compile(r"%%|%[sdb]|%|\\.|[^%\\]+|\\", re.S)


def _printf_output(fmt, args):
    """printf output for %s/%d/%b formats; None for formats it does not model."""
    out, index = [], 0
    while True:
        for token in _PRINTF_TOKEN.findall(fmt):
            if token == "%%":
                out.append("%")
            elif token in ("%s", "%d", "%b"):
                value = args[index] if index < len(args) else ""
                if token == "%b" and "\\" in value:
                    return None
                out.append(value)
                index += 1
            elif token == "%":
                return None
            elif token[0] == "\\" and len(token) == 2 and token[1] in _ANSI_SIMPLE:
                out.append(_ANSI_SIMPLE[token[1]])
            elif token[0] == "\\":
                return None  # \xHH, \NNN, \u...: the output is not modelled
            else:
                out.append(token)
        if index == 0 or index >= len(args):
            return "".join(out)


# =============================================================================
# Program knowledge
# =============================================================================

_SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "mksh", "ash", "fish"}
_INTERPRETER = re.compile(r"^(python[0-9.]*|pypy[0-9.]*|node|nodejs|ruby|perl[0-9.]*|php[0-9.]*|lua[0-9.]*|Rscript|tclsh)$")
_DISCARD = {"/dev/null", "/dev/stdout", "/dev/stderr", "/dev/stdin", "/dev/tty"}
_QUOTED_OPERATOR = re.compile(r"^(?:[0-9]*>>?|&>>?)$")
_EMBEDDED_REDIRECT = re.compile(r"^(?:[1-9]\d*|&)?>>?([^>].*)$")
_CONTROL_TOKENS = {"|", "||", "&&", ";", "--"}

_GIT_COMMIT = {"commit", "commit-tree", "write-tree", "merge", "cherry-pick", "revert", "am", "rebase", "fast-import"}
_GIT_PUSH = {"push", "send-pack"}
_GIT_TREE_CHANGERS = {"merge", "cherry-pick", "revert", "am", "rebase", "pull"}
_GIT_CONTROL = {"--abort", "--quit", "--show-current-patch", "--edit-todo"}
_GIT_READ_ONLY = {
    "status", "log", "show", "diff", "ls-files", "ls-tree", "ls-remote", "rev-parse", "rev-list", "describe",
    "blame", "annotate", "shortlog", "cat-file", "show-ref", "for-each-ref", "name-rev", "merge-base",
    "cherry", "count-objects", "check-ignore", "check-attr", "check-mailmap", "check-ref-format",
    "diff-tree", "diff-files", "diff-index", "show-branch", "verify-commit", "verify-tag", "var", "help",
    "version", "whatchanged", "grep", "range-diff", "fsck", "patch-id",
}
_GIT_SUBCOMMANDS = _GIT_COMMIT | _GIT_PUSH | _GIT_READ_ONLY | {
    "add", "apply", "archive", "bisect", "branch", "bundle", "checkout", "checkout-index", "citool", "clean",
    "clone", "commit-graph", "config", "credential", "diagnose", "difftool", "fast-export", "fetch",
    "fetch-pack", "filter-branch", "fmt-merge-msg", "for-each-repo", "format-patch", "gc", "gui",
    "hash-object", "hook", "index-pack", "init", "instaweb", "interpret-trailers", "mailinfo", "mailsplit",
    "maintenance", "merge-file", "merge-index", "merge-tree", "mktag", "mktree", "multi-pack-index", "mv",
    "notes", "pack-objects", "pack-redundant", "pack-refs", "prune", "prune-packed", "pull", "read-tree",
    "receive-pack", "reflog", "remote", "repack", "replace", "request-pull", "rerere", "reset", "restore",
    "rm", "send-email", "show-index", "sparse-checkout", "stage", "stash", "stripspace", "submodule",
    "switch", "symbolic-ref", "tag", "unpack-file", "unpack-objects", "update-index", "update-ref",
    "update-server-info", "upload-archive", "upload-pack", "verify-pack", "worktree", "lfs", "subtree",
    "http-push",
}
_GIT_GLOBAL_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env",
                     "--attr-source", "--list-cmds"}
_GIT_INFO_FLAGS = {"--version", "-v", "--help", "-h", "--html-path", "--man-path", "--info-path", "--exec-path"}
_SAFE_GIT_CONFIG_PREFIXES = ("color.", "advice.", "column.", "i18n.", "user.", "log.", "status.", "grep.", "format.")
_SAFE_GIT_CONFIG = {"core.quotepath", "core.abbrev", "diff.renames", "diff.algorithm", "init.defaultbranch",
                    "safe.directory", "commit.gpgsign", "tag.gpgsign", "gc.auto", "maintenance.auto"}
_SAFE_PAGERS = {"", "cat", "less", "more", "false", "true"}
_BRANCH_LISTING = {"--list", "-l", "-a", "--all", "-r", "--remotes", "-v", "-vv", "--verbose", "--contains",
                   "--no-contains", "--merged", "--no-merged", "--points-at", "--show-current", "--sort",
                   "--format", "--column", "--no-column", "--color", "--no-color", "-i", "--ignore-case"}
_TAG_LISTING = {"--list", "-l", "-n", "--contains", "--no-contains", "--merged", "--no-merged", "--points-at",
                "--sort", "--format", "--column", "--no-column", "--color", "-i", "--ignore-case"}

_GH_BUILTINS = {
    "agent-task", "alias", "api", "attestation", "auth", "browse", "cache", "codespace", "completion", "config",
    "copilot", "ext", "extension", "extensions", "gist", "gpg-key", "help", "issue", "label", "org", "pr", "preview", "project",
    "release", "repo", "ruleset", "run", "search", "secret", "ssh-key", "status", "variable", "workflow",
}
_GH_API_VALUE = {"-X", "--method", "-f", "-F", "--field", "--raw-field", "--input", "-H", "--header", "-q",
                 "--jq", "-t", "--template", "--cache", "-p", "--preview", "--hostname"}
_GH_API_WRITES = (
    (re.compile(r"(^|/)pulls/[^/]+/merge/?$"), ("PUT",), "pr_merge"),
    (re.compile(r"(^|/)pulls/?$"), ("POST",), "pr_create"),
    (re.compile(r"(^|/)pulls/[^/]+/update-branch/?$"), ("PUT",), "remote_write"),
    (re.compile(r"(^|/)merges/?$"), ("POST",), "pr_merge"),
    (re.compile(r"(^|/)releases/?$"), ("POST",), "release_create"),
    (re.compile(r"(^|/)releases/\d+/?$"), ("PATCH",), "release_create"),
    (re.compile(r"(^|/)releases/\d+/assets"), ("POST",), "release_create"),
    (re.compile(r"(^|/)git/refs(/|$)"), ("POST", "PATCH", "DELETE"), "remote_write"),
    (re.compile(r"(^|/)contents/"), ("PUT", "DELETE"), "remote_write"),
    (re.compile(r"(^|/)deployments/?$"), ("POST",), "deploy"),
    (re.compile(r"(^|/)merge-upstream/?$"), ("POST",), "remote_write"),
    (re.compile(r"^repos/[^/]+/[^/]+/dispatches/?$"), ("POST",), "remote_write"),
)
_GH_DISPATCH = re.compile(r"(^|/)actions/workflows/([^/]+)/dispatches/?$")
_GRAPHQL_MUTATIONS = (
    ("createPullRequest", "pr_create"),
    ("mergePullRequest", "pr_merge"),
    ("enablePullRequestAutoMerge", "pr_merge"),
    ("mergeBranch", "pr_merge"),
    ("createRef", "remote_write"),
    ("updateRefs?", "remote_write"),
    ("deleteRef", "remote_write"),
    ("createCommitOnBranch", "remote_write"),
    ("updatePullRequestBranch", "remote_write"),
)

_MCP_ACTIONS = {
    "create_pull_request": ("pr_create",),
    "create_pull_request_with_copilot": ("pr_create",),
    "create_merge_request": ("pr_create",),
    "merge_pull_request": ("pr_merge",),
    "merge_merge_request": ("pr_merge",),
    "accept_merge_request": ("pr_merge",),
    "enable_pr_auto_merge": ("pr_merge",),
    "push_files": ("commit", "push"),
    "create_or_update_file": ("commit", "push"),
    "delete_file": ("commit", "push"),
    "create_commit": ("commit", "push"),
    "update_pull_request_branch": ("commit", "push"),
    "create_branch": ("push",),
    "create_tag": ("push",),
    "create_ref": ("push",),
    "update_ref": ("push",),
    "create_release": ("release_create",),
    "actions_run_trigger": ("deploy",),
}

# actions_run_trigger methods that only stop or clean up runs (not a delivery)
_MCP_NON_DELIVERY_METHODS = {"cancel_workflow_run", "force_cancel_workflow_run", "delete_workflow_run_logs"}

_DEPLOY_FIRST = {"deploy", "release", "publish", "ship"}
_DEPLOY_ANY = {"deploy", "publish"}
_DEPLOY_NEVER = {"dry", "dryrun", "check", "lint", "test", "tests", "verify", "notes", "changelog", "plan",
                 "diff", "status", "list", "ls", "local"}
_DEPLOY_SUBCOMMANDS = {
    "kubectl": {"apply", "create", "replace", "rollout", "set", "scale", "patch", "delete", "edit", "run",
                "expose", "autoscale"},
    "helm": {"install", "upgrade", "uninstall", "delete", "rollback"},
    "terraform": {"apply", "destroy", "import", "taint", "untaint", "state"},
    "terragrunt": {"apply", "destroy", "import", "taint", "untaint", "state", "run-all", "apply-all",
                   "destroy-all"},
    "pulumi": {"up", "update", "destroy", "import", "refresh"},
    "cargo": {"publish"}, "twine": {"upload"}, "gem": {"push"}, "poetry": {"publish"}, "flit": {"publish"},
    "hatch": {"publish"}, "uv": {"publish"}, "pdm": {"publish"}, "nuget": {"push"},
    "docker": {"push", "image", "manifest", "buildx", "compose"},
    "serverless": {"deploy", "remove"}, "netlify": {"deploy"}, "fly": {"deploy"}, "firebase": {"deploy"},
    "cdk": {"deploy", "destroy"}, "sam": {"deploy", "delete", "sync"}, "kamal": {"deploy", "rollback", "redeploy"},
    "wrangler": {"deploy", "publish"}, "eb": {"deploy"}, "railway": {"up", "deploy", "redeploy"},
    "amplify": {"publish", "push"}, "skaffold": {"run", "deploy", "apply"}, "deployctl": {"deploy"},
    "heroku": {"releases:rollback", "container:release", "pipelines:promote"}, "dotnet": {"nuget"},
}
_TOOL_ALIASES = {"oc": "kubectl", "kubecolor": "kubectl", "tofu": "terraform", "podman": "docker",
                 "sls": "serverless", "flyctl": "fly"}
# subcommands that deploy only with one of these second positionals
_DEPLOY_NESTED = {
    ("kubectl", "rollout"): {"restart", "undo", "resume", "pause"},
    ("terraform", "state"): {"push", "rm", "mv", "replace-provider"},
    ("terragrunt", "state"): {"push", "rm", "mv", "replace-provider"},
    ("terragrunt", "run-all"): {"apply", "destroy"},
    ("docker", "image"): {"push"},
    ("docker", "manifest"): {"push"},
    ("docker", "compose"): {"push"},
    ("dotnet", "nuget"): {"push"},
}
_TOOL_VALUE_OPTIONS = {
    "kubectl": ("n", ("--namespace", "--context", "--kubeconfig", "--cluster", "--user", "--server", "-s",
                      "--token", "--as", "--as-group", "--request-timeout")),
    "helm": ("n", ("--namespace", "--kube-context", "--kubeconfig")),
    "pulumi": ("Cs", ("--cwd", "--stack")),
    "docker": ("Hc", ("--host", "--context", "--config", "--log-level")),
}
_VERCEL_OTHER = {"dev", "env", "pull", "build", "login", "logout", "ls", "list", "logs", "inspect", "link",
                 "whoami", "domains", "dns", "certs", "secrets", "teams", "switch", "projects", "project",
                 "help", "init", "bisect", "git", "integration", "telemetry", "target", "open", "blob",
                 "cache", "install", "plus", "token"}
_AWS_DEPLOY = {("cloudformation", "deploy"), ("cloudformation", "create-stack"),
               ("cloudformation", "update-stack"), ("cloudformation", "execute-change-set"),
               ("lambda", "update-function-code"), ("lambda", "publish-version"), ("ecs", "update-service"),
               ("deploy", "create-deployment"), ("elasticbeanstalk", "update-environment"),
               ("apprunner", "start-deployment"), ("amplify", "start-deployment")}
_TASK_RUNNERS = {"make", "gmake", "just", "task", "rake", "invoke", "fab", "mage", "cap", "gradle", "gradlew",
                 "mvn", "mvnw", "ansible-playbook", "nx", "turbo"}
_TASK_VALUE_SHORT = {"make": "CfIjlLoOWE", "gmake": "CfIjlLoOWE", "mvn": "fslPDeb", "mvnw": "fslPDeb",
                     "gradle": "bcDgIipPx", "gradlew": "bcDgIipPx", "ansible-playbook": "eiklMtTuf"}
_NPM_LIKE = {"npm", "pnpm", "yarn", "bun"}
_PACKAGE_BUILTINS = {"add", "install", "remove", "upgrade", "up", "run", "test", "exec", "dlx", "info", "init",
                     "link", "unlink", "pack", "why", "workspaces", "workspace", "config", "cache", "audit", "bin",
                     "create", "global", "import", "licenses", "list", "login", "logout", "outdated", "owner",
                     "policies", "tag", "team", "version", "versions", "autoclean", "check", "help", "node", "set",
                     "plugin", "npm", "constraints", "dedupe", "explain", "rebuild", "patch", "patch-commit",
                     "unplug", "jest", "vitest", "publish", "unpublish", "i", "rm", "ls", "t", "start",
                     "restart", "stop", "ci", "update", "prune", "fetch", "root", "store", "env", "setup",
                     "server", "doctor", "x"}
_TEST_RUNNERS = {"jest", "mocha", "tap", "vitest"}
_SNAPSHOT_FLAGS = {"-u", "--update", "--updateSnapshot", "--update-snapshot", "--outputFile"}
_NOT_DEPLOY_PROGRAMS = {"code", "cursor", "subl", "open", "xdg-open", "idea", "less", "more", "bat", "man"}

# programs that only read (subject to the argument checks of the ro_* methods)
_READ_ONLY = {
    "cat", "head", "tail", "wc", "nl", "cut", "tr", "paste", "join", "comm", "column", "fold", "fmt", "rev",
    "tac", "od", "hexdump", "strings", "cmp", "diff", "ls", "dir", "vdir", "tree", "du", "df", "stat", "file",
    "readlink", "realpath", "basename", "dirname", "pwd", "grep", "egrep", "fgrep", "rg", "printf",
    "true", "false", "test", "[", ":", "date", "jq", "yq", "which", "type", "hash", "help", "id", "whoami",
    "uname", "hostname", "groups", "logname", "tty", "printenv", "locale", "getconf", "nproc", "uptime",
    "sleep", "seq", "expr", "md5sum", "sha1sum", "sha224sum", "sha256sum", "sha384sum", "sha512sum",
    "shasum", "cksum", "b2sum", "sum", "md5", "base64", "base32", "xxd", "uniq", "sort", "awk", "gawk",
    "mawk", "nawk", "sed", "find", "graphify", "graphifyy",
}
_SHELL_STATE = {"export", "declare", "typeset", "local", "readonly", "unset", "read", "mapfile", "readarray",
                "cd", "pushd", "popd", "dirs", "alias", "unalias", "set", "shopt", "shift", "exit", "return",
                "break", "continue", "wait", "umask", "ulimit", "history", "jobs", "times", "getopts", "let",
                "logout", "caller", "complete", "compgen", "disown", "suspend", "fg", "bg"}
_UNSAFE_ENV = {"GIT_EXTERNAL_DIFF", "GIT_EDITOR", "GIT_SSH", "GIT_SSH_COMMAND", "GIT_ASKPASS", "GIT_EXEC_PATH",
               "GIT_PROXY_COMMAND", "GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT", "GIT_CONFIG_GLOBAL",
               "GIT_CONFIG_SYSTEM", "LD_PRELOAD", "LD_LIBRARY_PATH", "LD_AUDIT", "BASH_ENV", "ENV", "PERL5OPT",
               "PERL5LIB", "NODE_OPTIONS", "RUBYOPT", "RUBYLIB", "PYTHONSTARTUP", "PYTHONPATH", "PYTHONHOME",
               "LESSOPEN", "LESSCLOSE", "EDITOR", "VISUAL", "PROMPT_COMMAND", "SHELLOPTS", "BASHOPTS"}
_PAGER_ENV = {"PAGER", "GIT_PAGER", "MANPAGER"}

_CODE_DELIVERY = (
    (re.compile(r"""\bgit\b[\s'",\]\[]*(?:-C[\s'",]+\S+[\s'",]+)?(commit|merge|rebase|am|cherry-pick|revert|commit-tree|update-ref|fast-import)\b"""), "commit"),
    (re.compile(r"""\bgit\b[\s'",\]\[]*(?:-C[\s'",]+\S+[\s'",]+)?(push|send-pack)\b"""), "push"),
    (re.compile(r"""\bgh\b[\s'",]+pr[\s'",]+(create|new)\b"""), "pr_create"),
    (re.compile(r"""\bgh\b[\s'",]+pr[\s'",]+merge\b"""), "pr_merge"),
    (re.compile(r"""\bgh\b[\s'",]+release[\s'",]+(create|new)\b"""), "release_create"),
    (re.compile(r"""api\.github\.com/repos/[^'"\s]*/(pulls|merges|releases|git/refs|contents)\b"""), "remote_write"),
)
# calls that run a command; the text after the "(" is judged by _first_argument
_RUN_CALL = re.compile(
    r"(?<![A-Za-z0-9_$])(?:os\.(?:system|popen|exec[lv]p?e?|spawn[lv]p?e?|posix_spawnp?)|"
    r"subprocess\.(?:run|call|check_call|check_output|Popen|getoutput|getstatusoutput)|Popen|commands\.getoutput|"
    r"pty\.spawn|asyncio\.create_subprocess_(?:exec|shell)|(?:child_process\.)?(?:execSync|spawnSync|execFileSync|"
    r"execFile|exec|spawn|fork)|Bun\.(?:spawn|spawnSync)|Deno\.Command|Kernel\.(?:system|exec|spawn)|IO\.popen|"
    r"Open3\.\w+|system|spawn|popen|passthru|shell_exec|proc_open|pcntl_exec|backtick|qx)\s*\(")
_RUN_BACKTICK = re.compile(r"`([^`]*)`|%x\{([^}]*)\}|%x\(([^)]*)\)|\bqx\{([^}]*)\}|\bqx\(([^)]*)\)")
# code that executes text it builds or decodes: the command cannot be read from the source
_CODE_EXECUTES_TEXT = re.compile(
    r"(?<![A-Za-z0-9_.$])(?:eval|exec|compile)\s*\(|__import__|new\s+Function\(|\bFunction\(|\bmarshal\b|\bpickle\b")
_CODE_REACHES_BY_NAME = re.compile(r"\bgetattr\(|importlib|\bglobals\(\)|\b__builtins__")
_CODE_DECODES_TEXT = re.compile(
    r"\bchr\(|b64decode|\bbase64\b|\\x(?![1][bB])[0-9a-fA-F]{2}|fromCharCode|\batob\(|codecs|fromhex|"
    r"\\u[0-9a-fA-F]{4}")
_CODE_MENTIONS_PROCESSES = re.compile(r"\bos\b|subprocess|child_process|\bsystem\b|\bpopen\b|\bspawn\b")
_HOLE = "${_hole}"
_EXECUTABLES = {"sys.executable": "python3", "process.execPath": "node", "process.argv0": "node",
                "sys.executable,": "python3"}


def _read_string(code, j):
    """The string literal at code[j:] (an optional r/b/f/u prefix, quotes ' " or `): (text, end) or None.
    Holes ({x} in an f-string, ${x} in a template, %s and {} before a formatting operator) become ${_hole}."""
    m = re.compile(r"([rRbBuUfF]{0,2})(['\"`])").match(code, j)
    if m is None:
        return None
    prefix, quote, k, out = m.group(1).lower(), m.group(2), m.end(), []
    triple = code.startswith(quote * 3, m.start(2)) and quote != "`"
    if triple:
        k += 2
    while k < len(code):
        c = code[k]
        if c == "\\" and "r" not in prefix and k + 1 < len(code):
            out.append(code[k:k + 2])
            k += 2
            continue
        if code.startswith(quote * 3 if triple else quote, k):
            k += 3 if triple else 1
            break
        out.append(c)
        k += 1
    else:
        return None
    text = "".join(out)
    if "f" in prefix or quote == "`":
        text = re.sub(r"\$?\{[^{}]*\}", _HOLE, text)
    if code[k:k + 12].lstrip().startswith(("%", ".format")):
        text = re.sub(r"%[sdrif]|\{[^{}]*\}", _HOLE, text)
        k = _skip_format(code, k)
    return text, k


def _skip_format(code, k):
    """Past a `% x` / `.format(...)` that follows a string: up to the `,` or `)` that ends the argument."""
    depth = 0
    while k < len(code):
        c = code[k]
        if c in "'\"`":
            string = _read_string(code, k)
            if string is None:
                return len(code)
            k = string[1]
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                return k
            depth -= 1
        elif c == "," and depth == 0:
            return k
        k += 1
    return k


def _split_items(code, j):
    """The items of the list literal whose "[" is at code[j]: ([item texts], end) or None."""
    depth, items, start, k = 0, [], j + 1, j
    while k < len(code):
        c = code[k]
        if c in "'\"`":
            string = _read_string(code, k)
            if string is None:
                return None
            k = string[1]
            continue
        if c in "[({":
            depth += 1
        elif c in "])}":
            depth -= 1
            if depth == 0:
                if code[start:k].strip():
                    items.append(code[start:k].strip())
                return items, k + 1
        elif c == "," and depth == 1:
            items.append(code[start:k].strip())
            start = k + 1
        k += 1
    return None


def _literal_value(source):
    """A string literal, or a hole for any other expression: (text, is_literal)."""
    source = _EXECUTABLES.get(source.strip(), source.strip())
    if source in ("python3", "node"):
        return source, True
    string = _read_string(source, 0)
    if string is not None and string[1] >= len(source.rstrip()):
        return string[0], _HOLE not in string[0]
    return _HOLE, False


def _call_commands(code, kind):
    """Commands the inline ``code`` runs: ``[("code", text) | ("argv", [items]) | ("unknown", None)]``."""
    assigned = {}
    for m in re.finditer(r"(?:^|[;\n]\s*)(?:const\s+|let\s+|var\s+)?([A-Za-z_]\w*)\s*=\s*(?=['\"`\[rbfu])", code):
        assigned[m.group(1)] = assigned.get(m.group(1), 0) + 1
    runs = []
    pattern = _RUN_CALL
    imported = [alias for module, alias in re.findall(r"import\s+(subprocess|os)\s+as\s+(\w+)", code)]
    imported += re.findall(r"from\s+(?:subprocess|os)\s+import\s+([\w, ]+)", code)
    names = {name.strip() for group in imported for name in group.split(",") if name.strip()}
    if names:
        pattern = re.compile(_RUN_CALL.pattern + "|(?<![A-Za-z0-9_$.])(?:%s)(?:\\.\\w+)?\\s*\\(" % "|".join(
            map(re.escape, sorted(names))))
    for m in pattern.finditer(code):
        j = m.end()
        while code[j:j + 1].isspace():
            j += 1
        argument = code[j:j + 1]
        name = re.match(r"\s*([A-Za-z_]\w*)\s*[,)]", code[j:]) if argument.isalpha() or argument == "_" else None
        named = name is not None and assigned.get(name.group(1)) == 1
        if named:
            found = re.search(r"(?:^|[;\n]\s*)(?:const\s+|let\s+|var\s+)?%s\s*=\s*" % re.escape(name.group(1)), code)
            j = found.end()
            argument = code[j:j + 1]
        if argument == "[":
            listed = _split_items(code, j)
            texts = None if listed is None else [_literal_value(item) for item in listed[0]]
            if not texts or texts[0][1] is False and texts[0][0] == _HOLE:
                runs.append(("unknown", None))
            else:
                runs.append(("argv", [text for text, _ in texts]))
            continue
        string = _read_string(code, j)
        if string is None or string[0].startswith(_HOLE) or \
                not named and not re.match(r"\s*[,)]", code[string[1]:string[1] + 8]):
            runs.append(("unknown", None))
            continue
        tail = code[string[1]:].lstrip()
        if tail.startswith(",") and tail[1:].lstrip().startswith("["):  # spawn("git", ["commit"])
            listed = _split_items(tail, tail.index("["))
            if listed is not None:
                runs.append(("argv", [string[0]] + [_literal_value(item)[0] for item in listed[0]]))
                continue
        runs.append(("code", string[0]))
    for m in _RUN_BACKTICK.finditer(code if kind in ("ruby", "perl", "php") else ""):
        runs.append(("code", next(group for group in m.groups() if group is not None)))
    return runs


_INLINE_WRITES = {
    "python": (
        re.compile(r"""(?:pathlib\.)?Path\(\s*(['"])((?:(?!\1).)+)\1\s*\)\.(?:write_text|write_bytes|touch|mkdir|unlink|rename|replace)\s*\("""),
        re.compile(r"""(?:pathlib\.)?Path\(\s*(['"])((?:(?!\1).)+)\1\s*\)\.open\(\s*(?:mode\s*=\s*)?['"](?:a|w|x|r\+)"""),
        re.compile(r"""\bopen\(\s*(['"])((?:(?!\1).)+)\1\s*,\s*(?:mode\s*=\s*)?['"][^'"]*[awx+]"""),
        re.compile(r"""\bos\.(?:remove|unlink|rmdir|mkdir|makedirs)\(\s*(['"])((?:(?!\1).)+)\1"""),
    ),
    "node": (
        re.compile(r"""\b(?:appendFile|writeFile|createWriteStream|rm|rmdir|unlink|mkdir|truncate|copyFile|cp)(?:Sync)?\(\s*(['"`])((?:(?!\1).)+)\1"""),
    ),
    "ruby": (
        re.compile(r"""File\.(?:write|binwrite)\(\s*(['"])((?:(?!\1).)+)\1"""),
        re.compile(r"""File\.open\(\s*(['"])((?:(?!\1).)+)\1\s*,\s*['"](?:a|w|x)"""),
    ),
    "perl": (
        re.compile(r"""open\s*\([^)]*(['"])(?:>>|>|\+<)\1\s*,\s*(['"])(.+?)\2"""),
    ),
}
_INTERPRETER_FLAGS = {
    # kind: (options whose value is code, options that take a value, values must be attached)
    "python": ("c", "mWX", False),
    "node": ("ep", "rC", False),
    "ruby": ("e", "rICEFx", False),
    "perl": ("eE", "MmIxCdDF", True),
    "php": ("rR", "fcdz", False),
}
_NODE_VALUE_LONG = {"--require", "--import", "--loader", "--experimental-loader", "--input-type", "--env-file",
                    "--conditions", "--title"}


def _interpreter_kind(name):
    for prefix, kind in (("python", "python"), ("pypy", "python"), ("node", "node"), ("ruby", "ruby"),
                         ("perl", "perl"), ("php", "php")):
        if name.startswith(prefix):
            return kind
    return name


def _name_tokens(name):
    base = os.path.basename(name)
    base = re.sub(r"\.(sh|bash|zsh|py|js|mjs|cjs|ts|rb|pl|php|ps1|ya?ml)$", "", base, flags=re.I)
    base = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", base)
    return [t for t in re.split(r"[^A-Za-z0-9]+", base.lower()) if t]


def _deploy_name(name):
    """True for task, script and workflow names that ship (deploy, release:prod, publish-docs)."""
    tokens = _name_tokens(name)
    if not tokens or set(tokens) & _DEPLOY_NEVER:
        return False
    return tokens[0] in _DEPLOY_FIRST or bool(set(tokens) & _DEPLOY_ANY)


_DEPLOY_VERBS = {"apply", "rollout", "upgrade", "destroy", "deploy", "publish", "upload", "rollback", "redeploy",
                 "uninstall"}
_DEPLOY_DIRS = {"deploy", "deploys", "deployment", "deployments", "release", "releases", "publish", "ship"}
_DEPLOY_USER = re.compile(r"^(?:deploy|deployer|deployment|release|publish|ship)@", re.I)
_REMOTE_READ_ONLY = {"ls", "cat", "tail", "head", "grep", "journalctl", "uptime", "df", "du", "ps", "whoami", "id",
                     "hostname", "date", "uname", "free", "top", "less", "more", "wc", "stat", "file", "which"}
_REMOTE_READ_PAIRS = {("docker", "ps"), ("docker", "logs"), ("docker", "inspect"), ("docker", "images"),
                      ("docker", "stats"), ("docker", "top"), ("docker", "version"), ("docker", "info"),
                      ("kubectl", "get"), ("kubectl", "logs"), ("kubectl", "describe"), ("kubectl", "top"),
                      ("kubectl", "version"), ("systemctl", "status"), ("systemctl", "is-active"),
                      ("systemctl", "is-enabled"), ("systemctl", "list-units"), ("git", "status"), ("git", "log"),
                      ("git", "diff"), ("git", "show"), ("pm2", "list"), ("pm2", "status"), ("pm2", "logs"),
                      ("service", "status")}


# git settings and environment variables whose value is a command line git runs
_GIT_COMMAND_KEY = re.compile(
    r"^(?:core\.(?:pager|editor|sshcommand|fsmonitor|askpass|gitproxy)|pager\..+|sequence\.editor|diff\.external|"
    r"diff\..+\.(?:command|textconv)|merge\..+\.driver|filter\..+\.(?:clean|smudge|process)|"
    r"(?:difftool|mergetool)\..+\.(?:cmd|path)|credential(?:\..+)?\.helper|gpg(?:\..+)?\.program|web\.browser|"
    r"help\.browser|browser\..+\.(?:cmd|path)|man\..+\.cmd|uploadpack\.packobjectshook|trailer\..+\.command)$")
_GIT_COMMAND_ENV = ("GIT_EXTERNAL_DIFF", "GIT_PAGER", "GIT_EDITOR", "GIT_SSH", "GIT_SSH_COMMAND", "GIT_ASKPASS",
                    "GIT_SEQUENCE_EDITOR", "GIT_PROXY_COMMAND", "PAGER", "EDITOR", "VISUAL", "SSH_ASKPASS")
_STASH_REF = re.compile(r"^(?:refs/)?stash(?:@\{[^}]*\})?$")


def _local_repository(positionals, cwd):
    """`git pull <repository>` names this very repository (., ./, .git, $PWD, file://...)."""
    repo = _lit(positionals[0]) if positionals else None
    if repo is None:
        return False
    if repo in (".", "./", ".git", "./.git") or repo.startswith("file://"):
        return True
    return cwd is not None and os.path.realpath(os.path.join(cwd, repo)) == os.path.realpath(cwd)


def _remote_reads_only(items):
    """The command an ssh session runs only reads: a plain read-only program, no shell metacharacters."""
    texts = [_lit(item) for item in items]
    if not texts or any(t is None or re.search(r"[;&|<>$`()\\\n]", t) for t in texts):
        return False
    words = " ".join(texts).split()
    return bool(words) and (words[0] in _REMOTE_READ_ONLY or tuple(words[:2]) in _REMOTE_READ_PAIRS)


def _deploy_path(path):
    """A script path that deploys: a deploy-like file name, or a script inside a deploy/ directory."""
    if _deploy_name(path):
        return True
    parts = [p.lower() for p in path.split("/")[:-1]]
    return bool(set(parts) & _DEPLOY_DIRS) and not set(_name_tokens(path)) & _DEPLOY_NEVER


def _dry_run(args):
    return any(_lit(a) is not None and re.match(r"--dry-?run(=(client|server))?$", a) for a in args)


def _value_follows(token, value_short, value_long):
    """1 when option ``token`` takes the next argument as its value, else 0.

    Short options in ``value_short`` take a value (attached, or the next argument); long
    options in ``value_long`` take the next argument unless written --opt=value.
    """
    if token.startswith("--"):
        return 1 if token in value_long else 0
    for k, ch in enumerate(token[1:], start=1):
        if ch in value_short:
            return 1 if k == len(token) - 1 else 0
    return 0


def _options_end(args, value_short="", value_long=()):
    """Index of the first argument that is neither an option nor an option's value."""
    i = 0
    while i < len(args):
        token = _lit(args[i])
        if token is None or not token.startswith("-") or token == "-":
            return i
        if token == "--":
            return i + 1
        i += 1 + _value_follows(token, value_short, value_long)
    return len(args)


def _positionals(args, value_short="", value_long=()):
    """Positional arguments: options and their values are skipped, '--' ends the options,
    and dynamic arguments count as positionals."""
    out, i = [], 0
    while i < len(args):
        token = _lit(args[i])
        if token == "--":
            return out + list(args[i + 1:])
        if token is None or not token.startswith("-") or token == "-":
            out.append(args[i])
            i += 1
        else:
            i += 1 + _value_follows(token, value_short, value_long)
    return out


def _option_values(args, wanted_short="", wanted_long=(), value_short="", value_long=()):
    """Values given to the wanted options, with the same option grammar as _positionals."""
    values, i = [], 0
    value_short = value_short + wanted_short
    value_long = tuple(value_long) + tuple(wanted_long)
    while i < len(args):
        token = _lit(args[i])
        i += 1
        if token == "--":
            break
        if token is None or token == "-" or not token.startswith("-"):
            continue
        if token.startswith("--"):
            name, eq, value = token.partition("=")
            if name in value_long and not eq and i < len(args):
                value = args[i]
                i += 1
            if name in wanted_long and (eq or value):
                values.append(value)
            continue
        for k, ch in enumerate(token[1:], start=1):
            if ch not in value_short:
                continue
            if k < len(token) - 1:
                value = token[k + 1:]
            elif i < len(args):
                value = args[i]
                i += 1
            else:
                break
            if ch in wanted_short:
                values.append(value)
            break
    return values


def _has_flag(args, short="", long=()):
    for item in args:
        token = _lit(item)
        if token == "--":
            return False
        if token is None or not token.startswith("-"):
            continue
        if token.split("=", 1)[0] in long or not token.startswith("--") and set(token[1:]) & set(short):
            return True
    return False


def _patch_paths(text, strip):
    paths = []
    for line in text.splitlines():
        if not (line.startswith("+++ ") or line.startswith("--- ")):
            continue
        name = line[4:].split("\t", 1)[0].strip().strip('"')
        if name in ("/dev/null", ""):
            continue
        parts = name.split("/")
        name = "/".join(parts[strip:]) if len(parts) > strip else parts[-1]
        if name not in paths:
            paths.append(name)
    return paths


def _read_small(path, limit=2 * 1024 * 1024):
    try:
        with open(path, "rb") as handle:
            data = handle.read(limit + 1)
    except OSError:
        return None
    return None if len(data) > limit else data.decode("utf-8", "replace")


def _sed_effects(script):
    """(write targets, executes, parsed) for a sed script; parsed is False for unknown syntax."""
    writes, executes, i, n = [], False, 0, len(script)

    def line_end(k, also=""):
        while k < n and script[k] != "\n" and script[k] not in also:
            k += 1
        return k

    def skip_regex(k, delim):
        while k < n and script[k] != delim:
            k += 2 if script[k] == "\\" else 1
        return k + 1

    while i < n:
        c = script[i]
        if c in " \t\n;{}!,~+$" or c.isdigit():
            i += 1
        elif c == "#":
            i = line_end(i)
        elif c == "/":
            i = skip_regex(i + 1, "/")
        elif c == "\\" and i + 1 < n:
            i = skip_regex(i + 2, script[i + 1])
        elif c in ":btT":
            i = line_end(i + 1, ";")
        elif c in "aicrRv":
            i = line_end(i)
        elif c in "wW":
            writes.append(script[i + 1:line_end(i)].strip())
            i = line_end(i)
        elif c == "e":
            executes = True
            i = line_end(i, ";")
        elif c in "sy" and i + 1 < n:
            delim = script[i + 1]
            i = skip_regex(skip_regex(i + 2, delim), delim)
            if c == "s":
                while i < n and script[i] in "gpiImMe0123456789":
                    executes = executes or script[i] == "e"
                    i += 1
                if i < n and script[i] == "w":
                    writes.append(script[i + 1:line_end(i)].strip())
                    i = line_end(i)
        elif c in "dDgGhHlnNpPqQxzF=":
            i += 1
        else:
            return writes, executes, False
    return writes, executes, True


def _awk_effects(program):
    """(literal write targets, writes to computed files, runs commands) for an awk program."""
    masked = re.sub(r'"(?:[^"\\\n]|\\.)*"', lambda m: '"' + " " * (len(m.group()) - 2) + '"', program)
    executes = bool(re.search(r"\bsystem\s*\(|\|\s*getline|\|&", masked))
    literal, dynamic = [], False
    for m in re.finditer(r"\bprintf?\b", masked):
        depth, k = 0, m.end()
        while k < len(masked) and masked[k] not in ";}\n":
            ch = masked[k]
            depth += {"(": 1, ")": -1}.get(ch, 0)
            if depth == 0 and ch == "|" and masked[k + 1:k + 2] != "|":
                executes = True
                break
            if depth == 0 and ch == ">":
                rest = program[k:].lstrip(">").lstrip()
                target = re.match(r'"((?:[^"\\\n]|\\.)*)"', rest)
                if target is None:
                    dynamic = True
                elif target.group(1) not in _DISCARD:
                    literal.append(target.group(1))
                break
            k += 1
    return literal, dynamic, executes


def _git_config_safe(key, value):
    """True for -c settings that cannot make a read-only git command run programs."""
    if value is None:
        return False
    if key == "core.pager" or key.startswith("pager."):
        return value in _SAFE_PAGERS
    return key.startswith(_SAFE_GIT_CONFIG_PREFIXES) or key in _SAFE_GIT_CONFIG


def _repo_git_aliases(cwd):
    import subprocess  # only needed for the rare unknown git subcommand

    try:
        out = subprocess.run(["git", "-C", cwd, "config", "--get-regexp", r"^alias\."],
                             capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    aliases = {}
    for line in out.splitlines():
        key, _, value = line.partition(" ")
        aliases[key[len("alias."):].lower()] = value
    return aliases


def _gh_config_aliases(home):
    base = os.environ.get("GH_CONFIG_DIR") or os.path.join(
        os.environ.get("XDG_CONFIG_HOME") or os.path.join(home or "/", ".config"), "gh")
    aliases, in_block = {}, False
    for line in (_read_small(os.path.join(base, "config.yml")) or "").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line[0].isspace():
            in_block = line.rstrip() == "aliases:"
            continue
        m = re.match(r"\s+([^:\s]+):\s*(.*)$", line)
        if in_block and m is not None:
            value = m.group(2).strip()
            if len(value) >= 2 and value[0] == value[-1] == "'":
                value = value[1:-1].replace("''", "'")
            elif len(value) >= 2 and value[0] == value[-1] == '"':
                value = json.loads(value)
            aliases[m.group(1)] = value
    return aliases


def _split_words(text):
    """Split text into words the way the shell would, without expanding anything."""
    words = []
    for andor, _background in parse(text).items:
        for pipeline in andor:
            for node in pipeline:
                if isinstance(node, Simple):
                    for assign in node.assigns:  # NAME=value words before the program (env -S "A=1 prog")
                        value = None if assign.array or len(assign.value) != 1 else assign.value[0].literal()
                        words.append(assign.name + ("+=" if assign.append else "=") + value if value is not None
                                     else Dyn(assign.name + "=" + " ".join(w.text for w in assign.value)))
                    for word in node.words:
                        literal = word.literal()
                        words.append(literal if literal is not None else Dyn(word.text))
    return words


def _snapshot_update(args):
    return any(_lit(a) is not None and a.split("=", 1)[0] in _SNAPSHOT_FLAGS for a in args)


def _is_in_place_flag(command_name, arg):
    """-i, -i.bak, bundled short flags (sed -Ei, perl -pi) and --in-place[=SUFFIX]."""
    if arg == "--in-place" or arg.startswith("--in-place="):
        return True
    if not arg.startswith("-") or arg.startswith("--"):
        return False
    stop = {"sed": set("efl"), "perl": set("eEMmIxCdDF")}.get(command_name, set())
    for ch in arg[1:]:
        if ch == "i":
            return True
        if ch in stop:
            return False
    return False


def _word_source(word):
    """The word's atoms as shell text: literals as they are, expansions as `$name` or their raw text."""
    return "".join(atom[1] if atom[0] == "lit" else "$" + atom[1] if atom[0] == "var" else
                   atom[3] if atom[0] == "cmd" else atom[1] for atom in word.atoms)


def _delivery_verbs(text):
    """Delivery actions named literally in ``text`` (no parsing: the text may be a makefile, a vim script...)."""
    return {name for pattern, name in _CODE_DELIVERY if pattern.search(text)}


def _command_text(text):
    """The text reads as a shell command line: several words, the first one a program (not prose)."""
    text = text.lstrip("!: \t")
    if not re.search(r"\s", text.strip()):
        return False
    first = re.match(r"(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*([A-Za-z0-9_./+-]+)", text)
    if first is None:
        return False
    word = os.path.basename(first.group(1))
    return word in _PROBED_WORDS or word in _HANDLERS or word in ("cd", "true", "false", "exec")


def _path_form(word):
    """The word is `<expansion>/literal/path`: a script below a directory that is computed."""
    atoms = word.atoms
    return len(atoms) > 1 and atoms[0][0] in ("var", "cmd", "dyn") and atoms[1][0] == "lit" and \
        atoms[1][1].startswith("/") and not (atoms[0][0] == "dyn" and atoms[0][1].startswith(("<(", ">(")))


# handlers whose arguments may carry a command (`taskset -c 0 git commit`, `kubectl exec -- gh pr create`)
_ARGUMENT_COMMANDS = {"unknown", "deploy_tool", "task_runner", "npm", "node_runner", "editor", "vercel", "ssh",
                      "runner"}
# programs that run the commands they read on stdin
_STDIN_RUNNERS = {"at", "batch", "crontab", "newgrp", "sg", "expect", "ed", "ex", "vi", "vim", "nvim", "make", "gmake"}
# programs that only display or search text: a delivery verb among their arguments is a topic, not a command
_NOT_COMMAND_ARGS = {"man", "tldr", "help", "info", "apropos", "whatis", "cheat", "navi", "glow", "mdcat", "pandoc",
                     "code", "cursor", "subl", "open", "xdg-open", "idea", "less", "more", "bat", "batcat"}
# options whose value is a pattern, a message or a label, not a command
_PATTERN_OPTIONS = {"-k", "-m", "-t", "-b", "--grep", "--filter", "--match", "--message", "--title", "--body",
                    "--description", "--name", "--label", "--tag", "--reason", "--summary", "--subject", "--text",
                    "--comment", "--notes", "--testNamePattern", "--regexp", "--pattern", "--query", "--search",
                    "--msg", "--note"}


class _Feed:
    """What a command reads on stdin: known text, the paths find/ls print, or unknown."""

    __slots__ = ("kind", "value")

    def __init__(self, kind, value=None):
        self.kind = kind
        self.value = value


_UNKNOWN_FEED = _Feed("unknown")


# =============================================================================
# Walker: follows the command in execution order and records what it does
# =============================================================================


class _Budget(Exception):
    """The analysis used up its step or time budget."""


class _Analysis:
    def __init__(self, base_dir, lookups=True):
        self.base = base_dir
        self.lookups = lookups
        self.steps = 0
        self.deadline = time.monotonic() + MAX_SECONDS
        self.unseen_reasons = []
        self.defining = 0
        self.failed = ""
        self.config_unknown = False
        self.actions = set()
        self.possible = set()
        self.delivery = []
        self.reasons = []
        self.writes = []
        self.opaque_writers = []
        self.commands = []
        self.read_only = True
        self.read_only_legacy = True
        self.test_runner = False
        self.push = []
        self.commits = []
        self.staged = []
        self.scripts = []
        self.depth = 0
        self.active = set()
        self.gh_aliases = None
        self.repo_aliases = {}
        self.suffix_probe = False

    # -- recording ------------------------------------------------------------
    def tick(self):
        self.steps += 1
        if self.steps > MAX_STEPS or time.monotonic() > self.deadline:
            raise _Budget()

    def unseen(self, text):
        """Code runs that cannot be read statically: report the strictest possible tier."""
        self.mark("no")
        if self.defining:  # a function body is judged where it is called
            return
        self.reason(text)
        if text not in self.unseen_reasons:
            self.unseen_reasons.append(text)
            self.action("unseen", ["unseen:", text], possible=True)

    def reason(self, text):
        if text not in self.reasons and not self.defining:
            self.reasons.append(text)

    def mark(self, status):
        """Record that a command is not read-only ("no") or is a test runner ("test")."""
        self.read_only = False
        if status == "test":
            self.test_runner = True
        else:
            self.read_only_legacy = False

    def action(self, name, argv, possible=False):
        (self.possible if possible else self.actions).add(name)
        canonical = "%s [%s]" % (CANONICAL_PREFIX[name], " ".join(_text(a) for a in argv))
        self.delivery.append({"action": name, "tier": ACTION_TIER[name], "canonical": canonical,
                              "possible": possible})

    def write(self, item, env, via, scope="path"):
        text = _text(item)
        if not isinstance(item, Dyn) and (text in _DISCARD or text.startswith("/dev/fd/") or text in ("", "-")):
            return
        self.mark("no")
        if isinstance(item, Dyn) and item.roots is not None:
            for root in item.roots:
                self.write(root, env, via, scope)
            return
        if _GIT_CONFIG_FILE.search(text) or _GH_CONFIG_FILE.search(text) or \
                isinstance(item, Dyn) and re.search(r"(^|/)(config|gitconfig|config\.yml)$", text):
            self.config_unknown = True  # git or gh aliases may have been added to the configuration
        path = os.path.expanduser(text)
        key = None if isinstance(item, Dyn) else self.file_key(text, env)
        if key in env.files and via not in ("redirect", "chmod", "chown", "chgrp", "touch", "chattr"):
            env.files[key] = None  # rewritten by something else: what it holds now is not known
        dynamic = isinstance(item, Dyn) or (env.cwd is None and not os.path.isabs(path))
        full = os.path.join(env.cwd_text, path) if dynamic else os.path.realpath(os.path.join(env.cwd or "/", path))
        self.writes.append({"path": full, "raw": text, "dynamic": dynamic, "via": via, "scope": scope})

    def opaque_writer(self, program, reason):
        self.mark("no")
        self.opaque_writers.append({"program": _text(program), "reason": reason})

    # -- expansion --------------------------------------------------------------
    def expand(self, word, env):
        if len(word.atoms) == 1:
            fields = self.expand_all(word.atoms[0], env)
            if fields is not None:
                return fields
        alternatives = [word.atoms]
        if any(atom[0] == "lit" and not atom[2] and "{" in atom[1] for atom in word.atoms):
            expanded = _brace_expand(_units(word.atoms))
            if expanded is None:
                return [Dyn(word.text)]
            alternatives = [_atoms(units) for units in expanded]
        items = []
        for atoms in alternatives:
            items.extend(self.expand_atoms(atoms, env))
        return items

    def expand_all(self, atom, env):
        """Fields of a word that is exactly "$@", "${@:N}", ${name[@]} or "${name[@]:N:M}"; else None."""
        if atom[0] == "var" and atom[1] == "@" and env.positional is not None:
            return list(env.positional)
        if atom[0] != "dyn":
            return None
        m = _PARAM.match(atom[1])
        if m is None or m.group(1):
            return None
        name, subscript, rest = m.group(2), m.group(3), m.group(4)
        positional = name in ("@", "*") and subscript is None
        if positional and env.positional is not None:
            items = list(env.positional)
        elif subscript in ("@", "*"):
            items = env.arrays.get(name)
        else:
            return None
        if items is None:
            return None
        if not rest:
            return list(items)
        if not re.fullmatch(r":\s*-?\d+(?::\s*-?\d+)?", rest):
            return None
        numbers = [int(part) for part in rest[1:].split(":")]
        first = numbers[0] - 1 if positional and numbers[0] > 0 else numbers[0]  # ${@:N} starts at $N
        start = first if first >= 0 else max(len(items) + first, 0)
        end = None if len(numbers) < 2 else start + numbers[1] if numbers[1] >= 0 else len(items) + numbers[1]
        return list(items[start:end])

    def ifs_chars(self, env):
        """The characters unquoted expansions split at; None when IFS holds something unknown."""
        if "IFS" not in env.vars:
            return " \t\n"
        return env.vars["IFS"]

    def param_value(self, raw, env):
        """``${name op word}``: ``(value, tainted)`` with value a string when it can be worked out."""
        m = _PARAM.match(raw)
        if m is None or m.group(1) == "!":
            return None, True
        indirect, name, subscript, rest = m.group(1), m.group(2), m.group(3), m.group(4)
        if subscript is None:
            value, tainted = env.lookup(name)
        elif subscript in ("@", "*") or not re.fullmatch(r"\s*\d+\s*", subscript) or name not in env.arrays:
            joined = env.arrays.get(name) if subscript in ("@", "*") and not rest else None
            if joined is not None and all(_lit(item) is not None for item in joined):
                return " ".join(joined), False
            return None, True
        else:
            array = env.arrays[name]
            value = _lit(array[int(subscript)]) if int(subscript) < len(array) else ""
            tainted = value is None
        if indirect == "#":
            return (None if value is None else str(len(value))), False
        if not rest:
            return value, tainted
        kind = rest[:2] if rest[:2] in (":-", ":=", ":+", ":?") else rest[:1] if rest[:1] in "-=+?" else None
        if kind is None:
            if tainted or value is None:
                return None, tainted
            result = _param_operator(value, rest)
            return result, result is None
        word = rest[len(kind):]
        if tainted or any(c in word for c in "$`'\"\\"):
            return None, True
        colon, test = kind[0] == ":", kind[-1]
        unset = value is None or colon and value == ""
        if test in "-=":
            return (word, False) if unset else (value, False)
        if test == "+":
            return (word, False) if value is None or not unset else ("", False)
        return (None, False) if unset else (value, False)

    def dyn_value(self, raw, env):
        """Value of a dynamic atom (a brace expansion, arithmetic...): ``(text or None, tainted)``."""
        if raw.startswith(("<(", ">(")):
            return None, True
        if raw.startswith("${"):
            return self.param_value(raw, env)
        return None, False

    def expand_atoms(self, atoms, env):
        pieces, total, ifs = [], 0, self.ifs_chars(env)
        for index, atom in enumerate(atoms):
            kind, quoted = atom[0], atom[2]
            if kind == "lit":
                text = atom[1]
                if index == 0 and not quoted and text[:1] == "~":
                    text = self.tilde(text, env)
                pieces.append((text, quoted, False))
                total += len(text)
                continue
            if kind == "var":
                value, tainted = env.lookup(atom[1])
                raw = "$" + atom[1]
            elif kind == "cmd":
                value, raw = self.static_output(atom[1], env), atom[3]
                value = None if value is None else value.rstrip("\n")
                tainted = value is None and not _PATH_PRODUCER.match(raw)
            else:
                (value, tainted), raw = self.dyn_value(atom[1], env), atom[1]
            if value is not None and not quoted and ifs is None:
                value, tainted = None, True  # unquoted expansions split at an IFS nobody knows
            total += len(value or "")
            pieces.append((Dyn(raw, tainted=tainted),) if value is None else (value, quoted, not quoted))
            if total > MAX_VALUE_CHARS:  # repeated doubling: stop growing, the value is unknown
                return [Dyn("<oversized expansion>", tainted=True)]
        fields, parts, flags = [], [], {"dyn": False, "glob": False, "started": False, "tainted": False}
        splitter = re.compile("([%s]+)" % "".join("\\" + c if c in "]\\^-" else c for c in ifs)) if ifs else None

        def push():
            text = "".join(parts)
            fields.append(Dyn(text, tainted=flags["tainted"]) if flags["dyn"] else GlobStr(text) if flags["glob"]
                          else text)
            del parts[:]
            flags.update(dyn=False, glob=False, started=False, tainted=False)

        for piece in pieces:
            if len(piece) == 1:
                parts.append(piece[0].text)
                flags["dyn"] = flags["started"] = True
                flags["tainted"] = flags["tainted"] or piece[0].tainted
                continue
            text, quoted, split = piece
            split = split and splitter is not None
            for chunk in splitter.split(text) if split else [text]:
                if split and chunk and chunk[0] in ifs:
                    if flags["started"]:
                        push()
                    continue
                if split and not chunk:
                    continue
                parts.append(chunk)
                flags["started"] = True
                if not quoted and _has_glob(chunk):
                    flags["glob"] = True
        if flags["started"]:
            push()
        return fields

    def tilde(self, text, env):
        head, sep, tail = text.partition("/")
        replacement = {"~": env.home, "~+": env.cwd, "~-": env.oldpwd}.get(head)
        return text if replacement is None else replacement + sep + tail

    def static_output(self, script, env):
        """Output of a substitution that is one literal echo/printf/pwd, else None."""
        if len(script.items) != 1 or len(script.items[0][0]) != 1:
            return None
        pipeline = script.items[0][0][0]
        cmd = pipeline[0]
        if len(pipeline) != 1 or not isinstance(cmd, Simple) or cmd.assigns or cmd.redirs or \
                any(word.nested for word in cmd.words):
            return None
        argv = []
        for word in cmd.words:
            argv.extend(self.expand(word, env))
        if not argv or any(_lit(a) is None for a in argv):
            return None
        if argv[0] == "echo":
            return _echo_output(argv[1:])
        if argv[0] == "printf" and len(argv) > 1:
            return _printf_output(argv[1], argv[2:])
        if argv[0] == "pwd" and env.cwd is not None:
            return env.cwd + "\n"
        return None

    def literal_text(self, word, env):
        """The word's value as one string (no field splitting), or None when dynamic."""
        items = self.expand(word, env)
        if any(isinstance(item, Dyn) for item in items):
            return None
        return " ".join(items)

    # -- walking ----------------------------------------------------------------
    def run_code(self, text, env, stdin=None):
        """Parse and walk code that a shell, eval, trap or alias will run."""
        if self.depth >= MAX_DEPTH:
            self.unseen("nesting too deep")
            return
        self.depth += 1
        self.walk_script(parse(text), env, stdin)
        self.depth -= 1

    def walk_script(self, script, env, stdin=None):
        if script.error:  # bash may accept what the parser rejects: judge it by the strictest tier
            self.unseen("parse error: " + script.error)
        for andor, background in script.items:
            scope = env.copy() if background else env
            for pipeline in andor:
                if len(pipeline) == 1:
                    self.walk_command(pipeline[0], scope, stdin)
                    continue
                feed = stdin
                for node in pipeline:
                    feed = self.walk_command(node, scope.copy(), feed)
                    if feed is None:  # a pipe carries output this analysis cannot see
                        feed = _UNKNOWN_FEED

    def scan_word(self, word, env):
        """Expansions that evaluate or execute a variable's value (arithmetic, ${!n}, ${x@P})."""
        for atom in word.atoms:
            if atom[0] != "dyn":
                continue
            raw = atom[1]
            if raw.startswith(("$((", "$[")):
                self.arith_check(raw, env)
            elif raw.startswith("${") and not raw.startswith("${!") and not raw.endswith("@P}"):
                self.scan_parameter(raw, env)
            elif raw.startswith("${!") or raw.endswith("@P}"):
                self.mark("no")
                name = raw[3:-1] if raw.startswith("${!") else raw[2:-3]
                value = env.vars.get(name)
                if isinstance(value, str) and _EXEC_TEXT.search(value):
                    self.unseen("indirect expansion of a variable that holds a command substitution")

    def scan_parameter(self, raw, env):
        """${a[x]} and ${x:off:len} evaluate their subscript, offset and length as arithmetic."""
        m = _PARAM.match(raw)
        if m is None:
            return
        if m.group(3) is not None and m.group(3) not in ("@", "*"):
            self.arith_check(m.group(3), env)
        rest = m.group(4)
        if rest[:1] == ":" and rest[1:2] not in ("-", "=", "+", "?"):
            self.arith_check(rest[1:], env)

    def arith_check(self, text, env):
        """Arithmetic evaluates variable values (a[$(cmd)] runs cmd): a variable that holds a
        command substitution makes the command unseen, and any variable use is not read-only."""
        names = _ARITH_NAMES.findall(text)
        if names:
            self.mark("no")
        for name in names:
            value = env.vars.get(name)
            if isinstance(value, str) and _EXEC_TEXT.search(value):
                self.unseen("arithmetic evaluates a variable that holds a command substitution")
        if _SUBSCRIPT_EXEC.search(text):
            self.unseen("arithmetic subscript runs a command substitution")

    def scan_conditional(self, node, env):
        words = node.extra or []
        if len(words) == 1 and words[0].text.startswith("(("):
            self.arith_check(words[0].text, env)
            return
        texts = [w.literal() for w in words]
        for text in texts:
            if text is not None and _SUBSCRIPT_EXEC.search(text):
                self.unseen("test operand with a subscript that runs a command substitution")
        for index, text in enumerate(texts[:-1]):  # [[ -v $x ]] evaluates the subscript in the value of x
            if text in ("-v", "-R"):
                self.arith_check(_word_source(words[index + 1]), env)
        if any(text in ("-eq", "-ne", "-lt", "-gt", "-le", "-ge") for text in texts):
            names = []
            for w in words:
                names.extend(a[1] for a in w.atoms if a[0] == "var")
                names.extend(_ARITH_NAMES.findall(w.literal() or ""))
            self.arith_check(" ".join(names), env)

    def walk_nested(self, word, env):
        self.scan_word(word, env)
        for script in word.nested:
            self.walk_script(script, env.copy())

    def walk_command(self, node, env, stdin):
        self.tick()
        if isinstance(node, Simple):
            return self.walk_simple(node, env, stdin)
        stdin = self.redirections(node.redirs, env) or stdin
        if node.kind == "subshell":
            self.walk_script(node.parts[0], env.copy(), stdin)
        elif node.kind == "for":
            self.walk_for(node, env, stdin)
        elif node.kind == "function":
            if node.extra:
                env.functions[node.extra] = node.parts[0]
            self.defining += 1
            try:
                self.walk_script(node.parts[0], env.copy())
            finally:
                self.defining -= 1
        else:
            if node.kind == "words":
                self.scan_conditional(node, env)
            for word in node.extra or ():
                self.walk_nested(word, env)
            for part in node.parts:
                self.walk_script(part, env, stdin)
        return None

    def walk_for(self, node, env, stdin):
        name, values, headers = node.extra
        for header in headers:
            self.walk_command(header, env, None)
        items = []
        for word in values or ():
            self.walk_nested(word, env)
            items.extend(self.expand(word, env))
        body = node.parts[0]
        if name and items and len(items) <= MAX_LOOP_VALUES and not any(isinstance(i, Dyn) for i in items):
            for value in items:
                env.vars[name] = str(value)
                self.walk_script(body, env, stdin)
            return
        if name:
            env.vars[name] = None
        self.walk_script(body, env, stdin)

    def walk_simple(self, cmd, env, stdin):
        for assign in cmd.assigns:
            for word in assign.value:
                self.walk_nested(word, env)
        for word in cmd.words:
            self.walk_nested(word, env)
        for redir in cmd.redirs:
            self.walk_nested(redir.target, env)
            if redir.body_word is not None:
                self.walk_nested(redir.body_word, env)
        values = {}
        for assign in cmd.assigns:
            if assign.array:
                items = []
                for item_word in assign.value:
                    items.extend(self.expand(item_word, env))
                self.assign_array(assign, items, env)
                continue
            if assign.name in env.integers:
                self.arith_check(_word_source(assign.value[0]), env)  # y=x on an integer evaluates x
            value = self.literal_text(assign.value[0], env)
            if assign.append and value is not None:
                prior = env.get(assign.name)
                value = None if prior is None else prior + value
            values[assign.name] = _cap(value)
        argv = []
        for word in cmd.words:
            argv.extend(self.expand(word, env))
        stdin = self.redirections(cmd.redirs, env) or stdin
        if not argv:
            env.vars.update(values)
            self.record_files(cmd.redirs, env, _Feed("text", ""))  # `> run.sh` empties the file
            return None
        feed = self.execute(argv, env, values, stdin, cmd.words[0])
        self.record_files(cmd.redirs, env, feed)
        return feed

    @staticmethod
    def file_key(path, env):
        """The absolute path a command-line path names, or None when the directory is not known."""
        path = os.path.expanduser(path)
        if not os.path.isabs(path) and env.cwd is None:
            return None
        return os.path.normpath(os.path.join(env.cwd or "/", path))

    def record_files(self, redirs, env, feed):
        """`printf 'git push' > run.sh`: remember what a redirect wrote, so running the file later in the
        same command is judged by its text (content that cannot be read stays None)."""
        for redir in redirs:
            if redir.op not in (">", ">>", ">|", "&>", "&>>") or redir.fd not in (None, "1"):
                continue
            names = self.expand(redir.target, env)
            path = _lit(names[0]) if len(names) == 1 else None
            key = None if path is None or path in _DISCARD else self.file_key(path, env)
            if key is None:
                continue
            text = feed.value if feed is not None and feed.kind == "text" else None
            if redir.op.endswith(">>"):
                if key not in env.files:  # appended to a file that was there before: an ordinary script file
                    continue
                prior = env.files[key]
                text = None if text is None or prior is None else prior + text
            env.files[key] = _cap(text)

    def assign_array(self, assign, items, env):
        """Remember a literal array so "${a[@]}" can be read; a subscript that runs code is unseen."""
        if _SUBSCRIPT_EXEC.search(assign.name):
            self.unseen("array subscript runs a command substitution")
            return
        if "[" in assign.name:  # a[3]=x sets one element of an array of unknown shape
            env.arrays.pop(assign.name.split("[", 1)[0], None)
            return
        if assign.append and assign.name in env.arrays:
            env.arrays[assign.name] = env.arrays[assign.name] + items
        elif assign.append:
            env.arrays.pop(assign.name, None)
        else:
            env.arrays[assign.name] = items
        if len(env.arrays.get(assign.name, ())) > MAX_SEQUENCE:  # repeated doubling: the array is unknown
            del env.arrays[assign.name]

    def redirections(self, redirs, env):
        stdin = None
        for redir in redirs:
            op, target = redir.op, redir.target
            if op in ("<<", "<<-"):
                text = redir.body
                if redir.body_word is not None:
                    text = self.literal_text(redir.body_word, env)
                stdin = _Feed("text", text) if text is not None else _UNKNOWN_FEED
            elif op == "<<<":
                text = self.literal_text(target, env)
                stdin = _Feed("text", text + "\n") if text is not None else _UNKNOWN_FEED
            elif op in ("<", "<&") and redir.fd not in (None, "0"):
                continue  # 3< file feeds another descriptor, not stdin
            elif op == "<":
                names = self.expand(target, env)
                path = _lit(names[0]) if len(names) == 1 else None
                stdin = _Feed("file", path) if path is not None and not _STDIN_NAME.match(path) and \
                    not path.startswith(("/dev/", "/proc/")) else _UNKNOWN_FEED
            elif op == "<&":
                stdin = _UNKNOWN_FEED
            elif not (op == ">&" and (target.text.isdigit() or target.text == "-")):
                for item in self.expand(target, env):
                    self.write(item, env, "redirect")
        return stdin

    # -- running a command --------------------------------------------------------
    def execute(self, argv, env, prefix, stdin, first_word=None):
        self.tick()
        program = argv[0]
        self.commands.append({"program": _text(program), "argv": [_text(a) for a in argv], "cwd": env.cwd})
        self.check_env(prefix)
        argv = self.quoted_operators(argv, env)
        if _lit(program) is None:
            return self.execute_dynamic(argv, env, prefix, stdin, first_word)
        name = os.path.basename(program)
        helper = _GIT_HELPER.match(name)
        if helper is not None and helper.group(1) in _GIT_SUBCOMMANDS and name not in env.functions:
            return self.h_git(["git", helper.group(1)] + list(argv[1:]), env, prefix, stdin)
        if first_word is not None and first_word.unquoted_literal() == program and program in env.aliases:
            self.run_code(env.aliases[program] + "".join(" " + shlex.quote(_text(a)) for a in argv[1:]), env)
        if name in env.functions and name not in self.active:
            self.active.add(name)
            scope = env.copy()
            scope.positional = list(argv[1:])
            self.walk_script(env.functions[name], scope)
            self.active.discard(name)
        handler = _HANDLERS.get(name) or ("interpreter" if _INTERPRETER.match(name) else "unknown")
        result = getattr(self, "h_" + handler)(argv, env, prefix, stdin)
        if handler in _ARGUMENT_COMMANDS and name not in _NOT_COMMAND_ARGS:
            self.probe_arguments(argv, env, stdin)
        return result

    def execute_dynamic(self, argv, env, prefix, stdin, first_word):
        """A command whose program is not known statically."""
        program = argv[0]
        text = _text(program)
        self.reason("dynamic command word: " + text)
        self.mark("no")
        tail = os.path.basename(text)
        helper = _GIT_HELPER.match(tail)
        if helper is not None and helper.group(1) in _GIT_SUBCOMMANDS:
            return self.h_git(["git", helper.group(1)] + list(argv[1:]), env, prefix, stdin)
        if tail in ("git", "gh", "hub") and "$" not in tail and "`" not in tail:
            return getattr(self, "h_" + tail)([tail] + list(argv[1:]), env, prefix, stdin)
        if first_word is not None and _path_form(first_word):  # "$(git rev-parse --show-toplevel)/scripts/x.sh"
            self.opaque_writer(program, "runs a script")
            self.reason("runs a script (contents not analysed)")
            if _deploy_path("".join(atom[1] for atom in first_word.atoms[1:] if atom[0] == "lit")):
                self.action("deploy", argv)
            return None
        self.guess(argv, env)
        if _ARRAY_OR_ARGS.match(text) or getattr(program, "tainted", False):
            self.unseen("the program is computed at run time (read, substituted or cut from other text): " + text)
        elif self.ifs_chars(env) is None:
            self.unseen("IFS is changed to a value that is not known, so unquoted expansions split at unknown places")
        return None

    def check_env(self, prefix):
        for name, value in prefix.items():
            if name in _UNSAFE_ENV or name.startswith(("DYLD_", "GIT_CONFIG_")) or \
                    name in _PAGER_ENV and value not in _SAFE_PAGERS:
                self.mark("no")

    def quoted_operators(self, argv, env):
        """Treat a quoted redirection operator as a redirection, as the legacy helpers did.

        A host that joins an argv list without quoting would make it one, so the target
        after it counts as written and the command is not read-only.
        """
        name = os.path.basename(_text(argv[0]))
        out, i = [argv[0]], 1
        while i < len(argv):
            token = _lit(argv[i])
            if token is not None and _QUOTED_OPERATOR.match(token) and i + 1 < len(argv):
                operands = [a for a in argv[1:i] if not _text(a).startswith("-") and _text(a) not in _CONTROL_TOKENS]
                if (operands or name in ("echo", "printf")) and _text(argv[i + 1]) not in _CONTROL_TOKENS:
                    self.write(argv[i + 1], env, "redirect")
                    i += 2
                    continue
            elif token is not None:
                m = _EMBEDDED_REDIRECT.match(token)
                if m is not None and m.group(1) not in _DISCARD:
                    self.mark("no")
            out.append(argv[i])
            i += 1
        return out

    def probe(self, argv, env, suffix=False):
        """Actions ``argv`` would perform, from a throw-away analysis without lookups. ``suffix`` marks
        a probe of the tail of another program's arguments, whose own tail is probed by the caller's loop."""
        probe = _Analysis(self.base, lookups=False)
        probe.suffix_probe = suffix
        probe.gh_aliases = {}
        probe.steps, probe.deadline, probe.depth = self.steps, self.deadline, self.depth
        probe.config_unknown = self.config_unknown
        try:
            probe.execute(argv, env.copy(), {}, None)
        finally:
            self.steps = probe.steps
        return probe.actions | probe.possible

    def probe_code(self, text, env):
        """Actions that running ``text`` as shell code would perform, from a throw-away analysis."""
        probe = _Analysis(self.base, lookups=False)
        probe.gh_aliases = {}
        probe.steps, probe.deadline, probe.depth = self.steps, self.deadline, self.depth
        try:
            probe.run_code(text, env.copy())
        finally:
            self.steps = probe.steps
        return probe.actions | probe.possible

    def code_possible(self, text, argv, env):
        """A command line that a program will run (a git pager, a bisect script): record what it could do."""
        for name in sorted(self.probe_code(text, env)):
            if name == "unseen":
                self.unseen("a command line handed to a program runs code that cannot be read")
            else:
                self.action(name, argv, possible=True)

    def probe_arguments(self, argv, env, stdin=None):
        """A program that runs what its arguments say (taskset, uv run, tmux, vim -c, kubectl exec --, ssh host
        'cmd') hides a command among them: judge every suffix that starts at a program word, and every
        argument that reads as command text, and record what they could do."""
        found, previous, name = set(), None, os.path.basename(_text(argv[0]))
        for i in range(1, len(argv)):
            token = _lit(argv[i])
            if token is None:
                previous = None
                continue
            word = os.path.basename(token) if token.startswith("/") else token
            if word in _PROBED_WORDS or _INTERPRETER.match(word):
                if not self.suffix_probe:  # inside such a probe the caller's loop reaches every later word itself
                    found |= self.probe(argv[i:], env, suffix=True)
            else:
                text = token
                if token.startswith("--") and "=" in token:
                    option, _, text = token.partition("=")
                    previous = option
                if text[:1] != "-" and previous not in _PATTERN_OPTIONS and re.search(r"\s", text):
                    if _command_text(text):
                        found |= self.probe_code(text.lstrip("!: \t"), env)
                    else:  # osascript -e 'do shell script "gh pr create"', gdb -ex 'shell ...', expect -c 'spawn ...'
                        found |= _delivery_verbs(text)
            previous = token
        if name in _STDIN_RUNNERS and stdin is not None and stdin.kind == "text":
            found |= self.probe_code(stdin.value, env) if name not in ("ed", "ex", "vi", "vim", "nvim") else \
                self.probe_code("\n".join(line[1:] for line in stdin.value.splitlines() if line[:1] == "!"), env)
        found.discard("unseen")
        for verb in sorted(found):
            self.action(verb, argv, possible=True)

    def guess(self, argv, env):
        """Actions a dynamic program could perform, judged from its visible arguments."""
        args = list(argv[1:])
        found = self.probe(["git"] + args, env) | self.probe(["gh"] + args, env)
        positionals = _positionals(args)
        first = _lit(positionals[0]) if positionals else None
        if first is not None and first.lower() in ("deploy", "publish"):
            found.add("deploy")
        if first in _DEPLOY_VERBS:  # `$(which kubectl) apply ...`: the tool is hidden, the verb is not
            for tool, subs in _DEPLOY_SUBCOMMANDS.items():
                if first in subs:
                    found |= self.probe([tool] + args, env)
        for name in sorted(found):
            self.action(name, argv, possible=True)

    def h_unknown(self, argv, env, prefix, stdin):
        program = argv[0]
        name = os.path.basename(program)
        self.mark("no")
        if "/" in program or name.endswith(".sh"):
            self.run_script(program, argv, env, "runs a script")
        elif name.lower() in _DEPLOY_FIRST:
            self.action("deploy", argv)
        positionals = _positionals(argv[1:])
        if name not in _NOT_DEPLOY_PROGRAMS and positionals and _lit(positionals[0]) is not None and \
                positionals[0].lower() in ("deploy", "publish"):
            self.action("deploy", argv)
        return None

    def run_script(self, script, argv, env, reason, shell=True, stdin=None, kind=None):
        """A script file runs: judge its name and note that its writes are unknown.

        Shell scripts that exist are remembered (``invoked_script``) so a gate can read them.
        """
        self.opaque_writer(script, reason)
        self.reason(reason + " (contents not analysed)")
        target = _lit(script)
        if target is not None and re.fullmatch(r"/(?:dev|proc/self)/fd/(?:[1-9]\d*)", target):
            self.unseen("a script is read from an open file descriptor")
            return
        if _text(script).startswith("<(") or (target is not None and _STDIN_NAME.match(target)):
            if shell:
                self.shell_input(script, stdin, env)
            else:
                self.interpreter_input(kind, script, stdin, argv, env)
            return
        if target is None:
            self.reason("script path is dynamic: " + _text(script))
            return
        key = self.file_key(target, env)
        if key in env.files:  # written earlier in this very command: judge the text it was given
            if env.files[key] is None:
                self.unseen("runs a script that this command wrote with content that cannot be read")
            elif shell:
                self.run_code(env.files[key], env.copy())
            else:
                self.inline_code(kind, env.files[key], argv, env)
            return
        if shell and env.cwd is not None:
            path = os.path.realpath(os.path.join(env.cwd, os.path.expanduser(target)))
            if os.path.isfile(path):
                self.scripts.append(path)
        if _deploy_path(target) and not _dry_run(argv[1:]):
            self.action("deploy", argv)

    # -- read-only programs ---------------------------------------------------------
    def h_read_only(self, argv, env, prefix, stdin):
        check = getattr(self, "ro_" + os.path.basename(argv[0]), None)
        return check(argv[1:], env, stdin) if check is not None else None

    def h_echo(self, argv, env, prefix, stdin):
        if all(_lit(a) is not None for a in argv[1:]):
            text = _echo_output(list(argv[1:]))
            return _Feed("text", text) if text is not None else _UNKNOWN_FEED
        return _UNKNOWN_FEED

    def ro_printf(self, args, env, stdin):
        names = _option_values(args, "v")
        for name in names:
            env.vars[_text(name)] = None
            if _SUBSCRIPT_EXEC.search(_text(name)):
                self.unseen("printf -v names an array element whose subscript runs a command")
        rest = _positionals(args, "v")
        if not names and rest and all(_lit(a) is not None for a in rest):
            text = _printf_output(rest[0], rest[1:])
            if text is not None:
                return _Feed("text", text)
        return _UNKNOWN_FEED

    def ro_hash(self, args, env, stdin):
        if _has_flag(args, "p"):
            self.mark("no")  # hash -p binds a name to any program

    def ro_file(self, args, env, stdin):
        if _has_flag(args, "C", ("--compile",)):
            self.mark("no")  # file -C writes a compiled magic file

    def ro_cat(self, args, env, stdin):
        files = _positionals(args)
        if len(files) == 1 and _lit(files[0]) is not None and stdin is None and not _STDIN_NAME.match(files[0]):
            return _Feed("file", files[0])  # cat setup.sh | bash
        return stdin if not files and stdin is not None else _UNKNOWN_FEED

    def ro_ls(self, args, env, stdin):
        return _Feed("roots", _positionals(args, "IwT") or ["."])

    def ro_date(self, args, env, stdin):
        if _has_flag(args, "s", ("--set",)) or \
                any(_lit(a) is None or not a.startswith("+") for a in _positionals(args, "dfr")):
            self.mark("no")

    def ro_hostname(self, args, env, stdin):
        if _positionals(args, "F"):
            self.mark("no")

    def ro_sort(self, args, env, stdin):
        for target in _option_values(args, "o", ("--output",), "ktST",
                                     ("--key", "--field-separator", "--buffer-size", "--temporary-directory")):
            self.write(target, env, "sort -o")
        if any(_text(a).startswith("--compress-program") for a in args):
            self.mark("no")

    def ro_uniq(self, args, env, stdin):
        positionals = _positionals(args, "fsw", ("--skip-fields", "--skip-chars", "--check-chars"))
        for target in positionals[1:2]:
            self.write(target, env, "uniq")

    def ro_xxd(self, args, env, stdin):
        for target in _positionals(args, "cglsoC")[1:2]:
            self.write(target, env, "xxd")

    def ro_base64(self, args, env, stdin):
        for target in _option_values(args, "o", ("--output",), "bw", ("--wrap", "--break")):
            self.write(target, env, "base64 -o")

    def ro_tree(self, args, env, stdin):
        for target in _option_values(args, "o", (), "LPIH", ("--charset", "--filelimit", "--timefmt", "--sort")):
            self.write(target, env, "tree -o")

    def ro_rg(self, args, env, stdin):
        if any(_text(a).split("=", 1)[0] in ("--pre", "--pre-glob") for a in args):
            self.mark("no")

    def ro_yq(self, args, env, stdin):
        if _has_flag(args, "i", ("--inplace",)):
            for target in _positionals(args, "Ioep", ("--indent", "--output-format", "--input-format"))[1:]:
                self.write(target, env, "yq -i")

    def ro_graphify(self, args, env, stdin):
        positionals = _positionals(args)
        if not positionals or positionals[0] not in ("query", "path", "explain"):
            self.mark("no")

    ro_graphifyy = ro_graphify

    def ro_sed(self, args, env, stdin):
        value_short, value_long = "efl", ("--expression", "--file", "--line-length")
        scripts = _option_values(args, "e", ("--expression",), value_short, value_long)
        positionals = _positionals(args, value_short, value_long)
        if _option_values(args, "f", ("--file",), value_short, value_long):
            self.opaque_writer("sed", "sed script file")
        elif not scripts and positionals:
            scripts, positionals = positionals[:1], positionals[1:]
        for script in scripts:
            if _lit(script) is None:
                self.opaque_writer("sed", "dynamic sed script")
                continue
            writes, executes, parsed = _sed_effects(script)
            for target in writes:
                self.write(target, env, "sed w")
            if executes or not parsed:
                self.opaque_writer("sed", "sed e command" if executes else "unrecognised sed script")
            if executes:
                self.unseen("sed e command runs code that is not analysed")
        if any(_is_in_place_flag("sed", _text(a)) for a in args):
            for target in positionals:
                self.write(target, env, "sed -i")

    def ro_awk(self, args, env, stdin):
        value_short, value_long = "fFvieEl", ("--file", "--field-separator", "--assign", "--source", "--include",
                                             "--exec", "--load")
        positionals = _positionals(args, value_short, value_long)
        sources = _option_values(args, "e", ("--source",), value_short, value_long)
        if _option_values(args, "fEl", ("--file", "--exec", "--load"), value_short, value_long) or \
                _has_flag(args, "dpD", ("--dump-variables", "--profile", "--debug")):
            self.opaque_writer("awk", "awk program file, extension or dump")
        elif not sources and positionals:
            sources, positionals = positionals[:1], positionals[1:]
        if _option_values(args, "i", ("--include",), value_short, value_long):
            for target in positionals:
                if "=" not in _text(target):
                    self.write(target, env, "awk -i")
        for program in sources:
            if _lit(program) is None:
                self.opaque_writer("awk", "dynamic awk program")
                continue
            literal, dynamic, executes = _awk_effects(program)
            for target in literal:
                self.write(target, env, "awk print >")
            if dynamic or executes:
                self.opaque_writer("awk", "awk system(), command pipe or computed output file")
            if executes:
                self.awk_commands(_text(program), env)

    def awk_commands(self, program, env):
        """Commands an awk program runs: literal strings are analysed, anything else is unseen."""
        if re.search(r"system\s*\(\s*[^\"\s]", program):
            self.unseen("awk runs a command that is not a string literal")
        for text in re.findall(r'"((?:[^"\\]|\\.)*)"', program):
            for name in sorted(self.probe_code(text.replace('\\"', '"'), env)):
                self.action(name, ["awk", text], possible=False)

    ro_gawk = ro_mawk = ro_nawk = ro_awk

    def ro_find(self, args, env, stdin):
        i, roots = 0, []
        while i < len(args) and _lit(args[i]) in ("-H", "-L", "-P"):
            i += 1
        while i < len(args) and not (_text(args[i]).startswith("-") or _text(args[i]) in ("(", "!", ",")):
            roots.append(args[i])
            i += 1
        roots = roots or ["."]
        while i < len(args):
            token = _text(args[i])
            if token in ("-exec", "-execdir", "-ok", "-okdir"):
                j = i + 1
                while j < len(args) and _text(args[j]) not in (";", "+"):
                    j += 1
                inner = [Dyn("{}", roots) if _text(a) == "{}" else a for a in args[i + 1:j]]
                if inner:
                    self.execute(inner, env.copy(), {}, None)
                i = j + 1
            elif token == "-delete":
                for root in roots:
                    self.write(root, env, "find -delete")
                i += 1
            elif token in ("-fprint", "-fprint0", "-fls", "-fprintf"):
                for target in args[i + 1:i + 2]:
                    self.write(target, env, "find " + token)
                i += 3 if token == "-fprintf" else 2
            else:
                i += 2 if token in _FIND_VALUE or re.match(r"-newer[aBcmt][aBcmt]$", token) else 1
        return _Feed("roots", roots)

    # -- shell builtins ---------------------------------------------------------------
    def h_shell_state(self, argv, env, prefix, stdin):
        name = os.path.basename(argv[0])
        args = argv[1:]
        for item in args:  # a[$(cmd)] subscripts are evaluated by read, unset, declare, export...
            if _lit(item) is not None and _SUBSCRIPT_EXEC.search(item):
                self.unseen("%s names an array element whose subscript runs a command" % name)
            elif name in _DECLARATIONS and _lit(item) is not None and _EXEC_TEXT.search(item) and \
                    _has_flag(args, "aAi"):
                self.unseen("%s evaluates text that holds a command substitution" % name)
        if name in ("cd", "pushd"):
            positionals = _positionals(args)
            target = positionals[0] if positionals else (env.home or Dyn("~"))
            if _lit(target) == "-":
                target = env.oldpwd or Dyn("$OLDPWD")
            env.chdir(target)
        elif name == "popd":
            env.chdir(Dyn("$DIRSTACK"))
        elif name in _DECLARATIONS:
            integer = _has_flag(args, "i")
            for item in _positionals(args):
                key, eq, value = _text(item).partition("=")
                if integer and _NAME.fullmatch(key):
                    env.integers.add(key)
                    if eq:
                        self.arith_check(value, env)  # declare -i y=x evaluates x
                if eq and _NAME.fullmatch(key):
                    env.vars[key] = _cap(value) if _lit(item) is not None else None
        elif name == "history":
            if _has_flag(args, "awrnscd"):
                self.mark("no")
        elif name == "let":
            self.arith_check(" ".join(_text(a) for a in args), env)
        elif name == "shift":
            count = _lit(args[0]) if args else "1"
            if env.positional is not None:
                env.positional = env.positional[int(count):] if count is not None and count.isdigit() else None
        elif name == "unset":
            for item in _positionals(args):
                env.vars[_text(item)] = ""
                env.functions.pop(_text(item), None)
        elif name in ("read", "mapfile", "readarray"):
            for callback in _option_values(args, "C", ("--callback",), "adnNptuiCcOs", ()) if name != "read" else ():
                if _lit(callback) is None:
                    self.unseen("mapfile callback is not known statically")
                else:
                    self.run_code(callback, env.copy())
                self.mark("no")
            for item in _positionals(args, "adnNptuiCcOs"):
                env.vars[_text(item)] = None
        elif name == "alias":
            for item in args:
                key, eq, value = _text(item).partition("=")
                if eq and _lit(item) is not None:
                    env.aliases[key] = value
        elif name == "unalias":
            for item in args:
                env.aliases.pop(_text(item), None)
        elif name == "set" and "--" in [_lit(a) for a in args]:
            literal = [_lit(a) for a in args]
            env.positional = list(args[literal.index("--") + 1:])
            if len(env.positional) > MAX_SEQUENCE:  # repeated doubling: the parameters are unknown
                env.positional = None
        return None

    def h_eval(self, argv, env, prefix, stdin):
        if all(_lit(a) is not None for a in argv[1:]):
            self.run_code(" ".join(argv[1:]), env)
            return None
        self.reason("eval with a non-literal argument")
        self.mark("no")
        if all(_ENV_GENERATOR.match(_text(a)) for a in argv[1:]):
            return None  # eval "$(ssh-agent -s)": the whole argument is one well-known environment tool
        # whatever is visible in the text (its expansions are still to be done) is judged as well
        self.unseen("eval of text that is not known statically")
        for name in sorted(self.probe_code(" ".join(_text(a) for a in argv[1:]), env) - {"unseen"}):
            self.action(name, argv, possible=True)
        return None

    def h_source(self, argv, env, prefix, stdin):
        if len(argv) > 1:
            self.run_script(argv[1], argv, env, "sources a script", stdin=stdin)
        return None

    def h_trap(self, argv, env, prefix, stdin):
        args = argv[1:]
        if len(args) < 2 or _lit(args[0]) in ("-", "", "--", "-p", "-l"):
            return None
        if _lit(args[0]) is None:
            self.reason("trap with a non-literal handler")
            self.mark("no")
        self.run_code(_text(args[0]), env)  # the handler with its expansions still to be done
        return None

    def h_command(self, argv, env, prefix, stdin):
        end = _options_end(argv[1:]) + 1
        if any(_lit(a) is not None and set(a[1:]) & set("vV") for a in argv[1:end]):
            return None
        return self.execute(argv[end:], env, prefix, stdin) if end < len(argv) else None

    def h_wrapper(self, argv, env, prefix, stdin):
        """Wrappers that run their remaining arguments as a command."""
        name = os.path.basename(argv[0])
        value_short, value_long, skip = _WRAPPERS[name]
        args = argv[1:]
        end = _options_end(args, value_short, value_long)
        options = args[:end]
        for target in _option_values(options, "o", ("--output",), value_short, value_long) \
                if name in ("time", "strace", "ltrace") else ():
            self.write(target, env, name + " output")
        if name == "flock":
            codes = _option_values(args, "c", ("--command",), value_short, value_long)
            for code in codes:
                self.run_code(_text(code), env.copy())
            if codes:
                return None
        if name in ("npx", "pnpx", "bunx"):
            for code in _option_values(options, "c", ("--call",), value_short, value_long):
                self.run_code(_text(code), env.copy())
        rest = list(args[end + skip:])
        if name in ("sudo", "doas") and _has_flag(options, "e", ("--edit",)):
            for target in rest:
                self.write(target, env, "sudoedit")
            return None
        if rest and (name in ("sudo", "doas") and _has_flag(options, "si", ("--shell", "--login")) or
                     name == "watch" and not _has_flag(options, "x", ("--exec",))):
            self.run_code(" ".join(_text(a) for a in rest), env.copy())
            return None
        if rest:
            return self.execute(rest, env, prefix, stdin)
        self.mark("no")
        return None

    def h_runner(self, argv, env, prefix, stdin):
        """script -c, su -c, runuser -c: the -c value runs as shell code."""
        name = os.path.basename(argv[0])
        value_short, value_long = _RUNNERS[name]
        self.mark("no")
        for code in _option_values(argv[1:], "c", ("--command",), value_short, value_long):
            if _lit(code) is None:
                self.unseen("%s -c with a non-literal command" % name)
            else:
                self.run_code(code, env.copy())
        return None

    def h_env(self, argv, env, prefix, stdin):
        args = argv[1:]
        prefix = dict(prefix)
        scope, split, i = env, [], 0
        while i < len(args):
            token = _lit(args[i])
            if token is None or not token.startswith("-"):
                break
            i += 1
            if token == "--":
                break
            name, eq, value = token.partition("=")
            if name in ("-u", "-C", "-S", "-P", "--unset", "--chdir", "--split-string") and not eq:
                value = _text(args[i]) if i < len(args) else ""
                i += 1
            elif token[:2] in ("-u", "-C", "-S", "-P") and len(token) > 2:
                name, value = token[:2], token[2:]
            if name in ("-C", "--chdir"):
                scope = env.copy()
                scope.chdir(value)
            elif name in ("-S", "--split-string"):
                split = _split_words(value)
        rest = split + list(args[i:])
        while rest and _ASSIGN.match(_text(rest[0])):  # NAME=value, whether or not the value is known
            key, _, value = _text(rest[0]).partition("=")
            prefix[key] = value if _lit(rest[0]) is not None else None
            rest = rest[1:]
        return self.execute(rest, scope, prefix, stdin) if rest else None

    def h_rtk(self, argv, env, prefix, stdin):
        rest = list(argv[1:])
        if rest and _lit(rest[0]) == "proxy":
            rest = rest[1:]
        if not rest or _text(rest[0]).startswith("-"):
            self.mark("no")
            return None
        return self.execute(rest, env, prefix, stdin)

    def h_xargs(self, argv, env, prefix, stdin):
        args = argv[1:]
        value_short, value_long = "adEILnPs", ("--arg-file", "--delimiter", "--eof", "--max-lines", "--max-args",
                                               "--max-procs", "--max-chars", "--process-slot-var")
        end = _options_end(args, value_short, value_long)
        replace = None
        for value in _option_values(args[:end], "I", (), value_short, value_long):
            replace = _text(value)
        for item in args[:end]:
            token = _text(item)
            if token == "-i" or token.startswith("--replace"):
                replace = token.partition("=")[2] or "{}"
            elif token.startswith("-i") and not token.startswith("--"):
                replace = token[2:]
        rest = list(args[end:]) or ["echo"]
        if stdin is not None and stdin.kind == "text":
            items = stdin.value.splitlines() if replace is not None else stdin.value.split()
        else:
            items = [Dyn("{xargs input}", stdin.value if stdin is not None and stdin.kind == "roots" else None,
                         tainted=True)]
        if replace is None:
            return self.execute(rest + items[:MAX_LOOP_VALUES], env.copy(), prefix, None)
        for item in items[:MAX_LOOP_VALUES]:
            command, scope = [], env.copy()
            runs_shell = bool(rest) and _lit(rest[0]) is not None and os.path.basename(rest[0]) in _SHELLS
            for arg in rest:
                text = _text(arg)
                if replace not in text:
                    command.append(arg)
                elif _lit(item) is not None and _lit(arg) is not None:
                    command.append(text.replace(replace, item))
                elif runs_shell and _lit(arg) is not None and text != replace:
                    # sh -c 'tool {}': the item is data for the script, unknown to the analysis
                    scope.vars["_xargs_item"] = None
                    command.append(text.replace(replace, "${_xargs_item}"))
                else:
                    roots = getattr(item, "roots", None) if text.startswith(replace) else None
                    command.append(item if text == replace else Dyn(text.replace(replace, _text(item)), roots,
                                                                    tainted=True))
            self.execute(command, scope, prefix, None)
        return None

    def h_shell(self, argv, env, prefix, stdin):
        args = argv[1:]
        i, command_mode, stdin_mode = 0, False, False
        while i < len(args):
            token = _lit(args[i])
            if token is None or len(token) < 2 or token[0] not in "-+":
                break
            i += 1
            if token == "--":
                break
            if token in ("-o", "+o", "-O", "+O", "--rcfile", "--init-file"):
                i += 1
            elif not token.startswith("--"):
                command_mode = command_mode or "c" in token[1:]
                stdin_mode = stdin_mode or "s" in token[1:]
                i += 1 if token[-1] in "oO" else 0
        if i < len(args) and _lit(args[i]) == "-":
            i += 1
        rest = args[i:]
        if command_mode:
            if rest and _lit(rest[0]) is not None:
                scope = env.copy()
                scope.positional = list(rest[2:])
                scope.arg0 = None if len(rest) < 2 else _lit(rest[1]) if _lit(rest[1]) is not None else False
                self.run_code(rest[0], scope)
                return None
            self.unseen("shell -c with a missing or non-literal script")
            return None
        if rest and not stdin_mode:
            self.run_script(rest[0], argv, env, "runs a shell script", stdin=stdin)
        else:
            self.shell_input(None, stdin, env)
        return None

    def shell_input(self, item, stdin, env):
        """Code a shell reads from stdin (bash -s, a here-document or pipe) or from <(...)."""
        if item is not None and _text(item).startswith("<("):
            if not _ENV_GENERATOR.match(_text(item)):  # source <(kubectl completion bash)
                self.unseen("shell runs the output of a process substitution")
        elif stdin is not None and stdin.kind == "file":  # bash < setup.sh runs the script like bash setup.sh
            self.run_script(stdin.value, ["bash", stdin.value], env, "runs a shell script")
        elif stdin is not None and stdin.kind == "text":
            self.run_code(stdin.value, env.copy())
        elif stdin is not None:
            self.unseen("shell reads commands from a pipe or file that cannot be read")
        else:
            self.reason("shell reads commands from stdin")
            self.mark("no")

    def interpreter_input(self, kind, item, stdin, argv, env):
        """Program text an interpreter reads from stdin or <(...)."""
        if item is not None and _text(item).startswith("<("):
            self.unseen("%s runs the output of a process substitution" % kind)
        elif stdin is not None and stdin.kind == "file":
            self.run_script(stdin.value, argv, env, "runs a %s script" % kind, shell=False, kind=kind)
        elif stdin is not None and stdin.kind == "text":
            self.inline_code(kind, stdin.value, argv, env)
        elif stdin is not None:
            self.unseen("%s reads its program from a pipe or file that cannot be read" % kind)

    # -- interpreters -------------------------------------------------------------------
    def h_interpreter(self, argv, env, prefix, stdin):
        kind = _interpreter_kind(os.path.basename(argv[0]))
        code_flags, value_flags, attached_only = _INTERPRETER_FLAGS.get(kind, ("e", "", False))
        args = argv[1:]
        codes, module, test, i = [], None, False, 0
        while i < len(args):
            token = _lit(args[i])
            if token is None or not token.startswith("-") or token == "-":
                break
            i += 1
            if token == "--":
                break
            if token.startswith("--"):
                key, eq, value = token.partition("=")
                if key in ("--eval", "--print") or key in _NODE_VALUE_LONG and not eq:
                    if not eq:
                        value = args[i] if i < len(args) else ""
                        i += 1
                    if key in ("--eval", "--print"):
                        codes.append(value)
                test = test or key == "--test"
                continue
            for k, ch in enumerate(token[1:], start=1):
                if ch not in code_flags and ch not in value_flags:
                    continue
                value = token[k + 1:]
                if not value and not (attached_only and ch in value_flags):
                    value = args[i] if i < len(args) else ""
                    i += 1
                if ch in code_flags:
                    codes.append(value)
                elif ch == "m" and kind == "python":
                    module = value
                break
        operands = args[i:]
        if kind == "node" and test and not codes:
            self.mark("no" if _snapshot_update(args) else "test")
            return None
        if kind in ("perl", "ruby") and any(_is_in_place_flag("perl", _text(a)) for a in args[:i]):
            for target in operands if codes else operands[1:]:
                self.write(target, env, kind + " -i")
        if codes:
            for code in codes:
                self.inline_code(kind, code, argv, env)
        elif module is not None:
            self.opaque_writer(argv[0], "runs %s module %s" % (kind, _text(module)))
            self.reason("runs %s module %s (contents not analysed)" % (kind, _text(module)))
            module_args = [_lit(a) for a in operands]
            if _deploy_name(_text(module)) or module_args[:1] and module_args[0] in _DEPLOY_SUBCOMMANDS.get(
                    _text(module).split(".")[0], ()):
                self.action("deploy", argv)
        elif operands and _lit(operands[0]) != "-":
            self.run_script(operands[0], argv, env, "runs a %s script" % kind, shell=False, stdin=stdin, kind=kind)
        else:
            self.opaque_writer(argv[0], "%s reads its program from stdin" % kind)
            self.interpreter_input(kind, None, stdin, argv, env)
        return None

    def inline_code(self, kind, code, argv, env):
        self.opaque_writer(argv[0], "inline %s code" % kind)
        if _lit(code) is None:
            self.reason("dynamic inline %s code" % kind)
            if re.match(r"\s*[$`]", _text(code)) or getattr(code, "tainted", False):
                self.unseen("inline %s code is read or computed at run time" % kind)
            code = _text(code)
        for pattern in _INLINE_WRITES.get(kind, ()):
            for m in pattern.finditer(code):
                self.write(m.groups()[-1], env, "inline " + kind)
        for pattern, name in _CODE_DELIVERY:
            if pattern.search(code):
                self.action(name, argv, possible=True)
        runs = _call_commands(code, kind)
        for run, payload in runs:
            if run == "unknown":
                self.unseen("inline %s code runs a command that is not written out in the source" % kind)
                continue
            if run == "code":
                found = self.probe_code(payload.lstrip("!: \t"), env)
            else:
                found = self.probe([Dyn("$_hole") if _HOLE in part else part for part in payload], env)
            if "unseen" in found:
                self.unseen("inline %s code runs a command that cannot be read" % kind)
            for name in sorted(found - {"unseen"}):
                self.action(name, argv, possible=True)
        mentions = bool(runs) or _CODE_MENTIONS_PROCESSES.search(code) is not None
        if _CODE_EXECUTES_TEXT.search(code) or mentions and (
                _CODE_DECODES_TEXT.search(code) or _CODE_REACHES_BY_NAME.search(code)):
            self.unseen("inline %s code builds or decodes the code it runs" % kind)

    # -- writers ----------------------------------------------------------------------
    def h_copy(self, argv, env, prefix, stdin):
        name = os.path.basename(argv[0])
        args = argv[1:]
        self.mark("no")
        value_short = "gmoStT" if name == "install" else "St"
        value_long = ("--target-directory", "--suffix", "--mode", "--owner", "--group")
        positionals = _positionals(args, value_short, value_long)
        directories = _option_values(args, "t", ("--target-directory",), value_short, value_long)
        if name == "install" and _has_flag(args, "d", ("--directory",)):
            directories, positionals = positionals, []
        if not directories and len(positionals) > 1:
            directories, positionals = positionals[-1:], positionals[:-1]
        elif not directories and len(positionals) == 1 and name == "ln":
            directories = [os.path.basename(_text(positionals[0]))]
        for target in directories:
            self.write(target, env, name)
        for source in positionals if name == "mv" else ():
            self.write(source, env, "mv source")
        return None

    def h_operands(self, argv, env, prefix, stdin):
        """Programs that write every operand (rm, touch, mkdir, chmod, truncate...)."""
        name = os.path.basename(argv[0])
        positionals = _positionals(argv[1:], *_OPERAND_WRITERS[name])
        if name in ("chmod", "chown", "chgrp") and not any(_text(a).startswith("--reference") for a in argv[1:]):
            positionals = positionals[1:]
        self.mark("no")
        for target in positionals:
            self.write(target, env, name)
        return None

    def h_dd(self, argv, env, prefix, stdin):
        self.mark("no")
        for item in argv[1:]:
            if _text(item).startswith("of="):
                self.write(_text(item)[3:] if _lit(item) is not None else Dyn(_text(item)[3:]), env, "dd of=")
        return None

    def h_ssh(self, argv, env, prefix, stdin):
        """ssh/sftp as a deploy user, unless the remote command only reads."""
        self.mark("no")
        positionals = _positionals(argv[1:], "bcDEeFIiJLlmOopQRSWw")
        if not positionals or not _DEPLOY_USER.match(_text(positionals[0])):
            return None
        if os.path.basename(argv[0]) == "ssh" and _remote_reads_only(positionals[1:]):
            return None
        self.action("deploy", argv)
        return None

    def h_sync_copy(self, argv, env, prefix, stdin):
        self.mark("no")
        positionals = _positionals(argv[1:], "eBfTMiFPoS", _RSYNC_VALUE_LONG)
        if positionals and _DEPLOY_USER.match(_text(positionals[-1])):  # only a copy TO the deploy user ships
            self.action("deploy", argv)
        if len(positionals) > 1 and not re.match(r"^[^/]*:", _text(positionals[-1])):
            self.write(positionals[-1], env, os.path.basename(argv[0]))
        return None

    def h_curl(self, argv, env, prefix, stdin):
        args = argv[1:]
        self.mark("no")
        value_short = "AbcCdDeEFHKmoQrtTuUwxXyYz"
        for target in _option_values(args, "oDc", ("--output", "--dump-header", "--cookie-jar", "--trace",
                                                   "--trace-ascii", "--stderr", "--etag-save"), value_short,
                                     _CURL_VALUE_LONG):
            self.write(target, env, "curl output")
        if _has_flag(args, "O", ("--remote-name", "--remote-name-all")):
            directories = _option_values(args, "", ("--output-dir",), value_short, _CURL_VALUE_LONG)
            for url in _positionals(args, value_short, _CURL_VALUE_LONG):
                name = _text(url).split("?", 1)[0].rstrip("/").rsplit("/", 1)[-1]
                target = os.path.join(_text(directories[-1]), name) if directories else name
                self.write(target if isinstance(url, str) else Dyn(target), env, "curl -O")
        methods = _option_values(args, "X", ("--request",), value_short, _CURL_VALUE_LONG)
        posts = _has_flag(args, "dFT", ("--data", "--data-raw", "--data-binary", "--data-urlencode", "--json",
                                         "--form", "--upload-file"))
        method = _text(methods[-1]).upper() if methods else "POST" if posts else "GET"
        urls = _positionals(args, value_short, _CURL_VALUE_LONG) + \
            _option_values(args, "", ("--url",), value_short, _CURL_VALUE_LONG)
        self.github_http(urls, method, argv)
        return None

    def h_wget(self, argv, env, prefix, stdin):
        args = argv[1:]
        self.mark("no")
        value_short, value_long = "OoaPeiBUTtwQlARDIX", ("--output-document", "--output-file", "--append-output",
                                                           "--directory-prefix", "--input-file", "--user-agent")
        documents = _option_values(args, "O", ("--output-document",), value_short, value_long)
        for target in documents + _option_values(args, "oa", ("--output-file", "--append-output"), value_short,
                                                 value_long):
            self.write(target, env, "wget output")
        if not documents and not _has_flag(args, "", ("--spider",)):
            prefixes = _option_values(args, "P", ("--directory-prefix",), value_short, value_long)
            for url in _positionals(args, value_short, value_long):
                name = _text(url).split("?", 1)[0].rsplit("/", 1)[-1] or "index.html"
                self.write(os.path.join(_text(prefixes[-1]), name) if prefixes else name, env, "wget")
        methods = _option_values(args, "", ("--method",), value_short, value_long)
        posts = _has_flag(args, "", ("--post-data", "--post-file", "--body-data", "--body-file"))
        method = _text(methods[-1]).upper() if methods else "POST" if posts else "GET"
        self.github_http(_positionals(args, value_short, value_long), method, argv)
        return None

    def h_httpie(self, argv, env, prefix, stdin):
        """http / https / xh: [METHOD] URL [items]."""
        self.mark("no")
        positionals = _positionals(argv[1:], "", ("--auth", "-a", "--session", "--timeout", "--pretty", "--style"))
        method = "GET"
        if positionals and _lit(positionals[0]) is not None and positionals[0].isalpha() and positionals[0].isupper():
            method, positionals = positionals[0], positionals[1:]
        elif len(positionals) > 1:
            method = "POST"  # request items imply a body
        self.github_http(positionals[:1], method, argv)
        return None

    def h_tar(self, argv, env, prefix, stdin):
        args = list(argv[1:])
        self.mark("no")
        if args and _lit(args[0]) is not None and not args[0].startswith("-"):
            args[0] = "-" + args[0]
        value_short, value_long = "fCbKLNTVgHIX", ("--file", "--directory", "--exclude", "--files-from")
        letters = "".join(_text(a)[1:] for a in args if _text(a).startswith("-") and not _text(a).startswith("--"))
        longs = {_text(a).split("=", 1)[0] for a in args if _text(a).startswith("--")}
        if "x" in letters or {"--extract", "--get"} & longs:
            directories = _option_values(args, "C", ("--directory",), value_short, value_long)
            for target in directories:
                self.write(target, env, "tar -x")
            if not directories:
                self.write(".", env, "tar -x", "tree")
        elif set("cruA") & set(letters) or {"--create", "--append", "--update", "--catenate"} & longs:
            for target in _option_values(args, "f", ("--file",), value_short, value_long):
                self.write(target, env, "tar archive")
        return None

    def h_unzip(self, argv, env, prefix, stdin):
        args = argv[1:]
        self.mark("no")
        if _has_flag(args, "lptvzZ"):
            return None
        directories = _option_values(args, "d", (), "dxP")
        for target in directories:
            self.write(target, env, "unzip -d")
        if not directories:
            self.write(".", env, "unzip", "tree")
        return None

    def h_compress(self, argv, env, prefix, stdin):
        args = argv[1:]
        self.mark("no")
        if not _has_flag(args, "ctl", ("--stdout", "--to-stdout", "--test", "--list")):
            for target in _positionals(args, "S", ("--suffix",)):
                self.write(target, env, os.path.basename(argv[0]))
        return None

    def h_patch(self, argv, env, prefix, stdin):
        args = argv[1:]
        self.mark("no")
        if _has_flag(args, "", ("--dry-run",)):
            return None
        value_short, value_long = "dioprBDFVYzg", ("--directory", "--input", "--output", "--strip", "--prefix",
                                                  "--reject-file", "--suffix")
        scope = env
        for directory in _option_values(args, "d", ("--directory",), value_short, value_long):
            scope = env.copy()
            scope.chdir(directory)
        targets = _option_values(args, "o", ("--output",), value_short, value_long) or \
            _positionals(args, value_short, value_long)[:1]
        for target in targets:
            self.write(target, scope, "patch")
        if not targets:
            strips = _option_values(args, "p", ("--strip",), value_short, value_long)
            inputs = _option_values(args, "i", ("--input",), value_short, value_long)
            strip = int(strips[-1]) if strips and _text(strips[-1]).isdigit() else 0
            self.patch_targets(inputs[-1] if inputs else None, stdin, strip, scope, "patch")
        return None

    def patch_targets(self, source, stdin, strip, env, via):
        text = None
        if source is not None and _lit(source) is not None and env.cwd is not None:
            text = _read_small(os.path.join(env.cwd, os.path.expanduser(source)))
        elif source is None and stdin is not None and stdin.kind == "text":
            text = stdin.value
        if text is None:
            self.write(".", env, via, "tree")
            return
        for path in _patch_paths(text, strip):
            self.write(path, env, via)

    def h_editor(self, argv, env, prefix, stdin):
        name = os.path.basename(argv[0])
        self.mark("no")
        for item in _positionals(argv[1:], "cSuUiTwWtq" if name in ("ex", "ed") else "cSuUiTwWtqs", ("--cmd",)):
            if not _text(item).startswith("+"):
                self.write(item, env, name)
        return None

    def h_tee(self, argv, env, prefix, stdin):
        self.mark("no")
        for target in _positionals(argv[1:]):
            self.write(target, env, os.path.basename(argv[0]))
        return None

    def h_split(self, argv, env, prefix, stdin):
        self.mark("no")
        for target in _positionals(argv[1:], "abClnt", ("--suffix-length", "--bytes", "--line-bytes", "--lines",
                                                        "--number", "--separator", "--additional-suffix"))[1:2]:
            self.write(target, env, "split")
        return None

    # -- git ------------------------------------------------------------------------
    def h_git(self, argv, env, prefix, stdin, depth=0):
        args = argv[1:]
        scope, config, i, info = env, self.git_env_config(prefix, env), 0, False
        while i < len(args):
            token = _lit(args[i])
            if token is None or not token.startswith("-"):
                break
            if token in _GIT_GLOBAL_VALUE and i + 1 < len(args):
                value = args[i + 1]
                if token == "-C":
                    scope = scope.copy()
                    scope.chdir(value)
                elif token == "-c":
                    key, eq, setting = _text(value).partition("=")
                    config[key.lower()] = setting if _lit(value) is not None and eq else None
                    if key.lower().startswith("include"):
                        self.config_unknown = True
                elif token == "--config-env":
                    self.config_unknown = True
                i += 2
                continue
            if token.startswith("--config-env="):
                self.config_unknown = True
            info = info or token in _GIT_INFO_FLAGS
            i += 1
        if not all(_git_config_safe(key, value) for key, value in config.items()):
            self.mark("no")
        for key, value in list(config.items()) + [(name, _lit(prefix[name]) if name in prefix else
                                                     env.vars.get(name)) for name in _GIT_COMMAND_ENV
                                                    if name in prefix or name in env.vars]:
            if value and (key in _GIT_COMMAND_ENV or _GIT_COMMAND_KEY.match(key)):
                self.code_possible(value.lstrip("!"), argv, env)
        if i >= len(args):
            if not info:
                self.mark("no")
            return None
        sub, rest = _lit(args[i]), args[i + 1:]
        if sub is None:
            self.reason("dynamic git subcommand: " + _text(args[i]))
            self.mark("no")
            self.guess_git(argv, rest)
            if getattr(args[i], "tainted", False):
                self.unseen("the git subcommand is computed at run time: " + _text(args[i]))
            return None
        if rest and _lit(rest[0]) in ("-h", "--help"):  # git itself honours it only as the first argument
            return None
        if sub not in _GIT_SUBCOMMANDS:
            return self.git_alias(argv[:i + 1], sub, rest, scope, prefix, stdin, config, depth)
        return self.git_subcommand(sub, rest, argv, scope, stdin)

    def git_env_config(self, prefix, env):
        def lookup(name):
            return prefix[name] if name in prefix else env.vars.get(name)

        config = {}
        count = lookup("GIT_CONFIG_COUNT")
        if count is None and ("GIT_CONFIG_COUNT" in prefix or "GIT_CONFIG_COUNT" in env.vars):
            self.config_unknown = True  # set to something nobody can read
        if count is not None and not re.fullmatch(r"[0-9]{1,3}", count):
            count = None
            self.config_unknown = True
        for n in range(min(int(count), MAX_GIT_CONFIG) if count is not None else 0):
            key = lookup("GIT_CONFIG_KEY_%d" % n)
            if key is not None:
                config[key.lower()] = lookup("GIT_CONFIG_VALUE_%d" % n)
            if key is not None and key.lower().startswith("include"):
                self.config_unknown = True
        if count is not None and int(count) > MAX_GIT_CONFIG:
            self.config_unknown = True
        if any(name in prefix or name in env.vars for name in _GIT_CONFIG_SOURCES) or \
                lookup("GIT_CONFIG_PARAMETERS") is None and ("GIT_CONFIG_PARAMETERS" in prefix or
                                                             "GIT_CONFIG_PARAMETERS" in env.vars):
            self.config_unknown = True
        for key, value in re.findall(r"'([^']+)'='([^']*)'", lookup("GIT_CONFIG_PARAMETERS") or ""):
            config[key.lower()] = value
        return config

    def git_alias(self, head, sub, rest, env, prefix, stdin, config, depth):
        """Expand a git alias; ``head`` is the program and its global options."""
        self.mark("no")
        key = "alias." + sub.lower()
        if key in config:
            expansion = config[key]
            if expansion is None:
                self.reason("dynamic git alias: " + sub)
        else:
            expansion = env.git_aliases.get(sub.lower())
            if expansion is None and self.lookups and env.cwd is not None:
                if env.cwd not in self.repo_aliases:
                    self.repo_aliases[env.cwd] = _repo_git_aliases(env.cwd)
                expansion = self.repo_aliases[env.cwd].get(sub.lower())
        if expansion is None and self.config_unknown or expansion is None and key in config:
            # the aliases in effect cannot be read (config files redirected, included or written in this
            # command): the subcommand may be an alias of anything
            self.reason("git aliases cannot be resolved: " + sub)
            if not self.guess_git(list(head) + [sub], rest):
                self.action("commit", list(head) + [sub] + list(rest), possible=True)
        if expansion is None or depth >= 8:
            return None
        if expansion.startswith("!"):
            self.run_code(expansion[1:] + "".join(" " + shlex.quote(_text(a)) for a in rest), env.copy())
            return None
        return self.h_git(list(head) + _split_words(expansion) + list(rest), env, prefix, stdin, depth + 1)

    def guess_git(self, argv, rest):
        literals = [_lit(a) for a in rest]
        found = set()
        for token in literals:
            if token in _GIT_COMMIT:
                found.add("commit")
            if token in _GIT_PUSH:
                found.add("push")
        if any(token in ("-m", "--message", "-F", "--amend", "--allow-empty", "--no-edit") for token in literals):
            found.add("commit")
        if any(token in ("--tags", "--set-upstream", "-u", "--force-with-lease", "--mirror", "origin", "upstream")
               for token in literals):
            found.add("push")
        for name in sorted(found):
            self.action(name, argv, possible=True)
        return found

    def git_subcommand(self, sub, rest, argv, env, stdin):
        literal = [_lit(a) for a in rest]
        control = bool(set(literal) & _GIT_CONTROL)
        # -n is --no-commit for cherry-pick and revert, but --no-stat for merge
        no_commit = sub in ("merge", "cherry-pick", "revert") and (
            "--no-commit" in literal or sub != "merge" and "-n" in literal)
        kind = self.git_action_kind(sub, rest, literal, env.cwd)
        if kind == "update-ref-branch":
            self.action("commit", argv)
        elif kind in _GIT_COMMIT and not control and not no_commit:
            self.action("commit", argv)
            if sub == "commit":
                self.commits.append(self.git_commit_info(rest))
        elif kind == "hash-object" and _has_flag(rest, "w") or kind == "update-ref" and (
                "--stdin" in literal or any(_lit(t) is None or t in ("HEAD", "@") or t.startswith("refs/heads/")
                                            for t in _positionals(rest, "m"))):
            self.action("commit", argv)
        elif kind in _GIT_PUSH:
            info, dry = self.git_push_info(rest)
            if not dry:
                self.action("push", argv)
                self.push.append(info)
        if sub == "reset" and ("--soft" in literal or "--mixed" in literal) and any(
                isinstance(t, Dyn) or _EXEC_TEXT.search(_text(t)) for t in _positionals(rest)):
            self.action("commit", argv, possible=True)
        self.git_runs_commands(sub, rest, literal, argv, env)
        if self.moves_branch_to_stash(sub, rest, literal):
            self.action("commit", argv)  # the stash commit holds the agent's own work: it lands on the branch
        if sub in ("add", "stage"):
            self.staged.extend(_text(a) for a in _positionals(rest, "", ("--chmod", "--pathspec-from-file")))
        if sub == "config":
            self.git_config(rest, env)
            return None
        self.git_writes(sub, rest, literal, env, control, stdin)
        self.read_only_git(sub, rest, literal)
        if sub == "ls-files":
            return _Feed("roots", _positionals(rest, "xX", ("--exclude", "--exclude-from")) or ["."])
        return None

    @staticmethod
    def git_action_kind(sub, rest, literal, cwd=None):
        """The git command ``sub`` acts as: subtree and a local `pull .` commit, http-push pushes,
        a forced branch move rewrites refs/heads/* like update-ref."""
        if sub == "subtree":
            verb = literal[0] if literal else None
            return "push" if verb == "push" else "commit" if verb in ("add", "merge", "pull") else sub
        if sub == "http-push":
            return "push"
        if sub == "pull" and _local_repository(_positionals(rest, "o", ("--repo",))[:1], cwd):
            return "merge"  # `git pull . other` merges a local branch
        if sub == "branch" and _positionals(rest) and any(
                t and (t in ("--force", "--move", "--copy") or re.fullmatch(r"-[a-zA-Z]*[fMC][a-zA-Z]*", t))
                for t in literal):
            return "update-ref-branch"
        return sub

    def git_runs_commands(self, sub, rest, literal, argv, env):
        """Subcommands and options that hand a command line to a program (difftool -x, bisect run, grep -O...)."""
        commands = []
        if sub == "difftool":
            commands = _option_values(rest, "x", ("--extcmd",), "xtg", ("--tool", "--gui"))
        elif sub == "rebase":
            commands = _option_values(rest, "x", ("--exec",), "xsXCS", ("--onto", "--strategy", "--strategy-option"))
        elif sub == "grep":
            commands = [t[2:] for t in literal if t and t.startswith("-O") and len(t) > 2] + \
                [t.partition("=")[2] for t in literal if t and t.startswith("--open-files-in-pager=")]
        elif sub == "submodule":
            words = [_text(a) for a in _positionals(rest)]
            if words[:1] == ["foreach"] and len(words) > 1:
                commands = [" ".join(words[1:])]
        elif sub == "filter-branch":
            commands = _option_values(rest, "", ("--msg-filter", "--tree-filter", "--index-filter", "--commit-filter",
                                                 "--env-filter", "--parent-filter", "--subdirectory-filter",
                                                 "--tag-name-filter"))
        elif sub == "bisect" and literal[:1] == ["run"]:
            commands = [" ".join(shlex.quote(_text(a)) for a in rest[1:])]
        for text in commands:
            self.code_possible(_text(text), argv, env)

    @staticmethod
    def moves_branch_to_stash(sub, rest, literal):
        """checkout -B / switch -C / branch NAME / reset to a stash ref: the work stashed so far becomes
        the branch's commit without a `git commit`."""
        if sub == "reset":
            targets = _positionals(rest)[:1]
        elif sub in ("checkout", "switch") and any(t and re.fullmatch(r"-[bBcC]|--(?:force-)?create", t)
                                                   for t in literal):
            targets = _positionals(rest, "bBcC", ("--orphan", "--conflict", "--create", "--force-create"))[:1]
        elif sub == "branch":
            targets = _positionals(rest)[1:2]
        else:
            return False
        return any(_lit(t) is not None and _STASH_REF.match(t) for t in targets)

    def git_commit_info(self, rest):
        value_long = ("--message", "--file", "--author", "--date", "--template", "--fixup", "--squash", "--cleanup",
                      "--trailer", "--pathspec-from-file", "--reuse-message", "--reedit-message")
        flags = [t for t in (_lit(a) for a in rest[:_options_end(rest, "mFCct", value_long)]) if t]
        return {
            "all": any(t == "--all" or re.match(r"-[^-mFCct]*a", t) is not None for t in flags),
            "amend": "--amend" in flags,
            "pathspecs": [_text(a) for a in _positionals(rest, "mFCct", value_long)],
            "staged_paths": list(self.staged),
        }

    def git_push_info(self, rest):
        positionals = _positionals(rest, "o", ("--repo", "--receive-pack", "--exec", "--push-option"))
        flags = [t for t in (_lit(a) for a in rest) if t and t.startswith("-")]

        def has(*names):
            letters = {n[1] for n in names if len(n) == 2}
            return any(f.split("=", 1)[0] in names or f[1:2] != "-" and set(f[1:]) & letters for f in flags)

        refspecs = [_text(a) for a in positionals[1:]]
        dsts = [r.lstrip("+").split(":", 1)[-1] for r in refspecs]
        info = {
            "remote": _text(positionals[0]) if positionals else None,
            "refspecs": refspecs,
            "dsts": dsts,
            "tags": has("--tags", "--follow-tags") or any(d.startswith("refs/tags/") for d in dsts),
            "all": has("--all", "--branches"),
            "mirror": has("--mirror"),
            "delete": has("-d", "--delete") or any(r.startswith(":") for r in refspecs),
            "force": has("-f", "--force", "--force-with-lease") or any(r.startswith("+") for r in refspecs),
        }
        info["default"] = not (refspecs or info["all"] or info["mirror"] or info["tags"])
        return info, has("-n", "--dry-run")

    def git_config(self, rest, env):
        literal = set(_lit(a) for a in rest)
        positionals = _positionals(rest, "f", ("--file", "--blob", "--type", "--default", "--comment"))
        verb = _lit(positionals[0]) if positionals else None
        if verb in ("get", "list"):
            return
        if verb == "set":
            positionals = positionals[1:]
        if len(positionals) >= 2 and _lit(positionals[0]) is not None and \
                positionals[0].lower().startswith("alias."):
            env.git_aliases[positionals[0][len("alias."):].lower()] = _lit(positionals[1])
        reads = {"--get", "--get-all", "--get-regexp", "--get-urlmatch", "--list", "-l", "--get-color",
                 "--get-colorbool"}
        writes = {"--unset", "--unset-all", "--remove-section", "--rename-section", "--edit", "-e", "--add",
                  "--replace-all"}
        if literal & writes or not (literal & reads) and len(positionals) != 1:
            self.mark("no")
        key = _text(positionals[0]).lower() if positionals else ""
        if not literal & reads and (key.startswith("include") or key.startswith("alias.") and (
                len(positionals) < 2 or _lit(positionals[1]) is None)):
            self.config_unknown = True

    def git_writes(self, sub, rest, literal, env, control, stdin):
        if sub == "checkout":
            positionals = _positionals(rest, "bB", ("--orphan", "--conflict"))
            paths = rest[literal.index("--") + 1:] if "--" in literal else positionals[1:]
            if not paths and positionals and _lit(positionals[0]) is not None and env.cwd is not None and \
                    os.path.isfile(os.path.join(env.cwd, positionals[0])):
                paths = positionals
            for path in paths:
                self.write(path, env, "git checkout")
        elif sub == "restore":
            for path in _positionals(rest, "s", ("--source", "--conflict", "--pathspec-from-file")):
                self.write(path, env, "git restore")
        elif sub == "reset" and set(literal) & {"--hard", "--merge", "--keep"}:
            self.write(".", env, "git reset", "tree")
        elif sub == "clean" and _has_flag(rest, "f", ("--force",)) and not _has_flag(rest, "n", ("--dry-run",)):
            paths = _positionals(rest, "e", ("--exclude",))
            for path in paths or ["."]:
                self.write(path, env, "git clean", "path" if paths else "tree")
        elif sub == "stash" and (literal[0] if rest else "push") in ("push", "save", "pop", "apply"):
            self.write(".", env, "git stash", "tree")
        elif sub == "mv" or sub == "rm" and "--cached" not in literal:
            for path in _positionals(rest):
                self.write(path, env, "git " + sub)
        elif sub == "apply" and ("--apply" in literal or
                                 not set(literal) & {"--check", "--stat", "--numstat", "--summary", "--cached"}):
            strips = [t[2:] for t in literal if t and t.startswith("-p") and t[2:].isdigit()]
            sources = _positionals(rest, "pCx", ("--exclude", "--include", "--directory", "--whitespace"))
            for source in sources or [None]:
                self.patch_targets(source, stdin, int(strips[-1]) if strips else 1, env, "git apply")
        elif sub in _GIT_TREE_CHANGERS and not control:
            self.write(".", env, "git " + sub, "tree")

    def read_only_git(self, sub, rest, literal):
        if sub in _GIT_READ_ONLY:
            if any(t and (t.startswith(("--output", "--open-files-in-pager")) or sub == "grep" and
                          t.startswith("-O") or sub == "ls-remote" and t.startswith(("--upload-pack", "--exec", "-u")))
                   for t in literal):
                self.mark("no")
            return
        positionals = _positionals(rest)
        first = _lit(positionals[0]) if positionals else None
        flags = {t.split("=", 1)[0] for t in literal if t and t.startswith("-")}
        if sub in ("branch", "tag"):
            listing = _BRANCH_LISTING if sub == "branch" else _TAG_LISTING
            if not flags - listing and (not positionals or flags & {"--list", "-l"}):
                return
        elif (sub, first) in _GIT_READ_ONLY_FORMS:
            return
        self.mark("no")

    # -- GitHub ---------------------------------------------------------------------
    def h_gh(self, argv, env, prefix, stdin, depth=0):
        self.mark("no")
        if any(name in prefix or name in env.vars for name in _GH_CONFIG_SOURCES):
            self.config_unknown = True  # gh reads its aliases from a configuration the analysis cannot see
        args = argv[1:]
        i = 0
        while i < len(args) and _lit(args[i]) is not None and args[i].startswith("-"):
            i += 2 if args[i] in ("-R", "--repo") else 1
        if i >= len(args):
            return None
        group, rest = _lit(args[i]), args[i + 1:]
        if group is None:
            self.reason("dynamic gh command: " + _text(args[i]))
            if getattr(args[i], "tainted", False):
                self.unseen("the gh command is computed at run time: " + _text(args[i]))
            visible = {_lit(a) for a in args[i + 1:]}
            for name in sorted((visible & {"create", "new"} and {"pr_create", "release_create"} or set()) |
                               (visible & {"merge"} and {"pr_merge"} or set())):
                self.action(name, argv, possible=True)
            return None
        if _help_requested(rest, _GH_VALUE_OPTS):
            return None
        if group not in _GH_BUILTINS:
            if self.gh_aliases is None:
                self.gh_aliases = _gh_config_aliases(env.home)
            expansion = self.gh_aliases.get(group)
            if expansion is None and self.config_unknown:
                self.reason("gh aliases cannot be resolved: " + group)
                self.action("pr_create", argv, possible=True)
            if expansion is None or depth >= 8:
                return None
            if expansion.startswith("!"):
                self.run_code(expansion[1:] + "".join(" " + shlex.quote(_text(a)) for a in rest), env.copy())
                return None
            return self.h_gh(argv[:1] + _split_words(expansion) + list(rest), env, prefix, stdin, depth + 1)
        sub = _lit(rest[0]) if rest else ""
        tail = [_lit(a) for a in rest[1:]]
        if sub is None and group in ("pr", "release"):
            self.reason("dynamic gh %s subcommand" % group)
            for name in ("pr_create", "pr_merge") if group == "pr" else ("release_create",):
                self.action(name, argv, possible=True)
        elif group == "pr" and (sub in ("create", "new") or sub == "merge" and "--disable-auto" not in tail):
            self.action("pr_create" if sub != "merge" else "pr_merge", argv)
        elif group == "release" and sub in ("create", "new", "edit", "upload"):
            self.action("release_create", argv)
        elif group == "api":
            self.gh_api(rest, argv)
        elif group == "alias" and sub in ("set", "import", "delete") or \
                group in ("extension", "extensions", "ext") and sub in ("install", "upgrade", "create", "remove"):
            self.config_unknown = True  # gh aliases or commands changed in this command
        elif group == "repo" and sub == "sync":
            self.action("remote_write", argv)
        elif group == "workflow" and sub == "run":
            names = _positionals(rest[1:], "fFr", ("--field", "--raw-field", "--ref", "--repo"))
            if names and _deploy_name(_text(names[0])):
                self.action("deploy", argv)
        return None

    def gh_api(self, rest, argv):
        method, fields, endpoint, query, i = None, False, None, None, 0
        while i < len(rest):
            item, token = rest[i], _lit(rest[i])
            i += 1
            if token is None or not token.startswith("-"):
                endpoint = item if endpoint is None else endpoint
                continue
            name, eq, value = token.partition("=")
            if not token.startswith("--") and len(token) > 2:
                name, eq, value = token[:2], "=", token[2:]
            if name not in _GH_API_VALUE:
                continue
            if not eq:
                value = rest[i] if i < len(rest) else ""
                i += 1
            if name in ("-X", "--method"):
                method = _text(value).upper()
            elif name in ("-f", "-F", "--field", "--raw-field", "--input"):
                fields = True
                text = _text(value)
                if text.startswith("query="):
                    visible = _lit(value) is not None and not (name in ("-F", "--field") and text[6:7] == "@")
                    query = text[6:] if visible else None
        method = method or ("POST" if fields else "GET")
        if endpoint is None:
            return
        path = endpoint if isinstance(endpoint, str) else None
        if path is None:
            self.reason("dynamic gh api endpoint")
            if method != "GET":
                self.action("remote_write", argv, possible=True)
            return
        if path == "graphql":
            if query is None:
                self.reason("graphql query is not visible")
                for name in ("pr_create", "pr_merge", "remote_write"):
                    self.action(name, argv, possible=True)
            for mutation, action in _GRAPHQL_MUTATIONS if query is not None else ():
                if re.search(r"\b%s\b" % mutation, query):
                    self.action(action, argv)
            return
        self.api_write(method, path, argv)

    def api_write(self, method, path, argv):
        """Record the delivery action of a GitHub REST call ``method`` on ``path``."""
        path = re.sub(r"^https?://[^/]+/", "", path).split("?", 1)[0].lstrip("/")
        path = re.sub(r"^api/v3/", "", path)
        dispatch = _GH_DISPATCH.search(path)
        if dispatch is not None and method == "POST" and _deploy_name(dispatch.group(2)):
            self.action("deploy", argv)
        for pattern, methods, action in _GH_API_WRITES:
            if method in methods and pattern.search(path):
                self.action(action, argv)
                return

    def github_http(self, urls, method, argv):
        """curl/wget/httpie calls to the GitHub API: the same writes as `gh api`."""
        for url in urls:
            text = _text(url)
            m = _GITHUB_API_URL.match(text)
            if m is None:
                continue
            self.reason("raw HTTP request to the GitHub API")
            if _lit(url) is None or "$" in text:
                if method != "GET":
                    self.action("remote_write", argv, possible=True)
                continue
            self.api_write(method, text, argv)

    def h_forge(self, argv, env, prefix, stdin):
        """glab / tea / az repos / lab / jj / sl: the same delivery verbs as gh and git."""
        self.mark("no")
        name = os.path.basename(argv[0])
        words = [_lit(p) for p in _positionals(argv[1:])]
        if name in ("jj", "sl"):  # jj git push / sl push
            if words[:2] == ["git", "push"] or words[:1] == ["push"]:
                self.action("push", argv)
            return None
        group = words
        pr_words = ("mr", "pr", "merge-request", "pull-request", "pulls")
        if group[:1] and group[0] in pr_words and group[1:2] in (["create"], ["new"]):
            self.action("pr_create", argv)
        elif group[:1] and group[0] in pr_words and group[1:2] in (["merge"], ["accept"]):
            self.action("pr_merge", argv)
        elif group[:1] == ["release"] and group[1:2] in (["create"], ["new"]):
            self.action("release_create", argv)
        return None

    def h_hub(self, argv, env, prefix, stdin):
        args = argv[1:]
        positionals = _positionals(args)
        sub = _lit(positionals[0]) if positionals else None
        if sub == "pull-request":
            self.action("pr_create", argv)
        elif sub == "merge" and any(re.search(r"/pull/\d+", _text(a)) for a in args):
            self.action("pr_merge", argv)
        elif sub == "release" and [_lit(p) for p in positionals[1:2]] == ["create"]:
            self.action("release_create", argv)
        elif sub == "api":
            self.gh_api(args[args.index(positionals[0]) + 1:], argv)
        else:
            return self.h_git(["git"] + list(args), env, prefix, stdin)
        self.mark("no")
        return None

    # -- deploy tools and task runners -------------------------------------------------
    def h_deploy_tool(self, argv, env, prefix, stdin):
        name = os.path.basename(argv[0])
        tool = _TOOL_ALIASES.get(name, name)
        args = argv[1:]
        self.mark("no")
        positionals = [_lit(p) for p in _positionals(args, *_TOOL_VALUE_OPTIONS.get(tool, ("", ())))]
        if _dry_run(args) or not positionals:
            return None
        first = positionals[0]
        if tool in _DEPLOY_SUBCOMMANDS:
            deploys = first in _DEPLOY_SUBCOMMANDS[tool]
            nested = _DEPLOY_NESTED.get((tool, first))
            if deploys and nested is not None:
                deploys = positionals[1:2] != [] and positionals[1] in nested
            if first == "buildx":
                deploys = any(_text(a) == "--push" or "type=registry" in _text(a) for a in args)
        elif tool == "gcloud":
            deploys = "deploy" in positionals[:4]
        elif tool == "az" and first == "repos" and positionals[1:3] == ["pr", "create"]:
            self.action("pr_create", argv)
            deploys = False
        elif tool == "az":
            deploys = "deploy" in positionals[:4] or positionals[:2] == ["webapp", "up"] or \
                "deployment" in positionals[:3] and "create" in positionals[:4]
        elif tool == "aws":
            deploys = tuple(positionals[:2]) in _AWS_DEPLOY
        else:
            deploys = positionals[:2] in (["app", "sync"], ["app", "rollback"])
        if deploys:
            self.action("deploy", argv)
        return None

    def h_vercel(self, argv, env, prefix, stdin):
        args = argv[1:]
        self.mark("no")
        positionals = _positionals(args, "AeEmSt", ("--scope", "--token", "--env", "--build-env", "--meta",
                                                   "--target", "--local-config", "--global-config", "--cwd"))
        if not _dry_run(args) and (not positionals or _lit(positionals[0]) not in _VERCEL_OTHER):
            self.action("deploy", argv)
        return None

    def h_task_runner(self, argv, env, prefix, stdin):
        name = os.path.basename(argv[0])
        args = argv[1:]
        self.opaque_writer(argv[0], "runs project tasks")
        if _dry_run(args) or name in ("make", "gmake") and _has_flag(args, "nq", ("--just-print", "--recon",
                                                                                 "--question")):
            return None
        if name in ("make", "gmake"):  # makefile text given inline or on stdin: judge the commands it names
            texts = [_text(a) for a in _option_values(args, "E", ("--eval",), _TASK_VALUE_SHORT["make"],
                                                       _TASK_VALUE_LONG)]
            if stdin is not None and stdin.kind == "text" and "-" in [_lit(a) for a in args]:
                texts.append(stdin.value)
            for text in texts:
                for verb in sorted(_delivery_verbs(text)):
                    self.action(verb, argv, possible=True)
        targets = [p for p in _positionals(args, _TASK_VALUE_SHORT.get(name, "f"), _TASK_VALUE_LONG)
                   if _lit(p) is not None and "=" not in p]
        if any(_deploy_name(t) for t in targets):
            self.action("deploy", argv)
        return None

    def h_npm(self, argv, env, prefix, stdin):
        name = os.path.basename(argv[0])
        args = argv[1:]
        i = _options_end(args, "Cw", ("--prefix", "--cwd", "--workspace", "--filter", "--dir"))
        sub = _lit(args[i]) if i < len(args) else None
        rest = args[i + 1:]
        if sub in ("test", "t") or sub == "run" and rest and _lit(rest[0]) is not None and \
                (rest[0] == "test" or rest[0].startswith("test:")) or name == "yarn" and sub in ("jest", "vitest"):
            self.mark("no")  # a package script runs arbitrary project code
            return None
        if sub in ("exec", "x", "dlx"):
            for code in _option_values(rest, "c", ("--call",), "p", ("--package",)):
                self.run_code(_text(code), env.copy())
            end = _options_end(rest, "cp", ("--call", "--package"))
            if end < len(rest):
                return self.execute(list(rest[end:]), env, prefix, stdin)
        self.mark("no")
        script = None
        if sub in ("publish", "unpublish") and not _dry_run(rest) or \
                name == "yarn" and sub == "npm" and [_lit(a) for a in rest[:1]] == ["publish"]:
            self.action("deploy", argv)
        elif sub in ("run", "run-script", "rum", "urn") and rest:
            script = rest[0]
        elif sub == "workspace" and len(rest) > 1:
            script = rest[1]
        elif name != "npm" and sub is not None and sub not in _PACKAGE_BUILTINS:
            script = sub
        if script is not None:
            self.opaque_writer(argv[0], "runs package script " + _text(script))
            if _lit(script) is not None and _deploy_name(script) and not _dry_run(rest):
                self.action("deploy", argv)
        return None

    def h_node_runner(self, argv, env, prefix, stdin):
        """jest / mocha / tap / vitest run directly."""
        self.mark("no" if _snapshot_update(argv[1:]) else "test")
        return None


_FIND_VALUE = {"-name", "-iname", "-path", "-ipath", "-wholename", "-iwholename", "-regex", "-iregex", "-type",
               "-xtype", "-size", "-mtime", "-mmin", "-atime", "-amin", "-ctime", "-cmin", "-newer", "-anewer",
               "-cnewer", "-perm", "-user", "-group", "-uid", "-gid", "-links", "-inum", "-samefile",
               "-maxdepth", "-mindepth", "-printf", "-fstype", "-context", "-used", "-lname", "-ilname",
               "-regextype", "-files0-from"}
_GIT_READ_ONLY_FORMS = {("remote", None), ("remote", "show"), ("remote", "get-url"), ("stash", "list"),
                        ("stash", "show"), ("notes", "list"), ("notes", "show"), ("worktree", "list"),
                        ("submodule", None), ("submodule", "status"), ("submodule", "summary"), ("reflog", None),
                        ("reflog", "show"), ("reflog", "exists"), ("sparse-checkout", "list")}
_RSYNC_VALUE_LONG = ("--exclude", "--include", "--filter", "--rsh", "--rsync-path", "--files-from",
                     "--exclude-from", "--include-from", "--temp-dir", "--compare-dest", "--copy-dest",
                     "--link-dest", "--backup-dir", "--suffix", "--chmod", "--chown", "--password-file",
                     "--log-file", "--partial-dir", "--max-size", "--min-size", "--bwlimit", "--timeout", "--port",
                     "--out-format", "--info", "--debug")
_CURL_VALUE_LONG = ("--output", "--dump-header", "--cookie-jar", "--trace", "--trace-ascii", "--stderr",
                    "--etag-save", "--output-dir", "--data", "--data-raw", "--data-binary", "--data-urlencode",
                    "--header", "--user", "--request", "--user-agent", "--referer", "--cookie", "--form",
                    "--upload-file", "--max-time", "--connect-timeout", "--retry", "--proxy", "--config", "--cert",
                    "--key", "--cacert", "--write-out", "--range", "--json", "--url")
_TASK_VALUE_LONG = ("--directory", "--file", "--makefile", "--include-dir", "--jobs", "--inventory",
                    "--extra-vars", "--limit", "--tags")
_WRAPPERS = {
    # name: (short options with a value, long options with a value, positionals before the command)
    "nohup": ("", (), 0),
    "nice": ("n", ("--adjustment",), 0),
    "ionice": ("cnpPu", ("--class", "--classdata", "--pid", "--pgid", "--uid"), 0),
    "stdbuf": ("ioe", ("--input", "--output", "--error"), 0),
    "setsid": ("", (), 0),
    "unbuffer": ("", (), 0),
    "caffeinate": ("tw", (), 0),
    "chronic": ("", (), 0),
    "strace": ("abeEIoOpPsSuX", ("--output",), 0),
    "ltrace": ("aAeEnopsSuX", ("--output",), 0),
    "time": ("fo", ("--format", "--output"), 0),
    "timeout": ("sk", ("--signal", "--kill-after"), 1),
    "gtimeout": ("sk", ("--signal", "--kill-after"), 1),
    "sudo": ("ugpCDhrtTUR", ("--user", "--group", "--prompt", "--close-from", "--chdir", "--host", "--role",
                             "--type", "--command-timeout", "--other-user"), 0),
    "doas": ("uC", (), 0),
    "watch": ("nd", ("--interval", "--differences"), 0),
    "flock": ("Ewc", ("--exit-code", "--timeout", "--conflict-exit-code", "--command"), 1),
    "npx": ("pc", ("--package", "--call", "--node-arg"), 0),
    "pnpx": ("pc", ("--package", "--call"), 0),
    "bunx": ("pc", ("--package",), 0),
    "builtin": ("", (), 0),
    "exec": ("a", (), 0),
    "busybox": ("", (), 0),
}
_OPERAND_WRITERS = {
    "rm": ("", ()), "rmdir": ("", ()), "unlink": ("", ()), "link": ("", ()),
    "shred": ("ns", ("--iterations", "--size", "--random-source")),
    "touch": ("rtd", ("--reference", "--date")), "mkdir": ("m", ("--mode", "--context")),
    "chmod": ("", ("--reference",)), "chown": ("", ("--reference", "--from")), "chgrp": ("", ("--reference",)),
    "truncate": ("sr", ("--size", "--reference")), "mkfifo": ("m", ("--mode",)), "chattr": ("pv", ()),
}
_HANDLERS = {}
for _names, _handler in (
        (_READ_ONLY, "read_only"), (_SHELL_STATE, "shell_state"), (_SHELLS, "shell"), (_WRAPPERS, "wrapper"),
        (_OPERAND_WRITERS, "operands"), (list(_DEPLOY_SUBCOMMANDS) + list(_TOOL_ALIASES) +
                                         ["gcloud", "az", "aws", "argocd"], "deploy_tool"),
        (_TASK_RUNNERS, "task_runner"), (_NPM_LIKE, "npm"), (_TEST_RUNNERS, "node_runner"),
        (("vi", "vim", "nvim", "ex", "ed", "nano", "emacs", "pico", "micro", "joe", "mg", "hx"), "editor"),
        (("gzip", "gunzip", "bzip2", "bunzip2", "xz", "unxz", "zstd", "unzstd", "lz4", "compress",
          "uncompress"), "compress"),
        (("cp", "mv", "install", "ln"), "copy"), (("rsync", "scp"), "sync_copy"), (("vercel", "surge"), "vercel"),
        (("tee", "sponge"), "tee")):
    for _name in _names:
        _HANDLERS[_name] = _handler
_RUNNERS = {"script": ("cIOBETm", ("--command", "--log-in", "--log-out", "--log-io", "--log-timing", "--timing",
                                  "--logging-format", "--output-limit")),
            "su": ("cgGsw", ("--command", "--group", "--supp-group", "--shell", "--whitelist-environment")),
            "runuser": ("cgGsuw", ("--command", "--group", "--supp-group", "--shell", "--user",
                                   "--whitelist-environment"))}
_HANDLERS.update({
    "echo": "echo", "eval": "eval", "source": "source", ".": "source", "trap": "trap", "command": "command",
    "env": "env", "rtk": "rtk", "xargs": "xargs", "dd": "dd", "curl": "curl", "wget": "wget", "tar": "tar",
    "glab": "forge", "tea": "forge", "lab": "forge", "jj": "forge", "sl": "forge",
    "ssh": "ssh", "sftp": "ssh", "http": "httpie", "https": "httpie", "xh": "httpie", "xhs": "httpie", "script": "runner", "su": "runner", "runuser": "runner", "unzip": "unzip", "patch": "patch", "split": "split", "git": "git", "gh": "gh", "hub": "hub",
})
# program words whose appearance among the arguments of another program starts a command
_PROBED_WORDS = (set(_DEPLOY_SUBCOMMANDS) | set(_TOOL_ALIASES) | _TASK_RUNNERS | _NPM_LIKE | _SHELLS | set(_WRAPPERS) |
                 {"git", "gh", "hub", "glab", "tea", "lab", "jj", "sl", "eval", "xargs", "env", "rtk", "command",
                  "gcloud", "az", "aws", "argocd", "vercel", "surge", "curl", "wget", "ssh", "scp", "rsync"})


# =============================================================================
# Results and entry points
# =============================================================================

SHELL_TOOLS = {"Bash", "Shell", "shell", "exec_command"}
_PATCH_MARKER = re.compile(r"^\*\*\* (?:(?:Add|Update|Delete) File|Move to): (.+)$")
_REGEX_REDIRECT = re.compile(r'(^|[\s;|&])(?:>>|[0-9]?>)\s*(?:"([^"]+)"|\'([^\']+)\'|([^\s;|&]+))')
_LOAD_KEYS = ("status", "error", "tool_name", "tool_kind", "command", "file_path", "patch_paths", "actions",
              "tier", "possible_actions", "possible_tier", "could_be_delivery", "opaque", "opaque_reasons",
              "read_only", "read_only_legacy", "write_paths", "skill_adapter", "rtk_unwrapped", "invoked_script",
              "legacy_first_line", "unseen_reasons", "base_dir")


def _tier(actions):
    tier = "none"
    for action in actions:
        if TIER_RANK[ACTION_TIER[action]] > TIER_RANK[tier]:
            tier = ACTION_TIER[action]
    return tier


def _legacy_write_paths(writes):
    return {w["path"] for w in writes if w["scope"] == "path" and (not w["dynamic"] or "/" in w["raw"])}


def _regex_write_paths(text, base):
    """Redirect targets in text the parser rejected (bash rejects it as well)."""
    paths = set()
    for m in _REGEX_REDIRECT.finditer(text):
        target = next(group for group in m.groups()[1:] if group)
        if not ("$" in target or "`" in target or target in _DISCARD or target == "-"):
            paths.add(os.path.realpath(os.path.join(base, os.path.expanduser(target))))
    return paths


def _first_simple(script):
    if script.error or not script.items:
        return None
    first = script.items[0][0][0][0]
    return first if isinstance(first, Simple) else None


def _strip_prefix(text, script):
    """Text after a leading env/assignment/rtk prefix; None without a prefix, "" for a bare prefix."""
    first = _first_simple(script)
    if first is None:
        return None
    words = [word.literal() for word in first.words]
    k = 1 if words[:1] == ["env"] else 0
    while 0 < k < len(words) and words[k] is not None and _ASSIGN.match(words[k]):
        k += 1
    if words[k:k + 1] == ["rtk"]:
        k += 1
    if k == 0 and not first.assigns:
        return None
    return text[first.words[k].start:] if k < len(first.words) else ""


def rtk_unwrap(text):
    """shell_unwrap_rtk.py output: the command without a leading env/assignment/rtk prefix."""
    if not (text or "").strip():
        return ""
    stripped = _strip_prefix(text, parse(text))
    return text if stripped is None else stripped


def _skill_adapter(script):
    """True for one literal ``[env] [NAME=value...] .../scripts/silver-bullet invoke-skill ...`` command."""
    first = _first_simple(script)
    if first is None or len(script.items) != 1 or script.items[0][1] or len(script.items[0][0]) != 1 or \
            len(script.items[0][0][0]) != 1 or first.redirs:
        return False
    words = [word.literal() for word in first.words]
    if None in words or any(a.array or a.value[0].literal() is None for a in first.assigns):
        return False
    k = 1 if words[:1] == ["env"] else 0
    while 0 < k < len(words) and _ASSIGN.match(words[k]):
        k += 1
    return len(words) > k + 1 and words[k + 1] == "invoke-skill" and \
        (words[k] == "scripts/silver-bullet" or words[k].endswith("/scripts/silver-bullet"))


def is_skill_adapter_invocation(text):
    return _skill_adapter(parse(text or ""))


def _result(analysis, script, text):
    actions = sorted(analysis.actions)
    possible = sorted(analysis.possible - analysis.actions)
    tier, possible_tier = _tier(actions), _tier(possible)
    effective = possible_tier if TIER_RANK[possible_tier] > TIER_RANK[tier] else tier
    canonical = []
    for record in analysis.delivery:
        if record["tier"] == effective and record["canonical"] not in canonical:
            canonical.append(record["canonical"])
    paths = _legacy_write_paths(analysis.writes)
    if script.error:
        paths |= _regex_write_paths(text, analysis.base)
    opaque = bool(analysis.reasons)
    return {
        "schema": SCHEMA_VERSION,
        "base_dir": analysis.base,
        "status": "parse_failed" if script.error or analysis.failed else "ok" if text.strip() else "empty",
        "error": script.error or analysis.failed,
        "actions": actions,
        "tier": tier,
        "possible_actions": possible,
        "possible_tier": possible_tier,
        "could_be_delivery": bool(possible),
        "opaque": opaque,
        "opaque_reasons": list(analysis.reasons),
        "unseen_reasons": list(analysis.unseen_reasons),
        "read_only": analysis.read_only and not opaque,
        "read_only_legacy": analysis.read_only_legacy and not opaque,
        "test_runner": analysis.test_runner,
        "writes": analysis.writes,
        "write_paths": sorted(paths),
        "opaque_writers": analysis.opaque_writers,
        "delivery": analysis.delivery,
        "legacy_first_line": " ; ".join(canonical) if canonical else text.split("\n", 1)[0],
        "push": analysis.push,
        "commits": analysis.commits,
        "commands": analysis.commands,
        "skill_adapter": _skill_adapter(script),
        "invoked_script": analysis.scripts[0] if analysis.scripts else "",
        "rtk_unwrapped": _strip_prefix(text, script) or "",
    }


def _home():
    return os.environ.get("HOME") or None


def _guarded(analysis, walk):
    """Run ``walk``; a budget overrun or an analyzer fault reports unseen code instead of failing."""
    try:
        walk()
    except _Budget:
        analysis.unseen("analysis budget exceeded")
    except RecursionError:
        analysis.unseen("nesting too deep")
    except Exception as exc:  # the analyzer must never crash a hook: report the strictest tier
        analysis.failed = "analyzer error: %s" % type(exc).__name__
        analysis.unseen(analysis.failed)


def analyze_command(command, base_dir=None, lookups=True):
    """Analyze one shell command string (see the module docstring for the result)."""
    text = (command or "").replace("\x00", "")
    base = os.path.realpath(base_dir or os.getcwd())
    analysis = _Analysis(base, lookups)
    if len(text) > MAX_INPUT_CHARS:
        analysis.unseen("command too large to analyze")
        return _result(analysis, Script([], ""), text[:4096])
    script = parse(text)
    analysis.deadline = time.monotonic() + MAX_SECONDS  # the walk's own budget starts after the parse
    _guarded(analysis, lambda: analysis.walk_script(script, Env(base, _home())))
    return _result(analysis, script, text)


def analyze_argv(argv, base_dir=None, lookups=True):
    """Analyze a command given as an argv list (Codex exec_command ``cmd``), run without a shell."""
    argv = [str(part).replace("\x00", "") for part in argv]
    text = " ".join(shlex.quote(part) for part in argv)
    base = os.path.realpath(base_dir or os.getcwd())
    analysis = _Analysis(base, lookups)
    if len(text) > MAX_INPUT_CHARS:
        analysis.unseen("command too large to analyze")
        return _result(analysis, Script([], ""), text[:4096])
    if argv:
        _guarded(analysis, lambda: analysis.execute(argv, Env(base, _home()), {}, None))
    return _result(analysis, parse(text), text)


def _strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from _strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from _strings(item)


def patch_paths(tool_input):
    """Paths named by apply_patch markers anywhere in tool_input, in order, once each."""
    paths = []
    for text in _strings(tool_input):
        for line in text.splitlines():
            m = _PATCH_MARKER.match(line)
            path = m.group(1).strip() if m is not None else ""
            if path and path not in paths:
                paths.append(path)
    return paths


def _mcp_tool(tool_name, tool_input):
    if tool_name.startswith("mcp__") and tool_name.count("__") >= 2:
        parts = tool_name.split("__")
        return "__".join(parts[1:-1]), parts[-1]
    if tool_name in ("CallMcpTool", "MCP"):
        server = tool_input.get("server") or tool_input.get("mcpServer") or ""
        tool = tool_input.get("toolName") or tool_input.get("name") or tool_input.get("tool") or ""
        return str(server), str(tool)
    return None, None


def _tool_kind(tool_name, mcp_tool):
    if tool_name in SHELL_TOOLS or not tool_name:
        return "shell"
    if mcp_tool is not None:
        return "mcp"
    if tool_name == "apply_patch":
        return "patch"
    if tool_name in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        return "edit"
    return "other"


def analyze_payload(text, base_dir=None, lookups=True):
    """Analyze a hook payload (JSON text); shell tools get the command analysis, MCP tools
    are classified by tool name, Edit/Write/apply_patch report the paths they write."""
    base = os.path.realpath(base_dir or os.getcwd())
    payload, error = None, ""
    if (text or "").strip():
        try:
            payload = json.loads(text)
        except ValueError:
            pass
        if not isinstance(payload, dict):
            payload, error = None, "hook payload is not a JSON object"
    payload = payload or {}
    tool_name = payload.get("tool_name") if isinstance(payload.get("tool_name"), str) else ""
    tool_input = payload.get("tool_input")
    fields = tool_input if isinstance(tool_input, dict) else {}
    server, mcp_tool = _mcp_tool(tool_name, fields)
    kind = _tool_kind(tool_name, mcp_tool)
    command = fields.get("command")
    if command is None:
        command = fields.get("cmd")
    workdir = fields.get("workdir")
    if isinstance(workdir, str) and workdir:
        base = os.path.realpath(os.path.join(base, workdir))
    if kind == "shell" and isinstance(command, list):
        result = analyze_argv(command, base, lookups)
    else:
        result = analyze_command(command if kind == "shell" and isinstance(command, str) else "", base, lookups)
    command_text = command if isinstance(command, str) else \
        " ".join(shlex.quote(str(part)) for part in command) if isinstance(command, list) else ""
    paths = patch_paths(tool_input) if tool_input is not None else []
    file_path = fields.get("file_path")
    if file_path is None or file_path is False:
        response = payload.get("tool_response")
        file_path = response.get("filePath") if isinstance(response, dict) else None
    file_path = file_path if isinstance(file_path, str) and file_path else (paths[0] if paths else "")
    mcp_actions = _MCP_ACTIONS.get((mcp_tool or "").lower(), ()) if kind == "mcp" else ()
    if mcp_actions and (mcp_tool or "").lower() == "actions_run_trigger" and \
            str(fields.get("method", "")).lower() in _MCP_NON_DELIVERY_METHODS:
        mcp_actions = ()
    for action in mcp_actions:
        result["actions"] = sorted(set(result["actions"]) | {action})
        result["delivery"].append({"action": action, "tier": ACTION_TIER[action], "possible": False,
                                   "canonical": "%s [mcp %s %s]" % (CANONICAL_PREFIX[action], server, mcp_tool)})
    if kind == "mcp" and result["actions"]:
        result["tier"] = _tier(result["actions"])
        result["legacy_first_line"] = " ; ".join(
            r["canonical"] for r in result["delivery"] if r["tier"] == result["tier"])
    targets = paths if kind == "patch" else [file_path] if kind == "edit" and file_path else []
    for target in targets:
        result["writes"].append({"path": os.path.realpath(os.path.join(base, os.path.expanduser(target))),
                                 "raw": target, "dynamic": False, "via": tool_name, "scope": "path"})
    if kind != "shell":
        result["read_only"] = result["read_only_legacy"] = False
    if error or not payload or kind != "shell":
        result["status"] = "parse_failed" if error else "empty" if not payload else "ok"
        result["error"] = error
    result.update(tool={"name": tool_name, "kind": kind, "mcp_server": server, "mcp_tool": mcp_tool},
                  command=command_text.replace("\x00", ""), file_path=file_path, patch_paths=paths)
    return result


def _flat(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, list):
        return "\n".join(value)
    return value or ""


def load_records(result):
    """NUL-terminated key/value pairs for hooks/lib/shell-analysis.sh, ending with __end__."""
    values = dict(result, tool_name=result.get("tool", {}).get("name", ""),
                  tool_kind=result.get("tool", {}).get("kind", "shell"),
                  actions=" ".join(result["actions"]), possible_actions=" ".join(result["possible_actions"]))
    fields = []
    for key in _LOAD_KEYS:
        fields += [key, _flat(values.get(key, "")).replace("\x00", "")]
    fields += ["json", json.dumps(result, separators=(",", ":")), "__end__", ""]
    return "\x00".join(fields) + "\x00"


def read_input(args, index):
    """args[index], or stdin when it is absent or "-" (payloads may exceed argv limits)."""
    if len(args) > index and args[index] != "-":
        return args[index]
    stream = getattr(sys.stdin, "buffer", None)
    return stream.read().decode("utf-8", "replace") if stream is not None else sys.stdin.read()


def _write(text):
    stream = getattr(sys.stdout, "buffer", None)
    if stream is not None:
        stream.write(text.encode("utf-8", "replace"))
    else:
        sys.stdout.write(text)


def main(args):
    mode = args[0] if args else ""
    base = args[args.index("--base-dir") + 1] if "--base-dir" in args[:-1] else None
    if mode not in ("payload", "command", "load-payload", "load-command"):
        sys.stderr.write("usage: analyze.py payload|command|load-payload|load-command [--base-dir DIR] < input\n")
        return 2
    text = read_input([], 0)
    result = analyze_payload(text, base) if mode.endswith("payload") else analyze_command(text, base)
    _write(load_records(result) if mode.startswith("load-") else json.dumps(result) + "\n")
    return 0
