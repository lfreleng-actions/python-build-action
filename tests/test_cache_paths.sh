#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation

# Tests for scripts/cache-paths.sh: the glob-safe .tox cache path and
# the dependency hash derived from path_prefix. The expected tox_path
# strings are what @actions/glob, which actions/cache uses to read
# `path`, matches to the named directory alone.
#
# Usage: bash tests/test_cache_paths.sh

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/cache-paths.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Physical path, so assertions match what the script derives
work=$(cd -P "$work" && pwd)
ws="$work/ws"
failures=0
rc=0
out=''
tox_path=''
deps_hash=''

fail() {
  echo "  FAIL: $*"
  failures=$((failures + 1))
}

assert_eq() {
  local expected="$1" actual="$2" what="$3"
  if [ "$expected" != "$actual" ]; then
    fail "$what: expected '$expected', got '$actual'"
  fi
}

# Write a project's dependency files; each holds its directory name
make_project() {
  mkdir -p "$1/.tox"
  printf '%s\n' "$1" > "$1/pyproject.toml"
  printf '%s\n' "$1" > "$1/tox.ini"
}

# Run the script from the working directory $1 with path_prefix $2 and,
# optionally, GITHUB_WORKSPACE $3; extra_env adds environment entries
extra_env=()
derive() {
  local output="$work/github_output"
  : > "$output"
  rc=0
  out=$(cd "$1" && env -u CDPATH ${extra_env[@]+"${extra_env[@]}"} \
    GITHUB_WORKSPACE="${3:-$ws}" GITHUB_OUTPUT="$output" \
    INPUTS_PATH_PREFIX="$2" bash "$script" 2>&1) || rc=$?
  tox_path=$(sed -n 's/^tox_path=//p' "$output")
  deps_hash=$(sed -n 's/^deps_hash=//p' "$output")
  outputs=$(cat "$output")
}

setup_workspace() {
  rm -rf "$ws" "$work/outside" "$work/ws-link"
  mkdir -p "$ws"
  make_project "$ws"
  for dir in sub x a/b 'glob[1]' glob1 'a*b' 'a?b' axb '!bang' bang \
      '#hash' 'back\slash' project; do
    make_project "$ws/$dir"
  done
  make_project "$work/outside"
  ln -s "$ws" "$work/ws-link"
}

test_root_spellings() {
  for prefix in '.' './' ''; do
    derive "$ws" "$prefix"
    assert_eq 0 "$rc" "rc for '$prefix'"
    assert_eq './.tox' "$tox_path" "tox_path for '$prefix'"
  done
}

test_equivalent_spellings_share_one_path_and_hash() {
  derive "$ws" 'sub'
  local want_hash="$deps_hash"
  [ -n "$want_hash" ] || fail "no hash for 'sub'"
  for prefix in 'sub/' 'sub//' './sub' 'x/../sub' "$ws/sub" \
      "$work/ws-link/sub"; do
    derive "$ws" "$prefix"
    assert_eq 0 "$rc" "rc for '$prefix'"
    assert_eq './sub/.tox' "$tox_path" "tox_path for '$prefix'"
    assert_eq "$want_hash" "$deps_hash" "deps_hash for '$prefix'"
  done
  derive "$ws" 'sub/..'
  assert_eq './.tox' "$tox_path" "tox_path for 'sub/..'"
  derive "$ws" 'a/b'
  assert_eq './a/b/.tox' "$tox_path" "tox_path for 'a/b'"
}

test_resolves_relative_to_working_directory() {
  derive "$ws/sub" '.'
  assert_eq './sub/.tox' "$tox_path" "tox_path for '.' run from sub"
}

test_workspace_given_through_symlink() {
  # Both sides compare as physical paths, so the project still resolves
  # inside the workspace rather than to an absolute path
  derive "$ws" 'sub' "$work/ws-link"
  assert_eq './sub/.tox' "$tox_path" "tox_path with a symlinked workspace"
}

test_glob_characters_are_escaped() {
  derive "$ws" 'glob[1]'
  assert_eq './glob[[]1]/.tox' "$tox_path" "tox_path for 'glob[1]'"
  derive "$ws" 'a*b'
  assert_eq './a[*]b/.tox' "$tox_path" "tox_path for 'a*b'"
  derive "$ws" 'a?b'
  assert_eq './a[?]b/.tox' "$tox_path" "tox_path for 'a?b'"
  derive "$ws" 'back\slash'
  assert_eq './back\\slash/.tox' "$tox_path" "tox_path for 'back\\slash'"
}

test_escaping_ignores_inherited_shell_options() {
  # BASHOPTS=xpg_echo makes echo expand backslash escapes, which would
  # halve the backslashes the escaping adds
  extra_env=(BASHOPTS=xpg_echo)
  test_glob_characters_are_escaped
}

