#!/usr/bin/env bash
# tests/run.sh [name...]: runs tests/test_<name>.sh, or every test file, each in a temp home with stubs
# for the system's commands; the test_macos_* files run on macos only
set -uo pipefail

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
  elif bash "$file"; then
    echo "ok $name"
  else
    echo "FAIL $name"
    failed=1
  fi
done
exit "$failed"
