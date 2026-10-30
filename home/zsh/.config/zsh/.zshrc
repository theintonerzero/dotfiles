# zsh for an interactive shell; each plugin and tool loads only when it's installed

# claude code's shells get only the environment, from ~/.zshenv
[[ -n $CLAUDECODE ]] && return

# options and history
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT INTERACTIVE_COMMENTS EXTENDED_GLOB \
  NO_BEEP NO_FLOW_CONTROL
[[ -d $XDG_STATE_HOME/zsh && -d $XDG_CACHE_HOME/zsh ]] || mkdir -p $XDG_STATE_HOME/zsh $XDG_CACHE_HOME/zsh
HISTFILE=$XDG_STATE_HOME/zsh/history
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY INC_APPEND_HISTORY_TIME HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE \
  HIST_REDUCE_BLANKS HIST_VERIFY HIST_FCNTL_LOCK
# ctrl+w stops at a /
WORDCHARS=${WORDCHARS//\/}

# keys: emacs, with up and down searching the history for what's typed so far
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# completion; the full check for new completions runs once a day
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
autoload -Uz compinit
zcompdump=$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION
if [[ -n $zcompdump(#qN.mh+24) || ! -s $zcompdump ]]; then
  compinit -i -d $zcompdump
else
  compinit -C -d $zcompdump
fi
unset zcompdump

# fzf's keys (ctrl+t files, alt+c folders; ctrl+r is atuin's), then fzf-tab, which binds tab last
if (( $+commands[fzf] )); then
  FZF_CTRL_R_COMMAND= source <(fzf --zsh)
fi
if [[ -r $XDG_DATA_HOME/zsh/fzf-tab/fzf-tab.plugin.zsh ]]; then
  source $XDG_DATA_HOME/zsh/fzf-tab/fzf-tab.plugin.zsh
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
fi

# the tools: mise, atuin, starship and zoxide (as cd)
(( $+commands[mise] )) && eval "$(mise activate zsh)"
(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"
(( $+commands[starship] )) && eval "$(starship init zsh)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd cd)"

source $ZDOTDIR/aliases.zsh
source $ZDOTDIR/functions.zsh

# suggestions, then highlighting, last: it wraps every widget made before it
if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi
if [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
