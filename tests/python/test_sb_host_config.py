"""Unit tests for scripts/lib/sb_host_config.py: safe host-config I/O, the structural
TOML editor and the Silver Bullet hook-ownership predicate."""
from __future__ import annotations

import json
import os
import stat
import tempfile
import tomllib
import unittest
from pathlib import Path
from unittest import mock

from sbtest import load_module

m = load_module("scripts/lib/sb_host_config.py")


class Tmp(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name).resolve()


class FileWriteTest(Tmp):
    def test_read_bytes_absent_and_present(self):
        self.assertIsNone(m.read_bytes(self.tmp / "none"))
        (self.tmp / "f").write_bytes(b"x")
        self.assertEqual(m.read_bytes(self.tmp / "f"), b"x")

    def test_new_file_gets_umask_mode_and_no_backup(self):
        target = self.tmp / "sub" / "new.json"
        old = os.umask(0o027)
        try:
            self.assertTrue(m.write_atomic(target, b"{}\n"))
        finally:
            os.umask(old)
        self.assertEqual(target.read_bytes(), b"{}\n")
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o640)
        self.assertFalse((self.tmp / "sub" / "new.json.sb-backup").exists())

    def test_unchanged_file_is_not_touched(self):
        target = self.tmp / "same"
        target.write_bytes(b"a")
        os.utime(target, (1, 1))
        self.assertFalse(m.write_atomic(target, b"a"))
        self.assertEqual(target.stat().st_mtime, 1)
        self.assertFalse(Path(str(target) + ".sb-backup").exists())

    def test_change_keeps_mode_and_backs_up_previous_content(self):
        target = self.tmp / "conf"
        target.write_bytes(b"old")
        target.chmod(0o600)
        self.assertTrue(m.write_atomic(target, b"new"))
        backup = Path(str(target) + ".sb-backup")
        self.assertEqual((target.read_bytes(), backup.read_bytes()), (b"new", b"old"))
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(backup.stat().st_mode), 0o600)
        self.assertTrue(m.write_atomic(target, b"newer", backup=False))
        self.assertEqual(backup.read_bytes(), b"old")
        self.assertEqual([p.name for p in self.tmp.iterdir() if p.name.endswith(".tmp")], [])

    def test_first_backup_of_a_run_is_kept_and_a_stale_one_is_replaced(self):
        target = self.tmp / "conf"
        backup = Path(str(target) + ".sb-backup")
        target.write_bytes(b"original")
        with mock.patch.dict(os.environ, {"SB_INSTALL_RUN_START": str(int(__import__("time").time()))}):
            m.write_atomic(target, b"step1")
            m.write_atomic(target, b"step2")
            self.assertEqual(backup.read_bytes(), b"original")  # the user's file, not step1
        old = __import__("time").time() - 3600
        os.utime(backup, (old, old))
        with mock.patch.dict(os.environ, {"SB_INSTALL_RUN_START": str(int(__import__("time").time()))}):
            m.write_atomic(target, b"step3")
        self.assertEqual(backup.read_bytes(), b"step2")  # an older run's backup is replaced

    def test_a_parent_with_only_a_sub_table_gets_its_own_header(self):
        doc = m.TomlDocument("[features.sub]\na = 1\n")
        self.assertTrue(doc.set_value(("features",), "plugin_hooks", "true"))
        self.assertEqual(tomllib.loads(doc.text), {"features": {"sub": {"a": 1}, "plugin_hooks": True}})
        self.assertTrue(m.TomlDocument('[plugins."x".y]\na = 1\n').append_tables([(("plugins", "x"), [("enabled", "true")])]))
        with self.assertRaises(m.ConfigError):  # genuinely dotted: still refused
            m.TomlDocument("features.a = 1\n").set_value(("features",), "b", "1")

    def test_rename_tables_is_simultaneous_and_drops_stale_targets(self):
        text = ('[hooks.state."a:0:1"]\ntrusted_hash = "A"\n\n  [hooks.state."a:0:2"] # note\ntrusted_hash = "B"\n\n'
                '[hooks.state."a:0:0"]\ntrusted_hash = "stale"\n\n[other]\nk = 1\n')
        doc = m.TomlDocument(text)
        moved = {("hooks", "state", "a:0:1"): ("hooks", "state", "a:0:0"),
                 ("hooks", "state", "a:0:2"): ("hooks", "state", "a:0:1"),
                 ("hooks", "state", "a:9:9"): ("hooks", "state", "a:9:9")}
        self.assertEqual(doc.rename_tables(moved), 2)
        self.assertEqual(tomllib.loads(doc.text), {"hooks": {"state": {"a:0:0": {"trusted_hash": "A"},
                         "a:0:1": {"trusted_hash": "B"}}}, "other": {"k": 1}})
        crlf = m.TomlDocument('[x."a"]\r\nk = 1\r\n')
        crlf.rename_tables({("x", "a"): ("x", "b")})
        self.assertEqual(crlf.text, '[x.b]\r\nk = 1\r\n')
        self.assertEqual(m.TomlDocument("[a]\n").rename_tables({}), 0)

    def test_read_toml_repairing_only_repairs_what_it_is_told_to(self):
        path = self.tmp / "c.toml"
        path.write_text('[a."x"]\nk = 1\n[a."x"]\nk = 2\n[b]\nk = 1\n')
        doc, repaired = m.read_toml_repairing(path, lambda p: p[:1] == ("a",))
        self.assertEqual((tomllib.loads(doc.text), repaired), ({"b": {"k": 1}}, True))
        path.write_text("[a]\nk = 1\n")
        self.assertTrue(m.read_toml_repairing(path, lambda p: True)[1] is False)
        path.write_text('[b]\nk = 1\n[b]\n')
        with self.assertRaises(m.ConfigError):
            m.read_toml_repairing(path, lambda p: p[:1] == ("a",))
        path.write_bytes(b"\xff\xfe")
        with self.assertRaises(m.ConfigError):
            m.read_toml_repairing(path, lambda p: True)

    def test_symlink_is_written_through(self):
        real = self.tmp / "dotfiles" / "settings.json"
        real.parent.mkdir()
        real.write_bytes(b"1")
        link = self.tmp / "settings.json"
        link.symlink_to(real)
        m.write_atomic(link, b"2")
        self.assertTrue(link.is_symlink())
        self.assertEqual(real.read_bytes(), b"2")
        self.assertEqual(Path(str(real) + ".sb-backup").read_bytes(), b"1")

    def test_failed_write_leaves_target_and_no_temp_file(self):
        target = self.tmp / "conf"
        target.write_bytes(b"keep")
        with mock.patch.object(m.os, "replace", side_effect=OSError("disk full")), \
             mock.patch.object(m.os, "unlink", wraps=os.unlink) as unlink:
            with self.assertRaises(OSError):
                m.write_atomic(target, b"new", backup=False)
        self.assertEqual(target.read_bytes(), b"keep")
        self.assertTrue(unlink.called)
        self.assertEqual([p.name for p in self.tmp.iterdir()], ["conf"])

    def test_failed_cleanup_is_suppressed(self):
        target = self.tmp / "conf"
        with mock.patch.object(m.os, "replace", side_effect=OSError("boom")), \
             mock.patch.object(m.os, "unlink", side_effect=OSError("gone")):
            with self.assertRaisesRegex(OSError, "boom"):
                m.write_atomic(target, b"x")


