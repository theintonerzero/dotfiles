# ------------------------------------------------------------
# oh-my-zsh installation directory
# ------------------------------------------------------------

export ZSH="$HOME/.oh-my-zsh"

# ------------------------------------------------------------
# android sdk configuration
# ------------------------------------------------------------

export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"

# ------------------------------------------------------------
# oh-my-zsh plugins
# ------------------------------------------------------------

plugins=(
  git
  fzf
  zsh-autocomplete
  zsh-autosuggestions
  zsh-history-substring-search
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# ------------------------------------------------------------
# history configuration
# ------------------------------------------------------------

setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_VERIFY

# ------------------------------------------------------------
# completion configuration
# ------------------------------------------------------------

# case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# interactive completion menu
zstyle ':completion:*' menu select

# ------------------------------------------------------------
# terminal title
# ------------------------------------------------------------

precmd() { print -Pn "\e]0;%~ (%b)\a" }

# ------------------------------------------------------------
# shell tools
# ------------------------------------------------------------

eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"
eval "$(starship init zsh)"