#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation

# Derive the actions/cache inputs for the Python project at path_prefix.
#
# Environment:
#   INPUTS_PATH_PREFIX  project directory, resolved as every other step
#                       resolves it: relative to the working directory
#   GITHUB_WORKSPACE    workspace root
#   GITHUB_OUTPUT       step output file
#
# Outputs:
#   tox_path   the project's .tox directory, as an actions/cache path
#   deps_hash  SHA-256 over the project's dependency files; empty when
#              the project has none
#
# actions/cache reads `path` as @actions/glob patterns, so tox_path must
# match the project's .tox and nothing else:
# - canonical, and inside the workspace relative to it, so no '.' or
#   '..' segment trips @actions/glob's assertion and every spelling of
#   one directory shares a cache version (actions/cache versions an
#   entry by its literal path strings);
# - anchored with './', so a leading '!' or '#' stays literal;
# - escaped as @actions/glob's Pattern.globEscape() does ('\', '[', '?'
#   and '*'), so a directory named glob[1] cannot match glob1.
#
# The hash is computed here rather than with hashFiles(): that function
# also reads its arguments as glob patterns, and it skips every file
# outside GITHUB_WORKSPACE, which would leave a project there with a
# key that never changes.
#
# Usage: bash scripts/cache-paths.sh

set -euo pipefail

# cd -P leaves the physical path in PWD, so a symlink on either side
# cannot defeat the comparison below; reading PWD instead of $(pwd -P)
# also keeps a trailing newline that command substitution would strip,
# silently selecting a different directory. path_prefix is resolved
# first, while the working directory is still the caller's. CDPATH is
# cleared so cd prints nothing.
CDPATH='' cd -P -- "${INPUTS_PATH_PREFIX:-.}"
project=$PWD
CDPATH='' cd -P -- "$GITHUB_WORKSPACE"
workspace=$PWD

# A line break would split the pattern list and the output file
case "$project" in
  *$'\n'* | *$'\r'*)
    echo 'Error: path_prefix cannot contain line breaks ❌'
    exit 1 ;;
esac

case "$project" in
  "$workspace") tox_path='./.tox' ;;
  "$workspace"/*) tox_path="./${project#"$workspace"/}/.tox" ;;
  *) tox_path="$project/.tox" ;;
esac
tox_path=$(printf '%s' "$tox_path" | sed -e 's/\\/\\\\/g' \
  -e 's/\[/[[]/g' -e 's/?/[?]/g' -e 's/\*/[*]/g')

if command -v sha256sum > /dev/null 2>&1; then
  sha256() { sha256sum "$@"; }
else
  sha256() { shasum -a 256 "$@"; }
fi

# The files that decide what pip and tox install for this project. The C
# locale keeps the requirements*.txt order, and so the hash, stable.
cd -- "$project"
LC_ALL=C
shopt -s nullglob
files=()
for file in pyproject.toml setup.py setup.cfg requirements*.txt tox.ini; do
  if [ -f "$file" ]; then
    files+=("$file")
  fi
done
deps_hash=''
if [ "${#files[@]}" -gt 0 ]; then
  deps_hash=$(sha256 "${files[@]}" | sha256 | cut -d' ' -f1)
fi

# printf, not echo: tox_path holds backslash escapes that echo would
# expand if the caller's shell options (BASHOPTS=xpg_echo) reached it
{
  printf 'tox_path=%s\n' "$tox_path"
  printf 'deps_hash=%s\n' "$deps_hash"
} >> "$GITHUB_OUTPUT"
printf 'Cache path: %s\n' "$tox_path"
printf 'Dependency files hashed: %s\n' "${files[*]:-none}"
