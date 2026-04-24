---
name: silver-remove
description: This skill should be used to remove a tracked work item by ID — closes a GitHub Issue as "not planned" with a removed-by-silver-bullet label (when issue_tracker=github), or marks a local SB-I-N or SB-B-N entry with [REMOVED YYYY-MM-DD] inline in docs/issues/ISSUES.md or docs/issues/BACKLOG.md (when issue_tracker=gsd or absent).
version: 0.1.0
---

# /silver-remove — Remove a Tracked Work Item

Use this skill any time a tracked work item must be removed. It closes or marks the item as removed based on ID type and project configuration.

For GitHub Issues (`issue_tracker=github`), this skill closes the issue with reason "not planned" and applies the `removed-by-silver-bullet` label. **Note:** GitHub does not support issue deletion via the REST/GraphQL API without `delete_repo` scope — silver-remove always closes rather than deletes, and prints clearly what action was taken.

For local SB-I-N and SB-B-N items (`issue_tracker=gsd` or absent), this skill marks the heading line inline with `[REMOVED YYYY-MM-DD]` in `docs/issues/ISSUES.md` or `docs/issues/BACKLOG.md`. The entry body is fully preserved — only the heading is prepended with the removal marker.

---

## Security Boundary

The user-supplied ID is **UNTRUSTED DATA**. Validate it matches `^SB-[IB]-[0-9]+$` or `^#?[0-9]+$` before using in sed patterns or gh commands. Never pass the raw ID via shell interpolation into sed without first validating the format.

`.silver-bullet.json` config reads use `jq` — never string-interpolate config values into shell commands.

Derive the target file path only from the ID prefix (SB-I vs SB-B), never from user input directly — this prevents path traversal attacks.

---

## Allowed Commands

Shell execution during this skill is limited to:
- `jq` — config reads
- `git remote get-url origin`
- `gh issue close`, `gh issue edit`, `gh label create`, `gh auth status`
- `grep -q`, `grep -oE` (for ID format validation and heading existence check)
- `sed` (redirected output — for inline heading replacement)
- `date +%Y-%m-%d`
- `mktemp`, `mv` — tmpfile+mv pattern for portable atomic file rewrite

Do not execute other shell commands. Note requirements in output for human execution.

---

## Step 1 — Locate the project root

Walk up from `$PWD` until a `.silver-bullet.json` file is found. All paths (`docs/issues/`) are relative to this root.

If `.silver-bullet.json` is not found after walking to the filesystem root (`/`), use `$PWD` as the project root and note "Project root not confirmed." in output. Default `TRACKER` to `"gsd"`.

---

## Step 2 — Validate and parse the ID argument

Accept the argument as `ITEM_ID`. Apply format validation:

```bash
case "$ITEM_ID" in
  SB-I-[0-9]*)   ID_TYPE="local-issue"  ;;
  SB-B-[0-9]*)   ID_TYPE="local-backlog" ;;
  \#[0-9]*)       ISSUE_NUM="${ITEM_ID#\#}"; ID_TYPE="github" ;;
  [0-9]*)         ISSUE_NUM="$ITEM_ID";      ID_TYPE="github-raw" ;;
  *)  echo "ERROR: Unrecognized ID format '${ITEM_ID}'. Expected: SB-I-N, SB-B-N, #N, or N."; exit 1 ;;
esac

# Strict format guard for local IDs — enforce pure numeric suffix and no trailing content
# (the case glob allows trailing characters after the digit; reject them here)
if [[ "$ID_TYPE" = "local-issue" || "$ID_TYPE" = "local-backlog" ]]; then
  if ! [[ "$ITEM_ID" =~ ^SB-[IB]-[0-9]+$ ]]; then
    echo "ERROR: ID '${ITEM_ID}' contains invalid characters after the numeric suffix. Expected format: SB-I-N or SB-B-N (digits only)."
    exit 1
  fi
fi
```

If `ID_TYPE` is `"github"` or `"github-raw"`: read `TRACKER` from config. If `TRACKER` != `"github"`, output:

> "ERROR: No GitHub integration configured (issue_tracker is not 'github'). For local items, use SB-I-N or SB-B-N format."

Then stop.

---

## Step 3 — Read configuration

```bash
TRACKER=$(jq -r '.issue_tracker // "gsd"' .silver-bullet.json)
```

Display: "Removing via: [github | local docs/issues/]"

