"""Safe edits of host configuration files for the Silver Bullet installers.

The installers change files that belong to the user's coding hosts (~/.claude, ~/.codex,
~/.cursor). Everything here follows the same rules:

* Reads refuse instead of guessing: an unparseable or wrongly typed file raises
  ``ConfigError`` and the caller leaves the file alone.
* Writes are atomic: a temp file in the same directory is fsynced and renamed over the
  real (symlink-resolved) path, keeping the file's mode. An unchanged file is not
  touched; a changed one gets its previous content in ``<file>.sb-backup``.
* TOML is edited structurally. ``TomlDocument`` lexes the whole file (multi-line strings
  and arrays, inline tables, comments, quoted keys) into statements, so removing or
  adding a table never splits a value, and comments and unknown keys survive. When a
  TOML parser is importable (tomllib, tomli, or pip's vendored tomli) the result is
  parsed before it is written.
* Hook ownership is decided by the program a hook command runs: Silver Bullet owns a
  command only when that program lives in a Silver Bullet hooks directory.
"""

from __future__ import annotations

import contextlib
import importlib
import json
import os
import re
import shlex
import stat
import tempfile
from pathlib import Path

BACKUP_SUFFIX = ".sb-backup"


class ConfigError(ValueError):
    """A host config file cannot be read or changed safely; it was left unchanged."""


# --------------------------------------------------------------------------- files


def read_bytes(path) -> bytes | None:
    """The file's bytes, or None when it does not exist."""
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except FileNotFoundError:
        return None


def _default_mode() -> int:
    umask = os.umask(0)
    os.umask(umask)
    return 0o666 & ~umask


def _replace_file(target: str, payload: bytes, mode: int) -> None:
    directory = os.path.dirname(target)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix="." + os.path.basename(target) + ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, target)
    except BaseException:
        with contextlib.suppress(OSError):
            os.unlink(tmp)
        raise


def write_atomic(path, payload: bytes, *, backup: bool = True) -> bool:
    """Write ``payload`` to ``path`` atomically; return False when nothing changed.

    A symlinked ``path`` stays a symlink (its target is replaced). The previous
    content, when there is any and it differs, is kept in ``<target>.sb-backup``.
    """
    target = os.path.realpath(path)
    current = read_bytes(target)
    if current == payload:
        return False
    os.makedirs(os.path.dirname(target), exist_ok=True)
    if current is None:
        mode = _default_mode()
    else:
        mode = stat.S_IMODE(os.stat(target).st_mode)
        if backup:
            _replace_file(target + BACKUP_SUFFIX, current, mode)
    _replace_file(target, payload, mode)
    return True


# ---------------------------------------------------------------------------- JSON


def read_json(path, *, kind: type = dict, default=None):
    """Parse a JSON file that must hold a ``kind`` value; ``default`` when it is absent."""
    raw = read_bytes(path)
    if raw is None:
        return default
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as exc:
        raise ConfigError(f"{path}: not valid JSON ({exc}); left unchanged") from exc
    if not isinstance(data, kind):
        label = "an object" if kind is dict else "an array"
        raise ConfigError(f"{path}: expected {label} at the top level; left unchanged")
    return data


