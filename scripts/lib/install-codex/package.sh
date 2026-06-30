#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
materialize_silver_bullet_package() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "$package_root" ]] || return 0

  # Codex's cache materialization can drop symlink-backed package entries.
  # Replace SB's symlinked top-level package surface with real files/dirs so
  # hooks/hooks.json, skill-source/, templates/, and the rest survive install-time
  # copying into the versioned cache.
  python3 - "$package_root" <<'PY'
import pathlib
import shutil
import sys

package_root = pathlib.Path(sys.argv[1])

for entry in sorted(package_root.iterdir(), key=lambda p: p.name):
    if not entry.is_symlink():
        continue

    target = entry.resolve()
    materialized = entry.with_name(f".materialized-{entry.name}")

    if materialized.exists() or materialized.is_symlink():
        if materialized.is_dir() and not materialized.is_symlink():
            shutil.rmtree(materialized)
        else:
            materialized.unlink()

    if target.is_dir():
        shutil.copytree(target, materialized, symlinks=False)
    else:
        shutil.copy2(target, materialized)

    entry.unlink()
    materialized.rename(entry)
PY
}


sync_materialized_package_surface() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "$package_root" ]] || return 0

  local dir
  rm -rf -- "${package_root}/skills"

  for dir in hooks templates docs commands scripts; do
    if [[ -d "${marketplace_root}/${dir}" ]]; then
      mkdir -p "${package_root}/${dir}"
      rsync -a --delete "${marketplace_root}/${dir}/" "${package_root}/${dir}/"
    fi
  done

  if [[ ! -d "${package_root}/skill-source" && -d "${marketplace_root}/skills" ]]; then
    mkdir -p "${package_root}/skill-source"
    rsync -a --delete "${marketplace_root}/skills/" "${package_root}/skill-source/"
    find "${package_root}/skill-source" -name SKILL.md -type f -exec sh -c '
      for path do
        mv "$path" "$(dirname "$path")/SILVER_SOURCE"
      done
    ' sh {} +
  fi

  local file
  for file in \
    AGENTS.md \
    CHANGELOG.md \
    CODE_OF_CONDUCT.md \
    CONTRIBUTING.md \
    LICENSE \
    README.md \
    SECURITY.md \
    SENTINEL-audit-silver-bullet-v0.15.1.md \
    SENTINEL-audit-silver-init.md \
    .silver-bullet.json \
    silver-bullet.md; do
    if [[ -e "${marketplace_root}/${file}" ]]; then
      cp -p "${marketplace_root}/${file}" "${package_root}/${file}"
    fi
  done
}


fail_missing_silver_bullet_skill_surface() {
  local label="$1"
  local path="$2"

  printf 'ERROR: Silver Bullet %s is missing internal skill-source/ at %s\n' "$label" "$path" >&2
  printf 'Rebuild or reinstall the Silver Bullet Codex package before continuing.\n' >&2
  exit 1
}


silver_bullet_internal_skill_file() {
  local skill_dir="$1"
  if [[ -f "${skill_dir}/SILVER_SOURCE" ]]; then
    printf '%s\n' "${skill_dir}/SILVER_SOURCE"
    return 0
  fi
  if [[ -f "${skill_dir}/SILVER_SOURCE.md" ]]; then
    printf '%s\n' "${skill_dir}/SILVER_SOURCE.md"
    return 0
  fi
  if [[ -f "${skill_dir}/SILVER_SKILL.md" ]]; then
    printf '%s\n' "${skill_dir}/SILVER_SKILL.md"
    return 0
  fi
  if [[ -f "${skill_dir}/SKILL.md" ]]; then
    printf '%s\n' "${skill_dir}/SKILL.md"
    return 0
  fi
  return 1
}


validate_silver_bullet_skill_surface() {
  local label="$1"
  local package_root="$2"
  local skills_root="${package_root}/skill-source"
  local required_skill

  [[ -d "$package_root" ]] || return 0

  if [[ -d "${package_root}/skills" ]]; then
    printf 'ERROR: Silver Bullet %s exposes top-level skills/ at %s\n' "$label" "${package_root}/skills" >&2
    printf 'Codex surfaces top-level plugin skills with the /Silver Bullet prefix; SB skills must be mirrored natively from skill-source/ instead.\n' >&2
    exit 1
  fi

  if [[ ! -d "$skills_root" ]]; then
    fail_missing_silver_bullet_skill_surface "$label" "$skills_root"
  fi

  for required_skill in silver-init silver silver-feature; do
    if ! silver_bullet_internal_skill_file "${skills_root}/${required_skill}" >/dev/null; then
      printf 'ERROR: Silver Bullet %s is missing required skill surface %s at %s\n' \
        "$label" \
        "$required_skill" \
        "${skills_root}/${required_skill}/SILVER_SOURCE" >&2
      printf 'Rebuild or reinstall the Silver Bullet Codex package before continuing.\n' >&2
      exit 1
    fi
  done
}


