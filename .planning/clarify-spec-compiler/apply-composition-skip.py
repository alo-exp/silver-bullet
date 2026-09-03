#!/usr/bin/env python3
"""Apply composition-skip fixes. Idempotent string replacements."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(rel: str, old: str, new: str) -> None:
    path = ROOT / rel
    text = path.read_text()
    if new in text and old not in text:
        print(f"SKIP already: {rel}")
        return
    if old not in text:
        raise SystemExit(f"MISSING in {rel}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1))
    print(f"OK {rel}")


def main() -> None:
    replace_once(
        "hooks/lib/orchestrator-state.sh",
        '        queue="${queue//silver-context/silver-spec,silver-context}"',
        '        queue="${queue//silver-context/silver-clarify,silver-spec,silver-context}"',
    )
    replace_once(
        "hooks/lib/orchestrator-state.sh",
        "# Resolve composer queue with runtime conditionals (e.g. silver-spec when SPEC.md absent).",
        "# Resolve composer queue with runtime conditionals (silver-clarify --spec then silver-spec when SPEC.md absent).",
    )
    replace_once(
        "hooks/lib/orchestrator-state.sh",
        "  printf '%s' 'silver-spec,silver-feature,silver-ship,silver-release'",
        "  printf '%s' 'silver-clarify,silver-spec,silver-feature,silver-ship,silver-release'",
    )

    replace_once(
        "hooks/workflow-chain-guard.sh",
        """# Conditional silver-spec when SPEC.md is absent (greenfield feature/ui work).
if [[ "$composer_slug" == "silver-feature" || "$composer_slug" == "silver-ui" ]]; then
  if [[ ! -f "$repo_root/.planning/SPEC.md" ]]; then
    required_markers+=("silver-spec")
  fi
fi""",
        """# Conditional interview + compiler when SPEC.md is absent (greenfield feature/ui).
if [[ "$composer_slug" == "silver-feature" || "$composer_slug" == "silver-ui" ]]; then
  if [[ ! -f "$repo_root/.planning/SPEC.md" ]]; then
    required_markers+=("silver-clarify")
    required_markers+=("silver-spec")
  fi
fi""",
    )

    replace_once(
        "scripts/generate-apo-catalog.py",
        """        n("AF-BOOTSTRAP", optional=True), n("AF-ORIENT", optional=True),
        n("AF-CLARIFY", optional=True), n("AF-DECIDE", optional=True),
        n("AF-SPECIFY", optional=True), n("AF-QUALITY-GATE", label="pre-plan"),""",
        """        n("AF-BOOTSTRAP", optional=True), n("AF-ORIENT", optional=True),
        n("AF-CLARIFY", optional=True, condition="SPEC.md absent (required as --spec before AF-SPECIFY)"),
        n("AF-DECIDE", optional=True),
        n("AF-SPECIFY", optional=True, condition="SPEC.md absent (required compiler after AF-CLARIFY --spec)"),
        n("AF-QUALITY-GATE", label="pre-plan"),""",
    )

    replace_once(
        "tests/hooks/test-orchestrator-queue-order.sh",
        """if printf '%s' "$feature_no_spec" | grep -q 'FLOW-QUALITY-GATE,silver-spec,silver-context'; then
  echo "PASS: silver-feature queue inserts silver-spec when SPEC.md absent"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-feature missing conditional silver-spec (got: $feature_no_spec)"
  FAIL=$((FAIL + 1))
fi""",
        """if printf '%s' "$feature_no_spec" | grep -q 'FLOW-QUALITY-GATE,silver-clarify,silver-spec,silver-context'; then
  echo "PASS: silver-feature queue inserts silver-clarify then silver-spec when SPEC.md absent"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-feature missing clarify-then-spec when SPEC.md absent (got: $feature_no_spec)"
  FAIL=$((FAIL + 1))
fi""",
    )
    replace_once(
        "tests/hooks/test-orchestrator-queue-order.sh",
        """if printf '%s' "$ui_no_spec" | grep -q 'FLOW-QUALITY-GATE,silver-spec,silver-context'; then
  echo "PASS: silver-ui queue inserts silver-spec when SPEC.md absent"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-ui missing conditional silver-spec (got: $ui_no_spec)"
  FAIL=$((FAIL + 1))
fi""",
        """if printf '%s' "$ui_no_spec" | grep -q 'FLOW-QUALITY-GATE,silver-clarify,silver-spec,silver-context'; then
  echo "PASS: silver-ui queue inserts silver-clarify then silver-spec when SPEC.md absent"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-ui missing clarify-then-spec when SPEC.md absent (got: $ui_no_spec)"
  FAIL=$((FAIL + 1))
fi""",
    )

    replace_once(
        "tests/hooks/test-workflow-chain-guard.sh",
        """# Feature without SPEC.md requires silver-spec marker.
setup
touch "$TMPDIR_TEST/src/app.js"
rm -f "$TMPDIR_TEST/.planning/SPEC.md"
start_workflow "/silver:feature" "feature no spec" "plan,execute"
write_state_markers silver-quality-gates silver-context silver-plan silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:feature without SPEC.md blocks until silver-spec recorded" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:feature without SPEC.md passes after silver-spec marker" "$out"
teardown""",
        """# Feature without SPEC.md requires silver-clarify then silver-spec markers.
setup
touch "$TMPDIR_TEST/src/app.js"
rm -f "$TMPDIR_TEST/.planning/SPEC.md"
start_workflow "/silver:feature" "feature no spec" "plan,execute"
write_state_markers silver-quality-gates silver-context silver-plan silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:feature without SPEC.md blocks until clarify+spec recorded" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:feature without SPEC.md still blocks with spec but no clarify" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-clarify silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:feature without SPEC.md passes after clarify+spec markers" "$out"
teardown""",
    )
    replace_once(
        "tests/hooks/test-workflow-chain-guard.sh",
        """# UI without SPEC.md requires silver-spec marker (same conditional as feature).
setup
touch "$TMPDIR_TEST/src/app.js"
rm -f "$TMPDIR_TEST/.planning/SPEC.md"
start_workflow "/silver:ui" "ui no spec" "plan,design,execute"
write_state_markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:ui without SPEC.md blocks until silver-spec recorded" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:ui without SPEC.md passes after silver-spec marker" "$out"
teardown""",
        """# UI without SPEC.md requires silver-clarify then silver-spec (same as feature).
setup
touch "$TMPDIR_TEST/src/app.js"
rm -f "$TMPDIR_TEST/.planning/SPEC.md"
start_workflow "/silver:ui" "ui no spec" "plan,design,execute"
write_state_markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:ui without SPEC.md blocks until clarify+spec recorded" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:ui without SPEC.md still blocks with spec but no clarify" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-clarify silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:ui without SPEC.md passes after clarify+spec markers" "$out"
teardown""",
    )

    print("hook/test/catalog source replacements done")


if __name__ == "__main__":
    main()