test_leading_negation_and_comment_stay_literal() {
  derive "$ws" '!bang'
  assert_eq './!bang/.tox' "$tox_path" "tox_path for '!bang'"
  derive "$ws" '#hash'
  assert_eq './#hash/.tox' "$tox_path" "tox_path for '#hash'"
}

test_hash_reads_the_named_directory_only() {
  derive "$ws" 'glob[1]'
  local glob_hash="$deps_hash"
  derive "$ws" 'glob1'
  if [ "$glob_hash" = "$deps_hash" ]; then
    fail "'glob[1]' and 'glob1' hash the same files"
  fi
  derive "$ws" 'a*b'
  local star_hash="$deps_hash"
  derive "$ws" 'axb'
  if [ "$star_hash" = "$deps_hash" ]; then
    fail "'a*b' and 'axb' hash the same files"
  fi
}

test_hash_tracks_project_dependency_files() {
  derive "$ws" 'sub'
  local before="$deps_hash"

  # Unrelated projects, nested files and .tox contents do not count
  echo changed >> "$ws/x/pyproject.toml"
  echo changed >> "$ws/pyproject.toml"
  mkdir -p "$ws/sub/docs"
  echo docs > "$ws/sub/docs/requirements.txt"
  echo env > "$ws/sub/.tox/pyproject.toml"
  derive "$ws" 'sub'
  assert_eq "$before" "$deps_hash" "hash after unrelated changes"

  local file previous="$before"
  for file in tox.ini pyproject.toml setup.py setup.cfg \
      requirements.txt requirements-dev.txt; do
    echo changed >> "$ws/sub/$file"
    derive "$ws" 'sub'
    if [ "$previous" = "$deps_hash" ]; then
      fail "hash ignores sub/$file"
    fi
    previous="$deps_hash"
  done
}

test_hash_empty_without_dependency_files() {
  mkdir -p "$ws/empty"
  derive "$ws" 'empty'
  assert_eq 0 "$rc" "rc for a project without dependency files"
  assert_eq '' "$deps_hash" "deps_hash without dependency files"
  assert_eq './empty/.tox' "$tox_path" "tox_path for 'empty'"
}

test_project_outside_workspace() {
  derive "$ws" "$work/outside"
  assert_eq 0 "$rc" "rc for a project outside the workspace"
  assert_eq "$work/outside/.tox" "$tox_path" "tox_path outside workspace"
  [ -n "$deps_hash" ] || fail "no hash for a project outside the workspace"
  local before="$deps_hash"
  echo changed >> "$work/outside/tox.ini"
  derive "$ws" "$work/outside"
  if [ "$before" = "$deps_hash" ]; then
    fail "hash ignores changes outside the workspace"
  fi
}

test_line_breaks_are_rejected() {
  local prefix
  for prefix in 'project'$'\n' 'pro'$'\n''ject' 'project'$'\r'; do
    make_project "$ws/$prefix"
    derive "$ws" "$prefix"
    if [ "$rc" -eq 0 ]; then
      fail "$(printf 'accepted %q' "$prefix")"
    fi
    case "$out" in
      *'cannot contain line breaks'*) ;;
      *) fail "$(printf 'no line-break error for %q: %s' "$prefix" "$out")" ;;
    esac
    assert_eq '' "$outputs" "$(printf 'outputs written for %q' "$prefix")"
  done
}

test_ignores_inherited_cdpath() {
  # With CDPATH honoured, 'b' would resolve to a/b from the workspace
  local output="$work/github_output"
  : > "$output"
  rc=0
  (cd "$ws" && CDPATH="$ws/a" GITHUB_WORKSPACE="$ws" \
    GITHUB_OUTPUT="$output" INPUTS_PATH_PREFIX='b' \
    bash "$script" > /dev/null 2>&1) || rc=$?
  if [ "$rc" -eq 0 ]; then
    fail "CDPATH resolved 'b' to $(sed -n 's/^tox_path=//p' "$output")"
  fi
}

run_test() {
  echo "▶ $1"
  extra_env=()
  setup_workspace
  "$1"
}

run_test test_root_spellings
run_test test_equivalent_spellings_share_one_path_and_hash
run_test test_resolves_relative_to_working_directory
run_test test_workspace_given_through_symlink
run_test test_glob_characters_are_escaped
run_test test_escaping_ignores_inherited_shell_options
run_test test_leading_negation_and_comment_stay_literal
run_test test_hash_reads_the_named_directory_only
run_test test_hash_tracks_project_dependency_files
run_test test_hash_empty_without_dependency_files
run_test test_project_outside_workspace
run_test test_line_breaks_are_rejected
run_test test_ignores_inherited_cdpath

if [ "$failures" -gt 0 ]; then
  echo "❌ $failures assertion(s) failed"
  exit 1
fi
echo "✅ All tests passed"
