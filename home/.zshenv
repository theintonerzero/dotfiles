# ------------------------------------------------------------
# shared zsh environment (all shells)
# ------------------------------------------------------------

export EDITOR="nvim"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--FRX}"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export LANG="${LANG:-en_US.UTF-8}"

# ------------------------------------------------------------
# local machine-specific overrides
# ------------------------------------------------------------

[[ -f "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"
