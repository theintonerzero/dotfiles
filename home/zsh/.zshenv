# every zsh reads this first, scripts too: the xdg folders, zsh's own folder, PATH and the editor

# a shell started in a folder that's since been deleted begins at home
[[ $PWD = /* ]] || cd "$HOME"

export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
export ZDOTDIR=$XDG_CONFIG_HOME/zsh

# your scripts, mise's tools and cargo's first; mason's language servers last, for claude code's plugins
typeset -U path
path=(~/.local/bin $XDG_DATA_HOME/mise/shims ~/.cargo/bin $path $XDG_DATA_HOME/nvim/mason/bin)

export EDITOR=nvim VISUAL=nvim PAGER=less LESS='-R -F -i -M'
export EZA_ICONS_AUTO=1
export FZF_DEFAULT_OPTS_FILE=$XDG_CONFIG_HOME/fzf/fzfrc
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