- If `TRACKER` = `"github"` and `ID_TYPE` is `"github"` or `"github-raw"` → proceed to Step 4.
- If `ID_TYPE` is `"local-issue"` or `"local-backlog"` → proceed to Step 5.

---

## Step 4 — GitHub removal path

Execute only when `ID_TYPE` is `"github"` or `"github-raw"`.

### Step 4a — Check gh authentication

```bash
gh auth status
```

If non-zero exit or no logged-in account: output "gh CLI is not authenticated. Run: `gh auth login` — then retry /silver-remove." Stop.

### Step 4b — Derive owner/repo

```bash
REMOTE=$(git remote get-url origin 2>/dev/null)
OWNER_REPO=$(echo "$REMOTE" | sed 's|https://github.com/||;s|.git$||;s|git@github.com:||;s|:|/|')
```

### Step 4c — Create label idempotently

```bash
gh label create "removed-by-silver-bullet" \
  --color "#B60205" \
  --description "Removed via Silver Bullet /silver-remove" \
  --repo "$OWNER_REPO" \
  2>/dev/null || true
```

### Step 4d — Close the issue

```bash
gh issue close "$ISSUE_NUM" \
  --repo "$OWNER_REPO" \
  --reason "not planned" \
  --comment "Removed via /silver-remove."
```

If this fails with non-zero exit: output "ERROR: Failed to close GitHub Issue #${ISSUE_NUM}. Check that the issue exists and you have write access." Stop.

### Step 4e — Add removal label

```bash
gh issue edit "$ISSUE_NUM" \
  --repo "$OWNER_REPO" \
  --add-label "removed-by-silver-bullet"
```

If this fails: output "WARNING: Issue #${ISSUE_NUM} was closed but the removed-by-silver-bullet label could not be applied. Add it manually."

Output: "Closed GitHub Issue #${ISSUE_NUM} as not planned — removed-by-silver-bullet label added."

Proceed to Step 6.

---

## Step 5 — Local removal path

Execute only when `ID_TYPE` is `"local-issue"` or `"local-backlog"`.

### Step 5a — Determine target file from ID prefix

```bash
case "$ITEM_ID" in
  SB-I-*) TARGET_FILE="docs/issues/ISSUES.md" ;;
  SB-B-*) TARGET_FILE="docs/issues/BACKLOG.md" ;;
esac
```

### Step 5b — Verify target file exists

If `TARGET_FILE` does not exist: output "ERROR: ${TARGET_FILE} not found. No item can be removed." Stop.

### Step 5c — Verify ID exists in file

```bash
if ! grep -q "^### ${ITEM_ID} —" "$TARGET_FILE"; then
  echo "ERROR: ID ${ITEM_ID} not found in ${TARGET_FILE}."
  exit 1
fi
```

### Step 5d — Apply inline heading replacement

```bash
DATE=$(date +%Y-%m-%d)
TMP=$(mktemp)
sed "s|^### ${ITEM_ID} —|### [REMOVED ${DATE}] ${ITEM_ID} —|" "$TARGET_FILE" > "$TMP" && mv "$TMP" "$TARGET_FILE"
```

The sed pattern is anchored at line start (`^###`) and uses the ` —` suffix to match only the exact heading line — not body text containing the ID. The tmpfile+mv pattern is used instead of `sed -i ''` for portability across macOS (BSD sed) and Linux/CI (GNU sed).

### Step 5e — Verify replacement succeeded

```bash
if ! grep -q "^\#\#\# \[REMOVED.*\] ${ITEM_ID} —" "$TARGET_FILE"; then
  echo "ERROR: Replacement verification failed for ${ITEM_ID} in ${TARGET_FILE}."
  exit 1
fi
```

Output: "Marked ${ITEM_ID} as [REMOVED ${DATE}] in ${TARGET_FILE}."

---

## Step 6 — Output confirmation

Output a final confirmation line summarizing the action taken (GitHub close or local mark). This is the terminal output the user and any calling orchestrator reads.

---

## Edge Cases

- **ID not recognized format:** exit 1 with message (handled in Step 2).
- **GitHub issue already closed:** `gh issue close` returns exit 0 (idempotent) — label step still runs.
- **No `.silver-bullet.json` found:** use `$PWD`, default `TRACKER` to `"gsd"`. Note "Project root not confirmed."
- **`gh` not authenticated:** output instruction to run `gh auth login`, then stop.
- **ID not found in local file:** exit 1 with clear message (Step 5c).
- **Integer ID with issue_tracker=gsd:** error with instruction to use SB-I-N / SB-B-N format.