class JsonTest(Tmp):
    def test_read_json_variants(self):
        path = self.tmp / "a.json"
        self.assertEqual(m.read_json(path, default={"d": 1}), {"d": 1})
        path.write_bytes(b"\xff")
        with self.assertRaisesRegex(m.ConfigError, "not valid JSON"):
            m.read_json(path)
        path.write_text("{trailing,}")
        with self.assertRaisesRegex(m.ConfigError, "not valid JSON.*left unchanged"):
            m.read_json(path)
        path.write_text("[]")
        with self.assertRaisesRegex(m.ConfigError, "expected an object"):
            m.read_json(path)
        path.write_text("{}")
        with self.assertRaisesRegex(m.ConfigError, "expected an array"):
            m.read_json(path, kind=list)
        path.write_text('{"a": [1]}')
        self.assertEqual(m.read_json(path), {"a": [1]})

    def test_json_bytes_and_write(self):
        self.assertEqual(m.json_bytes({"k": "café"}), '{\n  "k": "café"\n}\n'.encode())
        self.assertEqual(m.json_bytes({"k": "\ud800"}), b'{\n  "k": "\\ud800"\n}\n')
        path = self.tmp / "o.json"
        self.assertTrue(m.write_json(path, {"a": 1}))
        self.assertEqual(json.loads(path.read_text()), {"a": 1})


