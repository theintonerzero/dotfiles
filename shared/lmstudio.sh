# shared/lmstudio.sh: lm studio's settings, which are the same file on every os
# shellcheck shell=bash

# lmstudio_settings: lmstudio-settings.json merged into lm studio's settings, which it makes on its first
# run; your own settings stay, and lm studio is closed for it, as it keeps its settings while it runs
lmstudio_settings() {
  local file=$HOME/.lmstudio/settings.json merged
  [[ -s $file ]] || return 0
  if ! merged=$(jq -s '.[0] * .[1]' "$file" "$DOTFILES/shared/lmstudio-settings.json" 2>/dev/null); then
    warn "lm studio's settings.json isn't valid json, so it's left as it is"
    return 0
  fi
  [[ $merged == "$(jq . "$file")" ]] && return 0
  if pgrep -x lm-studio >/dev/null; then
    todo "quit LM Studio, then run dot install again for its settings"
    return 0
  fi
  say "setting lm studio's settings"
  printf '%s\n' "$merged" >"$file.new"
  mv -f "$file.new" "$file"
}
