# OS detection
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *)      OS="unknown" ;;
esac

# Homebrew prefix (macOS only)
if [ "$OS" = "macos" ]; then
  BREW_PREFIX="$(brew --prefix)"
fi

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="" # disbaled for starship

plugins=(
  git
  )

source $ZSH/oh-my-zsh.sh

# zsh plugins
if [ "$OS" = "macos" ]; then
  [ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
  [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Path
export PATH="$HOME/.local/bin:$PATH"

# fnm
if [ -d "$HOME/.local/share/fnm" ]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
fi
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --shell zsh --version-file-strategy=recursive)"
  fnm use default 2>/dev/null || true
fi

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
fi

# fzf
if command -v fzf &>/dev/null; then
  if fzf --zsh &>/dev/null; then
    eval "$(fzf --zsh)"
  else
    for d in "$BREW_PREFIX/opt/fzf/shell" /usr/share/fzf/shell /usr/share/fzf; do
      [ -f "$d/key-bindings.zsh" ] && source "$d/key-bindings.zsh"
      [ -f "$d/completion.zsh" ] && source "$d/completion.zsh"
    done
  fi
fi
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# rust
export PATH="$HOME/.cargo/bin:$PATH"

# atuin
[ -d "$HOME/.atuin/bin" ] && export PATH="$HOME/.atuin/bin:$PATH"
command -v atuin &>/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# Aliases
[ -f "$HOME/.zsh_aliases" ] && source "$HOME/.zsh_aliases"

# starship
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
command -v starship &>/dev/null && eval "$(starship init zsh)"

# zoxide
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# android studio
if [ "$OS" = "macos" ]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
else
  export ANDROID_HOME="$HOME/Android/Sdk"
fi
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin

# java
if [ "$OS" = "macos" ]; then
  export JAVA_HOME=$(/usr/libexec/java_home -v 17 2>/dev/null)
elif command -v java &>/dev/null; then
  export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
fi
[ -n "$JAVA_HOME" ] && export PATH=$JAVA_HOME/bin:$PATH
