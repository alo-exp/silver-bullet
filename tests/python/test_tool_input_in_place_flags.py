"""In-place edit detection for sed/perl in the tool-input helpers.

candidate_write_paths.py reports the file operand of `sed`/`perl` in-place edits as a
write target; command_looks_read_only.py must refuse to call such a `sed` read-only.
Both must recognise bundled short flags (`sed -Ei`, `perl -pi`) and the long
`--in-place[=SUFFIX]` form, while option letters that take an attached argument
(sed -e/-f/-l, perl -e/-E/-M/-m/-I/-x/-C/-d/-D/-F) end the flag bundle, so an `i`
inside that argument is not an in-place flag.
"""

import tempfile
import unittest
from pathlib import Path

from tool_input_support import run_tool_input_script


class InPlaceFlagTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.base = Path(self._tmp.name).resolve()

    def tearDown(self):
        self._tmp.cleanup()

    def writes(self, command):
        res = run_tool_input_script("candidate_write_paths.py", str(self.base), command)
        self.assertEqual(res.code, 0)
        return res.lines

    def read_only(self, command):
        return run_tool_input_script("command_looks_read_only.py", command).code == 0

    # --- in-place forms are writes / not read-only -------------------------
    def test_bundled_and_long_in_place_flags_write_their_operand(self):
        target = [str(self.base / "f")]
        for cmd in (
            "sed -i s/a/b/ f",
            "sed -i.bak s/a/b/ f",
            "sed -Ei s/a/b/ f",
            "sed -ni s/a/b/p f",
            "sed -n -i s/a/b/p f",
            "sed --in-place s/a/b/ f",
            "sed --in-place=.bak s/a/b/ f",
            "perl -pi -e s/a/b/ f",
            "perl -i -pe s/a/b/ f",
            "perl -0777pi -e s/a/b/ f",
            "perl -l0pi -e s/a/b/ f",
        ):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.writes(cmd), target)

    def test_sed_in_place_is_never_read_only(self):
        for cmd in (
            "sed -i s/a/b/ f",
            "sed -Ei s/a/b/ f",
            "sed -ni s/a/b/p f",
            "sed --in-place s/a/b/ f",
            "sed --in-place=.bak s/a/b/ f",
        ):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.read_only(cmd))

    # --- attached option arguments are not flag bundles --------------------
    def test_i_inside_an_attached_option_argument_is_not_in_place(self):
        for cmd in (
            "sed -es/i/x/ f",
            "sed -fi.sed f",
            "sed -l5 -n p f",
            "sed -E --debug s/i/x/ f",
            "perl -Mlib=x -ne print f",
            "perl -Ilib/in -ne print f",
            "perl -mi18n -ne print f",
            "perl -ei f",
            "perl -Ei f",
            "perl -xinit f",
            "perl -Ci f",
            "perl -dit f",
            "perl -Din f",
            "perl -Fi -ane print f",
        ):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.writes(cmd), [])

    def test_sed_with_attached_arguments_stays_read_only(self):
        for cmd in ("sed -es/i/x/ f", "sed -fi.sed f", "sed -n -es/i/x/p f"):
            with self.subTest(cmd=cmd):
                self.assertTrue(self.read_only(cmd))

    def test_in_place_flag_after_an_attached_argument_is_unreachable_in_bundle(self):
        # `-es/i/x/` consumes the rest; a later separate -i still counts.
        self.assertEqual(self.writes("sed -es/a/b/ -i f"), [str(self.base / "f")])
        self.assertFalse(self.read_only("sed -es/a/b/ -i f"))


if __name__ == "__main__":
    unittest.main()
