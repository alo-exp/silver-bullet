"""Print a shell command without a leading env / NAME=value / rtk prefix.

Usage: shell_unwrap_rtk.py COMMAND | shell_unwrap_rtk.py [-] < command.txt
The rest of the command is printed verbatim; a command without such a prefix is printed
unchanged, and a command that is only the prefix prints nothing. A '#' inside a word is
not a comment (bash semantics), so nothing after it is lost.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shell_analysis  # noqa: E402

sys.stdout.write(shell_analysis.rtk_unwrap(shell_analysis.read_input(sys.argv, 1)))