class OwnershipTest(Tmp):
    NAMES = frozenset({"completion-audit.sh", "session-start", "cursor-hook-bridge.sh"})

    def test_hook_names_lists_files_only(self):
        hooks = self.tmp / "hooks"
        (hooks / "lib").mkdir(parents=True)
        (hooks / "a.sh").write_text("")
        self.assertEqual(m.sb_hook_names(hooks, self.tmp / "missing"), frozenset({"a.sh"}))

    def test_command_program(self):
        self.assertEqual(m.command_program(None), "")
        self.assertEqual(m.command_program(""), "")
        self.assertEqual(m.command_program('"/a b/x.sh" arg'), "/a b/x.sh")
        self.assertEqual(m.command_program("FOO=1 BAR=2 bash /x/y.sh"), "/x/y.sh")
        self.assertEqual(m.command_program("/usr/bin/node 'q.js'"), "q.js")
        self.assertEqual(m.command_program("bash"), "bash")
        self.assertEqual(m.command_program("FOO=1"), "")
        self.assertEqual(m.command_program('"unterminated /x/y.sh'), '"unterminated')

    def owned(self, command, roots=()):
        return m.is_sb_hook_command(command, hook_names=self.NAMES, install_roots=roots)

    def test_owned_commands(self):
        cache = "/h/.claude/plugins/cache/alo-labs/silver-bullet/current"
        self.assertTrue(self.owned(f'"{cache}/hooks/anything.sh"'))
        self.assertTrue(self.owned(f'"/h/.cursor/plugins/cache/alo-labs/silver-bullet/0.1.0/hooks/cursor-hook-bridge.sh" stop "x"'))
        self.assertTrue(self.owned('"${CLAUDE_PLUGIN_ROOT}/hooks/session-start"'))
        self.assertTrue(self.owned("${CURSOR_PLUGIN_ROOT}/hooks/completion-audit.sh"))
        self.assertTrue(self.owned("/repo/plugins/silver-bullet/hooks/completion-audit.sh"))
        self.assertTrue(self.owned("/home/me/silver-bullet/hooks/completion-audit.sh"))
        self.assertTrue(self.owned("/home/me/projects/silver-bullet/repo/hooks/completion-audit.sh"))
        self.assertTrue(self.owned("/opt/sb/hooks/mine.sh", roots=("", "/opt/sb/")))
        self.assertTrue(self.owned("/old/silver-bullet/1.0.0/hooks/completion-audit.sh"))
        self.assertTrue(self.owned("/m/silver-bullet/current/hooks/completion-audit.sh"))
        # a bare versioned layout owns nothing without an SB hook name (user scripts survive)
        self.assertFalse(self.owned("/old/silver-bullet/1.0.0/hooks/removed-long-ago.sh"))
        self.assertFalse(self.owned('node "$HOME/silver-bullet/1.0.0/hooks/lint.js"'))
        self.assertTrue(issubclass(m.ConfigError, ValueError))

    def test_foreign_commands(self):
        for command in (
            'node "$HOME/.claude/hooks/my-hook.js"',
            '"${CLAUDE_PROJECT_DIR}/.claude/hooks/lint.sh"',
            "bash ~/.claude/hooks/gsd-statusline.sh",
            "/usr/bin/true",
            "/hooks/completion-audit.sh",
            "/x/hooks/",
            "/x/hooks/sub/completion-audit.sh",
            "/x/silver-bullet/repo/hooks/my-own.sh",
            "${CLAUDE_PLUGIN_ROOT}/hooks/other-plugin.sh",
            "echo silver-bullet/x/hooks/completion-audit.sh is great",
            "bash -c '/h/.claude/plugins/cache/alo-labs/silver-bullet/1/hooks/x.sh'",
        ):
            self.assertFalse(self.owned(command, roots=("/opt/sb",)), command)


