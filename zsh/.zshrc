# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="" # disbaled for starship

plugins=(
  git
  )

source $ZSH/oh-my-zsh.sh
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Path
export PATH="$HOME/.local/bin:$PATH"

# fnm 
eval "$(fnm env --use-on-cd --shell zsh --version-file-strategy=recursive)"
fnm use default 2>/dev/null || true

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# fzf
source $(brew --prefix)/opt/fzf/shell/key-bindings.zsh
source $(brew --prefix)/opt/fzf/shell/completion.zsh
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# rust
export PATH="$HOME/.cargo/bin:$PATH"

# atuin
eval "$(atuin init zsh --disable-up-arrow)"

# Aliases
[ -f "$HOME/.zsh_aliases" ] && source "$HOME/.zsh_aliases"

# starship
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
eval "$(starship init zsh)"

# zoxide
eval "$(zoxide init zsh)"

# android studio
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin

# java
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export PATH=$JAVA_HOME/bin:$PATH
