import unittest

from sbtest import REPO_ROOT, load_module


class LoadModuleTest(unittest.TestCase):
    def test_loads_hyphenated_script_by_path(self):
        mod = load_module("tests/python/sbtest.py", "sbtest_self")
        self.assertEqual(mod.REPO_ROOT, REPO_ROOT)

    def test_missing_file_raises(self):
        with self.assertRaises((ImportError, FileNotFoundError)):
            load_module("tests/python/does-not-exist.py")


if __name__ == "__main__":
    unittest.main()