class RemoveHooksTest(unittest.TestCase):
    def test_removes_selected_entries_and_keeps_every_other_shape(self):
        sb = {"command": "sb"}
        events = {
            "Pre": [{"matcher": "Bash", "hooks": [{"command": "mine"}, sb]}, "foreign", {"hooks": "str"}],
            "Only": [{"hooks": [sb]}],
            "Mixed": [{"hooks": [sb]}, {"hooks": [{"command": "keep"}]}],
            "Empty": [],
            "Text": "x",
            "Odd": [{"hooks": ["str", None, sb]}],
        }
        removed = m.remove_hooks(events, lambda hook: hook.get("command") == "sb")
        self.assertEqual(removed, 4)
        self.assertEqual(events, {
            "Pre": [{"matcher": "Bash", "hooks": [{"command": "mine"}]}, "foreign", {"hooks": "str"}],
            "Mixed": [{"hooks": [{"command": "keep"}]}],
            "Empty": [],
            "Text": "x",
            "Odd": [{"hooks": ["str", None]}],
        })
        self.assertEqual(m.remove_hooks(events, lambda hook: False), 0)


class TomlHelpersTest(unittest.TestCase):
    def test_parser_lookup_and_fallbacks(self):
        self.assertIs(m.toml_parser(), tomllib.loads)
        real = m.importlib.import_module

        def only_vendored(name):
            if name in ("tomllib", "tomli"):
                raise ImportError(name)
            return real(name)

        with mock.patch.object(m.importlib, "import_module", side_effect=only_vendored):
            self.assertIsNotNone(m.toml_parser())
        with mock.patch.object(m.importlib, "import_module", side_effect=ImportError("none")):
            self.assertIsNone(m.toml_parser())
            m.check_toml("not = = toml", "f")  # nothing to validate with: accepted

    def test_check_toml(self):
        m.check_toml("a = 1\n", "f")
        with self.assertRaisesRegex(m.ConfigError, "f: not valid TOML"):
            m.check_toml("[a]\n[a]\n", "f")

    def test_strings_and_keys(self):
        self.assertEqual(m.toml_string('a"b\\c\x01\x7fé'), '"a\\"b\\\\c\\u0001\\u007fé"')
        self.assertEqual(m.format_key(("plugins", "sb@x", "a_b-1")), 'plugins."sb@x".a_b-1')


