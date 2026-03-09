#!/usr/bin/env bash
set -euo pipefail

case "$(uname)" in
Darwin)
  if command -v brew >/dev/null 2>&1; then
    brew bundle --file="$(pwd)/Brewfile"
  else
    echo "Homebrew is not installed."
    exit 1
  fi
  ;;
Linux)
  echo "Linux bootstrap not set up yet."
  echo "Install packages manually for now."
  ;;
*)
  echo "Unsupported OS."
  exit 1
  ;;
esac
