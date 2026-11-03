"""Print the shell script file a command runs (bash x.sh, ./x.sh, source x), if it exists.

Usage: invoked_script_path.py BASE_DIR COMMAND | invoked_script_path.py BASE_DIR [-] < command.txt
The first such script in execution order is printed, resolved against BASE_DIR and any
literal `cd` before it.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shell_analysis  # noqa: E402

result = shell_analysis.analyze_command(shell_analysis.read_input(sys.argv, 2), sys.argv[1])
if result["invoked_script"]:
    print(result["invoked_script"])