class LexerTest(unittest.TestCase):
    def doc(self, text):
        return m.TomlDocument(text, "cfg")

    def kinds(self, text):
        return [(st.kind, st.path) for st in self.doc(text).statements]

    def test_statement_kinds(self):
        text = (
            "  \n# c\n\r\na.'b'.\"c\" = 1\n[ t . \"q\" ] # h\nk = 'v'\n[[arr]]\n"
            'x = """\n[no]\n""" # c\ny = \'\'\'\n[no]\n\'\'\'\nz = [\n[1], # c\n{ a = "}" },\n]\n'
            "w = { a.b = 1, c = [1, 2], }\nlast = 2026-01-02 03:04:05Z"
        )
        self.assertEqual(self.kinds(text), [
            ("trivia", ()), ("trivia", ()), ("trivia", ()),
            ("keyval", ("a", "b", "c")),
            ("table", ("t", "q")), ("keyval", ("t", "q", "k")),
            ("array-table", ("arr",)),
            ("keyval", ("arr", "x")), ("keyval", ("arr", "y")), ("keyval", ("arr", "z")),
            ("keyval", ("arr", "w")), ("keyval", ("arr", "last")),
        ])
        self.assertEqual(self.kinds("   "), [("trivia", ())])

    def test_value_spans(self):
        doc = self.doc('a = "x"  # c\nb = 1.5\n')
        self.assertEqual([doc.text[slice(*st.value)] for st in doc.statements], ['"x"', "1.5"])

    def test_escapes_in_keys(self):
        doc = self.doc('"\\t\\u00e9\\U0001F600\\x41\\e\\"" = 1\n')
        self.assertEqual(doc.statements[0].path, ("\t\u00e9\U0001F600A\x1b\"",))

    def test_multiline_closing_quotes_and_escapes(self):
        doc = self.doc('a = """x\\""" y"""""\nb = \'\'\'z\'\'\'\'\'\nc = 1\n')
        self.assertEqual([st.path for st in doc.statements], [("a",), ("b",), ("c",)])

    def test_errors(self):
        for text, message in (
            ('a = 1\nb = "v" x\n', "line 2: unexpected 'x'"),
            ("a = 1\rb = 2\n", r"unexpected '\\r'"),
            ('a = "x\n', "unterminated string"),
            ('a = "x', "unterminated string"),
            ('a = "\\q"\n', "invalid escape"),
            ('a = "\\u12"\n', "invalid escape"),
            ('a = "\\u12zz"\n', "invalid escape"),
            ('a = "\\', "invalid escape"),
            ("a = 'x\n'\n", "unterminated string"),
            ("a = 'x", "unterminated string"),
            ('a = """x\n', "unterminated multi-line string"),
            ("a = '''x\n", "unterminated multi-line string"),
            ("= 1\n", "expected a key"),
            ("a.\n", "expected a key"),
            ("a 1\n", "expected '='"),
            ("a =\n", "expected a value"),
            ("a = [  # open", "expected a value"),
            ('a = ["x" "y"]\n', "expected ',' or ']'"),
            ("a = { b }\n", "expected '=' in an inline table"),
            ("[a\n", "expected ']'"),
            ("[[a]\n", "expected ']]'"),
        ):
            with self.assertRaisesRegex(m.ConfigError, message, msg=text):
                self.doc(text)


