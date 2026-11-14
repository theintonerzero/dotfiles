#!/usr/bin/env bash
# tests/run.sh [name...]: runs tests/test_<name>.sh, or every test file, each in a temp home with stubs
# for the system's commands; the test_macos_* files run on macos only
set -uo pipefail

# the steps need bash 4 or newer and macos's own is 3.2, so there this hands itself to homebrew's; each
# test file then runs under the bash this one does, whichever bash PATH finds first
if ((BASH_VERSINFO[0] < 4)); then
  [[ -x /opt/homebrew/bin/bash ]] || { echo "the tests need bash 4 or newer: brew install bash" >&2; exit 1; }
  exec /opt/homebrew/bin/bash "$0" "$@"
fi

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
files=()
if (($#)); then
  for name; do files+=("$dir/test_$name.sh"); done
else
  files=("$dir"/test_*.sh)
fi

failed=0
for file in "${files[@]}"; do
  name=$(basename "$file")
  if [[ $name == test_macos_* && $(uname -s) != Darwin ]]; then
    echo "skip $name"
  elif "$BASH" "$file"; then
    echo "ok $name"
  else
    echo "FAIL $name"
    failed=1
  fi
done
exit "$failed"
