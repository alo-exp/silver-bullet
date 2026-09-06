#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
sync_silver_bullet_native_codex_skill_mirror() {
  local package_root="${CODEX_HOME_ROOT}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
  local package_skills_root="${package_root}/skill-source"
  local native_skills_root="${CODEX_HOME_ROOT}/.codex/skills"

  if [[ ! -d "$package_skills_root" && -d "${package_root}/skills" ]]; then
    # Legacy pre-0.37.15 packages used top-level skills/. Keep upgrades from
    # failing before the refreshed package is in place, but current packages
    # must use skill-source/ so Codex does not expose plugin-prefixed skills.
    package_skills_root="${package_root}/skills"
  fi
  [[ -d "$package_skills_root" ]] || return 0

  python3 - "$package_root" "$package_skills_root" "$native_skills_root" <<'PY'
import pathlib
import re
import shutil
import sys

package_root = pathlib.Path(sys.argv[1]).resolve()
package_skills_root = pathlib.Path(sys.argv[2]).resolve()
native_skills_root = pathlib.Path(sys.argv[3]).expanduser()
marker_name = ".silver-bullet-managed"


def read_frontmatter(skill_md: pathlib.Path) -> dict[str, str]:
    try:
        lines = skill_md.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = skill_md.read_text(errors="replace").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}

    frontmatter: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if not match:
            continue
        key, value = match.groups()
        frontmatter[key] = value.strip().strip('"').strip("'")
    return frontmatter


def is_user_invocable(frontmatter: dict[str, str]) -> bool:
    return frontmatter.get("user-invocable", "").lower() != "false"


def is_silver_bullet_helper_picker_skill(dirname: str, skill_name: str) -> bool:
    helper_picker_skills = {
        "devops-quality-gates",
        "sb-review-fix-ladder",
        "security",
        "verify-tests",
    }
    return dirname in helper_picker_skills or skill_name in helper_picker_skills


def is_silver_bullet_native_mirror_route(dirname: str, skill_name: str) -> bool:
  return (
      dirname in {"sb"}
      or dirname in {"sb-feature", "sb:feature"}
      or skill_name in {"sb", "sb:feature"}
  )


def mirror_dirname(skill_dir_name: str, skill_name: str) -> str:
    """Codex TUI derives slash routes from ~/.codex/skills/<dirname>."""
    if is_silver_bullet_helper_picker_skill(skill_dir_name, skill_name):
        return skill_dir_name
    if skill_name == "sb":
        return "sb"
    if skill_name.startswith("sb:"):
        return skill_name
    if skill_name.startswith("sb-"):
        return "sb:" + skill_name.removeprefix("sb-")
    return skill_dir_name


def is_silver_bullet_picker_skill(dirname: str, skill_name: str) -> bool:
    return (
        dirname in {"sb"}
        or dirname.startswith("sb-")
        or dirname.startswith("sb:")
        or skill_name in {"sb"}
        or skill_name.startswith("sb:")
        or is_silver_bullet_helper_picker_skill(dirname, skill_name)
    )


desired: dict[str, pathlib.Path] = {}
for skill_dir in sorted(package_skills_root.iterdir(), key=lambda path: path.name):
    skill_md = skill_dir / "SILVER_SOURCE"
    if not skill_md.is_file():
        skill_md = skill_dir / "SILVER_SOURCE.md"
    if not skill_md.is_file():
        skill_md = skill_dir / "SILVER_SKILL.md"
    if not skill_md.is_file():
        skill_md = skill_dir / "SKILL.md"
    if not skill_dir.is_dir() or not skill_md.is_file():
        continue
    frontmatter = read_frontmatter(skill_md)
    skill_name = frontmatter.get("name", "")
    if not skill_name:
        continue
    if not is_user_invocable(frontmatter) and not is_silver_bullet_helper_picker_skill(skill_dir.name, skill_name) and not is_silver_bullet_native_mirror_route(skill_dir.name, skill_name):
        continue
    if not is_silver_bullet_picker_skill(skill_dir.name, skill_name):
        continue
    desired[mirror_dirname(skill_dir.name, skill_name)] = skill_dir

native_skills_root.mkdir(parents=True, exist_ok=True)

for target in sorted(native_skills_root.iterdir(), key=lambda path: path.name):
    if not target.is_dir():
        continue
    marker = target / marker_name
    if marker.exists() and target.name not in desired:
        shutil.rmtree(target)

for dirname, source in desired.items():
    target = native_skills_root / dirname
    if target.is_symlink() or target.is_file():
        target.unlink()
    elif target.exists():
        shutil.rmtree(target)
    shutil.copytree(source, target)
    internal_skill = target / "SILVER_SOURCE"
    if not internal_skill.is_file():
        internal_skill = target / "SILVER_SOURCE.md"
    if not internal_skill.is_file():
        internal_skill = target / "SILVER_SKILL.md"
    picker_skill = target / "SKILL.md"
    if internal_skill.is_file():
        if picker_skill.exists():
            picker_skill.unlink()
        internal_skill.rename(picker_skill)
    (target / marker_name).write_text(
        f"source=Silver Bullet\npackage={package_root}\nskill={dirname}\n",
        encoding="utf-8",
    )
PY
}


sync_silver_bullet_skill_cache() {
  local marketplace_root
  local current_package_dir=""

  marketplace_root="$(codex_marketplace_root)"
  [[ -d "$marketplace_root" ]] || return 0

  current_package_dir="${marketplace_root}/plugins/silver-bullet"
  [[ -d "${current_package_dir}/skill-source" ]] || return 0

  python3 - "${current_package_dir}/skill-source" <<'PY'
import pathlib
import re
import sys

skills_root = pathlib.Path(sys.argv[1])
name_re = re.compile(r'^(name:\s*)sb-([A-Za-z0-9_-]+)\s*$', re.MULTILINE)

for pattern in ("SILVER_SOURCE", "SILVER_SOURCE.md", "SILVER_SKILL.md", "SKILL.md"):
  for skill_md in skills_root.rglob(pattern):
    text = skill_md.read_text()
    updated = name_re.sub(lambda m: f"{m.group(1)}sb:{m.group(2)}", text, count=1)
    updated = re.sub(r'^(name:\s*)silver\s*$', r'\1sb', updated, count=1, flags=re.MULTILINE)
    if updated != text:
        skill_md.write_text(updated)
PY
}