def json_bytes(data) -> bytes:
    """Serialize like the hosts do (2-space indent, trailing newline)."""
    try:
        return (json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    except UnicodeEncodeError:
        # A lone surrogate cannot be written as UTF-8: keep it as an escape.
        return (json.dumps(data, indent=2) + "\n").encode("utf-8")


def write_json(path, data, *, backup: bool = True) -> bool:
    return write_atomic(path, json_bytes(data), backup=backup)


# ------------------------------------------------------------------ hook ownership

_INTERPRETERS = frozenset({"bash", "sh", "zsh", "node", "python", "python3", "env"})
_CACHE_ROOT_RE = re.compile(r"(?:/plugins/cache/[^/]+/silver-bullet/[^/]+|/silver-bullet/(?:\d+\.\d+\.\d+[^/]*|current))$")
_NAMED_ROOT_RE = re.compile(r"(?:/silver-bullet(?:/[^/]+)?|^\$\{(?:CLAUDE|CURSOR)_PLUGIN_ROOT\})$")
_ASSIGNMENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")


def sb_hook_names(*hook_dirs) -> frozenset:
    """Names of the files in Silver Bullet hooks directories (missing dirs are skipped)."""
    names = set()
    for hook_dir in hook_dirs:
        directory = Path(hook_dir)
        if directory.is_dir():
            names.update(entry.name for entry in directory.iterdir() if entry.is_file())
    return frozenset(names)


def command_program(command) -> str:
    """The program a hook command runs, after env assignments and an interpreter."""
    if not isinstance(command, str):
        return ""
    try:
        tokens = shlex.split(command)
    except ValueError:
        tokens = command.split()
    index = 0
    while index < len(tokens) and _ASSIGNMENT_RE.match(tokens[index]):
        index += 1
    if index < len(tokens) - 1 and os.path.basename(tokens[index]) in _INTERPRETERS:
        index += 1
    return tokens[index] if index < len(tokens) else ""


def is_sb_hook_command(command, *, hook_names=frozenset(), install_roots=()) -> bool:
    """True when the program ``command`` runs lives in a Silver Bullet hooks directory.

    Owned: anything under an installed host plugin cache
    (``.../plugins/cache/<marketplace>/silver-bullet/<version>/hooks/``), a versioned
    install mirror (``.../silver-bullet/<x.y.z>|current/hooks/``) or one of
    ``install_roots``; and, when the file name is one of ``hook_names``, Silver Bullet's
    checkout and mirror layouts (``.../silver-bullet/<dir>/hooks/``,
    ``.../plugins/silver-bullet/hooks/``) and the unexpanded ``${CLAUDE_PLUGIN_ROOT}`` /
    ``${CURSOR_PLUGIN_ROOT}`` placeholders. A user hook that merely mentions Silver
    Bullet, or runs its own script through ``$HOME`` or a project path, is never owned.
    """
    program = command_program(command)
    root, sep, name = program.rpartition("/hooks/")
    if not sep or not root or not name or "/" in name:
        return False
    if _CACHE_ROOT_RE.search(root):
        return True
    for install_root in install_roots:
        if install_root and root == str(install_root).rstrip("/"):
            return True
    return name in hook_names and bool(_NAMED_ROOT_RE.search(root))


def remove_hooks(events, owned) -> int:
    """Remove the hook entries ``owned(entry)`` selects from a Claude/Codex hooks object
    ({event: [{"matcher": ..., "hooks": [entry, ...]}, ...]}); return how many went.

    A group or event emptied by the removal is dropped; anything else (other entries,
    groups without a hook list, non-list events, empty events) is kept as it was.
    """
    removed = 0
    for event in list(events):
        groups = events[event]
        if not isinstance(groups, list) or not groups:
            continue
        kept_groups = []
        for group in groups:
            hooks = group.get("hooks") if isinstance(group, dict) else None
            if not isinstance(hooks, list):
                kept_groups.append(group)
                continue
            kept = [hook for hook in hooks if not (isinstance(hook, dict) and owned(hook))]
            removed += len(hooks) - len(kept)
            if len(kept) == len(hooks):
                kept_groups.append(group)
            elif kept:
                kept_groups.append({**group, "hooks": kept})
        if kept_groups:
            events[event] = kept_groups
        else:
            del events[event]
    return removed


# ---------------------------------------------------------------------------- TOML

_BARE_KEY_RE = re.compile(r"[A-Za-z0-9_-]+")
_ESCAPES = {"b": "\b", "t": "\t", "n": "\n", "f": "\f", "r": "\r", '"': '"', "\\": "\\", "e": "\x1b"}
_SCALAR_STOP = ",]}#\r\n"


def toml_parser():
    """A ``loads`` function from tomllib, tomli or pip's vendored tomli, or None."""
    for name in ("tomllib", "tomli", "pip._vendor.tomli"):
        try:
            return importlib.import_module(name).loads
        except ImportError:
            continue
    return None


def check_toml(text: str, label) -> None:
    """Raise ConfigError when an available TOML parser rejects ``text``."""
    loads = toml_parser()
    if loads is None:
        return
    try:
        loads(text)
    except Exception as exc:  # noqa: BLE001 - every parser has its own error type
        raise ConfigError(f"{label}: not valid TOML ({exc}); left unchanged") from exc


def toml_string(value: str) -> str:
    """A TOML basic-string literal for ``value``."""
    escaped = []
    for char in value:
        if char in '"\\':
            escaped.append("\\" + char)
        elif ord(char) < 0x20 or ord(char) == 0x7F:
            escaped.append(f"\\u{ord(char):04x}")
        else:
            escaped.append(char)
    return '"' + "".join(escaped) + '"'


def format_key(path) -> str:
    """A dotted TOML key for ``path``; parts that are not bare keys are quoted."""
    return ".".join(part if _BARE_KEY_RE.fullmatch(part) else toml_string(part) for part in path)


class TomlStatement:
    """One line-level statement: a table header, a key/value pair, or trivia."""

    __slots__ = ("kind", "start", "end", "path", "value")

    def __init__(self, kind, start, end, path=(), value=None):
        self.kind = kind  # "table", "array-table", "keyval" or "trivia"
        self.start = start
        self.end = end
        self.path = path  # header path, or table path + dotted key for keyval
        self.value = value  # (start, end) of a keyval's value text


class _Lexer:
    def __init__(self, text: str, label):
        self.text = text
        self.label = label

    def error(self, index, message):
        line = self.text.count("\n", 0, index) + 1
        return ConfigError(f"{self.label}: line {line}: {message}; left unchanged")

    def skip_ws(self, i):
        while i < len(self.text) and self.text[i] in " \t":
            i += 1
        return i

    def skip_space(self, i):
        """Whitespace, newlines and comments (inside arrays and inline tables)."""
        text = self.text
        while i < len(text):
            if text[i] in " \t\r\n":
                i += 1
            elif text[i] == "#":
                while i < len(text) and text[i] != "\n":
                    i += 1
            else:
                break
        return i

    def end_of_line(self, i):
        """Index after the rest of the line: whitespace, a comment, then a newline or EOF."""
        text = self.text
        i = self.skip_ws(i)
        if i < len(text) and text[i] == "#":
            while i < len(text) and text[i] != "\n":
                i += 1
        if i >= len(text):
            return i
        if text[i] == "\n":
            return i + 1
        if text.startswith("\r\n", i):
            return i + 2
        raise self.error(i, f"unexpected {text[i]!r}")

    def basic_string(self, i):
        """Decode a single-line basic string starting at the quote; return (value, end)."""
        text = self.text
        out = []
        j = i + 1
        while j < len(text):
            char = text[j]
            if char == '"':
                return "".join(out), j + 1
            if char == "\n":
                break
            if char != "\\":
                out.append(char)
                j += 1
                continue
            code = text[j + 1 : j + 2]
            if code in _ESCAPES:
                out.append(_ESCAPES[code])
                j += 2
                continue
            width = {"x": 2, "u": 4, "U": 8}.get(code)
            digits = text[j + 2 : j + 2 + width] if width else ""
            if not width or len(digits) != width or not all(c in "0123456789abcdefABCDEF" for c in digits):
                raise self.error(j, "invalid escape in a string")
            out.append(chr(int(digits, 16)))
            j += 2 + width
        raise self.error(i, "unterminated string")

    def literal_string(self, i):
        end = self.text.find("'", i + 1)
        newline = self.text.find("\n", i + 1)
        if end == -1 or (newline != -1 and newline < end):
            raise self.error(i, "unterminated string")
        return self.text[i + 1 : end], end + 1

    def key(self, i):
        """Parse a dotted key; return (path, end)."""
        text = self.text
        parts = []
        while True:
            i = self.skip_ws(i)
            if text.startswith('"', i):
                part, i = self.basic_string(i)
            elif text.startswith("'", i):
                part, i = self.literal_string(i)
            else:
                match = _BARE_KEY_RE.match(text, i)
                if not match:
                    raise self.error(i, "expected a key")
                part, i = match.group(0), match.end()
            parts.append(part)
            i = self.skip_ws(i)
            if not text.startswith(".", i):
                return tuple(parts), i
            i += 1

    def multiline(self, i, quote):
        """Skip a multi-line string whose opening delimiter starts at ``i``."""
        text = self.text
        delimiter = quote * 3
        j = i + 3
        while j < len(text):
            if quote == '"' and text[j] == "\\":
                j += 2
            elif text.startswith(delimiter, j):
                j += 3
                extra = 0
                while extra < 2 and j < len(text) and text[j] == quote:
                    j += 1
                    extra += 1
                return j
            else:
                j += 1
        raise self.error(i, "unterminated multi-line string")

    def value(self, i):
        """Skip one value starting at ``i``; return the index just after it."""
        text = self.text
        if text.startswith('"""', i):
            return self.multiline(i, '"')
        if text.startswith("'''", i):
            return self.multiline(i, "'")
        if text.startswith('"', i):
            return self.basic_string(i)[1]
        if text.startswith("'", i):
            return self.literal_string(i)[1]
        if text.startswith("[", i):
            return self.container(i + 1, "]", inline_table=False)
        if text.startswith("{", i):
            return self.container(i + 1, "}", inline_table=True)
        j = i
        while j < len(text) and text[j] not in _SCALAR_STOP:
            j += 1
        while j > i and text[j - 1] in " \t":
            j -= 1
        if j == i:
            raise self.error(i, "expected a value")
        return j

    def container(self, i, close, *, inline_table):
        text = self.text
        while True:
            i = self.skip_space(i)
            if text.startswith(close, i):
                return i + 1
            if inline_table:
                _, i = self.key(i)
                i = self.skip_ws(i)
                if not text.startswith("=", i):
                    raise self.error(i, "expected '=' in an inline table")
                i = self.skip_ws(i + 1)
            i = self.value(i)
            i = self.skip_space(i)
            if text.startswith(",", i):
                i += 1
            elif not text.startswith(close, i):
                raise self.error(i, f"expected ',' or {close!r}")

    def statements(self):
        text = self.text
        found = []
        table = ()
        i = 0
        while i < len(text):
            start = i
            i = self.skip_ws(i)
            if i >= len(text) or text[i] in "#\r\n":
                i = self.end_of_line(i)
                found.append(TomlStatement("trivia", start, i))
                continue
            if text[i] == "[":
                array = text.startswith("[[", i)
                path, i = self.key(i + (2 if array else 1))
                close = "]]" if array else "]"
                if not text.startswith(close, i):
                    raise self.error(i, f"expected {close!r}")
                i = self.end_of_line(i + len(close))
                table = path
                found.append(TomlStatement("array-table" if array else "table", start, i, path))
                continue
            key, i = self.key(i)
            if not text.startswith("=", i):
                raise self.error(i, "expected '='")
            value_start = self.skip_ws(i + 1)
            value_end = self.value(value_start)
            i = self.end_of_line(value_end)
            found.append(TomlStatement("keyval", start, i, table + key, (value_start, value_end)))
        return found


def _within(path, prefix) -> bool:
    return tuple(path[: len(prefix)]) == tuple(prefix)


class TomlDocument:
    """A TOML file edited at statement level: unchanged bytes stay byte-identical."""

    def __init__(self, text: str, label="config.toml"):
        self.label = label
        self._load(text)

    def _load(self, text):
        self.text = text
        self.statements = _Lexer(text, self.label).statements()

    @property
    def newline(self) -> str:
        return "\r\n" if "\r\n" in self.text else "\n"

    def headers(self, path):
        return [st for st in self.statements if st.kind == "table" and st.path == tuple(path)]

    def remove(self, predicate) -> int:
        """Remove every table whose path satisfies ``predicate``, and every dotted key whose
        full path does; return how many were removed. A removed table takes its body (up to
        its last key) and the blank lines after it; comments before the next table stay."""
        statements = self.statements
        spans = []
        index = 0
        while index < len(statements):
            statement = statements[index]
            if statement.kind in ("table", "array-table") and predicate(statement.path):
                last = index
                cursor = index + 1
                while cursor < len(statements) and statements[cursor].kind not in ("table", "array-table"):
                    if statements[cursor].kind == "keyval":
                        last = cursor
                    cursor += 1
                while last + 1 < cursor and not self.text[statements[last + 1].start : statements[last + 1].end].strip():
                    last += 1
                spans.append((statement.start, statements[last].end))
                index = last + 1
                continue
            if statement.kind == "keyval" and predicate(statement.path):
                spans.append((statement.start, statement.end))
            index += 1
        text = self.text
        for start, end in reversed(spans):
            text = text[:start] + text[end:]
        if spans:
            self._load(text)
        return len(spans)

    def _require_free(self, path, *, allow_dotted: bool) -> None:
        """Raise when ``path`` cannot get a ``[table]`` header (or keys) without conflict."""
        path = tuple(path)
        for statement in self.statements:
            if statement.kind == "array-table" and _within(path, statement.path):
                raise ConfigError(f"{self.label}: [{format_key(path)}] lies inside an array of tables; left unchanged")
            if statement.kind != "keyval":
                continue
            if _within(path, statement.path):
                raise ConfigError(f"{self.label}: {format_key(statement.path)} already holds a value; left unchanged")
            if not allow_dotted and _within(statement.path, path):
                raise ConfigError(f"{self.label}: [{format_key(path)}] is defined with dotted keys; left unchanged")

    def set_value(self, table, key: str, literal: str) -> bool:
        """Make ``table.key`` hold ``literal`` (a TOML value); return True when changed."""
        table = tuple(table)
        target = table + (key,)
        exact = [st for st in self.statements if st.kind == "keyval" and st.path == target]
        headers = self.headers(table)
        if len(exact) > 1 or len(headers) > 1:
            raise ConfigError(f"{self.label}: {format_key(target)} is defined more than once; left unchanged")
        if exact:
            start, end = exact[0].value
            if self.text[start:end] == literal:
                return False
            self._load(self.text[:start] + literal + self.text[end:])
            return True
        self._require_free(table, allow_dotted=bool(headers))
        line = f"{format_key((key,))} = {literal}{self.newline}"
        if headers:
            at = headers[0].end
            prefix = "" if self.text[:at].endswith("\n") else self.newline
            self._load(self.text[:at] + prefix + line + self.text[at:])
        else:
            self._load(self._with_block(f"[{format_key(table)}]{self.newline}{line}"))
        return True

    def append_tables(self, tables) -> bool:
        """Append ``[path]`` tables, each ``(path, [(key, literal), ...])``, at the end."""
        lines = []
        for path, items in tables:
            path = tuple(path)
            if self.headers(path):
                raise ConfigError(f"{self.label}: [{format_key(path)}] already exists; left unchanged")
            self._require_free(path, allow_dotted=False)
            lines.append(f"[{format_key(path)}]")
            lines.extend(f"{format_key((key,))} = {literal}" for key, literal in items)
            lines.append("")
        if not lines:
            return False
        self._load(self._with_block(self.newline.join(lines)))
        return True

    def _with_block(self, block: str) -> str:
        text = self.text
        if text and not text.endswith("\n"):
            text += self.newline
        if text.strip() and not text.endswith(self.newline * 2):
            text += self.newline
        return text + block


def read_toml(path, label=None) -> TomlDocument:
    """Load a TOML file (an absent file is an empty document); refuse an invalid one."""
    label = label or str(path)
    raw = read_bytes(path)
    try:
        text = "" if raw is None else raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ConfigError(f"{label}: not UTF-8 ({exc}); left unchanged") from exc
    check_toml(text, label)
    return TomlDocument(text, label)


def write_toml(path, document: TomlDocument, *, backup: bool = True) -> bool:
    """Validate and atomically write ``document``; return False when nothing changed."""
    check_toml(document.text, document.label)
    return write_atomic(path, document.text.encode("utf-8"), backup=backup)