class DocumentEditTest(unittest.TestCase):
    SB = ("plugins", "silver-bullet@alo-labs-codex")

    def doc(self, text):
        return m.TomlDocument(text, "cfg")

    def test_remove_tables_keys_and_keeps_neighbours(self):
        text = (
            "top = 1\n[plugins.\"silver-bullet@alo-labs-codex\"] # sb\n# inside\nenabled = true\n\n\n"
            "# about other\n[plugins.\"other@m\"]\nenabled = true\n[plugins.\"silver-bullet@alo-labs-codex\".sub]\n"
            "[plugins]\n\"silver-bullet@alo-labs-codex\".x = 1\nkeep = 2\n[[plugins.\"silver-bullet@alo-labs-codex\".arr]]\n"
        )
        doc = self.doc(text)
        self.assertEqual(doc.remove(lambda p: m._within(p, self.SB)), 4)
        self.assertEqual(doc.text, 'top = 1\n# about other\n[plugins."other@m"]\nenabled = true\n[plugins]\nkeep = 2\n')
        self.assertEqual(doc.remove(lambda p: False), 0)

    def test_remove_on_crlf_and_last_line_without_newline(self):
        doc = self.doc('a = 1\r\n[x]\r\nb = 2')
        doc.remove(lambda p: m._within(p, ("x",)))
        self.assertEqual(doc.text, "a = 1\r\n")
        self.assertEqual(doc.newline, "\r\n")
        self.assertEqual(self.doc("").newline, "\n")

    def test_set_value_edits_existing_value_in_place(self):
        doc = self.doc('[plugins."silver-bullet@alo-labs-codex"]\nenabled = false # keep comment\n')
        self.assertTrue(doc.set_value(self.SB, "enabled", "true"))
        self.assertEqual(doc.text, '[plugins."silver-bullet@alo-labs-codex"]\nenabled = true # keep comment\n')
        self.assertFalse(doc.set_value(self.SB, "enabled", "true"))
        dotted = self.doc('plugins."silver-bullet@alo-labs-codex".enabled = false\n')
        dotted.set_value(self.SB, "enabled", "true")
        self.assertEqual(dotted.text, 'plugins."silver-bullet@alo-labs-codex".enabled = true\n')

    def test_set_value_inserts_after_header_or_appends_table(self):
        doc = self.doc("[features]\nother = 1\n")
        doc.set_value(("features",), "plugin_hooks", "true")
        self.assertEqual(doc.text, "[features]\nplugin_hooks = true\nother = 1\n")
        bare = self.doc("[features]")
        bare.set_value(("features",), "plugin_hooks", "true")
        self.assertEqual(bare.text, "[features]\nplugin_hooks = true\n")
        sub = self.doc("[features]\nx.y = 1\n")
        sub.set_value(("features",), "plugin_hooks", "true")
        self.assertEqual(tomllib.loads(sub.text)["features"], {"plugin_hooks": True, "x": {"y": 1}})
        empty = self.doc("")
        empty.set_value(self.SB, "enabled", "true")
        self.assertEqual(empty.text, '[plugins."silver-bullet@alo-labs-codex"]\nenabled = true\n')
        tail = self.doc("a = 1")
        tail.set_value(("features",), "plugin_hooks", "true")
        self.assertEqual(tail.text, "a = 1\n\n[features]\nplugin_hooks = true\n")
        spaced = self.doc("a = 1\n\n")
        spaced.set_value(("features",), "plugin_hooks", "true")
        self.assertEqual(spaced.text, "a = 1\n\n[features]\nplugin_hooks = true\n")

    def test_set_value_refuses_conflicts(self):
        for text, message in (
            ("[a]\nk = 1\n[a]\n", "more than once"),
            ("a.k = 1\na.k = 2\n", "more than once"),
            ("a = { x = 1 }\n", "already holds a value"),
            ("a.x = 1\n", "defined with dotted keys"),
            ("[[a]]\n", "array of tables"),
        ):
            with self.assertRaisesRegex(m.ConfigError, message, msg=text):
                self.doc(text).set_value(("a",), "k", "true")

    def test_append_tables(self):
        doc = self.doc("[hooks.state]\n")
        self.assertFalse(doc.append_tables([]))
        key = ("hooks", "state", "silver-bullet@alo-labs-codex:hooks/hooks.json:stop:0:0")
        self.assertTrue(doc.append_tables([(key, [("trusted_hash", m.toml_string("sha256:1"))]),
                                           (("t",), [])]))
        self.assertEqual(tomllib.loads(doc.text)["hooks"]["state"][key[2]], {"trusted_hash": "sha256:1"})
        with self.assertRaisesRegex(m.ConfigError, "already exists"):
            doc.append_tables([(("t",), [])])
        with self.assertRaisesRegex(m.ConfigError, "already holds a value"):
            self.doc("[hooks]\nstate = {}\n").append_tables([(key, [])])
        crlf = self.doc("a = 1\r\n")
        crlf.append_tables([(("b",), [("c", "2")])])
        self.assertEqual(crlf.text, "a = 1\r\n\r\n[b]\r\nc = 2\r\n")


class ReadWriteTomlTest(Tmp):
    def test_read_toml(self):
        path = self.tmp / "config.toml"
        self.assertEqual(m.read_toml(path).text, "")
        path.write_bytes(b"\xff")
        with self.assertRaisesRegex(m.ConfigError, "not UTF-8"):
            m.read_toml(path)
        path.write_text("[a]\n[a]\n")
        with self.assertRaisesRegex(m.ConfigError, "not valid TOML"):
            m.read_toml(path, "label")
        path.write_text("a = 1\n")
        self.assertEqual(m.read_toml(path).statements[0].path, ("a",))

    def test_write_toml_validates(self):
        path = self.tmp / "config.toml"
        doc = m.TomlDocument("a = 1\n", "cfg")
        self.assertTrue(m.write_toml(path, doc))
        self.assertFalse(m.write_toml(path, doc))
        doc.text = "[a]\n[a]\n"
        with self.assertRaises(m.ConfigError):
            m.write_toml(path, doc)
        self.assertEqual(path.read_text(), "a = 1\n")


if __name__ == "__main__":
    unittest.main()
