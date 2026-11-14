# macos/llm.sh: lm studio, from homebrew's cask, with the settings fedora gives it; apple's gpu needs no
# engine of its own
# shellcheck shell=bash

LMS=$HOME/.lmstudio/bin/lms

llm_install() {
  lmstudio_setup
}

llm_update() {
  lmstudio_setup
}

# lmstudio_setup: lm studio's settings, once lm studio has run and put lms in ~/.lmstudio/bin
lmstudio_setup() {
  [[ -d "$APPS/LM Studio.app" ]] || return 0
  if [[ ! -x $LMS ]]; then
    todo "open LM Studio once, then run dot install again to finish setting it up"
    return 0
  fi
  lmstudio_settings
}
