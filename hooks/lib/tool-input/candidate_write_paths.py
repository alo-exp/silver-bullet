"""Print the paths a shell command may write, one per line, sorted.

Usage: candidate_write_paths.py BASE_DIR COMMAND | candidate_write_paths.py BASE_DIR [-] < command.txt

Relative paths resolve against BASE_DIR and any literal `cd` before the write; $HOME,
$PWD, ~ and variables assigned literally earlier in the command are expanded. A target
that stays dynamic is printed only when it keeps a directory part (``$ROOT/src/a.py``);
the full list, with dynamic targets flagged, is in shell_analysis.py's ``writes``.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shell_analysis  # noqa: E402

for path in shell_analysis.analyze_command(shell_analysis.read_input(sys.argv, 2), sys.argv[1])["write_paths"]:
    print(path)
