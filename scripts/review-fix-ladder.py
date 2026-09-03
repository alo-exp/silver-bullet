#!/usr/bin/env python3
"""Resolve host-aware model/reasoning rungs for silver:review-fix-ladder.

Public Policy C / failure-management flags (also listed on --help):
  --write-policy-c --assert-policy-c --assert-rfl-advance --assert-consecutive-clean --record-rung-review-outcome
  --issue-ledger --write-review-brief
  --write-review-brief is the only legal review brief (hand-written one-ID briefs are non-compliant).
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_LIB = _HERE / "lib"
_IMPL = _HERE / "_review_fix_ladder_impl.py"
for _path in (_LIB, _HERE):
    _text = str(_path)
    if _text not in sys.path:
        sys.path.insert(0, _text)

import rfl_launcher_policy as _rfl_policy  # noqa: E402

_spec = importlib.util.spec_from_file_location("_review_fix_ladder_impl", _IMPL)
if _spec is None or _spec.loader is None:
    raise ImportError(f"cannot load review-fix-ladder impl from {_IMPL}")
_impl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_impl)

# Re-export the impl public API so `import`/`runpy` callers keep working.
for _name in dir(_impl):
    if _name.startswith("_"):
        continue
    if _name in {"decide_launch", "main"}:
        continue
    globals()[_name] = getattr(_impl, _name)

_ORIG_DECIDE_LAUNCH = _impl.decide_launch


def decide_launch(
    model: str,
    reasoning: str,
    *,
    prefix: str = "sb",
    subscription_exit: int | None = None,
    subscription_output: str = "",
):
    payload = _ORIG_DECIDE_LAUNCH(
        model,
        reasoning,
        prefix=prefix,
        subscription_exit=subscription_exit,
        subscription_output=subscription_output,
    )
    return _rfl_policy.attach_default_host_route(payload, model)


_impl.decide_launch = decide_launch  # type: ignore[method-assign]


def main() -> int:
    pre = argparse.ArgumentParser(add_help=False, allow_abbrev=False)
    pre.add_argument("--model")
    _rfl_policy.add_policy_arguments(pre)
    known, _rest = pre.parse_known_args()
    policy_exit = _rfl_policy.dispatch_policy_cli(known)
    if policy_exit is not None:
        return policy_exit
    return int(_impl.main())


if __name__ == "__main__":
    sys.exit(main())
